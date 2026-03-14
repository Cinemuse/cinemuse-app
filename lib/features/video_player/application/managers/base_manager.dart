import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Base class for all domain managers.
/// Provides access to the common dependencies needed by most managers.
abstract class BaseManager {
  @protected
  final Ref ref;
  
  @protected
  final Player player;

  BaseManager({
    required this.ref,
    required this.player,
  });

  @mustCallSuper
  void dispose() {
    // Override if needed
  }
}
