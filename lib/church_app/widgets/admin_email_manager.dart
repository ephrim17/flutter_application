import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/input_validators.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';

class AdminEmailManager extends StatefulWidget {
  const AdminEmailManager({
    super.key,
    required this.initialAdmins,
    required this.onSave,
  });

  final List<String> initialAdmins;
  final Future<void> Function(List<String> admins) onSave;

  @override
  State<AdminEmailManager> createState() => _AdminEmailManagerState();
}

class _AdminEmailManagerState extends State<AdminEmailManager> {
  final TextEditingController _emailController = TextEditingController();
  late List<String> _admins;
  int? _editingIndex;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _admins = _normalizedAdmins(widget.initialAdmins);
  }

  @override
  void didUpdateWidget(covariant AdminEmailManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSaving && oldWidget.initialAdmins != widget.initialAdmins) {
      _admins = _normalizedAdmins(widget.initialAdmins);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  List<String> _normalizedAdmins(Iterable<String> values) {
    return values
        .map((email) => email.trim().toLowerCase())
        .where((email) => email.isNotEmpty)
        .toSet()
        .toList(growable: true);
  }

  void _beginEditing(int index) {
    setState(() {
      _editingIndex = index;
      _emailController.text = _admins[index];
      _emailController.selection = TextSelection.collapsed(
        offset: _emailController.text.length,
      );
      _errorText = null;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingIndex = null;
      _emailController.clear();
      _errorText = null;
    });
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim().toLowerCase();
    if (!InputValidators.isValidEmail(email)) {
      setState(
        () => _errorText = context.t('studio.admin_email_invalid'),
      );
      return;
    }

    final duplicateIndex = _admins.indexOf(email);
    if (duplicateIndex != -1 && duplicateIndex != _editingIndex) {
      setState(
        () => _errorText = context.t('studio.admin_email_duplicate'),
      );
      return;
    }

    final nextAdmins = List<String>.from(_admins);
    final editingIndex = _editingIndex;
    if (editingIndex == null) {
      nextAdmins.add(email);
    } else {
      nextAdmins[editingIndex] = email;
    }
    await _persist(nextAdmins);
  }

  Future<void> _delete(int index) async {
    if (_admins.length == 1) {
      setState(() {
        _errorText = context.t('studio.admin_last_remove_error');
      });
      return;
    }

    final email = _admins[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.person_remove_outlined),
        title: Text(context.t('studio.admin_remove_title')),
        content: Text(
          context.t(
            'studio.admin_remove_message',
            parameters: {'email': email},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.t('studio.admin_remove_action')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final nextAdmins = List<String>.from(_admins)..removeAt(index);
    await _persist(nextAdmins);
  }

  Future<void> _persist(List<String> nextAdmins) async {
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      await widget.onSave(nextAdmins);
      if (!mounted) return;
      setState(() {
        _admins = nextAdmins;
        _editingIndex = null;
        _emailController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('studio.admin_updated'))),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = context.t('studio.admin_update_failed');
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = _editingIndex != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Text(
          context.t('studio.admins_title'),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.t('studio.admins_description'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        AppTextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _isSaving ? null : _submit(),
          decoration: InputDecoration(
            labelText: context.t(
              editing ? 'studio.admin_update_label' : 'studio.admin_add_label',
            ),
            prefixIcon: const Icon(Icons.alternate_email_rounded),
            errorText: _errorText,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('admin-email-submit'),
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        editing
                            ? Icons.check_rounded
                            : Icons.person_add_alt_1_rounded,
                      ),
                label: Text(
                  context.t(
                    editing
                        ? 'studio.admin_update_action'
                        : 'studio.admin_add_action',
                  ),
                ),
              ),
            ),
            if (editing) ...[
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _isSaving ? null : _cancelEditing,
                child: Text(context.t('common.cancel')),
              ),
            ],
          ],
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Text(
              context.t('studio.admins_current'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '${_admins.length}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_admins.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(context.t('studio.admins_empty')),
          )
        else
          ...List.generate(_admins.length, (index) {
            final email = _admins[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    child: const Icon(Icons.admin_panel_settings_rounded),
                  ),
                  title: Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(context.t('studio.admin_role')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: context.t('studio.admin_edit_tooltip'),
                        onPressed:
                            _isSaving ? null : () => _beginEditing(index),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: context.t('studio.admin_remove_tooltip'),
                        onPressed: _isSaving ? null : () => _delete(index),
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
