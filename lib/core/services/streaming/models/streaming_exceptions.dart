sealed class StreamingException implements Exception {
  final String message;
  StreamingException(this.message);

  @override
  String toString() => message;
}

class MediaDetailsResolutionException extends StreamingException {
  MediaDetailsResolutionException([String message = 'Could not fetch media details']) : super(message);
}

class ImdbIdResolutionException extends StreamingException {
  ImdbIdResolutionException([String message = 'Could not resolve IMDB ID']) : super(message);
}

class NoProvidersEnabledException extends StreamingException {
  NoProvidersEnabledException([String message = 'No streaming providers are enabled']) : super(message);
}

class NoAnimeProvidersEnabledException extends StreamingException {
  NoAnimeProvidersEnabledException([String message = 'No anime providers are enabled']) : super(message);
}

class NoResultsFoundException extends StreamingException {
  NoResultsFoundException([String message = 'No results found across providers']) : super(message);
}

class DebridKeyNotSpecifiedException extends StreamingException {
  DebridKeyNotSpecifiedException([String message = 'Debrid API key is not specified']) : super(message);
}

class StreamResolutionFailedException extends StreamingException {
  StreamResolutionFailedException([String message = 'Failed to resolve the selected stream']) : super(message);
}
