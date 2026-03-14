class MimeResolver {
  /// Resolves the MIME type for a given [url].
  ///
  /// Optionally accepts a [providedMime] which might be incomplete or a generic placeholder.
  static String resolve(String url, [String? providedMime]) {
    // 1. If we have a specific non-generic MIME, trust it
    if (providedMime != null &&
        providedMime.isNotEmpty &&
        providedMime != 'video/mp4' &&
        providedMime != 'application/octet-stream' &&
        providedMime != 'application/force-download' &&
        providedMime != 'binary/octet-stream') {
      return providedMime;
    }

    final lowerUrl = url.toLowerCase();
    final uri = Uri.tryParse(lowerUrl);
    final path = uri?.path ?? lowerUrl;

    // 2. Protocol & Extension Pattern Matching
    
    // HLS (Most common for Live and Web streams)
    if (path.endsWith('.m3u8') ||
        lowerUrl.contains('protocol=hls') ||
        lowerUrl.contains('.hls') ||
        path.contains('/m3u8') ||
        path.contains('m3u8')) {
      return 'application/x-mpegURL';
    }

    // DASH
    if (path.endsWith('.mpd') || lowerUrl.contains('protocol=dash')) {
      return 'application/dash+xml';
    }

    // Matroska (MKV)
    if (path.endsWith('.mkv') || lowerUrl.contains('container=mkv')) {
      return 'video/x-matroska';
    }

    // WebM
    if (path.endsWith('.webm') || lowerUrl.contains('container=webm')) {
      return 'video/webm';
    }

    // MP4
    if (path.endsWith('.mp4') || lowerUrl.contains('container=mp4')) {
      return 'video/mp4';
    }

    // 3. Fallback to provided or generic default
    return providedMime ?? 'video/mp4';
  }

  /// Maps a raw engine format (from mpv) to a standard MIME type.
  static String? fromEngineFormat(String? format) {
    if (format == null) return null;
    final f = format.toLowerCase();
    
    if (f.contains('hls') || f.contains('mpegurl')) return 'application/x-mpegURL';
    if (f.contains('dash')) return 'application/dash+xml';
    if (f.contains('matroska')) return 'video/x-matroska';
    if (f.contains('mp4') || f.contains('mov') || f.contains('m4v')) return 'video/mp4';
    if (f.contains('webm')) return 'video/webm';
    if (f.contains('avi')) return 'video/x-msvideo';
    
    return null;
  }
}
