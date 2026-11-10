import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:qr_jukebox/app/qr_jukebox_app.dart';
import 'package:qr_jukebox/services/app_version.dart';

class SettingsPage extends StatefulWidget {
  final SharedPreferences prefs;
  const SettingsPage({super.key, required this.prefs});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _pathCtrl;
  late final TextEditingController _offsetCtrl;

  @override
  void initState() {
    super.initState();
    _pathCtrl = TextEditingController(
      text: widget.prefs.getString('mediaRootPath') ?? '',
    );
    _offsetCtrl = TextEditingController(
      text: (widget.prefs.getInt('playbackStartOffset') ?? 0).toString(),
    );
  }

  @override
  void dispose() {
    _pathCtrl.dispose();
    _offsetCtrl.dispose();
    super.dispose();
  }

  Future<void> _savePath(String path) async {
    await widget.prefs.setString('mediaRootPath', path.trim());
    if (mounted) setState(() {});
  }

  Future<void> _saveOffset(String value) async {
    final offset = int.tryParse(value) ?? 0;
    await widget.prefs.setInt('playbackStartOffset', offset);
    if (mounted) setState(() {});
  }

  Future<void> _toggleStopwatch(bool value) async {
    await widget.prefs.setBool('showStopwatch', value);
    if (mounted) setState(() {});
  }

  Future<void> _toggleKeepAwake(bool value) async {
    await widget.prefs.setBool('keepAwake', value);
    WakelockPlus.toggle(enable: value);
    if (mounted) setState(() {});
  }

  Future<void> _pickDir() async {
    try {
      String? selectedDirectory = await FilePicker.getDirectoryPath();

      if (selectedDirectory != null) {
        setState(() {
          _pathCtrl.text = selectedDirectory;
        });
        await _savePath(selectedDirectory);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking folder: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'system',
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto),
                ),
                ButtonSegment(
                  value: 'light',
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode),
                ),
                ButtonSegment(
                  value: 'dark',
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode),
                ),
              ],
              selected: {widget.prefs.getString('themeMode') ?? 'system'},
              onSelectionChanged: (newSelection) async {
                final jukeboxApp = QRJukeboxApp.of(context);
                final mode = newSelection.first;
                await widget.prefs.setString('themeMode', mode);
                if (!mounted) return;
                jukeboxApp?.reloadTheme();
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Dynamic Color'),
            subtitle: const Text('Use Material You system wallpaper colors'),
            value: widget.prefs.getBool('useDynamicColor') ?? true,
            onChanged: (value) async {
              final jukeboxApp = QRJukeboxApp.of(context);
              await widget.prefs.setBool('useDynamicColor', value);
              if (!mounted) return;
              jukeboxApp?.reloadTheme();
              setState(() {});
            },
            secondary: const Icon(Icons.palette_outlined),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 16),
          Text('Device Settings',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Keep Screen Awake'),
            subtitle: const Text('Prevent device from sleeping while using the app'),
            value: widget.prefs.getBool('keepAwake') ?? true,
            onChanged: _toggleKeepAwake,
            secondary: const Icon(Icons.lightbulb_outline),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 16),
          Text('Playback Settings',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Show Stopwatch'),
            subtitle: const Text('Track time spent on each card'),
            value: widget.prefs.getBool('showStopwatch') ?? false,
            onChanged: _toggleStopwatch,
            secondary: const Icon(Icons.timer_outlined),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _offsetCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Playback Start Offset (seconds)',
              hintText: 'e.g. 30',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.fast_forward_outlined),
            ),
            onChanged: _saveOffset,
          ),

          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 16),

          Text('Media Folder',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _pickDir,
              icon: const Icon(Icons.folder_open),
              label: const Text('Choose Folder'),
            ),
          ),
          const SizedBox(height: 2),
          if (_pathCtrl.text.isEmpty) ...[
            Text(
              'No folder selected!',
              style: TextStyle(
                fontSize: 24,
                color: cs.error,
              ),
            ),
          ] else ...[
            Text(
              'Selected folder: ${_pathCtrl.text}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          const Text('Expected folder structure:'),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '<Media Folder>/\n'
                  '└── example.com/\n'
                  '    └── de_original-game-edition/\n'
                  '        ├── 00015_Song Title.mp3\n'
                  '        ├── 00016_Another Song.mp3\n'
                  '        └── aaaa0015_Superhits-Extension/\n'
                  '            ├── 00015_Song Title.mp3\n'
                  '            └── 00016_Another Song.mp3',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: cs.onSurface,
              ),
            ),
          ),

          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Image.asset(
                  'assets/branding/app_icon_inapp.png',
                  width: 64,
                  height: 64,
                  color: cs.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'QR Jukebox',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Version ${AppVersion.version}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                Text(
                  'Created by Lennard Hanß',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse('https://github.com/lexygo/QRJukebox'),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.code),
                  label: const Text('Further information in GitHub'),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
