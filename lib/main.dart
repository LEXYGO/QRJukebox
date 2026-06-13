import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:marquee/marquee.dart';

// ─── Entry Point ───────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(QRJukeboxApp(prefs: prefs));
}

// ─── App Root ──────────────────────────────────────────────────────────────

class QRJukeboxApp extends StatelessWidget {
  final SharedPreferences prefs;
  const QRJukeboxApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Jukebox',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2200FF),
        ),
        useMaterial3: true,
      ),
      home: HomePage(prefs: prefs),
    );
  }
}

// ─── Helpers ───────────────────────────────────────────────────────────────

/// Parses a URL into its components: host, language, gameId, trackId.
/// Expected format: https://<host>/<language>/<gameId>/<trackId>
({String host, String language, String gameId, String trackId})? parseUrl(String raw) {
  try {
    final url = raw.startsWith('http') ? raw : 'https://$raw';
    final uri = Uri.parse(url);
    final host = uri.host;
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (host.isNotEmpty && segs.length >= 3) {
      return (
        host: host,
        language: segs[0],
        gameId: segs[1],
        trackId: segs[2],
      );
    }
  } catch (_) {}
  return null;
}

/// Resolves the local audio file based on the new folder rules:
/// /root/<host>/<language>/<gameId>_*/<trackId>_*.<ext>
Future<File?> findTrackFile({
  required String mediaRoot,
  required String host,
  required String language,
  required String gameId,
  required String trackId,
}) async {
  final baseDir = Directory(mediaRoot);
  if (!await baseDir.exists()) return null;

  // 1. Host folder
  final hostDir = Directory(p.join(mediaRoot, host));
  if (!await hostDir.exists()) return null;

  // 2. Language folder
  final langDir = Directory(p.join(hostDir.path, language));
  if (!await langDir.exists()) return null;

  // 3. Game folder (prefix match gameId)
  Directory? gameDir;
  await for (final entity in langDir.list()) {
    if (entity is Directory && p.basename(entity.path).startsWith(gameId)) {
      gameDir = entity;
      break;
    }
  }
  if (gameDir == null) return null;

  // 4. Track file (prefix match trackId)
  await for (final entity in gameDir.list()) {
    if (entity is! File) continue;
    final ext = p.extension(entity.path).toLowerCase();
    if (ext != '.mp3' && ext != '.m4a' && ext != '.wav') continue;
    
    final name = p.basenameWithoutExtension(entity.path);
    if (name.startsWith(trackId)) return entity;
  }
  
  return null;
}

String _fmt(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

// ─── Home Page ─────────────────────────────────────────────────────────────

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
                          ? p.basename(_mediaRoot)
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

// ─── Scanner Page ──────────────────────────────────────────────────────────

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool _hasScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_hasScanned) return;
          final url = capture.barcodes.firstOrNull?.rawValue;
          if (url != null) {
            _hasScanned = true;
            Navigator.pop(context, url);
          }
        },
      ),
    );
  }
}

// ─── Player Page ───────────────────────────────────────────────────────────

class PlayerPage extends StatefulWidget {
  final ({String host, String language, String gameId, String trackId}) parsed;
  final String mediaRoot;

