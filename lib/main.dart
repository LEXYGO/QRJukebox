import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:marquee/marquee.dart';
import 'package:audiotags/audiotags.dart';
import 'package:file_picker/file_picker.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Entry Point ───────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final prefs = await SharedPreferences.getInstance();
  
  final keepAwake = prefs.getBool('keepAwake') ?? true;
  WakelockPlus.toggle(enable: keepAwake);
  
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
      debugShowCheckedModeBanner: false,
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

/// Parses a URL into its components: host, folders, trackId.
/// The last segment is always the trackId, segments before are folders.
({String host, List<String> folders, String trackId})? parseUrl(String raw) {
  try {
    final url = raw.startsWith('http') ? raw : 'https://$raw';
    final uri = Uri.parse(url);
    final host = uri.host;
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    
    if (host.isNotEmpty && segs.length >= 2) {
      return (
        host: host,
        folders: segs.sublist(0, segs.length - 1),
        trackId: segs.last,
      );
    }
  } catch (_) {}
  return null;
}

/// Resolves the local audio file by traversing the folder structure.
Future<File?> findTrackFile({
  required String mediaRoot,
  required String host,
  required List<String> folders,
  required String trackId,
}) async {
  final baseDir = Directory(mediaRoot);
  if (!await baseDir.exists()) return null;

  // 1. Host folder
  Directory? currentDir;
  await for (final entity in baseDir.list()) {
    if (entity is Directory) {
      final name = p.basename(entity.path).toLowerCase();
      if (name == host.toLowerCase() || name.startsWith('${host.toLowerCase()}_')) {
        currentDir = entity;
        break;
      }
    }
  }
  if (currentDir == null) return null;

  // 2. Traverse folders (e.g. ['de', 'aaaa0015'])
  for (final segment in folders) {
    Directory? nextDir;
    final search = segment.toLowerCase();
    await for (final entity in currentDir!.list()) {
      if (entity is Directory) {
        final name = p.basename(entity.path).toLowerCase();
        // Match exact or "segment_something"
        if (name == search || name.startsWith('${search}_')) {
          nextDir = entity;
          break;
        }
      }
    }
    if (nextDir == null) return null;
    currentDir = nextDir;
  }

  // 3. Find track file in the final directory
  await for (final entity in currentDir!.list()) {
    if (entity is! File) continue;
    final ext = p.extension(entity.path).toLowerCase();
    if (!['.mp3', '.m4a', '.wav', '.flac'].contains(ext)) continue;
    
    final name = p.basenameWithoutExtension(entity.path).toLowerCase();
    if (name == trackId.toLowerCase() || name.startsWith('${trackId.toLowerCase()}_')) {
      return entity;
    }
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
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: ReaderWidget(
        onScan: (result) {
          if (_hasScanned) return;
          if (result.text != null && result.text!.isNotEmpty) {
            _hasScanned = true;
            HapticFeedback.mediumImpact();
            Navigator.pop(context, result.text);
          }
        },
        scanDelay: const Duration(milliseconds: 100),
        showScannerOverlay: false,
        tryHarder: true,
        tryInverted: true,
        cropPercent: 0.8,
      ),
    );
  }
}

// ─── Player Page ───────────────────────────────────────────────────────────

class PlayerPage extends StatefulWidget {
  final ({String host, List<String> folders, String trackId}) parsed;
  final String mediaRoot;
  final SharedPreferences prefs;

  const PlayerPage({
    super.key,
    required this.parsed,
    required this.mediaRoot,
    required this.prefs,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final _player = AudioPlayer();

  File? _file;
  Tag? _tags;
  bool _loading = true;
  bool _completed = false;
  String? _error;
  String? _gameName;
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
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
      folders: widget.parsed.folders,
      trackId: widget.parsed.trackId,
    );

    if (!mounted) return;

    if (file == null) {
      final fullPath = [widget.parsed.host, ...widget.parsed.folders].join('/');
      setState(() {
        _error = 'Track not found.\n\n'
            'Searched in:\n'
            '${widget.mediaRoot}/$fullPath/\n\n'
            'Filename must start with\n"${widget.parsed.trackId}".';
        _loading = false;
      });
      return;
    }

    final folderName = p.basename(file.parent.path);
    final underscoreIdx = folderName.indexOf('_');

    Tag? tags;
    try {
      tags = await AudioTags.read(file.path);
    } catch (_) {}

    setState(() {
      _file = file;
      _loading = false;
      _tags = tags;
      _gameName = underscoreIdx != -1
          ? folderName.substring(underscoreIdx + 1)
          : folderName;
    });

    final startOffset = widget.prefs.getInt('playbackStartOffset') ?? 0;
    await _player.play(
      DeviceFileSource(file.path),
      position: Duration(seconds: startOffset),
    );
  }

