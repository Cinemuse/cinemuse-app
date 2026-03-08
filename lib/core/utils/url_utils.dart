class UrlUtils {
  /// Cleans a Stremio manifest URL to extract the base URL.
  /// Removes 'manifest.json', trailing slashes, and whitespace.
  static String cleanStremioBaseUrl(String url) {
    var cleaned = url.trim();
    
    // Strip manifest.json and anything that follows (like /stream/...)
    final manifestIndex = cleaned.toLowerCase().indexOf('/manifest.json');
    if (manifestIndex != -1) {
      cleaned = cleaned.substring(0, manifestIndex);
    }
    
    // Also handle cases without a leading slash if any
    if (cleaned.toLowerCase().endsWith('manifest.json')) {
      cleaned = cleaned.substring(0, cleaned.length - 'manifest.json'.length);
    }

    // Remove trailing slashes
    while (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned;
  }

  /// Basic security check for URLs.
  static bool isSecureUrl(String url) {
    return url.startsWith('https://') || url.startsWith('http://');
  }
}
