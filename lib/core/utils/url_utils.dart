class UrlUtils {
  /// Extracts a clean base URL and optional query parameters from an addon URL.
  /// Matches PlayTorrioV2 logic for robust Stremio protocol handling.
  static ({String baseUrl, String? queryParams}) splitStremioUrl(String url) {
    String trimmed = url.trim();
    if (trimmed.startsWith('stremio://')) {
      trimmed = trimmed.replaceFirst('stremio://', 'https://');
    }

    final qIdx = trimmed.indexOf('?');
    String path = qIdx >= 0 ? trimmed.substring(0, qIdx) : trimmed;
    final query = qIdx >= 0 ? trimmed.substring(qIdx + 1) : null;
    
    // Clean trailing manifest.json and slashes
    path = path.replaceAll(RegExp(r'/manifest\.json$', caseSensitive: false), '')
               .replaceAll(RegExp(r'/$'), '');
    
    if (!path.startsWith('http')) path = 'https://$path';
    
    return (baseUrl: path, queryParams: query);
  }

  /// Cleans a Stremio manifest URL to extract the base path.
  static String cleanStremioBaseUrl(String url) {
    return splitStremioUrl(url).baseUrl;
  }

  /// Replaces encoded characters that Stremio addons usually expect to be literal.
  static String unencodeStremioUrl(String url) {
    return url.replaceAll('%7C', '|');
  }

  /// Basic security check for URLs.
  static bool isSecureUrl(String url) {
    return url.startsWith('https://') || url.startsWith('http://');
  }
}
