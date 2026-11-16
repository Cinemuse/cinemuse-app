import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:dio/dio.dart';

/// The address to use for this visit to a site listed at [listed], given what
/// its [home] page answered.
///
/// A site that moved forwards its old address, but a search can't follow a
/// forward and the video server is told which site asks. So the whole visit
/// moves to where the home page landed. It is never saved: an expired address
/// bought by someone else must not stay in the app, so each visit asks again.
///
/// Only a new domain counts: a home page sent to `/home` isn't a move. A forward
/// away from `https` is ignored, as the server's list only accepts `https`.
String addressAfterForward(String listed, Response<Object?> home) {
  final start = Uri.parse(listed);
  // A forward's address may be partial, so each one starts from the last.
  final landed = home.redirects.fold(
    start,
    (from, forward) => from.resolveUri(forward.location),
  );
  if (landed.scheme != 'https' ||
      landed.host.isEmpty ||
      landed.authority == start.authority) {
    return listed;
  }
  AppLogger.info('SiteForward', 'The site moved: this visit follows it');
  return 'https://${landed.authority}';
}
