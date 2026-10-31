import 'dart:math' as math;
import 'dart:typed_data';

/// Background sounds, made from scratch on the phone (noise, filters and
/// simple instrument models), so there are no recordings and nothing to
/// license. Each sound is a 30- to 60-second loop that never repeats inside itself
/// and meets itself seamlessly: noise is cross-faded at the seam, slow
/// swells wander freely but come back to where they started, and individual
/// events (drops, notes, chirps) wrap around the end into the start.
const ambientCount = 10;

/// One background sound: how it is made, how long its loop is and the
/// random seed.
typedef _Sound = ({Float64List Function(_Gen) make, double seconds, int seed});

/// Slow, calm sounds only. Testers found most of the earlier 30 too busy
/// for reading that needs thought.
final List<_Sound> _sounds = [
  (make: _nightTrain, seconds: 40, seed: 2001),
  (make: _slowOcean, seconds: 60, seed: 2002),
  (make: _softRain, seconds: 40, seed: 2003),
  (make: _deepHum, seconds: 60, seed: 2004),
  (make: _slowBreeze, seconds: 60, seed: 2005),
  (make: _slowPad, seconds: 60, seed: 2006),
  (make: _drone, seconds: 60, seed: 2007),
  (make: _distantBowl, seconds: 60, seed: 2008),
  (make: _thaiMusicBox, seconds: _musicBoxSeconds, seed: 2009),
  (make: _slowPiano, seconds: 64, seed: 2010),
];

/// Loop length of sound [id] in seconds.
double ambientSeconds(int id) => _sounds[id].seconds;

/// A 16-bit mono WAV of background sound [id] (0-9).
Uint8List ambientWav(int id, {int sampleRate = 22050}) => _wav(ambientSamples(id, sampleRate: sampleRate), sampleRate);

/// Samples of sound [id] in -1..1, levelled to a quiet background loudness.
Float64List ambientSamples(int id, {int sampleRate = 22050}) {
  final s = _sounds[id];
  final g = _Gen(sampleRate, s.seconds, s.seed);
  final x = s.make(g);
  return _level(_dcBlock(x, sampleRate));
}

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

Float64List _drop(_Gen g, {double f = 0, double len = 0.004}) {
  final hp = _Bq.hp(1500, 0.7, g.sr);
  final freq = f > 0 ? f : g.range(2000, 5000);
  return g.tone(len + 0.02, (t) {
    final click = hp.run(g.white()) * _env(t, 0.0005, len / 3);
    final plink = math.sin(2 * math.pi * freq * t) * _env(t, 0.001, 0.006) * 0.4;
    return click + plink;
  });
}

// ----------------------------------------------------------------- noises ---

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

// ------------------------------------------------------------ slow sounds ---

/// The train, further away and slower: deeper rumble, rail joints about
/// every 2.5 s, soft clacks.
Float64List _nightTrain(_Gen g) {
  final br = _Brown(), lp = _Bq.lp(220, 0.7, g.sr);
  final d = g.drift(1, 3);
  final out = g.bed((i) => lp.run(br.run(g.white())) * (0.9 + 0.1 * d(i)));
  Float64List clack(double gain) {
    final bp = _Bq.bp(g.range(800, 1000), 1.5, g.sr);
    final soft = _Lp(1800, g.sr);
    return g.tone(
      0.25,
      (t) =>
          soft.run(bp.run(g.white())) * _env(t, 0.004, 0.04) * gain +
          math.sin(2 * math.pi * 60 * t) * _env(t, 0.006, 0.08) * gain,
    );
  }

  final joints = g.spaced(16, 0.04);
  for (var k = 0; k < joints.length; k++) {
    final a = (k.isEven ? 0.5 : 0.4) * g.range(0.85, 1.0);
    g.add(out, joints[k], clack(a));
    g.add(out, joints[k] + g.range(0.24, 0.27), clack(a * 0.8));
  }
  return out;
}

/// Long, lazy waves: five in a minute, each a slow rise and a long wash.
Float64List _slowOcean(_Gen g) {
  final lp = _Bq.lp(600, 0.7, g.sr), rumble = _Lp(110, g.sr), br = _Brown();
  const lo = 0.1;
  final starts = [for (final t in g.spaced(5, 0.2)) (t * g.sr).round(), g.n];
  final heights = [for (var k = 0; k < 5; k++) g.range(0.6, 1.0)];
  final swell = g.drift(1, 3);
  var w = 0;
  return g.bed((raw) {
    final i = raw % g.n;
    if (i == 0) w = 0;
    while (i >= starts[w + 1]) {
      w++;
    }
    final p = (i - starts[w]) / (starts[w + 1] - starts[w]);
    final shape = p < 0.4
        ? math.pow(math.sin(math.pi / 2 * p / 0.4), 2)
        : (math.exp(-(p - 0.4) * 3.5) - math.exp(-2.1)) / (1 - math.exp(-2.1));
    final e = lo + (1 - lo) * heights[w] * shape;
    if (i % 32 == 0) lp.lp(250 + 1300 * e, 0.7, g.sr);
    final surf = lp.run(g.white()) * (0.2 + 0.8 * e);
    return surf + rumble.run(br.run(g.white())) * (0.5 + 0.1 * swell(i));
  });
}

