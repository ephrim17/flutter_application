import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart'
    show churchRepositoryProvider;
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Lets a church's own admin edit its public profile — name, pastor,
/// contact details and social links — reachable from Settings
/// (`_ChurchProfileSection`) rather than the old Discover tab.
class ChurchProfileEditorSheet extends ConsumerStatefulWidget {
  const ChurchProfileEditorSheet({
    super.key,
    required this.church,
    required this.onSaved,
  });

  final Church church;
  final Future<void> Function() onSaved;

  @override
  ConsumerState<ChurchProfileEditorSheet> createState() =>
      _ChurchProfileEditorSheetState();
}

class _ChurchProfileEditorSheetState
    extends ConsumerState<ChurchProfileEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _pastorController;
  late final TextEditingController _addressController;
  late final TextEditingController _contactController;
  late final TextEditingController _emailController;
  late final TextEditingController _facebookController;
  late final TextEditingController _instagramController;
  late final TextEditingController _youtubeController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.church.name);
    _pastorController = TextEditingController(text: widget.church.pastorName);
    _addressController = TextEditingController(text: widget.church.address);
    _contactController = TextEditingController(text: widget.church.contact);
    _emailController = TextEditingController(text: widget.church.email);
    _facebookController =
        TextEditingController(text: widget.church.facebookLink);
    _instagramController =
        TextEditingController(text: widget.church.instagramLink);
    _youtubeController = TextEditingController(text: widget.church.youtubeLink);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pastorController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _youtubeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(churchRepositoryProvider).updateChurchDiscoveryDetails(
            churchId: widget.church.id,
            name: _nameController.text,
            pastorName: _pastorController.text,
            address: _addressController.text,
            contact: _contactController.text,
            email: _emailController.text,
            facebookLink: _facebookController.text,
            instagramLink: _instagramController.text,
            youtubeLink: _youtubeController.text,
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      await widget.onSaved();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('ui.go_further.church_discovery_details'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              context.t(
                  'ui.go_further.update_your_church_details_and_add_facebook_instagram_o'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            _EditorField(
              controller: _nameController,
              label: context.t('ui.go_further.church_name'),
            ),
            _EditorField(
              controller: _pastorController,
              label: context.t('ui.go_further.pastor_name'),
            ),
            _EditorField(
              controller: _addressController,
              label: context.t('ui.go_further.address_d70f'),
            ),
            _EditorField(
              controller: _contactController,
              label: context.t('ui.go_further.contact_b374'),
            ),
            _EditorField(
              controller: _emailController,
              label: context.t('ui.go_further.email_84ad'),
            ),
            _EditorField(
              controller: _facebookController,
              label: context.t('ui.go_further.facebook_link'),
            ),
            _EditorField(
              controller: _instagramController,
              label: context.t('ui.go_further.instagram_link'),
            ),
            _EditorField(
              controller: _youtubeController,
              label: context.t('ui.go_further.youtube_link'),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.t('ui.go_further.save')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorField extends StatelessWidget {
  const _EditorField({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppTextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(cornerRadius),
          ),
        ),
      ),
    );
  }
}
