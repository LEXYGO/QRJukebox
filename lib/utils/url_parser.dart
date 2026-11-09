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