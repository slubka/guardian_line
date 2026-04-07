import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/audio_capture_service.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  RTCPeerConnection? _callerPc;
  RTCPeerConnection? _calleePc;
  MediaStream? _localStream;

  final AudioCaptureService _audioCapture = AudioCaptureService();

  bool _callActive = false;
  int _chunkCount = 0;

  static const Map<String, dynamic> _rtcConfig = {
    'iceServers': [],
    'sdpSemantics': 'unified-plan',
  };

  @override
  void initState() {
    super.initState();
    _audioCapture.onChunkReceived = (count) {
      if (mounted) setState(() => _chunkCount = count);
    };
  }

  @override
  void dispose() {
    _hangUp();
    super.dispose();
  }

  Future<bool> _requestMicPermission() async {
    debugPrint('[GuardianLine] requesting mic permission...');
    final status = await Permission.microphone.request();
    debugPrint('[GuardianLine] mic permission status: $status');
    if (!status.isGranted) {
      _showSnack('Microphone permission denied');
      return false;
    }
    return true;
  }

Future<void> _startCall() async {
    debugPrint('[GuardianLine] _startCall tapped');
    if (!await _requestMicPermission()) return;
    debugPrint('[GuardianLine] mic permission granted');

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'sampleRate': 16000,
      },
      'video': false,
    });

    _callerPc = await createPeerConnection(_rtcConfig);

    _callerPc!.onIceCandidate = (c) => _calleePc!.addCandidate(c);

    _calleePc!.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'audio') {
        debugPrint('[CallScreen] Remote audio track received — attaching');
        _audioCapture.attachToTrack(event.track);
      }
    };

    for (final track in _localStream!.getAudioTracks()) {
      await _callerPc!.addTrack(track, _localStream!);
    }

    final offer = await _callerPc!.createOffer({'offerToReceiveAudio': true});
    await _callerPc!.setLocalDescription(offer);
    await _calleePc!.setRemoteDescription(offer);

    final answer = await _calleePc!.createAnswer();
    await _calleePc!.setLocalDescription(answer);
    await _callerPc!.setRemoteDescription(answer);

    setState(() => _callActive = true);
    debugPrint('[CallScreen] ✅ Loopback call established');
  }

  Future<void> _hangUp() async {
    _audioCapture.dispose();
    await _callerPc?.close();
    await _calleePc?.close();
    _localStream?.getTracks().forEach((t) => t.stop());
    _callerPc = null;
    _calleePc = null;
    _localStream = null;
    if (mounted) {
      setState(() {
        _callActive = false;
        _chunkCount = 0;
      });
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _callActive ? Colors.greenAccent : Colors.white24,
                  boxShadow: _callActive
                      ? [BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.6),
                          blurRadius: 8,
                        )]
                      : [],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _callActive ? 'GuardianLine Active' : 'GuardianLine',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _callActive
                    ? 'Audio capture running'
                    : 'Tap to start protected call',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                ),
              ),
              if (_callActive) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'PCM CHUNKS RECEIVED',
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_chunkCount',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        '→ audio pipe confirmed',
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () {
                  debugPrint('[GuardianLine] button tapped');
                  _callActive ? _hangUp() : _startCall();
                },
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _callActive ? Colors.red : Colors.green,
                  ),
                  child: Icon(
                    _callActive ? Icons.call_end : Icons.call,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}