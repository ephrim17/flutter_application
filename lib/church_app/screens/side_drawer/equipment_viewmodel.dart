import 'package:flutter_application/church_app/models/side_drawer_models/equipment_item_model.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/screens/side_drawer/equipment_view_state.dart';
import 'package:flutter_application/church_app/services/side_drawer/equipment_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final equipmentItemsProvider =
    StreamProvider<List<EquipmentItem>>((ref) async* {
  final churchId = await ref.watch(currentChurchIdProvider.future);
  if (churchId == null || churchId.trim().isEmpty) {
    yield const <EquipmentItem>[];
    return;
  }

  final repository = ref.watch(equipmentRepositoryProvider);
  yield* repository.watchEquipment(churchId);
});

final equipmentViewModelProvider =
    NotifierProvider<EquipmentViewModel, EquipmentViewState>(
  EquipmentViewModel.new,
);

class EquipmentViewModel extends Notifier<EquipmentViewState> {
  @override
  EquipmentViewState build() {
    final isAdmin = ref.watch(isAdminProvider);
    final church = ref.watch(selectedChurchProvider);
    final churchName =
        church?.name.trim().isNotEmpty == true ? church!.name.trim() : 'Church';

    ref.listen<AsyncValue<List<EquipmentItem>>>(equipmentItemsProvider, (
      _,
      next,
    ) {
      final items = next.asData?.value;
      if (items == null) return;
      state = state.copyWith(items: items);
    });

    return EquipmentViewState.initial(
      isAdmin: isAdmin,
      churchName: churchName,
      items: const <EquipmentItem>[],
    );
  }

  void setQuery(String value) {
    state = state.copyWith(query: value);
  }

  void clearQuery() {
    state = state.copyWith(query: '');
  }

  void selectCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void selectCondition(String condition) {
    state = state.copyWith(selectedCondition: condition);
  }

  void selectSortOption(EquipmentSortOption option) {
    state = state.copyWith(sortOption: option);
  }

  Future<void> addEquipment(EquipmentFormData form) async {
    final churchId = await ref.read(currentChurchIdProvider.future);
    if (churchId == null || churchId.trim().isEmpty) {
      throw StateError('No church selected.');
    }

    state = state.copyWith(isSubmitting: true);
    try {
      await ref
          .read(equipmentRepositoryProvider)
          .createEquipment(churchId: churchId, form: form);

      state = state.copyWith(
        isSubmitting: false,
        query: '',
        selectedCategory: 'All',
        selectedCondition: 'All health',
        sortOption: EquipmentSortOption.newestFirst,
      );
    } catch (_) {
      state = state.copyWith(isSubmitting: false);
      rethrow;
    }
  }

  Future<void> updateEquipment(EquipmentFormData form) async {
    final churchId = await ref.read(currentChurchIdProvider.future);
    if (churchId == null || churchId.trim().isEmpty) {
      throw StateError('No church selected.');
    }

    state = state.copyWith(isSubmitting: true);
    try {
      await ref
          .read(equipmentRepositoryProvider)
          .updateEquipment(churchId: churchId, form: form);
      state = state.copyWith(isSubmitting: false);
    } catch (_) {
      state = state.copyWith(isSubmitting: false);
      rethrow;
    }
  }

  Future<void> deleteEquipment(EquipmentItem item) async {
    final churchId = await ref.read(currentChurchIdProvider.future);
    if (churchId == null || churchId.trim().isEmpty) {
      throw StateError('No church selected.');
    }

    state = state.copyWith(isSubmitting: true);
    try {
      await ref
          .read(equipmentRepositoryProvider)
          .deleteEquipment(churchId: churchId, item: item);
      state = state.copyWith(isSubmitting: false);
    } catch (_) {
      state = state.copyWith(isSubmitting: false);
      rethrow;
    }
  }
}
