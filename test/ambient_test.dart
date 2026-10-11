import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_flip_reader/ambient_synth.dart';

void main() {
  test('all 30 background sounds are quiet, clean, seamless loops', () {
    final out = Platform.environment['AMBIENT_OUT'];
    for (var id = 0; id < ambientCount; id++) {
      final sw = Stopwatch()..start();
      final x = ambientSamples(id);
      sw.stop();
      expect(x.length, 22050 * 24, reason: 'length of $id');
      var sum = 0.0, peak = 0.0;
      for (final v in x) {
        expect(v.isFinite, isTrue, reason: 'finite $id');
        sum += v * v;
        peak = math.max(peak, v.abs());
      }
      final rms = math.sqrt(sum / x.length);
      expect(peak, lessThanOrEqualTo(0.64), reason: 'peak of $id');
      expect(rms, greaterThan(0.01), reason: 'loud enough $id');
      // The seam: the jump from the last sample to the first is no bigger
      // than jumps inside the loop.
      var maxStep = 0.0;
      for (var i = 1; i < x.length; i++) {
        maxStep = math.max(maxStep, (x[i] - x[i - 1]).abs());
      }
      expect((x.first - x.last).abs(), lessThanOrEqualTo(maxStep), reason: 'seam of $id');
      // ignore: avoid_print
      print('$id rms=${rms.toStringAsFixed(3)} peak=${peak.toStringAsFixed(2)} ${sw.elapsedMilliseconds}ms');
      if (out != null) File('$out/ambient_$id.wav').writeAsBytesSync(ambientWav(id));
    }
  });
}
