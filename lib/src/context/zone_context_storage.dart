import 'dart:async';

import 'package:purple_otel_api/purple_otel_api.dart';

/// A [ContextStorage] implementation backed by Dart [Zone] values.
///
/// Contexts are stored in zone values and walk up the zone tree to find the
/// nearest ancestor context. If no context is found, [Context.root] is returned.
///
/// Use [ZoneContextStorage.runWithContext] to execute a callback in a new zone
/// with an explicit context.
final class ZoneContextStorage implements ContextStorage {
  static final _key = Object();

  @override
  Context get current {
    Zone? zone = Zone.current;
    while (zone != null) {
      final ctx = zone[_key] as Context?;
      if (ctx != null) return ctx;
      zone = zone.parent;
    }
    return Context.root;
  }

  @override
  Context attach(Context context) {
    return context;
  }

  @override
  Context detach(Context context) {
    return Context.root;
  }

  /// Executes [fn] in a new zone with [context] as the active context.
  ///
  /// The context is available to all code within [fn] and any asynchronous
  /// continuations scheduled from it.
  static R runWithContext<R>(Context context, R Function() fn) {
    return runZoned(fn, zoneValues: {_key: context});
  }
}
