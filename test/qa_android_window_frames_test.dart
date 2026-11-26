import 'package:balloon_burst/debug/qa_android_window_frames.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TJ-45F native listener is disabled in regular and public builds', () {
    expect(QaAndroidWindowFrames.enabled, isFalse);
  });

  test('disabled listener makes no platform channel calls', () async {
    await QaAndroidWindowFrames.start();
    expect(await QaAndroidWindowFrames.snapshot(), isEmpty);
    await QaAndroidWindowFrames.stop();
  });
}
