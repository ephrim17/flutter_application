import 'package:hooks_riverpod/legacy.dart';

enum Filter {
  glutenFree,
}

class FiltersProvider extends StateNotifier<Map<Filter, bool>> {
  FiltersProvider() : super({
    Filter.glutenFree: false,
  });

  void setFilter(Map<Filter, bool> chosenFilters) {
    state = chosenFilters;
  }
}

final filterProvider = StateNotifierProvider<FiltersProvider, Map<Filter, bool>>((ref) {
  return FiltersProvider();
});