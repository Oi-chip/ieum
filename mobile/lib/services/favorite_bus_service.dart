import 'package:shared_preferences/shared_preferences.dart';

class FavoriteBusService {
  static const String _favoriteBusKey = 'favorite_bus_route_ids';

  // 저장된 즐겨찾기 버스 routeId 목록 불러오기
  static Future<Set<String>> getFavoriteRouteIds() async {
    final preferences = await SharedPreferences.getInstance();

    final savedRouteIds =
        preferences.getStringList(_favoriteBusKey) ?? [];

    return savedRouteIds.toSet();
  }

  // 특정 버스가 즐겨찾기인지 확인
  static Future<bool> isFavorite(String routeId) async {
    final favoriteRouteIds = await getFavoriteRouteIds();

    return favoriteRouteIds.contains(routeId);
  }

  // 즐겨찾기 추가
  static Future<void> addFavorite(String routeId) async {
    final preferences = await SharedPreferences.getInstance();

    final favoriteRouteIds = await getFavoriteRouteIds();

    favoriteRouteIds.add(routeId);

    await preferences.setStringList(
      _favoriteBusKey,
      favoriteRouteIds.toList(),
    );
  }

  // 즐겨찾기 삭제
  static Future<void> removeFavorite(String routeId) async {
    final preferences = await SharedPreferences.getInstance();

    final favoriteRouteIds = await getFavoriteRouteIds();

    favoriteRouteIds.remove(routeId);

    await preferences.setStringList(
      _favoriteBusKey,
      favoriteRouteIds.toList(),
    );
  }

  // 즐겨찾기 상태 반전
  static Future<bool> toggleFavorite(String routeId) async {
    final favoriteRouteIds = await getFavoriteRouteIds();

    if (favoriteRouteIds.contains(routeId)) {
      await removeFavorite(routeId);
      return false;
    }

    await addFavorite(routeId);
    return true;
  }
}