import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_application/church_app/models/learning_module_models.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';

class LearningModuleRepository {
  LearningModuleRepository({
    required this.firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })  : storage = storage ?? FirebaseStorage.instance,
        auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final FirebaseAuth auth;

  CollectionReference<Map<String, dynamic>> get _modules =>
      FirestorePaths.learningModulesCollection(firestore);

  String createModuleId() => _modules.doc().id;

  Future<int> nextModuleOrder({String? churchId}) async {
    final collection = churchId == null
        ? _modules
        : FirestorePaths.churchLearningModulesCollection(firestore, churchId);
    final snapshot =
        await collection.orderBy('order', descending: true).limit(1).get();
    if (snapshot.docs.isEmpty) return 10;
    return _number(snapshot.docs.first.data()['order']) + 10;
  }

  Future<void> reorderGlobalModules(List<LearningModule> modules) async {
    await _requireSuperAdmin();
    final batch = firestore.batch();
    for (var index = 0; index < modules.length; index++) {
      batch.set(
        _modules.doc(modules[index].id),
        {
          'order': (index + 1) * 10,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Stream<List<LearningModule>> watchPublishedModules() =>
      _modules.orderBy('order').snapshots().map((snapshot) => snapshot.docs
          .map(LearningModule.fromDoc)
          .where((module) => module.enabled && module.isConfigured)
          .toList(growable: false));

  Stream<List<LearningModule>> watchAllModules() =>
      _modules.orderBy('order').snapshots().map((snapshot) =>
          snapshot.docs.map(LearningModule.fromDoc).toList(growable: false));

  Stream<ChurchLearningConfig> watchChurchConfig(String churchId) =>
      FirestorePaths.churchLearningConfig(firestore, churchId)
          .snapshots()
          .map((snapshot) => ChurchLearningConfig.fromMap(snapshot.data()));

  Stream<List<LearningModule>> watchChurchModules(String churchId) =>
      FirestorePaths.churchLearningModulesCollection(firestore, churchId)
          .orderBy('order')
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map(LearningModule.fromDoc)
              .toList(growable: false));

  Stream<List<LearningModule>> watchResolvedPublishedModules(
    String churchId,
  ) {
    late final StreamController<List<LearningModule>> controller;
    List<LearningModule>? globals;
    List<LearningModule>? churchModules;
    ChurchLearningConfig? config;
    final subscriptions = <StreamSubscription<dynamic>>[];

    void emit() {
      if (globals == null || churchModules == null || config == null) return;
      controller.add(
        resolveChurchLearningModules(
          config: config!,
          globalModules: globals!,
          churchModules: churchModules!,
        ),
      );
    }

    controller = StreamController<List<LearningModule>>(
      onListen: () {
        subscriptions.add(
          watchAllModules().listen((value) {
            globals = value;
            emit();
          }, onError: controller.addError),
        );
        subscriptions.add(
          watchChurchModules(churchId).listen((value) {
            churchModules = value;
            emit();
          }, onError: controller.addError),
        );
        subscriptions.add(
          watchChurchConfig(churchId).listen((value) {
            config = value;
            emit();
          }, onError: controller.addError),
        );
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  Stream<LearningProgress> watchProgress({
    required String churchId,
    required String userId,
  }) =>
      FirestorePaths.churchUserLearningProgress(
        firestore,
        churchId,
        userId,
      ).doc('progress').snapshots().map(
            (snapshot) => LearningProgress.fromMap(snapshot.data()),
          );

  Stream<List<LearningQuizResult>> watchChurchResults(String churchId) =>
      FirestorePaths.churchLearningResults(firestore, churchId)
          .orderBy('submittedAt', descending: true)
          .limit(500)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map(LearningQuizResult.fromDoc)
              .toList(growable: false));

  Future<void> saveModule({
    required String id,
    required String title,
    required String description,
    required int order,
    required bool enabled,
    required List<LearningSection> sections,
    required List<LearningQuizQuestion> finalExamQuestions,
    required int passingPercentage,
  }) async {
    await _requireSuperAdmin();
    final reference = _modules.doc(id);
    final existing = await reference.get();
    await reference.set({
      'title': title.trim(),
      'description': description.trim(),
      'order': order,
      'enabled': enabled,
      'sections': sections.map((section) => section.toMap()).toList(),
      'finalExamQuestions':
          finalExamQuestions.map((question) => question.toMap()).toList(),
      'passingPercentage': passingPercentage,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveChurchModule({
    required String churchId,
    required String id,
    required String title,
    required String description,
    required int order,
    required bool enabled,
    required List<LearningSection> sections,
    required List<LearningQuizQuestion> finalExamQuestions,
    required int passingPercentage,
    String sourceModuleId = '',
  }) async {
    await _requireSuperAdmin();
    final reference = FirestorePaths.churchLearningModulesCollection(
      firestore,
      churchId,
    ).doc(id);
    final existing = await reference.get();
    await reference.set({
      'title': title.trim(),
      'description': description.trim(),
      'order': order,
      'enabled': enabled,
      'sourceModuleId': sourceModuleId.trim(),
      'sections': sections.map((section) => section.toMap()).toList(),
      'finalExamQuestions':
          finalExamQuestions.map((question) => question.toMap()).toList(),
      'passingPercentage': passingPercentage,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveChurchConfig({
    required String churchId,
    required ChurchLearningConfig config,
  }) async {
    await _requireSuperAdmin();
    await FirestorePaths.churchLearningConfig(firestore, churchId).set({
      'enabled': config.enabled,
      'inheritGlobalModules': config.inheritGlobalModules,
      'hiddenGlobalModuleIds': config.hiddenGlobalModuleIds.toList(),
      'moduleOrder': config.moduleOrder,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<LearningResource> uploadResource({
    required String moduleId,
    required String sectionId,
    required String fileName,
    required Uint8List bytes,
    required LearningResourceType type,
    required String contentType,
    required int order,
    String? churchId,
  }) async {
    await _requireSuperAdmin();
    final safeName = _safeFileName(fileName);
    final objectName = '${DateTime.now().microsecondsSinceEpoch}_$safeName';
    final path = churchId == null
        ? 'churches/global/learning_modules/$moduleId/$sectionId/$objectName'
        : 'churches/$churchId/learning_modules/$moduleId/$sectionId/$objectName';
    final reference = storage.ref().child(path);
    await reference.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: {'originalName': fileName.trim()},
      ),
    );
    return LearningResource(
      name: fileName.trim(),
      downloadUrl: await reference.getDownloadURL(),
      storagePath: path,
      type: type,
      order: order,
    );
  }

  Future<LearningResource> copyResourceToChurch({
    required String churchId,
    required String moduleId,
    required String sectionId,
    required LearningResource resource,
  }) async {
    await _requireSuperAdmin();
    if (resource.storagePath.isEmpty) return resource;
    final bytes = await storage
        .ref()
        .child(resource.storagePath)
        .getData(15 * 1024 * 1024);
    if (bytes == null) throw StateError('Unable to copy learning resource.');
    return uploadResource(
      moduleId: moduleId,
      sectionId: sectionId,
      fileName: resource.name,
      bytes: bytes,
      type: resource.type,
      contentType: resource.type == LearningResourceType.image
          ? _imageContentType(resource.name)
          : 'application/pdf',
      order: resource.order,
      churchId: churchId,
    );
  }

  Future<void> deleteResource(LearningResource resource) async {
    await _requireSuperAdmin();
    if (resource.storagePath.isEmpty) return;
    try {
      await storage.ref().child(resource.storagePath).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }

  Future<void> deleteModule(LearningModule module) async {
    await _requireSuperAdmin();
    for (final section in module.sections) {
      for (final resource in section.resources) {
        await deleteResource(resource);
      }
    }
    await _modules.doc(module.id).delete();
  }

  Future<void> deleteChurchModule({
    required String churchId,
    required LearningModule module,
  }) async {
    await _requireSuperAdmin();
    final ownedPrefix = 'churches/$churchId/learning_modules/${module.id}/';
    for (final section in module.sections) {
      for (final resource in section.resources) {
        if (resource.storagePath.startsWith(ownedPrefix)) {
          await deleteResource(resource);
        }
      }
    }
    await FirestorePaths.churchLearningModulesCollection(
      firestore,
      churchId,
    ).doc(module.id).delete();
  }

  Future<void> submitSectionQuiz({
    required String churchId,
    required String userId,
    required String moduleId,
    required String sectionId,
    required String userName,
    required String userEmail,
    required List<int> answers,
    required int score,
    required int total,
    required bool passed,
  }) async {
    final reference = FirestorePaths.churchUserLearningProgress(
      firestore,
      churchId,
      userId,
    ).doc('progress');
    final resultReference =
        FirestorePaths.churchLearningResults(firestore, churchId).doc();
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final current = snapshot.data() ?? const <String, dynamic>{};
      final attempts = current['attempts'] is Map
          ? Map<String, dynamic>.from(current['attempts'] as Map)
          : <String, dynamic>{};
      final attemptCounts = current['attemptCounts'] is Map
          ? Map<String, dynamic>.from(current['attemptCounts'] as Map)
          : <String, dynamic>{};
      final attemptNumber = _number(attemptCounts[sectionId]) + 1;
      attemptCounts[sectionId] = attemptNumber;
      attempts[sectionId] = {
        'moduleId': moduleId,
        'answers': answers,
        'score': score,
        'total': total,
        'passed': passed,
        'attemptNumber': attemptNumber,
        'completedAt': Timestamp.now(),
      };
      transaction.set(
        reference,
        {
          'userId': userId,
          'churchId': churchId,
          if (passed) 'completedSectionIds': FieldValue.arrayUnion([sectionId]),
          'attempts': attempts,
          'attemptCounts': attemptCounts,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      transaction.set(resultReference, {
        'churchId': churchId,
        'userId': userId,
        'userName': userName.trim(),
        'userEmail': userEmail.trim(),
        'moduleId': moduleId,
        'sectionId': sectionId,
        'answers': answers,
        'score': score,
        'total': total,
        'passed': passed,
        'attemptNumber': attemptNumber,
        'submittedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> completeSection({
    required String churchId,
    required String userId,
    required String sectionId,
  }) async {
    await FirestorePaths.churchUserLearningProgress(
      firestore,
      churchId,
      userId,
    ).doc('progress').set({
      'userId': userId,
      'churchId': churchId,
      'completedSectionIds': FieldValue.arrayUnion([sectionId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> submitModuleExam({
    required String churchId,
    required String userId,
    required String moduleId,
    required String userName,
    required String userEmail,
    required List<int> answers,
    required int score,
    required int total,
    required bool passed,
  }) async {
    final progressReference = FirestorePaths.churchUserLearningProgress(
      firestore,
      churchId,
      userId,
    ).doc('progress');
    final resultReference =
        FirestorePaths.churchLearningResults(firestore, churchId).doc();
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(progressReference);
      final current = snapshot.data() ?? const <String, dynamic>{};
      final attemptCounts = current['moduleAttemptCounts'] is Map
          ? Map<String, dynamic>.from(current['moduleAttemptCounts'] as Map)
          : <String, dynamic>{};
      final attemptNumber = _number(attemptCounts[moduleId]) + 1;
      attemptCounts[moduleId] = attemptNumber;
      transaction.set(
        progressReference,
        {
          'userId': userId,
          'churchId': churchId,
          if (passed) 'completedModuleIds': FieldValue.arrayUnion([moduleId]),
          'moduleAttemptCounts': attemptCounts,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      transaction.set(resultReference, {
        'churchId': churchId,
        'userId': userId,
        'userName': userName.trim(),
        'userEmail': userEmail.trim(),
        'moduleId': moduleId,
        'sectionId': '',
        'assessmentType': 'finalExam',
        'answers': answers,
        'score': score,
        'total': total,
        'passed': passed,
        'attemptNumber': attemptNumber,
        'submittedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _requireSuperAdmin() async {
    final email = auth.currentUser?.email?.trim().toLowerCase() ?? '';
    if (email.isEmpty) throw StateError('Super admin authentication required.');
    final snapshot = await firestore
        .collection('superAdmins')
        .where('email', isEqualTo: email)
        .where('enabled', isEqualTo: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      throw StateError('Super admin authorization required.');
    }
  }
}

int _number(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

String _safeFileName(String value) {
  final normalized = value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  return normalized.isEmpty ? 'resource' : normalized;
}

String _imageContentType(String fileName) {
  final extension = fileName.split('.').last.toLowerCase();
  return switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    _ => 'image/jpeg',
  };
}
