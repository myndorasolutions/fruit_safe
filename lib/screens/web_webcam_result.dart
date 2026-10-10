import 'dart:typed_data';

/// Outcome of the browser webcam dialog.
enum WebWebcamStatus { captured, cancelled, unavailable }

class WebWebcamResult {
  const WebWebcamResult.captured(this.bytes) : status = WebWebcamStatus.captured;

  const WebWebcamResult.cancelled()
    : status = WebWebcamStatus.cancelled,
      bytes = null;

  const WebWebcamResult.unavailable()
    : status = WebWebcamStatus.unavailable,
      bytes = null;

  final WebWebcamStatus status;
  final Uint8List? bytes;
}
