import 'package:cinemuse_app/core/application/locale_service.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localizationsProvider = Provider<AppLocalizations>((ref) {
  final locale = ref.watch(localeProvider);
  return lookupAppLocalizations(locale);
});
