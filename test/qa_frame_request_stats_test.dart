import 'package:balloon_burst/debug/qa_frame_request_stats.dart';
import 'package:balloon_burst/debug/qa_frame_request_binding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TJ-45K flag disabled by default in existing build variants', () {
    expect(QaFrameRequestFlags.enabled, isFalse);
  });

  test('request, begin and existing ticker pair without another frame loop', () {
    final s = QaFrameRequestStats()..reset();
    s.recordRequest(1000);
    s.recordBegin(18000, 1000000);
    expect(s.recordTicker(
        tickerSample: 1, wallUs: 19000, rawStampUs: 1000000), isNull);

    s.recordRequest(19010);
    s.recordBegin(39000, 1016667);
    final wallOnly = s.recordTicker(
        tickerSample: 2, wallUs: 68000, rawStampUs: 1016667);
    expect(wallOnly, isNotNull);
    expect(wallOnly!.requestToBeginUs, 19990);
    expect(wallOnly.beginToTickerUs, 29000);
    expect(wallOnly.wallGapUs, 49000);
    expect(wallOnly.engineGapUs, 16667);
    expect(s.wallOnlySlow, 1);
    expect(s.worstWallOnly.single.tickerSample, 2);

    s.recordRequest(68010);
    s.recordBegin(119000, 1033334);
    final wait = s.recordTicker(
        tickerSample: 3, wallUs: 122000, rawStampUs: 1033334);
    expect(wait, isNotNull);
    expect(wait!.requestToBeginUs, 50990);
    expect(wait.beginToTickerUs, 3000);
    expect(s.requestWaitsOverThreshold, 1);
    expect(s.worstRequestWait.single.tickerSample, 3);
    expect(s.reportFields, contains('qaFrameRequestCorrelationDiagnostic: enabled'));
    expect(s.reportFields, contains('sample=2'));
    expect(s.reportFields, contains('requestToBeginMs=50.99'));
  });

  test('only eight worst events retained, resets for next run', () {
    final s = QaFrameRequestStats()..reset();
    var t = 100;
    var raw = 1000;
    for (var i = 0; i < 20; i++) {
      s.recordRequest(t);
      t += 40000 + i * 1000;
      raw += 16667;
      s.recordBegin(t, raw);
      t += 1000;
      s.recordTicker(tickerSample: i + 1,
          wallUs: t, rawStampUs: raw);
    }
    expect(s.requestWaitsOverThreshold, 20);
    expect(s.worstRequestWait.length, 8);
    expect(s.worstRequestWait.first.requestToBeginUs, 59000);
    expect(s.worstRequestWait.last.requestToBeginUs, 52000);
    s.reset();
    expect(s.requestWaitsOverThreshold, 0);
    expect(s.worstRequestWait, isEmpty);
    expect(s.beginFrames, 0);
    expect(s.reportFields, contains('qaFrameRequestCount: 0'));
  });

  test('pause cannot join a stale request or ticker clock', () {
    final s = QaFrameRequestStats()..reset();
    s.recordRequest(5);
    s.recordBegin(15, 1000);
    s.recordTicker(tickerSample: 1, wallUs: 20, rawStampUs: 1000);
    s.recordRequest(25);
    s.markLifecycle();
    s.recordBegin(500000, 1100);
    final resumed = s.recordTicker(
        tickerSample: 2, wallUs: 500010, rawStampUs: 1100);
    expect(resumed, isNull);
    expect(s.unmatchedBegins, 1);
    expect(s.wallOnlySlow, 0);
    expect(s.tickerCallbacks, 2);
  });

  test('clock anchor preserves uncertainty and monotonic vs boottime', () {
    final s = QaFrameRequestStats()..reset();
    s.recordClockAnchor(
      dartBeforeUs: 10000, dartAfterUs: 12000,
      nativeMonotonicNs: 20000000000,
      nativeBoottimeNs: 20500000000,
    );
    expect(s.reportFields, contains('qaFrameRequestClockAnchorRoundTripUs: 2000'));
    expect(s.reportFields, contains('qaFrameRequestClockMonoAtZeroNs: 19989000000'));
    expect(s.reportFields, contains('qaFrameRequestClockBootMinusMonoNs: 500000000'));
  });

  test('a nonmatching frame timestamp never masquerades as a ticker pair', () {
    final s = QaFrameRequestStats()..reset();
    s.recordRequest(100);
    s.recordBegin(200, 1000);
    expect(s.recordTicker(tickerSample: 1,
        wallUs: 210, rawStampUs: 900), isNull);
    expect(s.unmatchedTickers, 1);
    expect(s.tickerCallbacks, 0);
  });
}
