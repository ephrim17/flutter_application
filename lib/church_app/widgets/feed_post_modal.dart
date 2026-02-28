import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/feeds_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/services/feed_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';

class CreatePostModal extends ConsumerStatefulWidget {
  const CreatePostModal({super.key});

  @override
  ConsumerState<CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends ConsumerState<CreatePostModal> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feedControllerProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              const Text(
                "Create Post",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Title",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "Description",
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image),
                  label: const Text("Add Image (Optional)"),
                ),
              ),
              if (_selectedImage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImage!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: state.isLoading
                      ? null
                      : () async {
                          final title = _titleController.text.trim();
                          final description =
                              _descriptionController.text.trim();

                          if (title.isEmpty || description.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("All fields are required"),
                              ),
                            );
                            return;
                          }

                          try {
                            await ref
                                .read(feedControllerProvider.notifier)
                                .createPost(
                                  title: title,
                                  description: description,
                                );

                            if (mounted) {
                              Navigator.of(context).pop();
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                ),
                              );
                            }
                          }
                        },
                  child: state.isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Post"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final feedControllerProvider =
    StateNotifierProvider<FeedController, AsyncValue<void>>(
  (ref) => FeedController(
    ref.read(feedRepositoryProvider),
    ref,
  ),
);

class FeedController extends StateNotifier<AsyncValue<void>> {
  final FeedRepository _repository;
  final Ref _ref;

  FeedController(this._repository, this._ref) : super(const AsyncData(null));

  Future<void> createPost({
    required String title,
    required String description,
  }) async {
    final churchAsync = _ref.read(currentChurchIdProvider);
    final churchId = churchAsync.value;
    final userAsync = _ref.read(getCurrentUserProvider);

    final user = userAsync.value;

    if (user == null) return;

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await _repository.createPost(
        churchId: churchId!,
        userId: user.uid,
        userName: user.name,
        title: title,
        description: description,
        imageFile: _selectedImage,
      );
    });
  }
}

File? _selectedImage;
final _picker = ImagePicker();
