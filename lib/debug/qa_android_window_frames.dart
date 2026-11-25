import 'package:balloon_burst/debug/auto_tap/auto_tap_controller.dart';
import 'package:flutter/services.dart';

/// QA-only native HOST WINDOW probe. Surface presentation requires Perfetto.
class QaAndroidWindowFrames {
  static const bool enabled = kEnableQaAutoTap &&
      bool.fromEnvironment('TJ45F_ANDROID_PRESENTATION', defaultValue: false);
  static const MethodChannel _channel =
      MethodChannel('com.cube23.balloonburst/qa_window_frames');

  static Future<void> start() async {
    if (!enabled) return;
    try {
      await _channel.invokeMethod<bool>('start');
    } on MissingPluginException {
      // Not an Android host.
    } on PlatformException {
      // Optional instrumentation must not block gameplay.
    }
  }

  static Future<void> stop() async {
    if (!enabled) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // No host.
    } on PlatformException {
      // Best effort.
    }
  }

  static Future<String> snapshot() async {
    if (!enabled) return '';
    try {
      return await _channel.invokeMethod<String>('snapshot') ??
          'qaAndroidWindowFrameProbe: unavailable';
    } on MissingPluginException {
      return 'qaAndroidWindowFrameProbe: unavailable-host';
    } on PlatformException {
      return 'qaAndroidWindowFrameProbe: unavailable-platform';
    }
  }
}
