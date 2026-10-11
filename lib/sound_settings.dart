import 'package:flutter/material.dart';

import 'flip_sounds.dart';
import 'l10n.dart';
import 'settings.dart';

/// Bottom sheet: switch the page-turn sound on or off, pick one of ten
/// sounds (tapping one plays it) and set the volume.
Future<void> showSoundSettings(BuildContext context, Settings settings, FlipSounds sounds) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => ListenableBuilder(
      listenable: settings,
      builder: (ctx, _) {
        final s = S.of(ctx);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            child: ListView(
              shrinkWrap: true,
              children: [
                SwitchListTile(
                  title: Text(s.soundSwitch),
                  secondary: Icon(settings.soundOn ? Icons.volume_up : Icons.volume_off),
                  value: settings.soundOn,
                  onChanged: (v) => settings.soundOn = v,
                ),
                ListTile(
                  enabled: settings.soundOn,
                  leading: const Icon(Icons.tune),
                  title: Slider(
                    value: settings.volume,
                    onChanged: settings.soundOn ? (v) => settings.volume = v : null,
                    onChangeEnd: (_) => sounds.preview(settings.soundIndex),
                  ),
                  subtitle: Text(s.volume),
                ),
                const Divider(),
                RadioGroup<int>(
                  groupValue: settings.soundIndex,
                  onChanged: (v) {
                    if (v == null || !settings.soundOn) return;
                    settings.soundIndex = v;
                    sounds.preview(v);
                  },
                  child: Column(
                    children: [
                      for (var i = 0; i < flipSoundCount; i++)
                        RadioListTile<int>(
                          value: i,
                          enabled: settings.soundOn,
                          title: Text('${i + 1}. ${s.soundName(i)}'),
                          secondary: IconButton(
                            tooltip: s.preview,
                            icon: const Icon(Icons.play_circle_outline),
                            onPressed: () => sounds.preview(i),
                          ),
                        ),
                    ],
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
