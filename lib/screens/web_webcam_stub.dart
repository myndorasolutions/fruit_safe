import 'package:flutter/widgets.dart';
import 'package:fruit_safe/screens/web_webcam_result.dart';

/// Non-web builds use the image picker instead of a browser viewfinder.
Future<WebWebcamResult> showWebWebcam(BuildContext context) async {
  return const WebWebcamResult.unavailable();
}
