import 'dart:async';

import 'package:purple_otel_api/purple_otel_api.dart';

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

  static R runWithContext<R>(Context context, R Function() fn) {
    return runZoned(fn, zoneValues: {_key: context});
  }
}