  const PlayerPage({
    super.key,
    required this.parsed,
    required this.mediaRoot,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final _player = AudioPlayer();

  File? _file;
  bool _loading = true;
  bool _completed = false;
  String? _error;
  String? _gameName;
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) {
        setState(() {
          _playing = s == PlayerState.playing;
          if (_playing) _completed = false;
        });
      }
    });

    _player.onPositionChanged.listen((d) {
      if (mounted) setState(() => _pos = d);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      
      setState(() {
        _playing = false;
        _completed = true;
        _pos = Duration.zero;
      });
    });
    _loadAndPlay();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadAndPlay() async {
    setState(() { _loading = true; _error = null; });

    if (Platform.isAndroid) {
      if (!await _ensurePermission()) {
        if (mounted) {
          setState(() {
            _error =
                'Storage access denied.\n\nPlease allow "Manage all files" in Android settings.';
            _loading = false;
          });
        }
        return;
      }
    }
    final file = await findTrackFile(
      mediaRoot: widget.mediaRoot,
      host: widget.parsed.host,
      language: widget.parsed.language,
      gameId: widget.parsed.gameId,
      trackId: widget.parsed.trackId,
    );

    if (!mounted) return;

    if (file == null) {
      setState(() {
        _error = 'Track not found.\n\n'
            'Searched in:\n'
            '${widget.mediaRoot}/${widget.parsed.host}/${widget.parsed.language}/${widget.parsed.gameId}_*/\n\n'
            'Filename must start with\n"${widget.parsed.trackId}".';
        _loading = false;
      });
      return;
    }

    final folderName = p.basename(file.parent.path);
    final underscoreIdx = folderName.indexOf('_');

    setState(() {
      _file = file;
      _loading = false;
      _gameName = underscoreIdx != -1
          ? folderName.substring(underscoreIdx + 1)
          : folderName;
    });
    await _player.play(DeviceFileSource(file.path));
  }

  Future<void> _scanAndPlay() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerPage()),
    );
    if (result != null && mounted) {
      final parsed = parseUrl(result);
      if (parsed == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid URL format')),
        );
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerPage(
            parsed: parsed,
            mediaRoot: widget.mediaRoot,
            ),
          ),
        );
      }
    }

  Future<bool> _ensurePermission() async {
    if (await Permission.manageExternalStorage.isGranted) return true;
    final r = await Permission.manageExternalStorage.request();
    if (r.isGranted) return true;
    return (await Permission.storage.request()).isGranted;
  }

  Future<void> _togglePlayPause() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    if (_file == null) return;
    if (_completed) {
      await _player.play(DeviceFileSource(_file!.path));
      return;
    }
    await _player.resume();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final trackDisplay = int.tryParse(widget.parsed.trackId.toString()) ?? widget.parsed.trackId;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.inversePrimary,
        title: Row(
          children: [            
            Expanded(
              child: SizedBox(
                height: 24,
                child: Marquee(
                  text: '#$trackDisplay  ·  ${_gameName ?? widget.parsed.gameId}',
                  style: Theme.of(context).appBarTheme.titleTextStyle ?? 
                        Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.normal,
                        ),
                  scrollAxis: Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  blankSpace: 50.0,
                  velocity: 30.0,
                  pauseAfterRound: const Duration(seconds: 2),
                  startPadding: 0.0,
                  accelerationDuration: const Duration(seconds: 1),
                  accelerationCurve: Curves.linear,
                  decelerationDuration: const Duration(milliseconds: 500),
                  decelerationCurve: Curves.easeOut,
                ),
              ),
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildError()
                  : _buildPlayer(cs),
        ),
      ),
    );
  }

  Widget _buildError() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 72, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadAndPlay,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _scanAndPlay,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan again'),
            ),
          ],
        ),
      );

  Widget _buildPlayer(ColorScheme cs) {
    final maxMs = _dur.inMilliseconds.toDouble();
    final curMs =
        _pos.inMilliseconds.toDouble().clamp(0.0, maxMs > 0 ? maxMs : 1.0);
    final trackDisplay = int.tryParse(widget.parsed.trackId.toString()) ?? widget.parsed.trackId;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _scanAndPlay,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              _playing ? Icons.music_note_rounded : Icons.music_note,
              size: 80,
              color: cs.onPrimaryContainer,
            ),
          ),
        ),

        const SizedBox(height: 32),

        Text('Game Pack',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey)),
        Text(
          _gameName ?? widget.parsed.gameId,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text('Track #$trackDisplay',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: const Color.fromARGB(255, 158, 158, 158))),
        if (_file != null) ...[
          const SizedBox(height: 4),
          Text(
            p.basename(_file!.path),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade400,
                  fontStyle: FontStyle.italic,
                ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],

        const SizedBox(height: 32),

        Slider(
          value: curMs,
          max: maxMs > 0 ? maxMs : 1.0,
          onChanged: maxMs > 0
              ? (v) => _player.seek(Duration(milliseconds: v.toInt()))
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(_pos),
                  style: Theme.of(context).textTheme.bodySmall),
              Text(_fmt(_dur),
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),

        const SizedBox(height: 24),

        FilledButton(
          onPressed: _togglePlayPause,
          style: FilledButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(24),
          ),
          child: Icon(
            _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 48,
          ),
        ),      
      ],
    );
  }
}

// ─── Settings Page ─────────────────────────────────────────────────────────

class SettingsPage extends StatefulWidget {
  final SharedPreferences prefs;
  const SettingsPage({super.key, required this.prefs});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _pathCtrl;

  @override
  void initState() {
    super.initState();
    _pathCtrl = TextEditingController(
      text: widget.prefs.getString('mediaRootPath') ?? '',
    );
  }

  @override
  void dispose() {
    _pathCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(String path) async {
    await widget.prefs.setString('mediaRootPath', path.trim());
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved ✓')),
      );
    }
  }

  Future<void> _pickDir() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Please enter path manually, e.g.: /storage/emulated/0/Music/Jukebox',
       ),
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.inversePrimary,
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Media Folder',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _pathCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Path',
                    hintText: '/storage/emulated/0/Music/Jukebox',
                    border: OutlineInputBorder(),
                    helperText: 'Folder containing <host>/<language>/<gameId>_*/',
                  ),
                  onSubmitted: _save,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: IconButton.filled(
                  icon: const Icon(Icons.folder_open),
                  onPressed: _pickDir,
                  tooltip: 'Choose Folder',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _save(_pathCtrl.text),
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ),

          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 16),

          Text('Expected Folder Structure',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '<Media Folder>/\n'
              '└── example.com/\n'
              '    └── de/\n'
              '        └── aaaa0015_Superhits/\n'
              '            ├── 00015_Song Title.mp3\n'
              '            └── 00016_Another Song.mp3',
              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
