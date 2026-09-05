import 'package:flutter_application/church_app/models/side_drawer_models/equipment_item_model.dart';
import 'package:flutter_application/church_app/screens/side_drawer/equipment_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('equipment view model seeds an already-loaded provider snapshot', () {
    final item = EquipmentItem(
      id: 'equipment-id',
      name: 'Microphone',
      category: 'Audio',
      condition: 'Good',
      location: 'Main hall',
      purchaseDate: DateTime(2026, 8, 14),
      amount: 100,
      description: '',
      billUrl: '',
      billFileName: '',
      createdAt: DateTime(2026, 8, 14),
      updatedAt: DateTime(2026, 8, 14),
    );

    expect(
      equipmentItemsFromSnapshot(AsyncData([item])),
      [item],
    );
    expect(
      equipmentItemsFromSnapshot(
        const AsyncLoading<List<EquipmentItem>>(),
      ),
      isEmpty,
    );
  });
}
