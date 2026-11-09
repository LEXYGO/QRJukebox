import 'dart:io';
import 'package:path/path.dart' as path;

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
      final name = path.basename(entity.path).toLowerCase();
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
        final name = path.basename(entity.path).toLowerCase();
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
    final ext = path.extension(entity.path).toLowerCase();
    if (!['.mp3', '.m4a', '.wav', '.flac'].contains(ext)) continue;

    final name = path.basenameWithoutExtension(entity.path).toLowerCase();
    if (name == trackId.toLowerCase() || name.startsWith('${trackId.toLowerCase()}_')) {
      return entity;
    }
  }

  return null;
}