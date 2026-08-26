import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

class FavoriteBusService {
  static const String _favoriteBusKey = 'favorite_bus_route_ids';
  static Future<void> _operationBarrier = Future<void>.value();

  static Future<T> _serialize<T>(Future<T> Function() operation) {
    final previousOperation = _operationBarrier;
    final release = Completer<void>();
    _operationBarrier = release.future;

    return () async {
      await previousOperation;
      try {
        return await operation();
      } finally {
        release.complete();
      }
    }();
  }

  static Set<String> _read(SharedPreferences preferences) {
    return (preferences.getStringList(_favoriteBusKey) ?? []).toSet();
  }

  static Future<void> _save(
    SharedPreferences preferences,
    Set<String> favoriteRouteIds,
  ) async {
    await preferences.setStringList(
      _favoriteBusKey,
      favoriteRouteIds.toList()..sort(),
    );
  }

  static Future<Set<String>> getFavoriteRouteIds() {
    return _serialize(() async {
      final preferences = await SharedPreferences.getInstance();
      return _read(preferences);
    });
  }

  static bool containsRoute(
    Set<String> favoriteRouteIds, {
    required String routeKey,
    required String routeId,
  }) {
    return favoriteRouteIds.contains(routeKey) ||
        favoriteRouteIds.contains(routeId);
  }

  static Future<bool> isFavorite(
    String routeKey, {
    String? legacyRouteId,
  }) async {
    final favoriteRouteIds = await getFavoriteRouteIds();
    return favoriteRouteIds.contains(routeKey) ||
        (legacyRouteId != null && favoriteRouteIds.contains(legacyRouteId));
  }

  static Future<void> addFavorite(String routeId) {
    return _serialize(() async {
      final preferences = await SharedPreferences.getInstance();
      final favoriteRouteIds = _read(preferences)..add(routeId);
      await _save(preferences, favoriteRouteIds);
    });
  }

  static Future<void> removeFavorite(String routeId) {
    return _serialize(() async {
      final preferences = await SharedPreferences.getInstance();
      final favoriteRouteIds = _read(preferences)..remove(routeId);
      await _save(preferences, favoriteRouteIds);
    });
  }

  static Future<bool> toggleFavorite(String routeKey, {String? legacyRouteId}) {
    return _serialize(() async {
      final preferences = await SharedPreferences.getInstance();
      final favoriteRouteIds = _read(preferences);
      // 예전 routeId 형식도 읽고, 새 값은 provider:routeId로 저장한다.
      final wasFavorite =
          favoriteRouteIds.contains(routeKey) ||
          (legacyRouteId != null && favoriteRouteIds.contains(legacyRouteId));

      favoriteRouteIds.remove(routeKey);
      if (legacyRouteId != null) {
        favoriteRouteIds.remove(legacyRouteId);
      }

      if (!wasFavorite) {
        favoriteRouteIds.add(routeKey);
      }

      await _save(preferences, favoriteRouteIds);
      return !wasFavorite;
    });
  }
}
