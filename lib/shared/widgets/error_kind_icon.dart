import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:flutter/material.dart';

/// The one icon per [ErrorKind] used by every error widget (REV-45).
extension ErrorKindIcon on ErrorKind {
  IconData get icon => switch (this) {
    ErrorKind.network => Icons.wifi_off_rounded,
    ErrorKind.auth => Icons.lock_person_rounded,
    ErrorKind.server => Icons.cloud_off_rounded,
    ErrorKind.streaming => Icons.movie_filter_rounded,
    ErrorKind.validation || ErrorKind.unknown => Icons.error_outline_rounded,
  };
}
