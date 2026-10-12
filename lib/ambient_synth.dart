import 'dart:math' as math;
import 'dart:typed_data';

/// Background sounds, made from scratch on the phone (noise, filters and
/// simple instrument models), so there are no recordings and nothing to
/// license. Each sound is a 30-second loop that never repeats inside itself
/// and meets itself seamlessly: noise is cross-faded at the seam, slow
/// swells wander freely but come back to where they started, and individual
/// events (drops, notes, chirps) wrap around the end into the start.
const ambientCount = 30;

/// A 16-bit mono WAV of background sound [id] (0-29).
Uint8List ambientWav(int id, {int sampleRate = 22050, double seconds = 30}) =>
    _wav(ambientSamples(id, sampleRate: sampleRate, seconds: seconds), sampleRate);

/// Samples of sound [id] in -1..1, levelled to a quiet background loudness.
Float64List ambientSamples(int id, {int sampleRate = 22050, double seconds = 30}) {
  final g = _Gen(sampleRate, seconds, 1000 + id);
  final x = _sounds[id](g);
  return _level(_dcBlock(x, sampleRate));
}

final List<Float64List Function(_Gen)> _sounds = [
  _ocean,
  _lightRain,
  _heavyRain,
  _thunderstorm,
  _gentleWind,
  _mountainWind,
  _leaves,
  _brook,
  _waterfall,
  _campfire,
  _crickets,
  _birds,
  _frogs,
  _windowRain,
  _underwater,
  _white,
  _pink,
  _brown,
  _fan,
  _train,
  _clock,
  _heartbeat,
  _singingBowl,
  _windChimes,
  _piano,
  _musicBox,
  _harp,
  _kalimba,
  _pad,
  _drone,
];

// ------------------------------------------------------------------ tools ---

class _Gen {
  _Gen(this.sr, double seconds, int seed) : n = (sr * seconds).round(), r = math.Random(seed);

  final int sr;
  final int n;
  final math.Random r;

  double get seconds => n / sr;

  /// Nearest frequency that repeats exactly over the loop.
  double q(double f) => (f * seconds).roundToDouble() / seconds;

  /// A phase that turns [cycles] whole times over the loop at sample [i].
  double cyc(int i, num cycles) => 2 * math.pi * cycles * i / n;

  double white() => r.nextDouble() * 2 - 1;

  double range(double a, double b) => a + (b - a) * r.nextDouble();

  /// A smooth curve in -1..1 that wanders without repeating inside the loop
  /// yet ends where it began: whole-loop waves [from]..[to] times round, with
  /// random strengths and phases.
  double Function(int i) drift([int from = 1, int to = 6]) {
    final parts = [for (var h = from; h <= to; h++) (h, range(0.4, 1) / math.sqrt(h), range(0, 2 * math.pi))];
    final norm = parts.fold(0.0, (s, p) => s + p.$2);
    return (i) {
      var v = 0.0;
      for (final (h, a, ph) in parts) {
        v += a * math.sin(cyc(i, h) + ph);
      }
      return v / norm;
    };
  }

  /// The wind's strength (about 0.15..0.95) at sample [i]; one curve per
  /// sound, so rustles and chimes follow the same gusts as the wind.
  double gust(int i) => 0.55 + 0.4 * (_gust ??= drift(1, 9))(i);
  double Function(int)? _gust;

  /// [count] event times spread over the loop, each gap varying by [jitter]
  /// around the even spacing, starting at [start].
  List<double> spaced(int count, double jitter, [double start = 0]) {
    final gaps = [for (var k = 0; k < count; k++) range(1 - jitter, 1 + jitter)];
    final sum = gaps.fold(0.0, (a, b) => a + b);
    final out = <double>[];
    var t = start;
    for (final gap in gaps) {
      out.add(t);
      t += gap * seconds / sum;
    }
    return out;
  }

  /// A noise texture: [next] is called once per sample for a little more
  /// than the loop, and the overshoot is cross-faded into the start. Only
  /// for noise: a tone that already repeats over the loop would swell at the
  /// seam, so add those afterwards.
  Float64List bed(double Function(int i) next) {
    final fade = sr; // one second
    final raw = Float64List(n + fade);
    for (var i = 0; i < raw.length; i++) {
      raw[i] = next(i);
    }
    final out = Float64List(n);
    for (var i = 0; i < n; i++) {
      if (i < fade) {
        final a = math.pi / 2 * i / fade;
        out[i] = raw[i] * math.sin(a) + raw[n + i] * math.cos(a);
      } else {
        out[i] = raw[i];
      }
    }
    return out;
  }

  /// Adds [s] into [out] starting at second [at], wrapping past the end.
  void add(Float64List out, double at, Float64List s, [double gain = 1]) {
    var j = ((at * sr).round()) % n;
    if (j < 0) j += n;
    for (var i = 0; i < s.length; i++) {
      out[j] += s[i] * gain;
      if (++j == n) j = 0;
    }
  }

