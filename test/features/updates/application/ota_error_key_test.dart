import 'package:cinemuse_app/features/updates/application/update_service.dart';
import 'package:cinemuse_app/features/updates/domain/update_state.dart';
import 'package:cinemuse_app/features/updates/presentation/update_overlay.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_update/ota_update.dart';

void main() {
  final it = AppLocalizationsIt();

  String messageFor(OtaStatus status) => updateErrorMessage(
    it,
    UpdateState(status: UpdateStatus.error, errorKey: otaErrorKey(status)),
  );

  test('every Android error is shown translated (REV-29)', () {
    expect(
      messageFor(OtaStatus.ALREADY_RUNNING_ERROR),
      it.updateAlreadyRunning,
    );
    expect(
      messageFor(OtaStatus.PERMISSION_NOT_GRANTED_ERROR),
      it.updatePermissionDenied,
    );
    expect(messageFor(OtaStatus.DOWNLOAD_ERROR), it.updateNetworkError);
    expect(messageFor(OtaStatus.CHECKSUM_ERROR), it.updateIntegrityError);
    expect(messageFor(OtaStatus.INTERNAL_ERROR), it.updateFailed);
  });

  test('a failed install is an error too, not silence', () {
    expect(otaErrorKey(OtaStatus.INSTALLATION_ERROR), 'updateFailed');
  });

  test('progress and a user cancel are not errors', () {
    for (final status in [
      OtaStatus.DOWNLOADING,
      OtaStatus.INSTALLING,
      OtaStatus.INSTALLATION_DONE,
      OtaStatus.CANCELED,
    ]) {
      expect(otaErrorKey(status), isNull, reason: status.name);
    }
  });

  test('an unknown key falls back to the generic message', () {
    final state = UpdateState(status: UpdateStatus.error, errorKey: 'nope');

    expect(
      updateErrorMessage(AppLocalizationsEn(), state),
      AppLocalizationsEn().updateFailed,
    );
  });
}