  Future<void> _seekRelative(int seconds) async {
    final newPos = _pos + Duration(seconds: seconds);
    await _player.seek(newPos < Duration.zero ? Duration.zero : newPos);
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
            prefs: widget.prefs,
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

  String _formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  void _showInfoDialog() {
    if (_file == null) return;

    final size = _file!.lengthSync();
    final sizeStr = _formatBytes(size, 2);
    final trackDisplay =
        int.tryParse(widget.parsed.trackId.toString()) ?? widget.parsed.trackId;
    final hasCover = _tags?.pictures.isNotEmpty == true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Track Information'),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              if (hasCover)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullscreenCover(
                            imageBytes: _tags!.pictures.first.bytes,
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _tags!.pictures.first.bytes,
                        height: 150,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              _infoRow('Track #', trackDisplay.toString()),
              _infoRow('Game Set', _gameName ?? (widget.parsed.folders.isNotEmpty ? widget.parsed.folders.last : 'Root')),
              if (_tags?.title != null && _tags!.title!.isNotEmpty)
                _infoRow('Title', _tags!.title!),
              if (_tags?.trackArtist != null && _tags!.trackArtist!.isNotEmpty)
                _infoRow('Artist', _tags!.trackArtist!),
              if (_tags?.album != null && _tags!.album!.isNotEmpty)
                _infoRow('Album', _tags!.album!),
              if (_tags?.year != null)
                _infoRow('Year', _tags!.year!.toString()),
              _infoRow('File Size', sizeStr),
              _infoRow('File Name', p.basename(_file!.path)),
              _infoRow('Full Path', _file!.path),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 2),
          SelectableText(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
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
                  text: '#$trackDisplay  ·  ${_gameName ?? (widget.parsed.folders.isNotEmpty ? widget.parsed.folders.last : 'Root')}',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
            tooltip: 'Track Info',
          ),
        ],
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
        const SizedBox(height: 8),
        Text(
          'Click to scan again',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: cs.primary.withValues(alpha: 0.5),
          ),
        ),

        const SizedBox(height: 24),

        Text('Game Pack',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey)),
        Text(
          _gameName ?? (widget.parsed.folders.isNotEmpty ? widget.parsed.folders.last : 'Root'),
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

        const SizedBox(height: 16),

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

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.replay_10_rounded),
              onPressed: () => _seekRelative(-10),
              iconSize: 32,
              color: cs.primary,
            ),
            const SizedBox(width: 16),
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
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.forward_10_rounded),
              onPressed: () => _seekRelative(10),
              iconSize: 32,
              color: cs.primary,
            ),
          ],
        ),

        if (widget.prefs.getBool('showStopwatch') ?? false) ...[
          const SizedBox(height: 32),
          StreamBuilder(
            stream: Stream.periodic(const Duration(seconds: 1)),
            builder: (context, _) {
              final elapsed = _stopwatch.elapsed;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, size: 18, color: cs.onSecondaryContainer),
                    const SizedBox(width: 8),
                    Text(
                      'Spent time: ${_fmt(elapsed)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class FullscreenCover extends StatelessWidget {
  final List<int> imageBytes;
  const FullscreenCover({super.key, required this.imageBytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Hero(
            tag: 'cover',
            child: Image.memory(
              Uint8List.fromList(imageBytes),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
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
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

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
        backgroundColor: cs.inversePrimary,
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                  onSubmitted: _savePath,
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
              onPressed: () => _savePath(_pathCtrl.text),
              icon: const Icon(Icons.save),
              label: const Text('Save Path'),
            ),
          ),

          const SizedBox(height: 8),

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
              '    └── de_original-game-edition/\n'
              '        ├── 00015_Song Title.mp3\n'
              '        ├── 00016_Another Song.mp3\n'
              '        └── aaaa0015_Superhits-Extension/\n'
              '            ├── 00015_Song Title.mp3\n'
              '            └── 00016_Another Song.mp3',
              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),

          const SizedBox(height: 48),
          const Divider(),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Image.asset(
                  'assets/branding/app_icon.png',
                  width: 64,
                  height: 64,
                  color: Colors.grey,
                  colorBlendMode: BlendMode.srcIn,
                ),
                const SizedBox(height: 12),
                Text(
                  'QR Jukebox',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Text(
                  'Version 1.0.14',
                  style: TextStyle(color: Colors.grey),
                ),
                const Text(
                  'Created by Lennard Hanß',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
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