  /// Random event times averaging [perSecond], shaped by [density] (0..1)
  /// at each moment.
  Iterable<double> times(double perSecond, [double Function(double t)? density]) sync* {
    var t = 0.0;
    while (true) {
      t += -math.log(1 - r.nextDouble()) / perSecond;
      if (t >= seconds) return;
      if (density == null || r.nextDouble() < density(t)) yield t;
    }
  }

  Float64List tone(double dur, double Function(double t) sample) {
    final s = Float64List((dur * sr).round());
    for (var i = 0; i < s.length; i++) {
      s[i] = sample(i / sr);
    }
    return s;
  }
}

/// One-pole low-pass.
class _Lp {
  _Lp(double f, int sr) : a = 1 - math.exp(-2 * math.pi * f / sr);
  double a;
  double y = 0;
  double run(double x) => y += a * (x - y);
  void set(double f, int sr) => a = 1 - math.exp(-2 * math.pi * f / sr);
}

/// RBJ biquad.
class _Bq {
  _Bq.lp(double f, double q, int sr) {
    lp(f, q, sr);
  }
  _Bq.hp(double f, double q, int sr) {
    final w = 2 * math.pi * f / sr, al = math.sin(w) / (2 * q), c = math.cos(w);
    _set((1 + c) / 2, -(1 + c), (1 + c) / 2, 1 + al, -2 * c, 1 - al);
  }
  _Bq.bp(double f, double q, int sr) {
    bp(f, q, sr);
  }

  double b0 = 0, b1 = 0, b2 = 0, a1 = 0, a2 = 0;
  double x1 = 0, x2 = 0, y1 = 0, y2 = 0;

  void lp(double f, double q, int sr) {
    final w = 2 * math.pi * f / sr, al = math.sin(w) / (2 * q), c = math.cos(w);
    _set((1 - c) / 2, 1 - c, (1 - c) / 2, 1 + al, -2 * c, 1 - al);
  }

  void bp(double f, double q, int sr) {
    final w = 2 * math.pi * f / sr, al = math.sin(w) / (2 * q), c = math.cos(w);
    _set(al, 0, -al, 1 + al, -2 * c, 1 - al);
  }

  void _set(double nb0, double nb1, double nb2, double a0, double na1, double na2) {
    b0 = nb0 / a0;
    b1 = nb1 / a0;
    b2 = nb2 / a0;
    a1 = na1 / a0;
    a2 = na2 / a0;
  }

  double run(double x) {
    final y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
    x2 = x1;
    x1 = x;
    y2 = y1;
    y1 = y;
    return y;
  }
}

/// Paul Kellet's pink noise filter.
class _Pink {
  double b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0;
  double run(double w) {
    b0 = 0.99886 * b0 + w * 0.0555179;
    b1 = 0.99332 * b1 + w * 0.0750759;
    b2 = 0.96900 * b2 + w * 0.1538520;
    b3 = 0.86650 * b3 + w * 0.3104856;
    b4 = 0.55000 * b4 + w * 0.5329522;
    b5 = -0.7616 * b5 - w * 0.0168980;
    final y = b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362;
    b6 = w * 0.115926;
    return y * 0.11;
  }
}

/// Leaky integrated noise.
class _Brown {
  double y = 0;
  double run(double w) {
    y = (y + 0.02 * w) * 0.998;
    return y * 3.5;
  }
}

/// Small room reverb (Schroeder), run over the loop twice so its tail wraps
/// into the start.
Float64List _reverb(_Gen g, Float64List x, {double mix = 0.3, double size = 1}) {
  final combs = [1557, 1617, 1491, 1422].map((d) => Float64List((d * size * g.sr / 44100).round())).toList();
  final aps = [225, 556].map((d) => Float64List((d * g.sr / 44100).round())).toList();
  final ci = List.filled(combs.length, 0), ai = List.filled(aps.length, 0);
  final lowState = List.filled(combs.length, 0.0);
  final out = Float64List(x.length);
  for (var pass = 0; pass < 2; pass++) {
    for (var i = 0; i < x.length; i++) {
      var wet = 0.0;
      for (var c = 0; c < combs.length; c++) {
        final buf = combs[c];
        final y = buf[ci[c]];
        lowState[c] = y * 0.7 + lowState[c] * 0.3; // damping
        buf[ci[c]] = x[i] + lowState[c] * 0.84;
        ci[c] = (ci[c] + 1) % buf.length;
        wet += y;
      }
      wet *= 0.25;
      for (var a = 0; a < aps.length; a++) {
        final buf = aps[a];
        final b = buf[ai[a]];
        final y = -wet + b;
        buf[ai[a]] = wet + b * 0.5;
        ai[a] = (ai[a] + 1) % buf.length;
        wet = y;
      }
      if (pass == 1) out[i] = x[i] * (1 - mix) + wet * mix * 2;
    }
  }
  return out;
}

