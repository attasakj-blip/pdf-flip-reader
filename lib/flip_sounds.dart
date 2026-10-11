import 'package:audioplayers/audioplayers.dart';

import 'settings.dart';

/// Number of bundled page-turn sounds. They were synthesised for this
/// project (see tools/gen_sounds.py), so there are no licensing strings.
/// Their names are translated in l10n.dart (S.soundName).
const flipSoundCount = 10;

class FlipSounds {
  FlipSounds(this.settings);

  final Settings settings;
  // Short effects must not take audio focus: that would stop the background
  // sound (and any music app) on every page turn.
  static final _effects = AudioContext(
    android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none, usageType: AndroidUsageType.game),
  );
  late final List<AudioPlayer> _players = List.generate(2, (_) => AudioPlayer()..setAudioContext(_effects));
  bool _used = false;
  int _next = 0;

  /// Plays the selected sound if sound is switched on.
  Future<void> playTurn() async {
    if (!settings.soundOn) return;
    await preview(settings.soundIndex);
  }

  /// Plays sound [index] regardless of the on/off switch (for the picker).
  Future<void> preview(int index) async {
    // Alternate players so quick turns don't cut each other off.
    _used = true;
    final p = _players[_next];
    _next = (_next + 1) % _players.length;
    try {
      await p.stop();
      await p.setVolume(settings.volume);
      await p.play(AssetSource('sounds/flip_${(index + 1).toString().padLeft(2, '0')}.wav'));
    } catch (_) {
      // A missing audio device should never break page turning.
    }
  }

  void dispose() {
    if (!_used) return;
    for (final p in _players) {
      p.dispose();
    }
  }
}
