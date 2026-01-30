
import 'package:flutter_application/church_app/models/for_you_section_model/favorites_model.dart';
import 'package:hooks_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, List<FavoriteVerse>>(
  (ref) => FavoritesNotifier(),
);

class FavoritesNotifier extends StateNotifier<List<FavoriteVerse>> {
  FavoritesNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('favorites') ?? [];
    state = list.map((e) => FavoriteVerse.fromJson(e)).toList();
  }

  Future<void> toggle(FavoriteVerse verse) async {
    final prefs = await SharedPreferences.getInstance();

    final exists = state.any(
      (v) => v.reference == verse.reference,
    );

    if (exists) {
      state = state.where((v) => v.reference != verse.reference).toList();
    } else {
      state = [...state, verse];
    }

    await prefs.setStringList(
      'favorites',
      state.map((e) => e.toJson()).toList(),
    );
  }

  bool isFavorite(String reference) {
    return state.any((v) => v.reference == reference);
  }
}
