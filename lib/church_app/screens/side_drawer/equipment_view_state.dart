import 'package:flutter_application/church_app/models/side_drawer_models/equipment_item_model.dart';

enum EquipmentSortOption {
  newestFirst,
  oldestFirst,
  nameAscending,
  categoryAscending,
}

class EquipmentViewState {
  const EquipmentViewState({
    required this.isAdmin,
    required this.churchName,
    required this.items,
    required this.isSubmitting,
    required this.query,
    required this.selectedCategory,
    required this.selectedCondition,
    required this.sortOption,
  });

  final bool isAdmin;
  final String churchName;
  final List<EquipmentItem> items;
  final bool isSubmitting;
  final String query;
  final String selectedCategory;
  final String selectedCondition;
  final EquipmentSortOption sortOption;

  factory EquipmentViewState.initial({
    required bool isAdmin,
    required String churchName,
    required List<EquipmentItem> items,
  }) {
    return EquipmentViewState(
      isAdmin: isAdmin,
      churchName: churchName,
      items: items,
      isSubmitting: false,
      query: '',
      selectedCategory: 'All',
      selectedCondition: 'All health',
      sortOption: EquipmentSortOption.newestFirst,
    );
  }

  List<String> get categories => <String>[
        'All',
        ...items.map((item) => item.category).toSet(),
      ];

  List<String> get conditions => <String>[
        'All health',
        ...items.map((item) => item.condition).toSet(),
      ];

  List<EquipmentItem> get visibleItems {
    final normalizedQuery = query.trim().toLowerCase();
    final filtered = items.where((item) {
      final matchesCategory =
          selectedCategory == 'All' || item.category == selectedCategory;
      final matchesCondition = selectedCondition == 'All health' ||
          item.condition == selectedCondition;
      final matchesQuery = normalizedQuery.isEmpty ||
          item.name.toLowerCase().contains(normalizedQuery) ||
          item.category.toLowerCase().contains(normalizedQuery) ||
          item.condition.toLowerCase().contains(normalizedQuery) ||
          item.location.toLowerCase().contains(normalizedQuery) ||
          item.description.toLowerCase().contains(normalizedQuery);
      return matchesCategory && matchesCondition && matchesQuery;
    }).toList(growable: false);

    filtered.sort((a, b) {
      switch (sortOption) {
        case EquipmentSortOption.newestFirst:
          return b.purchaseDate.compareTo(a.purchaseDate);
        case EquipmentSortOption.oldestFirst:
          return a.purchaseDate.compareTo(b.purchaseDate);
        case EquipmentSortOption.nameAscending:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case EquipmentSortOption.categoryAscending:
          final categoryCompare =
              a.category.toLowerCase().compareTo(b.category.toLowerCase());
          if (categoryCompare != 0) return categoryCompare;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });

    return filtered;
  }

  int get totalCount => items.length;

  int get categoryCount => categories.length - 1;

  int get locationCount => items.map((item) => item.location).toSet().length;

  int get recentCount => items
      .where(
          (item) => DateTime.now().difference(item.purchaseDate).inDays <= 45)
      .length;

  int get activeFilterCount =>
      (selectedCategory == 'All' ? 0 : 1) +
      (selectedCondition == 'All health' ? 0 : 1) +
      (query.trim().isEmpty ? 0 : 1);

  EquipmentViewState copyWith({
    bool? isAdmin,
    String? churchName,
    List<EquipmentItem>? items,
    bool? isSubmitting,
    String? query,
    String? selectedCategory,
    String? selectedCondition,
    EquipmentSortOption? sortOption,
  }) {
    return EquipmentViewState(
      isAdmin: isAdmin ?? this.isAdmin,
      churchName: churchName ?? this.churchName,
      items: items ?? this.items,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      query: query ?? this.query,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedCondition: selectedCondition ?? this.selectedCondition,
      sortOption: sortOption ?? this.sortOption,
    );
  }
}
