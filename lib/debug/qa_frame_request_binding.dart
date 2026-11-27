import 'package:flutter/widgets.dart';
import 'package:balloon_burst/debug/auto_tap/auto_tap_controller.dart';
import 'qa_frame_request_stats.dart';
import 'qa_native_handoff_calibration.dart';

class QaFrameRequestFlags {
  static const bool enabled = kEnableQaAutoTap &&
      (bool.fromEnvironment('TJ45K_FRAME_REQUEST', defaultValue: false) ||
       bool.fromEnvironment('TJ45L_NATIVE_HANDOFF', defaultValue: false) ||
       bool.fromEnvironment('TJ45M_CLOCK_EPOCH', defaultValue: false));
}

/// TJ-45N opt-in: only emits trace breadcrumbs for bounded slow frames.
/// Not a presentation timestamp and never enabled in public/control APKs.
class QaAppFrameTraceFlags {
  static const bool enabled = QaClockEpochFlags.enabled &&
      bool.fromEnvironment('TJ45N_APP_FRAME_TRACE', defaultValue: false);
}

class QaNativeHandoffFlags {
  static const bool enabled = QaFrameRequestFlags.enabled &&
      (bool.fromEnvironment('TJ45L_NATIVE_HANDOFF', defaultValue: false) ||
       bool.fromEnvironment('TJ45M_CLOCK_EPOCH', defaultValue: false));
}

class QaClockEpochFlags {
  static const bool enabled = QaNativeHandoffFlags.enabled &&
      bool.fromEnvironment('TJ45M_CLOCK_EPOCH', defaultValue: false);
}

/// Observe the *existing* Flutter framework frame requests and begins.
/// Only constructed in the dedicated TJ-45K QA APK before runApp.
/// Does NOT schedule frames itself, attach another native VSync listener,
/// or substitute the engine's frame callback.
class QaFrameRequestBinding extends WidgetsFlutterBinding {
  static QaFrameRequestBinding? _active;
  final QaFrameRequestStats stats = QaFrameRequestStats();
  late final QaNativeHandoffCalibration handoff =
      QaNativeHandoffCalibration(stats);
  QaFrameRequestBinding() { _active = this; }
  static QaFrameRequestBinding? get active => _active;

  @override
  void scheduleFrame() {
    final shouldCount = !hasScheduledFrame && framesEnabled;
    final stamp = shouldCount ? stats.clockUs : 0;
    super.scheduleFrame();
    if (shouldCount && hasScheduledFrame) stats.recordRequest(stamp);
  }

  @override
  void handleBeginFrame(Duration? rawTimeStamp) {
    stats.recordBegin(stats.clockUs, rawTimeStamp?.inMicroseconds ?? -1);
    super.handleBeginFrame(rawTimeStamp);
  }
}
