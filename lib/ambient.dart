import 'dart:io';
import 'dart:isolate';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'ambient_synth.dart';
import 'l10n.dart';
import 'settings.dart';

/// Plays the chosen background sound on a loop while a book is open.
class AmbientPlayer {
  AmbientPlayer(this.settings);

  final Settings settings;
  AudioPlayer? _player;
  int _playing = -1;
  bool _disposed = false;

  /// True while a sound is being made for the first time.
  final busy = ValueNotifier(false);

  /// Starts the saved choice, if any.
  Future<void> start() => _apply();

  Future<void> select(int index) {
    settings.ambientIndex = index;
    return _apply();
  }

  Future<void> setVolume(double v) async {
    settings.ambientVolume = v;
    await _player?.setVolume(v);
  }

  Future<void> _apply() async {
    final i = settings.ambientIndex;
    if (i == _playing || _disposed) return;
    _playing = i;
    try {
      await _player?.stop();
      if (i < 0) return;
      busy.value = true;
      final file = await ambientFile(i).whenComplete(() => busy.value = false);
      if (_playing != i || _disposed) return; // changed while it was being made
      final p = _player ??= AudioPlayer();
      await p.setReleaseMode(ReleaseMode.loop);
      await p.setVolume(settings.ambientVolume);
      await p.play(DeviceFileSource(file.path));
    } catch (_) {
      // No audio device: reading goes on in silence.
    }
  }

  void dispose() {
    _disposed = true;
    _player?.dispose();
  }
}

/// The loop for sound [index], made once and kept in the app's files.
Future<File> ambientFile(int index) async {
  final dir = Directory('${(await getApplicationSupportDirectory()).path}/ambient');
  final file = File('${dir.path}/v1_$index.wav');
  if (await file.exists()) return file;
  await dir.create(recursive: true);
  final bytes = await Isolate.run(() => ambientWav(index));
  final tmp = File('${file.path}.part');
  await tmp.writeAsBytes(bytes, flush: true);
  return tmp.rename(file.path);
}

/// Bottom sheet: pick a background sound (or none) and its volume.
Future<void> showAmbientSettings(BuildContext context, Settings settings, AmbientPlayer player) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => ListenableBuilder(
      listenable: settings,
      builder: (ctx, _) {
        final s = S.of(ctx);
        final on = settings.ambientIndex >= 0;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(s.ambientMenu, style: Theme.of(ctx).textTheme.titleMedium),
                  subtitle: Text(s.ambientHint),
                ),
                ListTile(
                  enabled: on,
                  leading: Icon(on ? Icons.volume_up : Icons.volume_off),
                  title: Slider(value: settings.ambientVolume, onChanged: on ? player.setVolume : null),
                  subtitle: Text(s.volume),
                ),
                ValueListenableBuilder(
                  valueListenable: player.busy,
                  builder: (_, busy, _) => busy ? const LinearProgressIndicator() : const Divider(height: 1),
                ),
                Flexible(
                  child: RadioGroup<int>(
                    groupValue: settings.ambientIndex,
                    onChanged: (v) => player.select(v ?? -1),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        RadioListTile<int>(value: -1, title: Text(s.ambientOff)),
                        for (var i = 0; i < ambientCount; i++)
                          RadioListTile<int>(
                            value: i,
                            title: Text('${i + 1}. ${s.ambientName(i)}'),
                            secondary: Icon(_icon(i), size: 20),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

IconData _icon(int i) {
  if (i <= 14) return Icons.forest;
  if (i <= 21) return Icons.graphic_eq;
  return Icons.music_note;
}
