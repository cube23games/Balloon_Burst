import 'dart:ui' show FrameTiming;

import 'package:balloon_burst/debug/frame_phase_slow_stats.dart';
import 'package:flutter_test/flutter_test.dart';

FrameTiming frame({
  required int number,
  required int wait,
  required int build,
  required int queue,
  required int raster,
  int start = 1000000,
}) {
  final bStart = start + wait;
  final bFinish = bStart + build;
  final rStart = bFinish + queue;
  final rFinish = rStart + raster;
  return FrameTiming(
    frameNumber: number,
    vsyncStart: start,
    buildStart: bStart,
    buildFinish: bFinish,
    rasterStart: rStart,
    rasterFinish: rFinish,
    rasterFinishWallTime: rFinish,
  );
}

void main() {
  group('TJ-45E same-frame phase sampler', () {
    test('preserves four correlated stages and frame identity', () {
      final s = FramePhaseSlowStats();
      s.record(frame(number: 42, wait: 21000, build: 3000, queue: 4000, raster: 9000));
      expect(s.samples, 1);
      expect(s.slowFrames, 1);
      expect(s.dominantVsyncWait, 1);
      final f = s.worstFrames.single;
      expect(f.frameNumber, 42);
      expect(f.vsyncTimestampUs, 1000000);
      expect(f.vsyncWaitMicros, 21000);
      expect(f.buildMicros, 3000);
      expect(f.rasterQueueMicros, 4000);
      expect(f.rasterMicros, 9000);
      expect(f.totalMicros, 37000);
      expect(s.reportFields, contains('qaFramePhaseDiagnostic: enabled'));
      expect(s.reportFields, contains('frame=42'));
      expect(s.reportFields, contains('totalMs=37.00'));
    });

    test('classifies UI, queue and raster bottlenecks without double counting', () {
      final s = FramePhaseSlowStats();
      s.record(frame(number: 1, wait: 1000, build: 19000, queue: 1000, raster: 2000));
      s.record(frame(number: 2, wait: 1000, build: 1000, queue: 19000, raster: 2000));
      s.record(frame(number: 3, wait: 1000, build: 1000, queue: 2000, raster: 19000));
      expect(s.slowFrames, 3);
      expect(s.dominantUiBuild, 1);
      expect(s.dominantRasterQueue, 1);
      expect(s.dominantRasterWork, 1);
      expect(s.dominantVsyncWait, 0);
    });

    test('exact budget does not count, malformed phases are rejected', () {
      final s = FramePhaseSlowStats();
      s.record(frame(number: 10, wait: 1000, build: 3000, queue: 4000, raster: 8667));
      s.record(frame(number: 11, wait: 1000, build: 3000, queue: 4000, raster: 8668));
      s.record(frame(number: 12, wait: 1000, build: 3000, queue: -1, raster: 15000));
      expect(s.samples, 2);
      expect(s.invalidPhaseOrder, 1);
      expect(s.slowFrames, 1);
      expect(s.worstFrames.single.frameNumber, 11);
    });

    test('bounded top eight, sorted by actual total, can be reset', () {
      final s = FramePhaseSlowStats();
      for (var i = 0; i < 40; i++) {
        s.record(frame(number: i, wait: 1000+i*1000, build: 3000,
            queue: 4000, raster: 9000));
      }
      expect(s.samples, 40);
      expect(s.slowFrames, 40);
      expect(s.retainedCount, 8);
      expect(s.worstFrames.first.frameNumber, 39);
      expect(s.worstFrames.last.frameNumber, 32);
      expect(s.dominantVsyncWait+s.dominantUiBuild+
             s.dominantRasterQueue+s.dominantRasterWork, s.slowFrames);
      expect(s.reportFields.split('qaFramePhaseWorst[').length-1, 8);
      s.reset();
      expect(s.samples, 0);
      expect(s.slowFrames, 0);
      expect(s.retainedCount, 0);
      expect(s.worstFrames, isEmpty);
      s.record(frame(number: 90, wait: 1000, build: 1000,
          queue: 1000, raster: 2000));
      expect(s.samples, 1);
      expect(s.slowFrames, 0);
    });
  });
}