/// Steady, dark rain: a soft bed and only a few gentle drops.
Float64List _softRain(_Gen g) {
  final pink = _Pink(), hp = _Bq.hp(300, 0.7, g.sr), lp = _Bq.lp(2200, 0.7, g.sr);
  final d = g.drift(1, 3);
  final out = g.bed((i) => lp.run(hp.run(pink.run(g.white()))) * (1 + 0.08 * d(i)));
  final soft = _Lp(3000, g.sr);
  for (final t in g.times(10)) {
    final drop = _drop(g, f: g.range(1500, 2600), len: 0.008);
    for (var i = 0; i < drop.length; i++) {
      drop[i] = soft.run(drop[i]);
    }
    g.add(out, t, drop, g.range(0.03, 0.12));
  }
  return out;
}

/// Deep brown noise that breathes very slowly (a few times a minute).
Float64List _deepHum(_Gen g) {
  final b = _Brown(), hp = _Bq.hp(35, 0.7, g.sr), lp = _Bq.lp(500, 0.7, g.sr);
  final breathe = g.drift(1, 3);
  return g.bed((i) => lp.run(hp.run(b.run(g.white()))) * (0.9 + 0.1 * breathe(i)));
}

/// Wind that rises and falls over 15-30 seconds, never gusting.
Float64List _slowBreeze(_Gen g) {
  final pink = _Pink(), bp = _Bq.bp(350, 0.7, g.sr);
  final slow = g.drift(1, 3);
  return g.bed((i) {
    final e = 0.5 + 0.35 * slow(i);
    if (i % 64 == 0) bp.bp(220 + 300 * e, 0.7, g.sr);
    return bp.run(pink.run(g.white())) * e;
  });
}

/// The warm pad, with each chord held about fifteen seconds.
Float64List _slowPad(_Gen g) => _pad(g);

/// A singing bowl struck softly every twelve seconds or so, far away, over
/// a faint room tone.
Float64List _distantBowl(_Gen g) {
  final br = _Brown(), lp = _Lp(250, g.sr);
  final out = g.bed((_) => lp.run(br.run(g.white())) * 0.15);
  final pitches = [196.0, 174.6, 220.0, 164.8, 196.0];
  final at = g.spaced(5, 0.15, 0.5);
  for (var k = 0; k < 5; k++) {
    g.add(
      out,
      at[k],
      _struck(g, pitches[k], [1, 2.76, 5.40], [1, 0.3, 0.08], [10, 6, 2.5], beat: 0.5),
      g.range(0.35, 0.45),
    );
  }
  return _reverb(g, out, mix: 0.4, size: 1.3);
}

// ------------------------------------------------------------ slow music ---

/// Khang Khao Kin Kluai (ค้างคาวกินกล้วย, "the bat eats bananas"), a
/// traditional Thai folk melody, in the public domain. Thai notation: four
/// slots to a group, '-' holds the note before; a ' after a note means an
/// octave up. Played slowly, it loops after about 75 seconds.
const _khangKhao = [
  '-l-s -ssm\' --s\'m\' --r\'m\' --r\'m\' --s\'m\' s\'m\'r\'d\' --r\'m\'',
  '-l-s -ssm\' --s\'m\' --r\'m\' --s\'m\' --r\'m\' s\'m\'r\'d\' --r\'d\'',
  '---- -r\'-r\' --m\'r\' -d\'r\'- ltd\'r\' m\'r\'d\'t lslt -d\'-r\'',
  '---- -r\'-r\' --m\'r\' -d\'r\'- -r\'-r\' m\'d\'r\'m\' s\'m\'r\'d\' -t-l',
  '---- -l-l sld\'l sm-s -m-l sm-s lsms ld\'-l',
  '---- -l-l sld\'l sm-s -m-l sm-s -m-r smmm',
];

const _mbSlot = 0.38; // seconds per slot: slow, like a winding-down box

/// Each line as (slot, scale step) onsets; steps 0 = do ... 6 = ti, +7 up.
List<List<(int, int)>> _parseThai(List<String> lines) => [
  for (final line in lines)
    () {
      final out = <(int, int)>[];
      final chars = line.replaceAll(' ', '');
      var slot = 0;
      for (var i = 0; i < chars.length; i++) {
        final c = chars[i];
        if (c == '\'') continue;
        if (c != '-') {
          final step = 'drmfslt'.indexOf(c);
          final up = i + 1 < chars.length && chars[i + 1] == '\'';
          out.add((slot, step + (up ? 7 : 0)));
        }
        slot++;
      }
      return out;
    }(),
];

