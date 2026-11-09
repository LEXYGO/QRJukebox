import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:marquee/marquee.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';


import 'package:qr_jukebox/services/track_finder.dart';
import 'package:qr_jukebox/app/fullscreen_cover.dart';
import 'package:qr_jukebox/utils/formatting.dart';
import 'package:qr_jukebox/utils/url_parser.dart';
import 'package:qr_jukebox/screens/scanner_page.dart';


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
  AudioMetadata? _tags;
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
    _player.onPlayerStateChanged.listen((playerState) {
      if (mounted) {
        setState(() {
          _playing = playerState == PlayerState.playing;
          if (_playing) _completed = false;
        });
      }
    });

    _player.onPositionChanged.listen((playerDuration) {
      if (mounted) setState(() => _pos = playerDuration);
    });
    _player.onDurationChanged.listen((playerDuration) {
      if (mounted) setState(() => _dur = playerDuration);
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
            'Storage access denied.\n\nPlease allow storage permission in Android settings.';
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

    AudioMetadata? tags;
    try {
      tags = readMetadata(file, getImage: true);
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
    if (await Permission.audio.isGranted || await Permission.storage.isGranted) {
      return true;
    }
    final audioStatus = await Permission.audio.request();
    if (audioStatus.isGranted) return true;

    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
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

  void _showInfoDialog() {
    if (_file == null) return;

    final size = _file!.lengthSync();
    final sizeStr = formatBytes(size, 2);
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
              if (_tags?.artist != null && _tags!.artist!.isNotEmpty)
                _infoRow('Artist', _tags!.artist!),
              if (_tags?.album != null && _tags!.album!.isNotEmpty)
                _infoRow('Album', _tags!.album!),
              if (_tags?.year != null && _tags!.year!.year != 0)
                _infoRow('Year', _tags!.year!.year.toString()),
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
                ?.copyWith(color: Colors.grey)),

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
              Text(formatDuration(_pos),
                  style: Theme.of(context).textTheme.bodySmall),
              Text(formatDuration(_dur),
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
                      'Spent time: ${formatDuration(elapsed)}',
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