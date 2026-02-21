import 'package:hooks_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/for_you_section_models/highlight_verse_model.dart';

final highlightsProvider =
    StateNotifierProvider<HighlightsNotifier, Set<String>>((ref) {
  return HighlightsNotifier();
});

class HighlightsNotifier extends StateNotifier<Set<String>> {
  static const _globalKey = 'all_highlights';

  HighlightsNotifier() : super({}) {
    loadHighlights();
  }

  Future<void> loadHighlights() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_globalKey) ?? [];
    state = stored.toSet();
  }

  Future<void> toggleHighlight(HighlightRef refData) async {
    final prefs = await SharedPreferences.getInstance();

    final key =
        "${refData.book}_${refData.chapter}_${refData.verse}";

    final newState = {...state};

    if (newState.contains(key)) {
      newState.remove(key);
    } else {
      newState.add(key);
    }

    state = newState;
    await prefs.setStringList(_globalKey, state.toList());
  }

  bool isHighlighted(String key) {
    return state.contains(key);
  }
}
