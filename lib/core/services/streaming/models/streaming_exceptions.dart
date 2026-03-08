import 'package:cinemuse_app/core/error/app_exception.dart';

abstract class StreamingException extends AppException {
  StreamingException({
    required super.message,
    super.metadata,
    super.originalError,
  }) : super(type: AppExceptionType.streaming);
}

class NoProvidersEnabledException extends StreamingException {
  NoProvidersEnabledException() : super(message: "No streaming providers are enabled");
}

class CapabilityMissingException extends StreamingException {
  final String category;
  CapabilityMissingException(this.category) 
    : super(
        message: "No enabled provider supports $category",
        metadata: {'category': category},
      );
}

class MediaDetailsResolutionException extends StreamingException {
  MediaDetailsResolutionException() : super(message: "Could not resolve media details for search");
}

class ImdbIdResolutionException extends StreamingException {
  ImdbIdResolutionException() : super(message: "Media is missing an IMDB ID, which is required by most providers");
}

class NoResultsFoundException extends StreamingException {
  NoResultsFoundException() : super(message: "No results found across providers");
}

class DebridKeyNotSpecifiedException extends StreamingException {
  final String debridName;
  DebridKeyNotSpecifiedException(this.debridName) 
    : super(
        message: "$debridName key is not specified in settings",
        metadata: {'debrid': debridName},
      );
}

class StreamResolutionFailedException extends StreamingException {
  StreamResolutionFailedException(String details) 
    : super(message: "Stream resolution failed: $details");
}

class ProviderSearchException extends StreamingException {
  final String providerName;
  ProviderSearchException(this.providerName, dynamic originalError)
    : super(
        message: "Search failed for provider: $providerName",
        originalError: originalError,
        metadata: {'provider': providerName},
      );
}