/// Removes rumble below ~40 Hz: phone speakers can't play it and it eats
/// headroom. Runs round the loop twice so the start is settled too.
Float64List _dcBlock(Float64List x, int sr) {
  final a = _Bq.hp(40, 0.7, sr), b = _Bq.hp(40, 0.7, sr);
  final out = Float64List(x.length);
  for (var pass = 0; pass < 2; pass++) {
    for (var i = 0; i < x.length; i++) {
      out[i] = b.run(a.run(x[i]));
    }
  }
  return out;
}

/// Quiet, even loudness: about -20 dBFS RMS, peaks no higher than -4 dBFS.
Float64List _level(Float64List x) {
  var sum = 0.0, peak = 0.0;
  for (final v in x) {
    sum += v * v;
    peak = math.max(peak, v.abs());
  }
  final rms = math.sqrt(sum / x.length);
  if (rms == 0) return x;
  final k = math.min(0.1 / rms, 0.63 / peak);
  for (var i = 0; i < x.length; i++) {
    x[i] *= k;
  }
  return x;
}

Uint8List _wav(Float64List x, int sr) {
  final b = ByteData(44 + x.length * 2);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      b.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  b.setUint32(4, 36 + x.length * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, sr, Endian.little);
  b.setUint32(28, sr * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  str(36, 'data');
  b.setUint32(40, x.length * 2, Endian.little);
  for (var i = 0; i < x.length; i++) {
    b.setInt16(44 + i * 2, (x[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  return b.buffer.asUint8List();
}

double _env(double t, double attack, double decay) => t < attack ? t / attack : math.exp(-(t - attack) / decay);

double _midi(num m) => 440 * math.pow(2, (m - 69) / 12).toDouble();

// ----------------------------------------------------------------- nature ---

Float64List _ocean(_Gen g) {
  final lp = _Bq.lp(800, 0.7, g.sr), rumble = _Lp(120, g.sr), br = _Brown();
  const lo = 0.06;
  // Four waves of different lengths and sizes: a quick rise, then a long wash.
  final starts = [for (final t in g.spaced(4, 0.3)) (t * g.sr).round(), g.n];
  final heights = [for (var k = 0; k < 4; k++) g.range(0.55, 1.0)];
  final swell = g.drift(1, 4);
  var w = 0;
  return g.bed((raw) {
    final i = raw % g.n;
    if (i == 0) w = 0;
    while (i >= starts[w + 1]) {
      w++;
    }
    final p = (i - starts[w]) / (starts[w + 1] - starts[w]);
    final shape = p < 0.3 ? math.pow(p / 0.3, 2) : (math.exp(-(p - 0.3) * 4) - math.exp(-2.8)) / (1 - math.exp(-2.8));
    final e = lo + (1 - lo) * heights[w] * shape;
    if (i % 32 == 0) lp.lp(300 + 2200 * e, 0.7, g.sr);
    final surf = lp.run(g.white()) * (0.2 + 0.8 * e);
    return surf + rumble.run(br.run(g.white())) * (0.5 + 0.15 * swell(i));
  });
}

Float64List _drop(_Gen g, {double f = 0, double len = 0.004}) {
  final hp = _Bq.hp(1500, 0.7, g.sr);
  final freq = f > 0 ? f : g.range(2000, 5000);
  return g.tone(len + 0.02, (t) {
    final click = hp.run(g.white()) * _env(t, 0.0005, len / 3);
    final plink = math.sin(2 * math.pi * freq * t) * _env(t, 0.001, 0.006) * 0.4;
    return click + plink;
  });
}

Float64List _rainBed(_Gen g, double bright) {
  final pink = _Pink(), hp = _Bq.hp(500, 0.7, g.sr), lp = _Bq.lp(2500 + 4000 * bright, 0.7, g.sr);
  final d = g.drift();
  return g.bed((i) => lp.run(hp.run(pink.run(g.white()))) * (1 + 0.15 * d(i)));
}

Float64List _lightRain(_Gen g) {
  final out = _rainBed(g, 0.2);
  for (var i = 0; i < out.length; i++) {
    out[i] *= 0.6;
  }
  final busy = g.drift(1, 5);
  for (final t in g.times(85, (t) => 0.75 + 0.25 * busy((t * g.sr).round()))) {
    g.add(out, t, _drop(g), g.range(0.05, 0.35));
  }
  return out;
}

Float64List _heavyRain(_Gen g) {
  final out = _rainBed(g, 0.8);
  final lowLp = _Lp(200, g.sr), br = _Brown();
  final low = g.bed((i) => lowLp.run(br.run(g.white())));
  for (var i = 0; i < out.length; i++) {
    out[i] = out[i] * 1.4 + low[i] * 0.4;
  }
  for (final t in g.times(250)) {
    g.add(out, t, _drop(g, len: 0.006), g.range(0.05, 0.3));
  }
  return out;
}

Float64List _thunder(_Gen g, double dur) {
  final br = _Brown(), lp = _Bq.lp(160, 0.7, g.sr), crack = _Bq.lp(1200, 0.7, g.sr);
  final rolls = List.generate(4, (_) => (g.range(0, dur * 0.6), g.range(0.6, 1.0)));
  return g.tone(dur, (t) {
    var e = 0.0;
    for (final (at, a) in rolls) {
      if (t > at) e += a * _env(t - at, 0.25, dur / 5);
    }
    final rumble = lp.run(br.run(g.white())) * e;
    final c = t < 0.4 ? crack.run(g.white()) * _env(t, 0.01, 0.12) * 0.6 : 0.0;
    return rumble + c;
  });
}

Float64List _thunderstorm(_Gen g) {
  final out = _heavyRain(g);
  for (var i = 0; i < out.length; i++) {
    out[i] *= 0.7;
  }
  // Three rolls of different sizes at uneven times; the last may run over
  // the end and finish at the start.
  final at = g.spaced(3, 0.35, g.range(0.5, 3));
  final sizes = [(9.0, 2.2), (6.0, 1.0), (8.0, 1.6)]..shuffle(g.r);
  for (var k = 0; k < 3; k++) {
    g.add(out, at[k], _thunder(g, sizes[k].$1), sizes[k].$2);
  }
  return out;
}

Float64List _gentleWind(_Gen g) {
  final pink = _Pink(), bp = _Bq.bp(400, 0.8, g.sr);
  return g.bed((i) {
    final e = g.gust(i);
    if (i % 32 == 0) bp.bp(250 + 500 * e, 0.8, g.sr);
    return bp.run(pink.run(g.white())) * math.pow(e, 1.5);
  });
}

Float64List _mountainWind(_Gen g) {
  final pink = _Pink(), bp = _Bq.bp(400, 0.7, g.sr), whistle = _Bq.bp(600, 18, g.sr);
  return g.bed((i) {
    final e = g.gust(i);
    if (i % 32 == 0) {
      bp.bp(200 + 600 * e, 0.7, g.sr);
      whistle.bp(420 + 520 * e, 18, g.sr);
    }
    final w = g.white();
    return bp.run(pink.run(w)) * e * e + whistle.run(w) * math.pow(e, 3) * 0.9;
  });
}

Float64List _leaves(_Gen g) {
  final hp = _Bq.hp(1800, 0.7, g.sr), lp = _Bq.lp(7000, 0.7, g.sr);
  final out = Float64List(g.n);
  final bed = _gentleWind(g);
  for (var i = 0; i < g.n; i++) {
    out[i] = bed[i] * 0.5;
  }
  // Rustles: short grains of bright noise, more of them in gusts.
  for (final t in g.times(45, (t) => g.gust((t * g.sr).round()) - 0.2)) {
    final len = g.range(0.02, 0.09);
    g.add(out, t, g.tone(len, (s) => lp.run(hp.run(g.white())) * math.sin(math.pi * s / len)), g.range(0.1, 0.5));
  }
  return out;
}

Float64List _bubble(_Gen g, double f0, double len, double rise) {
  return g.tone(len, (t) {
    final f = f0 * (1 + rise * t / len);
    return math.sin(2 * math.pi * f * t) * _env(t, 0.002, len / 3);
  });
}

Float64List _brook(_Gen g) {
  final lp = _Bq.lp(1500, 0.7, g.sr), hp = _Bq.hp(200, 0.7, g.sr), pink = _Pink();
  final d = g.drift(1, 8);
  final out = g.bed((i) => lp.run(hp.run(pink.run(g.white()))) * (0.8 + 0.2 * d(i)));
  for (final t in g.times(55)) {
    g.add(out, t, _bubble(g, g.range(500, 2200), g.range(0.012, 0.05), g.range(0.3, 1.2)), g.range(0.02, 0.12));
  }
  return out;
}

Float64List _waterfall(_Gen g) {
  final pink = _Pink(), lp = _Bq.lp(3200, 0.7, g.sr), rumble = _Lp(150, g.sr), br = _Brown();
  final d = g.drift(2, 9);
  return g.bed((i) => lp.run(pink.run(g.white())) * 1.2 * (1 + 0.08 * d(i)) + rumble.run(br.run(g.white())) * 0.6);
}

Float64List _campfire(_Gen g) {
  final br = _Brown(), lp = _Lp(350, g.sr), hiss = _Bq.hp(3000, 0.7, g.sr);
  final out = g.bed((i) => lp.run(br.run(g.white())) * 0.5 + hiss.run(g.white()) * 0.02);
  // Crackles: clusters of tiny clicks; now and then a louder pop.
  for (final t in g.times(9)) {
    final clicks = 1 + g.r.nextInt(7);
    for (var c = 0; c < clicks; c++) {
      final len = g.range(0.0008, 0.003);
      final hp = _Bq.hp(1000, 0.7, g.sr);
      g.add(
        out,
        t + g.range(0, 0.04),
        g.tone(len + 0.002, (s) => hp.run(g.white()) * _env(s, 0.0002, len / 2)),
        g.range(0.15, 0.9),
      );
    }
  }
  for (final t in g.times(0.8)) {
    final bp = _Bq.bp(g.range(800, 2500), 2, g.sr);
    g.add(out, t, g.tone(0.04, (s) => bp.run(g.white()) * _env(s, 0.0005, 0.008)), g.range(1.0, 2.2));
  }
  return out;
}

Float64List _crickets(_Gen g) {
  final pink = _Pink(), lp = _Lp(600, g.sr);
  final out = g.bed((i) => lp.run(pink.run(g.white())) * 0.15);
  for (final (f, every, gain) in [(4200.0, 0.5, 1.0), (3700.0, 0.75, 0.6), (4600.0, 0.6, 0.35)]) {
    // Steady chirping, evenly round the seam too, that swells and fades.
    final mood = g.drift(1, 5);
    for (final t in g.spaced((g.seconds / every).round(), 0.08, g.range(0, every))) {
      final chirp = g.tone(0.14, (s) {
        // Three quick pulses.
        final k = (s / 0.045).floor();
        final ph = s - k * 0.045;
        final pulse = k < 3 && ph < 0.025 ? math.sin(math.pi * ph / 0.025) : 0.0;
        return math.sin(2 * math.pi * f * s) * pulse;
      });
      g.add(out, t, chirp, gain * g.range(0.7, 1.0) * (0.65 + 0.35 * mood((t * g.sr).round())));
    }
  }
  return out;
}

Float64List _birdNote(_Gen g, double f0, double f1, double len) {
  final vib = g.range(25, 60), depth = g.range(0, 300);
  var ph = 0.0;
  return g.tone(len, (t) {
    final f = f0 + (f1 - f0) * t / len + depth * math.sin(2 * math.pi * vib * t);
    ph += 2 * math.pi * f / g.sr;
    return math.sin(ph) * math.pow(math.sin(math.pi * t / len), 2);
  });
}

Float64List _birds(_Gen g) {
  final out = _gentleWind(g);
  for (var i = 0; i < out.length; i++) {
    out[i] *= 0.25;
  }
  // Three kinds of bird, each with its own range and phrase style.
  final kinds = [(2400.0, 4200.0, 0.08, 1.1), (3200.0, 5600.0, 0.05, 0.7), (1800.0, 3000.0, 0.14, 0.45)];
  for (final (lo, hi, len, rate) in kinds) {
    for (final t in g.times(rate)) {
      var at = t;
      final notes = 2 + g.r.nextInt(5);
      final gain = g.range(0.25, 0.8);
      for (var k = 0; k < notes; k++) {
        final l = len * g.range(0.6, 1.4);
        g.add(out, at, _birdNote(g, g.range(lo, hi), g.range(lo, hi), l), gain);
        at += l + g.range(0.02, 0.09);
      }
    }
  }
  return out;
}

Float64List _frogs(_Gen g) {
  final pink = _Pink(), lp = _Lp(500, g.sr);
  final out = g.bed((i) => lp.run(pink.run(g.white())) * 0.2);
  for (final (f, rate, gain) in [(380.0, 0.5, 1.0), (520.0, 0.4, 0.7), (300.0, 0.25, 0.8)]) {
    for (final t in g.times(rate)) {
      final pulses = 5 + g.r.nextInt(7);
      final bp = _Bq.bp(f * 2, 4, g.sr);
      final croak = g.tone(pulses * 0.04, (s) {
        final ph = s % 0.04;
        final buzz = math.sin(2 * math.pi * f * s) + 0.6 * math.sin(4 * math.pi * f * s);
        return bp.run(buzz) * (ph < 0.025 ? math.sin(math.pi * ph / 0.025) : 0.0);
      });
      g.add(out, t, croak, gain * g.range(0.6, 1));
    }
  }
  return out;
}

Float64List _windowRain(_Gen g) {
  final out = _lightRain(g);
  for (var i = 0; i < out.length; i++) {
    out[i] *= 0.6;
  }
  for (final t in g.times(5)) {
    g.add(out, t, _drop(g, f: g.range(1400, 3000), len: 0.01), g.range(0.15, 0.4));
  }
  return out;
}

Float64List _underwater(_Gen g) {
  final br = _Brown(), lp = _Bq.lp(420, 0.9, g.sr);
  final d = g.drift(1, 7);
  final out = g.bed((i) => lp.run(br.run(g.white())) * (0.85 + 0.25 * d(i)));
  for (final t in g.times(1.2)) {
    var at = t;
    for (var k = 0; k < 2 + g.r.nextInt(6); k++) {
      g.add(out, at, _bubble(g, g.range(250, 700), g.range(0.05, 0.12), g.range(0.5, 1.5)), g.range(0.05, 0.2));
      at += g.range(0.04, 0.15);
    }
  }
  return out;
}

// ----------------------------------------------------------------- noises ---

Float64List _white(_Gen g) {
  final lp = _Bq.lp(7000, 0.7, g.sr);
  return g.bed((_) => lp.run(g.white()));
}

Float64List _pink(_Gen g) {
  final p = _Pink();
  return g.bed((_) => p.run(g.white()));
}

Float64List _brown(_Gen g) {
  final b = _Brown(), hp = _Bq.hp(30, 0.7, g.sr);
  return g.bed((_) => hp.run(b.run(g.white())));
}

Float64List _fan(_Gen g) {
  final p = _Pink(), lp = _Bq.lp(1400, 0.7, g.sr), hp = _Bq.hp(70, 0.7, g.sr);
  final blade = g.q(13), hum = g.q(100);
  final out = g.bed((i) => lp.run(hp.run(p.run(g.white()))) * (1 + 0.06 * math.sin(2 * math.pi * blade * i / g.sr)));
  for (var i = 0; i < g.n; i++) {
    final t = i / g.sr;
    out[i] += 0.02 * math.sin(2 * math.pi * hum * t) + 0.01 * math.sin(4 * math.pi * hum * t);
  }
  return out;
}

Float64List _train(_Gen g) {
  final br = _Brown(), lp = _Bq.lp(320, 0.7, g.sr);
  final d = g.drift(1, 5);
  final out = g.bed((i) => lp.run(br.run(g.white())) * (0.9 + 0.12 * d(i)));
  Float64List clack(double gain) {
    final bp = _Bq.bp(g.range(1400, 1800), 2, g.sr);
    return g.tone(
      0.15,
      (t) =>
          bp.run(g.white()) * _env(t, 0.001, 0.025) * gain +
          math.sin(2 * math.pi * 70 * t) * _env(t, 0.002, 0.05) * gain * 0.8,
    );
  }

  // Wheels over rail joints about every 1.2 s, never quite evenly.
  final joints = g.spaced(25, 0.03);
  for (var k = 0; k < joints.length; k++) {
    final a = (k.isEven ? 1.0 : 0.8) * g.range(0.85, 1.0);
    g.add(out, joints[k], clack(a));
    g.add(out, joints[k] + g.range(0.17, 0.19), clack(a * 0.85));
  }
  return out;
}

Float64List _clock(_Gen g) {
  final br = _Brown(), lp = _Lp(300, g.sr);
  final out = g.bed((_) => lp.run(br.run(g.white())) * 0.03);
  final ticks = g.seconds.round();
  for (var k = 0; k < ticks; k++) {
    final (f1, f2) = k.isEven ? (2800.0, 4100.0) : (2300.0, 3400.0);
    final hp = _Bq.hp(2000, 0.7, g.sr);
    g.add(
      out,
      k * g.seconds / ticks,
      g.tone(0.04, (t) {
        final e = _env(t, 0.0005, 0.006);
        return (math.sin(2 * math.pi * f1 * t) + 0.6 * math.sin(2 * math.pi * f2 * t)) * e +
            hp.run(g.white()) * e * 0.5;
      }),
    );
  }
  return out;
}

Float64List _heartbeat(_Gen g) {
  final out = Float64List(g.n);
  Float64List thump(double fHi, double fLo, double gain) {
    var ph = 0.0;
    return g.tone(0.25, (t) {
      final f = fLo + (fHi - fLo) * math.exp(-t / 0.03);
      ph += 2 * math.pi * f / g.sr;
      return (math.sin(ph) + 0.35 * math.sin(2 * ph)) * _env(t, 0.006, 0.07) * gain;
    });
  }

  // 60 a minute, with the small give of a real heart.
  for (final t in g.spaced(g.seconds.round(), 0.04)) {
    final a = g.range(0.9, 1.0);
    g.add(out, t, thump(90, 45, a));
    g.add(out, t + g.range(0.28, 0.32), thump(110, 55, 0.65 * a));
  }
  return out;
}

// ------------------------------------------------------------------ music ---

/// A struck metal bowl or tube: inharmonic partials that beat slowly.
Float64List _struck(_Gen g, double f, List<double> ratios, List<double> amps, List<double> taus, {double beat = 0.8}) {
  final dur = taus.reduce(math.max) * 4;
  return g.tone(dur, (t) {
    var v = 0.0;
    for (var p = 0; p < ratios.length; p++) {
      final fp = f * ratios[p];
      final e = _env(t, 0.008, taus[p]);
      v += amps[p] * e * 0.5 * (math.sin(2 * math.pi * fp * t) + math.sin(2 * math.pi * (fp + beat * (p + 1)) * t));
    }
    return v;
  });
}

Float64List _singingBowl(_Gen g) {
  final out = Float64List(g.n);
  final pitches = [196.0, 247.0, 220.0, 165.0];
  final at = g.spaced(4, 0.25, 0.5);
  for (var k = 0; k < 4; k++) {
    g.add(
      out,
      at[k],
      _struck(g, pitches[k], [1, 2.76, 5.40, 8.93], [1, 0.45, 0.2, 0.08], [9, 6, 3.5, 2]),
      g.range(0.75, 1.0),
    );
  }
  return _reverb(g, out, mix: 0.25, size: 1.2);
}

Float64List _windChimes(_Gen g) {
  final out = _gentleWind(g);
  for (var i = 0; i < out.length; i++) {
    out[i] *= 0.15;
  }
  final tubes = [72, 74, 77, 79, 81, 84].map((m) => _midi(m + 12)).toList();
  for (final t in g.times(2.2, (t) => g.gust((t * g.sr).round()))) {
    final f = tubes[g.r.nextInt(tubes.length)];
    g.add(out, t, _struck(g, f, [1, 2.76, 5.40], [1, 0.35, 0.12], [2.5, 1.2, 0.5], beat: 1.5), g.range(0.2, 0.6));
  }
  return _reverb(g, out, mix: 0.3);
}

Float64List _pianoNote(_Gen g, double f, double dur) {
  return g.tone(dur, (t) {
    var v = 0.0;
    for (var h = 1; h <= 8; h++) {
      final fh = f * h * math.sqrt(1 + 0.0004 * h * h);
      if (fh > g.sr / 2.2) break;
      v += math.sin(2 * math.pi * fh * t) * math.pow(h, -1.4) * math.exp(-t * (0.6 + 0.5 * h));
    }
    return v * math.min(1, t / 0.004);
  });
}

/// C major pentatonic, as MIDI notes.
const _penta = [60, 62, 64, 67, 69, 72, 74, 76, 79, 81];

Float64List _piano(_Gen g) {
  final out = Float64List(g.n);
  const beats = 32; // eight to a chord
  final beat = g.seconds / beats;
  final chords = [
    [48, 55, 64],
    [45, 52, 60],
    [41, 48, 57],
    [43, 50, 59],
  ];
  var idx = 5;
  for (var b = 0; b < beats; b++) {
    if (b % 8 == 0) {
      for (final m in chords[b ~/ 8]) {
        g.add(out, b * beat, _pianoNote(g, _midi(m), 5), 0.22);
      }
    }
    if (g.r.nextDouble() < 0.75) {
      idx = (idx + g.r.nextInt(5) - 2).clamp(2, _penta.length - 1);
      g.add(out, b * beat, _pianoNote(g, _midi(_penta[idx]), 3.5), g.range(0.3, 0.45));
      if (g.r.nextDouble() < 0.25) {
        final m = _penta[(idx + 1).clamp(0, _penta.length - 1)];
        g.add(out, (b + 0.5) * beat, _pianoNote(g, _midi(m), 3), 0.25);
      }
    }
  }
  return _reverb(g, out, mix: 0.3, size: 1.1);
}

Float64List _musicBox(_Gen g) {
  final out = Float64List(g.n);
  // An original lullaby in 3/4: sixteen bars, a note per beat (0 = rest).
  const tune = [
    76, 79, 84, 83, 79, 76, 77, 81, 84, 83, 79, 0, 76, 79, 84, 86, 84, 79, 81, 77, 74, 72, 0, 0, //
    74, 77, 81, 79, 76, 72, 74, 77, 81, 79, 0, 0, 76, 79, 84, 83, 81, 79, 77, 74, 71, 72, 0, 0,
  ];
  const bass = [60, 55, 53, 55, 60, 55, 50, 48, 50, 48, 50, 55, 48, 55, 55, 48];
  final beat = g.seconds / tune.length;
  Float64List tine(double f) => g.tone(2.5, (t) {
    final e = _env(t, 0.002, 0.9);
    return (math.sin(2 * math.pi * f * t) + 0.25 * math.sin(4 * math.pi * f * t) * math.exp(-t * 3)) * e;
  });
  for (var i = 0; i < tune.length; i++) {
    if (tune[i] > 0) g.add(out, i * beat, tine(_midi(tune[i] + 12)), 0.5);
    if (i % 3 == 0) g.add(out, i * beat, tine(_midi(bass[i ~/ 3] + 12)), 0.3);
  }
  return _reverb(g, out, mix: 0.25);
}

/// Plucked string (Karplus-Strong).
Float64List _pluck(_Gen g, double f, double dur) {
  final len = math.max(2, (g.sr / f).round());
  final buf = Float64List(len);
  for (var i = 0; i < len; i++) {
    buf[i] = g.white();
  }
  final mean = buf.reduce((a, b) => a + b) / len;
  for (var i = 0; i < len; i++) {
    buf[i] -= mean;
  }
  var j = 0;
  final out = Float64List((dur * g.sr).round());
  for (var i = 0; i < out.length; i++) {
    final next = (j + 1) % len;
    final v = buf[j];
    buf[j] = 0.996 * 0.5 * (buf[j] + buf[next]);
    out[i] = v;
    j = next;
  }
  // Soften the attack's buzz.
  final lp = _Lp(3000, g.sr);
  for (var i = 0; i < out.length; i++) {
    out[i] = lp.run(out[i]);
  }
  return out;
}

Float64List _harp(_Gen g) {
  final out = Float64List(g.n);
  final chords = [
    [48, 55, 60, 64, 67, 72, 76, 79],
    [45, 52, 57, 60, 64, 69, 72, 76],
    [41, 48, 53, 57, 60, 65, 69, 72],
    [43, 50, 55, 59, 62, 67, 71, 74],
  ];
  final step = g.seconds / 64;
  for (var c = 0; c < 4; c++) {
    // Each chord is broken its own way: from the bass, wandering up and down.
    final notes = chords[c];
    var j = 0;
    for (var k = 0; k < 16; k++) {
      if (k > 0) {
        j += const [-2, -1, 1, 1, 2, 2][g.r.nextInt(6)];
        if (j < 0) j = -j;
        if (j >= notes.length) j = 2 * (notes.length - 1) - j;
        if (g.r.nextDouble() < 0.1) continue;
      }
      g.add(out, (c * 16 + k) * step, _pluck(g, _midi(notes[j]), 3), k == 0 ? 0.7 : g.range(0.35, 0.5));
    }
  }
  return _reverb(g, out, mix: 0.3, size: 1.1);
}

Float64List _kalimba(_Gen g) {
  final out = Float64List(g.n);
  const scale = [67, 69, 71, 74, 76, 79, 81, 83];
  Float64List tine(double f) => g.tone(2, (t) {
    return (math.sin(2 * math.pi * f * t) * _env(t, 0.002, 0.7) +
        0.15 * math.sin(2 * math.pi * f * 5.6 * t) * _env(t, 0.001, 0.05));
  });
  // Six phrases that each wander their own way, with a breath between them.
  const roots = [0, 3, 1, 4, 2, 0];
  final step = g.seconds / 96;
  var j = 2;
  for (var k = 0; k < 96; k++) {
    final phrase = k ~/ 16, at = k % 16;
    if (at == 0) {
      j = roots[phrase] + g.r.nextInt(3);
      g.add(out, k * step, tine(_midi(scale[roots[phrase]] - 12)), 0.3);
    } else {
      j = (j + const [-2, -1, -1, 1, 1, 2][g.r.nextInt(6)]).clamp(0, scale.length - 1);
    }
    if (at >= 14) continue;
    if (g.r.nextDouble() < (k.isEven ? 0.95 : 0.55)) {
      g.add(out, k * step, tine(_midi(scale[j])), g.range(0.35, 0.5));
    }
  }
  return _reverb(g, out, mix: 0.2);
}

Float64List _pad(_Gen g) {
  final out = Float64List(g.n);
  final chords = [
    [48, 55, 59, 64],
    [45, 52, 55, 60],
    [41, 48, 52, 57],
    [43, 50, 55, 62],
  ];
  final slot = g.seconds / 4;
  for (var c = 0; c < 4; c++) {
    for (final m in chords[c]) {
      final f = _midi(m);
      final dur = slot * 2;
      g.add(
        out,
        c * slot - slot / 2,
        g.tone(dur, (t) {
          final e = math.pow(math.sin(math.pi * t / dur), 2).toDouble();
          var v = 0.0;
          for (var h = 1; h <= 6; h++) {
            for (final d in [-0.0015, 0.0, 0.0015]) {
              v += math.sin(2 * math.pi * f * h * (1 + d) * t + h * d * 1000) / (h * h);
            }
          }
          return v * e;
        }),
        0.15,
      );
    }
  }
  return _reverb(g, out, mix: 0.35, size: 1.3);
}

Float64List _drone(_Gen g) {
  final f = g.q(136.1);
  final pink = _Pink(), bp = _Bq.bp(400, 1.5, g.sr);
  final swell = g.drift(1, 4), breathe = g.drift(1, 7);
  // Every partial turns a whole number of times per loop, the fifth too.
  final partials = [
    for (final (h, a) in const [(1.0, 1.0), (2.0, 0.5), (3.0, 0.3), (4.0, 0.15), (1.5, 0.35)]) (g.q(f * h), a),
  ];
  // Each partial beats slowly at its own rate, so the shimmer never settles
  // into a pattern.
  final beats = [
    for (final c in const [3, 7, 5, 9, 4]) (c, g.drift(1, 5)),
  ];
  final out = g.bed((i) => bp.run(pink.run(g.white())) * (0.5 + 0.5 * breathe(i)) * 0.4);
  for (var i = 0; i < g.n; i++) {
    final t = i / g.sr;
    var v = 0.0;
    for (var k = 0; k < partials.length; k++) {
      final (fh, a) = partials[k];
      final (c, wander) = beats[k];
      final w = 2 * math.pi * fh * t;
      v += a * (math.sin(w) + math.sin(w + g.cyc(i, c) + 2 * wander(i))) * 0.5;
    }
    out[i] += v * (0.8 + 0.2 * swell(i)) * 0.3;
  }
  return out;
}
