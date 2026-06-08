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
  runApp(BttrHitsterApp(prefs: prefs));
}

// ─── App Root ──────────────────────────────────────────────────────────────

class BttrHitsterApp extends StatelessWidget {
  final SharedPreferences prefs;
  const BttrHitsterApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'bttrHitster',
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

/// Parst z.B. "www.hitstergame.com/de/aaaa0015/00094"
/// → (gameId: 'aaaa0015', trackNumber: '00094')
/// Nimmt einfach die letzten zwei Pfadsegmente.
({String gameId, String trackNumber})? parseHitsterUrl(String raw) {
  try {
    final url = raw.startsWith('http') ? raw : 'https://$raw';
    final segs = Uri.parse(url)
        .pathSegments
        .where((s) => s.isNotEmpty)
        .toList();
    if (segs.length >= 2) {
      return (
        gameId: segs[segs.length - 2],
        trackNumber: segs[segs.length - 1],
      );
    }
  } catch (_) {}
  return null;
}

/// Sucht in `mediaRoot/gameId/` nach einer MP3, deren Dateiname mit
/// `trackNumber` beginnt – sowohl mit führenden Nullen ("00094")
/// als auch ohne ("94").
Future<File?> findTrackFile(
  String mediaRoot,
  String gameId,
  String trackNumber,
) async {
  final baseDir = Directory(mediaRoot);
  if (!await baseDir.exists()) return null;

  // Ordner finden, der mit gameId beginnt (z.B. "aaaa0015_Superhits")
  Directory? gameDir;
  await for (final entity in baseDir.list()) {
    if (entity is Directory &&
        p.basename(entity.path).startsWith(gameId)) {
      gameDir = entity;
      break;
    }
  }
  if (gameDir == null) return null;

  // ... Rest bleibt gleich, nur dir → gameDir:
  final trackNum = int.tryParse(trackNumber);
  await for (final entity in gameDir.list()) {
    if (entity is! File) continue;
    if (p.extension(entity.path).toLowerCase() != '.mp3') continue;
    final name = p.basenameWithoutExtension(entity.path);
    if (name.startsWith(trackNumber)) return entity;
    if (trackNum != null) {
      final numStr = trackNum.toString();
      if (name.startsWith(numStr)) {
        final rest = name.substring(numStr.length);
        if (rest.isEmpty || !RegExp(r'\d').hasMatch(rest[0])) return entity;
      }
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
    final parsed = parseHitsterUrl(url);
    if (parsed == null) {
      _snack('Ungültige Hitster-URL');
      return;
    }
    if (_mediaRoot.isEmpty) {
      _snack('Bitte zuerst den Medienordner in den Einstellungen festlegen.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPage(
          gameId: parsed.gameId,
          trackNumber: parsed.trackNumber,
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
        title: const Text('URL eingeben'),
        content: TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: 'Hitster-URL',
            hintText: 'hitstergame.com/de/aaaa0015/00094',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (_) => _submitDialog(ctx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
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
    setState(() {}); // Ordnername in der Anzeige aktualisieren
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasRoot = _mediaRoot.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.inversePrimary,
        title: const Text('bttrHitster'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
            tooltip: 'Einstellungen',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.music_note_rounded, size: 96, color: cs.primary),
              const SizedBox(height: 12),
              Text(
                'bttrHitster',
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
                          : 'Kein Medienordner konfiguriert',
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
                  label: const Text('QR-Code scannen'),
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
                  label: const Text('URL manuell eingeben'),
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
                    label: const Text('Medienordner einrichten'),
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
      appBar: AppBar(title: const Text('Scan your Game-Cards QR-Code')),
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
  final String gameId;
  final String trackNumber;
  final String mediaRoot;

  const PlayerPage({
    super.key,
    required this.gameId,
    required this.trackNumber,
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
  String? _packName;
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
                'Speicherzugriff verweigert.\n\nBitte in den Android-Einstellungen\n"Alle Dateien verwalten" erlauben.';
            _loading = false;
          });
        }
        return;
      }
    }
    final file = await findTrackFile(
        widget.mediaRoot, widget.gameId, widget.trackNumber);

    if (!mounted) return;

    if (file == null) {
      setState(() {
        _error = 'Track nicht gefunden.\n\n'
            'Gesucht in:\n'
            '${widget.mediaRoot}/${widget.gameId}/\n\n'
            'Dateiname muss mit\n"${widget.trackNumber}" beginnen.';
        _loading = false;
      });
      return;
    }

    final folderName = p.basename(file.parent.path);
      final underscoreIdx = folderName.indexOf('_');
      setState(() {
      _file = file;
      _loading = false;
      _packName = underscoreIdx != -1
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
      final parsed = parseHitsterUrl(result);
      if (parsed == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ungültige Hitster-URL')),
        );
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerPage(
            gameId: parsed.gameId,
            trackNumber: parsed.trackNumber,
            mediaRoot: widget.mediaRoot,
            ),
          ),
        );
      }
    }

  Future<bool> _ensurePermission() async {
    // Android 11+ (API 30+): MANAGE_EXTERNAL_STORAGE
    if (await Permission.manageExternalStorage.isGranted) return true;
    final r = await Permission.manageExternalStorage.request();
    if (r.isGranted) return true;
    // Fallback Android 9/10
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
    return Scaffold(
      /* appBar: AppBar(
        backgroundColor: cs.inversePrimary,
        title: Text('# ${int.tryParse(widget.trackNumber.toString()) ?? widget.trackNumber}  ·  ${_packName ?? widget.gameId}'),
      ),*/
      appBar: AppBar(
        backgroundColor: cs.inversePrimary,
        title: Row(
          children: [            
            // Der bewegliche Teil (Laufschrift)
            Expanded(
              child: SizedBox(
                height: 24,
                child: Marquee(
                  text: '#${int.tryParse(widget.trackNumber.toString()) ?? widget.trackNumber}  ·  ${_packName ?? widget.gameId}',
                  // Hier holen wir uns den exakten Stil, den die AppBar sonst auch nutzen würde:
                  style: Theme.of(context).appBarTheme.titleTextStyle ?? 
                        Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.normal, // Verhindert, dass es fett ist
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

    return Column(
      /*
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Cover-Platzhalter
        Container(
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
        */

      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Cover-Platzhalter (Jetzt klickbar!)
        GestureDetector(
          onTap: () {
            // Hier kommt deine Funktion rein, z.B.:
            _scanAndPlay();
          },
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
          _packName ?? widget.gameId,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text('Track #${int.tryParse(widget.trackNumber.toString()) ?? widget.trackNumber}',
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

        // Fortschrittsbalken
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

        // Play / Pause
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
        const SnackBar(content: Text('Gespeichert ✓')),
      );
    }
  }

   // _pickDir ersetzen:
  Future<void> _pickDir() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Bitte Pfad manuell eingeben, z.B.: /storage/emulated/0/Music/Hitster',
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
        title: const Text('Einstellungen'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Medienordner',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _pathCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Pfad',
                    hintText: '/storage/emulated/0/Music/Hitster',
                    border: OutlineInputBorder(),
                    helperText: 'Ordner, der die GameID-Unterordner enthält',
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
                  tooltip: 'Ordner wählen',
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
              label: const Text('Speichern'),
            ),
          ),

          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 16),

          Text('Erwartete Ordnerstruktur',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '<Medienordner>/\n'
              '├── aaaa0015_Superhits/\n'
              '│   ├── 00094_Song Title.mp3\n'
              '│   └── 00095_Another Song.mp3\n'
              '└── bbbb0023_SomeOtherFolder/\n'
              '    └── 00001_Third Song.mp3',
              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}