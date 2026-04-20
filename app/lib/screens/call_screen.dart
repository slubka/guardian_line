import 'package:app/services/interfaces/i_text_classification_service.dart';
import 'package:app/services/interfaces/i_transcription_service.dart';
import 'package:app/services/service_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/audio_capture_service.dart';
import '../services/text_classification_service.dart';
import '../services/transcription_service.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  RTCPeerConnection? _peerConnection;
  RTCPeerConnection? _loopbackCaller; 
  final _remoteRenderer = RTCVideoRenderer();
    
  bool _isCallActive = false;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _setupPeerConnection();

    _initServices();
  }

  void _initServices() {
    ServiceProvider().initializeServices();

    // we would like to process 15 second windows of audio data for classification, so we subscribe to the audio capture service with that window size
    Duration look_back_window = const Duration(seconds: 15);
    ServiceProvider().audioCaptureService.subscribe(
      look_back_window,
      (data) async {
        // pass the audio data to transcription service for conversion to text
        ServiceProvider().transcriptionService.addData(data);
      });
    
    // whenever there is text data ready, we pass it down to text classification
    ServiceProvider().transcriptionService.subscribe(
      look_back_window,
      (data) async {
        // pass the transcribed text to the text classification service for analysis
        ServiceProvider().textClassificationService.addData(data);
      });
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
        ServiceProvider().audioCaptureService.startCapture();

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
    ServiceProvider().cleanup();

    _peerConnection?.close();
    _loopbackCaller?.close();
    if (mounted) {
      setState(() => _isCallActive = false);
    }
  }

  @override
  void dispose() {
    ServiceProvider().cleanup();
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

extension on ITextClassificationService {
  void addData(Object? data) {}
}

extension on ITranscriptionService {
  void subscribe(Duration look_back_window, Future<Null> Function(data) param1) {}
}