final double _musicBoxSeconds = _khangKhao.length * 32 * _mbSlot;

Float64List _thaiMusicBox(_Gen g) {
  final out = Float64List(g.n);
  // do = G4: the tune sits in a music box's sweet range (B4-D6).
  const steps = [0, 2, 4, 5, 7, 9, 11];
  double pitch(int n) => _midi(67 + steps[n % 7] + 12 * (n ~/ 7));
  Float64List tine(double f, double len) => g.tone(len, (t) {
    final e = _env(t, 0.003, 1.1);
    return (math.sin(2 * math.pi * f * t) +
            0.3 * math.sin(2 * math.pi * f * 2 * t) * math.exp(-t * 4) +
            0.08 * math.sin(2 * math.pi * f * 5.4 * t) * math.exp(-t * 18)) *
        e;
  });
  final lines = _parseThai(_khangKhao);
  for (var l = 0; l < lines.length; l++) {
    final t0 = l * 32 * _mbSlot;
    for (final (slot, step) in lines[l]) {
      g.add(out, t0 + slot * _mbSlot, tine(pitch(step), 2.8), g.range(0.42, 0.5));
    }
    // A soft low do or sol on every second group.
    for (var k = 0; k < 4; k++) {
      g.add(out, t0 + (k * 8 + 3) * _mbSlot, tine(_midi(k.isEven ? 43 : 50), 3.5), 0.2);
    }
  }
  return _reverb(g, out, mix: 0.3, size: 1.2);
}

Float64List _pianoNote(_Gen g, double f, double dur) {
  return g.tone(dur, (t) {
    var v = 0.0;
    for (var h = 1; h <= 8; h++) {
      final fh = f * h * math.sqrt(1 + 0.0004 * h * h);
      if (fh > g.sr / 2.2) break;
      v += math.sin(2 * math.pi * fh * t) * math.pow(h, -1.4) * math.exp(-t * (0.5 + 0.45 * h));
    }
    // Soft felt hammer: a gentle attack, and a release at the end.
    final rel = math.min(1.0, (dur - t) / 0.3);
    return v * math.min(1, t / 0.008) * rel;
  });
}

/// An original slow piano piece (written for this app): sixteen bars at 60
/// beats a minute, a quiet broken chord under a simple tune.
Float64List _slowPiano(_Gen g) {
  final out = Float64List(g.n);
  const beat = 1.0;
  // Chord per bar as root, fifth, tenth (MIDI).
  const chords = [
    [48, 55, 64], [45, 52, 60], [41, 48, 57], [43, 50, 59], //
    [48, 55, 64], [40, 47, 55], [41, 48, 57], [43, 50, 59],
    [45, 52, 60], [41, 48, 57], [48, 55, 64], [43, 50, 59],
    [41, 48, 57], [43, 50, 59], [48, 55, 64], [48, 55, 64],
  ];
  // Tune: (MIDI note or 0 for rest, beats).
  const tune = [
    [(76, 2), (79, 2)], [(81, 3), (79, 1)], [(77, 2), (76, 1), (74, 1)], [(74, 4)], //
    [(76, 2), (79, 2)], [(83, 3), (81, 1)], [(81, 2), (79, 1), (77, 1)], [(79, 4)],
    [(84, 2), (83, 1), (81, 1)], [(81, 2), (79, 2)], [(76, 2), (79, 1), (76, 1)], [(74, 4)],
    [(72, 2), (74, 1), (76, 1)], [(77, 2), (74, 2)], [(72, 4)], [(0, 4)],
  ];
  for (var bar = 0; bar < 16; bar++) {
    final t0 = bar * 4 * beat;
    final c = chords[bar];
    // Broken chord: root, fifth, tenth, fifth; the last bar just rings.
    final pattern = bar == 15 ? [c[0]] : [c[0], c[1], c[2], c[1]];
    for (var k = 0; k < pattern.length; k++) {
      g.add(out, t0 + k * beat, _pianoNote(g, _midi(pattern[k]), bar == 15 ? 4 : 2.5), k == 0 ? 0.2 : 0.13);
    }
    var t = t0;
    for (final (m, len) in tune[bar]) {
      if (m > 0) g.add(out, t + g.range(0, 0.02), _pianoNote(g, _midi(m), len * beat + 1.2), g.range(0.36, 0.42));
      t += len * beat;
    }
  }
  return _reverb(g, out, mix: 0.3, size: 1.2);
}
