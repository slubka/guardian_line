import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/audio_capture_service.dart';
import '../services/audio_classification_service.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  RTCPeerConnection? _peerConnection;
  RTCPeerConnection? _loopbackCaller; 
  final _remoteRenderer = RTCVideoRenderer();
  
  final AudioCaptureService _audioCapture = AudioCaptureService();
  final AudioClassificationService _audioClassification = AudioClassificationService(); 
  
  bool _isCallActive = false;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _setupPeerConnection();
  }

  Future<void> _initRenderers() async {
    await _remoteRenderer.initialize();
  }

  void _setupPeerConnection() async {
    final configuration = {
      'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}]
    };

    _peerConnection = await createPeerConnection(configuration);

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'audio') {
        debugPrint('Guardian Logic: Remote track detected.');
        
        // Start the service and subscriber logic
        _audioCapture.startCapture();
        _audioClassification.init(_audioCapture);

        if (mounted) setState(() => _isCallActive = true);
      }
      
      if (event.streams.isNotEmpty && event.track.kind == 'video') {
        _remoteRenderer.srcObject = event.streams[0];
      }
    };
  }

  /// Simulation: The Simulator calling itself to trigger the Callee logic
  Future<void> _simulateIncomingCall() async {
    _loopbackCaller = await createPeerConnection({
      'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}]
    });

    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': true, 
      'video': false
    });
    
    stream.getTracks().forEach((track) => _loopbackCaller!.addTrack(track, stream));

    _loopbackCaller!.onIceCandidate = (candidate) => _peerConnection?.addCandidate(candidate);
    _peerConnection!.onIceCandidate = (candidate) => _loopbackCaller?.addCandidate(candidate);

    RTCSessionDescription offer = await _loopbackCaller!.createOffer();
    await _loopbackCaller!.setLocalDescription(offer);
    await _peerConnection!.setRemoteDescription(offer);

    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    await _loopbackCaller!.setRemoteDescription(answer);
  }

  void _endCall() {
    _audioCapture.stop();
    _peerConnection?.close();
    _loopbackCaller?.close();
    if (mounted) {
      setState(() => _isCallActive = false);
    }
  }

  @override
  void dispose() {
    _audioCapture.stop();
    _remoteRenderer.dispose();
    _peerConnection?.dispose();
    _loopbackCaller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Guardian Line")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isCallActive) ...[
              const Icon(Icons.shield, color: Colors.green, size: 80),
              const Text("Monitoring Incoming Call...", 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              SizedBox(height: 200, width: 300, child: RTCVideoView(_remoteRenderer)),
            ] else ...[
              const Text("Waiting for call..."),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _simulateIncomingCall,
                child: const Text("Simulate Incoming Call"),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: _isCallActive 
        ? FloatingActionButton(
            onPressed: _endCall,
            backgroundColor: Colors.red,
            child: const Icon(Icons.call_end),
          )
        : null,
    );
  }
}