import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/equipment_item_model.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final equipmentRepositoryProvider = Provider<EquipmentRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return EquipmentRepository(
    firestore: firestore,
    storage: FirebaseStorage.instance,
  );
});

class EquipmentRepository {
  EquipmentRepository({
    required this.firestore,
    required this.storage,
  });

  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  CollectionReference<Map<String, dynamic>> _rawCollection(String churchId) {
    return FirestorePaths.churchEquipments(firestore, churchId);
  }

  CollectionReference<EquipmentItem> _collection(String churchId) {
    return _rawCollection(churchId).withConverter<EquipmentItem>(
      fromFirestore: (snapshot, _) => EquipmentItem.fromFirestore(
        snapshot.id,
        snapshot.data() ?? <String, dynamic>{},
      ),
      toFirestore: (item, _) => item.toMap(),
    );
  }

  Stream<List<EquipmentItem>> watchEquipment(String churchId) {
    return _collection(churchId)
        .orderBy('purchaseDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> createEquipment({
    required String churchId,
    required EquipmentFormData form,
  }) async {
    final docRef = _rawCollection(churchId).doc();
    String billUrl = '';
    String billFileName = '';

    if (form.billImage != null) {
      billUrl = await _uploadBill(
        churchId: churchId,
        equipmentId: docRef.id,
        billImage: form.billImage!,
      );
      billFileName = form.billImage!.name;
    }

    await docRef.set({
      'name': form.name.trim(),
      'category': form.category.trim(),
      'condition': form.condition.trim(),
      'location': form.location.trim(),
      'description': form.description.trim(),
      'purchaseDate': Timestamp.fromDate(form.purchaseDate),
      'amount': form.amount,
      'billUrl': billUrl,
      'billFileName': billFileName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateEquipment({
    required String churchId,
    required EquipmentFormData form,
  }) async {
    final equipmentId = form.id;
    if (equipmentId == null || equipmentId.trim().isEmpty) {
      throw StateError('Equipment id is required for update.');
    }

    var billUrl = form.existingBillUrl;
    var billFileName = form.existingBillFileName;

    if (form.billImage != null) {
      if (billUrl.trim().isNotEmpty) {
        try {
          await storage.refFromURL(billUrl).delete();
        } on FirebaseException catch (error) {
          if (error.code != 'object-not-found') rethrow;
        }
      }

      billUrl = await _uploadBill(
        churchId: churchId,
        equipmentId: equipmentId,
        billImage: form.billImage!,
      );
      billFileName = form.billImage!.name;
    }

    await _rawCollection(churchId).doc(equipmentId).set({
      'name': form.name.trim(),
      'category': form.category.trim(),
      'condition': form.condition.trim(),
      'location': form.location.trim(),
      'description': form.description.trim(),
      'purchaseDate': Timestamp.fromDate(form.purchaseDate),
      'amount': form.amount,
      'billUrl': billUrl,
      'billFileName': billFileName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteEquipment({
    required String churchId,
    required EquipmentItem item,
  }) async {
    if (item.billUrl.trim().isNotEmpty) {
      try {
        await storage.refFromURL(item.billUrl).delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') rethrow;
      }
    }

    await _rawCollection(churchId).doc(item.id).delete();
  }

  Future<String> _uploadBill({
    required String churchId,
    required String equipmentId,
    required PickedImageData billImage,
  }) async {
    final extensionParts = billImage.name.trim().split('.');
    final extension =
        extensionParts.length > 1 ? extensionParts.last.toLowerCase() : 'jpg';
    final storageRef = storage
        .ref()
        .child('churches/$churchId/equipments/$equipmentId/bill.$extension');

    await storageRef.putData(
      billImage.bytes,
      _metadataFor(billImage.name),
    );
    return storageRef.getDownloadURL();
  }
}

SettableMetadata _metadataFor(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) return SettableMetadata(contentType: 'image/png');
  if (lower.endsWith('.webp')) {
    return SettableMetadata(contentType: 'image/webp');
  }
  if (lower.endsWith('.gif')) return SettableMetadata(contentType: 'image/gif');
  if (lower.endsWith('.pdf')) {
    return SettableMetadata(contentType: 'application/pdf');
  }
  return SettableMetadata(contentType: 'image/jpeg');
}
