import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_flip_reader/ambient_synth.dart';

/// Loudness every quarter second, round the loop.
List<double> _envelope(Float64List x, int frame) => [
  for (var f = 0; f < x.length ~/ frame; f++)
    math.sqrt(Iterable.generate(frame, (k) => x[f * frame + k] * x[f * frame + k]).reduce((a, b) => a + b) / frame),
];

/// How closely the loudness curve matches itself shifted by 3..27 seconds
/// (1 = the same pattern comes round again).
double _selfSimilarity(List<double> e) {
  // Compare the detail, not the slow swell: take off a 4-second average.
  final d = [
    for (var i = 0; i < e.length; i++)
      e[i] - Iterable.generate(17, (k) => e[(i + k - 8) % e.length]).reduce((a, b) => a + b) / 17,
  ];
  final zero = d.fold(0.0, (s, v) => s + v * v);
  var best = 0.0;
  for (var lag = 12; lag <= d.length - 12; lag++) {
    var c = 0.0;
    for (var i = 0; i < d.length; i++) {
      c += d[i] * d[(i + lag) % d.length];
    }
    best = math.max(best, c / zero);
  }
  return best;
}

const _rhythmic = {10, 19, 20, 21, 24, 25, 26, 27};

void main() {
  test('all 30 background sounds are quiet, clean, 30-second seamless loops', () {
    final out = Platform.environment['AMBIENT_OUT'];
    const sr = 22050;
    for (var id = 0; id < ambientCount; id++) {
      final sw = Stopwatch()..start();
      final x = ambientSamples(id);
      sw.stop();
      expect(x.length, sr * 30, reason: 'length of $id');
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
      // Nor does the loudness swell or dip there: the half second either
      // side of the seam is within the range of the rest of the loop.
      final env = _envelope(x, sr ~/ 4);
      final seam = (env.first + env.last) / 2;
      final inner = env.sublist(2, env.length - 2);
      expect(seam, lessThanOrEqualTo(inner.reduce(math.max) * 1.05), reason: 'seam swell of $id');
      expect(seam, greaterThanOrEqualTo(inner.reduce(math.min) * 0.95), reason: 'seam dip of $id');
      final sim = _selfSimilarity(env);
      // Apart from sounds that keep a beat (crickets, train, clock, heart,
      // tunes), no stretch of the loop comes round again inside it.
      if (!_rhythmic.contains(id)) expect(sim, lessThan(0.45), reason: 'repeats inside $id');
      // ignore: avoid_print
      print(
        '$id rms=${rms.toStringAsFixed(3)} peak=${peak.toStringAsFixed(2)} '
        'repeat=${sim.toStringAsFixed(2)} ${sw.elapsedMilliseconds}ms',
      );
      if (out != null) File('$out/ambient_$id.wav').writeAsBytesSync(ambientWav(id));
    }
  });
}
