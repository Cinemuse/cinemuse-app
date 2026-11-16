import 'dart:io';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

void setupSqlite() {
  if (Platform.isAndroid) {
    applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  }
}
