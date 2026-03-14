class CastConstants {
  /// Default Media Receiver App ID
  static const String defaultAppId = 'CC1AD845';

  /// Cast Metadata Types
  static const int metadataGeneric = 0;
  static const int metadataMovie = 1;
  static const int metadataTvShow = 2;
  static const int metadataMusicTrack = 3;
  static const int metadataPhoto = 4;

  /// Cast Stream Types
  static const String streamTypeBuffered = 'BUFFERED';
  static const String streamTypeLive = 'LIVE';

  /// Message Namespaces
  static const String nsReceiver = 'urn:x-cast:com.google.cast.receiver';
  static const String nsMedia = 'urn:x-cast:com.google.cast.media';
  static const String nsConnection = 'urn:x-cast:com.google.cast.tp.connection';
  static const String nsHeartbeat = 'urn:x-cast:com.google.cast.tp.heartbeat';
}
