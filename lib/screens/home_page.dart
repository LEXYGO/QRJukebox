import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

import 'package:qr_jukebox/screens/scanner_page.dart';
import 'package:qr_jukebox/screens/settings_page.dart';
import 'package:qr_jukebox/screens/player_page.dart';
import 'package:qr_jukebox/utils/url_parser.dart';

class HomePage extends StatefulWidget {
  final SharedPreferences prefs;
  const HomePage({super.key, required this.prefs});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  String get _mediaRoot => widget.prefs.getString('mediaRootPath') ?? '';

  void _handleUrl(String url) {
    final parsed = parseUrl(url);
    if (parsed == null) {
      _snack('Invalid URL format');
      return;
    }
    if (_mediaRoot.isEmpty) {
      _snack('Please set the media folder in settings first.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPage(
          parsed: parsed,
          mediaRoot: _mediaRoot,
          prefs: widget.prefs,
        ),
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _startScanner() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerPage()),
    );
    if (result != null && mounted) _handleUrl(result);
  }

  void _showUrlDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter URL'),
        content: TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: 'URL',
            hintText: 'example.com/de/aaaa0015/00015',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (_) => _submitDialog(ctx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => _submitDialog(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _submitDialog(BuildContext ctx) {
    final url = _urlController.text.trim();
    _urlController.clear();
    Navigator.pop(ctx);
    if (url.isNotEmpty) _handleUrl(url);
  }

  void _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SettingsPage(prefs: widget.prefs)),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasRoot = _mediaRoot.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.inversePrimary,
        title: const Text('QR Jukebox'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_2_rounded, size: 96, color: cs.primary),
              const SizedBox(height: 12),
              Text(
                'QR Jukebox',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasRoot ? Icons.folder_rounded : Icons.folder_off,
                    size: 16,
                    color: hasRoot ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      hasRoot
                          ? path.basename(_mediaRoot)
                          : 'No media folder configured',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: hasRoot ? Colors.green : Colors.orange,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _startScanner,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR Code'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showUrlDialog,
                  icon: const Icon(Icons.edit),
                  label: const Text('Enter URL manually'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              if (!hasRoot) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Setup Media Folder'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: Colors.orange,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
