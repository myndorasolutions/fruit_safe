import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:fruit_safe/screens/web_webcam_result.dart';
import 'package:fruit_safe/theme/app_theme.dart';
import 'package:web/web.dart' as web;

var _webcamViewSequence = 0;

/// Opens a live `<video>` viewfinder and returns the captured JPEG bytes.
Future<WebWebcamResult> showWebWebcam(BuildContext context) {
  return showDialog<WebWebcamResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _WebWebcamDialog(),
  ).then((result) => result ?? const WebWebcamResult.cancelled());
}

class _WebWebcamDialog extends StatefulWidget {
  const _WebWebcamDialog();

  @override
  State<_WebWebcamDialog> createState() => _WebWebcamDialogState();
}

class _WebWebcamDialogState extends State<_WebWebcamDialog> {
  web.HTMLVideoElement? _video;
  web.MediaStream? _stream;
  String? _viewType;
  var _ready = false;
  var _capturing = false;
  var _settled = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final video = web.HTMLVideoElement()
      ..autoplay = true
      ..muted = true;
    video.setAttribute('playsinline', 'true');
    video.setAttribute(
      'style',
      'width:100%;height:100%;object-fit:cover;background:#0F172A;',
    );
    _video = video;
    try {
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(video: true.toJS))
          .toDart;
      if (!mounted || _settled) {
        _stopTracks(stream);
        return;
      }
      _stream = stream;
      video.srcObject = stream;
      video.play();
      final viewType = 'fruit-safe-webcam-${_webcamViewSequence++}';
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) => video);
      setState(() {
        _viewType = viewType;
        _ready = true;
      });
    } catch (_) {
      _release();
      if (!mounted || _settled) return;
      _pop(const WebWebcamResult.unavailable());
    }
  }

  Future<void> _capture() async {
    final video = _video;
    if (video == null || _capturing || _settled || !_ready) return;
    if (video.videoWidth == 0 || video.videoHeight == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The camera is still starting. Try again.')),
      );
      return;
    }
    setState(() => _capturing = true);
    try {
      final canvas = web.HTMLCanvasElement()
        ..width = video.videoWidth
        ..height = video.videoHeight;
      final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      context.drawImage(video, 0, 0);
      final dataUrl = canvas.toDataURL('image/jpeg', 0.85.toJS);
      final bytes = _bytesFromDataUrl(dataUrl);
      _release();
      if (!mounted) return;
      _pop(WebWebcamResult.captured(bytes));
    } catch (_) {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not capture that frame. Try again.')),
      );
    }
  }

  void _close() {
    _release();
    _pop(const WebWebcamResult.cancelled());
  }

  void _pop(WebWebcamResult result) {
    if (_settled || !mounted) return;
    _settled = true;
    Navigator.of(context).pop(result);
  }

  void _release() {
    final stream = _stream;
    _stream = null;
    if (stream != null) _stopTracks(stream);
    _video?.srcObject = null;
  }

  void _stopTracks(web.MediaStream stream) {
    for (final track in stream.getTracks().toDart) {
      track.stop();
    }
  }

  Uint8List _bytesFromDataUrl(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    final payload = comma >= 0 ? dataUrl.substring(comma + 1) : dataUrl;
    return base64Decode(payload);
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewType = _viewType;
    return PopScope(
      canPop: !_capturing,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Live camera',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close camera',
                    onPressed: _capturing ? null : _close,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 360,
                    width: double.infinity,
                    child: _ready && viewType != null
                        ? HtmlElementView(viewType: viewType)
                        : const ColoredBox(
                            color: AppColors.darkSlate,
                            child: Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                button: true,
                label: 'Capture photo',
                child: Material(
                  color: _ready && !_capturing
                      ? AppColors.harvestPureGreen
                      : AppColors.harvestPureGreen.withValues(alpha: 0.45),
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _ready && !_capturing ? _capture : null,
                    child: SizedBox(
                      width: 84,
                      height: 84,
                      child: _capturing
                          ? const Padding(
                              padding: EdgeInsets.all(26),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Icon(Icons.camera_alt, color: Colors.white, size: 36),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
