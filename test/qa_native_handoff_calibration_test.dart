import 'package:balloon_burst/debug/qa_frame_request_stats.dart';
import 'package:balloon_burst/debug/qa_frame_request_binding.dart';
import 'package:balloon_burst/debug/qa_native_handoff_calibration.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TJ-45L flag stays disabled by default', () {
    expect(QaNativeHandoffFlags.enabled, isFalse);
    expect(QaFrameRequestFlags.enabled, isFalse);
  });

  test('minimum round trip wins; narrower native bracket breaks ties', () {
    final c = QaNativeHandoffCalibration(QaFrameRequestStats()..reset());
    expect(c.recordSample(phase: 'runStart', beforeUs: 1000,
        afterUs: 43000, monoBeforeNs: 20000000000,
        bootNs: 25000000100, monoAfterNs: 20000000200), isTrue);
    expect(c.recordSample(phase: 'runStart', beforeUs: 50000,
        afterUs: 53000, monoBeforeNs: 20049000000,
        bootNs: 25049000100, monoAfterNs: 20049000200), isTrue);
    expect(c.recordSample(phase: 'runStart', beforeUs: 54000,
        afterUs: 57000, monoBeforeNs: 20054000000,
        bootNs: 25054000100, monoAfterNs: 20054000100), isTrue);
    final best = c.anchorFor('runStart')!;
    expect(best.rttUs, 3000);
    expect(best.nativeSpanNs, 100);
    expect(best.dartMidUs, 55500);
    expect(best.bootMinusMonoNs, 5000000050);
    expect(best.nominalHalfWindowUs, 1501);
    expect(c.reportFields, contains('qaNativeHandoffrunStartBestRttUs: 3000'));
    expect(c.reportFields, contains('qaNativeHandoffrunStartValid: 3'));
  });

  test('invalid anchors rejected and reset clears prior measurements', () {
    final c = QaNativeHandoffCalibration(QaFrameRequestStats()..reset());
    expect(c.recordSample(phase: 'runStart', beforeUs: 10,
        afterUs: 5, monoBeforeNs: 100, bootNs: 200,
        monoAfterNs: 110), isFalse);
    expect(c.failures, 1);
    expect(c.anchorFor('runStart'), isNull);
    c.recordSample(phase: 'runStart', beforeUs: 10,
        afterUs: 20, monoBeforeNs: 1000, bootNs: 2000,
        monoAfterNs: 1100);
    expect(c.anchorFor('runStart'), isNotNull);
    c.reset();
    expect(c.anchorFor('runStart'), isNull);
    expect(c.failures, 0);
    expect(c.reportFields, contains('qaNativeHandoffrunStartBestRttUs: -1'));
  });

  test('early and late anchors report drift and select nearer epoch', () {
    final s = QaFrameRequestStats()..reset();
    final c = QaNativeHandoffCalibration(s);
    c.recordSample(phase: 'runStart', beforeUs: 0, afterUs: 100,
      monoBeforeNs: 10000000000, monoAfterNs: 10000000200,
      bootNs: 11000000100);
    c.recordSample(phase: 'reportExport', beforeUs: 1000000,
      afterUs: 1000100, monoBeforeNs: 11000050000,
      monoAfterNs: 11000050200, bootNs: 12000050100);
    expect(c.bestAt(500)!.phase, 'runStart');
    expect(c.bestAt(999900)!.phase, 'reportExport');
    expect(c.reportFields, contains('qaNativeHandoffOffsetDriftNs: 50000'));
    expect(c.reportFields, contains('qaNativeHandoffBootMinusMonoDriftNs: 0'));
  });

  test('late-frame evidence has boot estimates, not invented VSync', () {
    final s = QaFrameRequestStats()..reset();
    final c = QaNativeHandoffCalibration(s);
    c.recordSample(phase: 'runStart', beforeUs: 0, afterUs: 200,
      monoBeforeNs: 10000000000, monoAfterNs: 10000000100,
      bootNs: 11000000050);
    s.recordRequest(1000);
    s.recordBegin(2000, 100000);
    s.recordTicker(tickerSample: 1, wallUs: 2010, rawStampUs: 100000);
    s.recordRequest(2010);
    s.recordBegin(51000, 116667);
    s.recordTicker(tickerSample: 2, wallUs: 51020, rawStampUs: 116667);
    expect(c.eventFields, contains('qaNativeHandoffWorstWallOnly[0]'));
    expect(c.eventFields, contains('sample=2'));
    expect(c.eventFields, contains('requestToBeginUs=48990'));
    expect(c.eventFields, contains('nominalHalfWindowUs=101'));
  });

  test('nine native calls per phase; no unnecessary repeat', () async {
    const channel = MethodChannel('com.cube23.balloonburst/lifecycle');
    var calls = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getQaNativeHandoffClockAnchor');
      calls++;
      return <String, int>{
        'monoBeforeNs': 10000000000 + calls * 1000,
        'boottimeNs': 11000000000 + calls * 1000,
        'monoAfterNs': 10000000100 + calls * 1000,
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final c = QaNativeHandoffCalibration(QaFrameRequestStats()..reset());
    await c.samplePhase('runStart');
    expect(calls, QaNativeHandoffCalibration.probesPerPhase);
    await c.samplePhase('runStart');
    expect(calls, QaNativeHandoffCalibration.probesPerPhase);
    await c.samplePhase('reportExport');
    expect(calls, QaNativeHandoffCalibration.probesPerPhase * 2);
    expect(c.reportFields, contains('qaNativeHandoffreportExportValid: 9'));
    c.reset();
    await c.samplePhase('runStart');
    expect(calls, QaNativeHandoffCalibration.probesPerPhase * 3);
  });
}
