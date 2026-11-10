import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/models/attendance_service_model.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/side_drawer/attendance_providers.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Record a service, or edit one that exists.
///
/// Pops the new service's id when creating, so the caller can go straight on
/// to marking attendance; pops null when editing or cancelling.
class AttendanceServiceForm extends ConsumerStatefulWidget {
  const AttendanceServiceForm({super.key, this.existing});

  final AttendanceService? existing;

  @override
  ConsumerState<AttendanceServiceForm> createState() =>
      _AttendanceServiceFormState();
}

class _AttendanceServiceFormState extends ConsumerState<AttendanceServiceForm> {
  static final _dateFormat = DateFormat('EEEE, d MMM yyyy');

  late DateTime _date = widget.existing?.date ?? DateTime.now();
  late String _type = widget.existing?.type ?? attendanceServiceTypeKeys.first;
  late final _visitors = TextEditingController(
    text: (widget.existing?.visitorCount ?? 0) == 0
        ? ''
        : '${widget.existing!.visitorCount}',
  );
  late final _children = TextEditingController(
    text: (widget.existing?.childrenCount ?? 0) == 0
        ? ''
        : '${widget.existing!.childrenCount}',
  );
  late final _subheader =
      TextEditingController(text: widget.existing?.subheader ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');

  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _visitors.dispose();
    _children.dispose();
    _subheader.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing
                    ? context.t('attendance.edit_service')
                    : context.t('attendance.record_service'),
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              _FieldLabel(text: context.t('attendance.service_date')),
              const SizedBox(height: 6),
              _DateField(
                label: _dateFormat.format(_date),
                onTap: _pickDate,
              ),
              const SizedBox(height: 16),
              _FieldLabel(text: context.t('attendance.service_type')),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final key in attendanceServiceTypeKeys)
                    ChoiceChip(
                      label: Text(
                        context.t('attendance.service_type.$key',
                            fallback: key),
                      ),
                      selected: _type == key,
                      onSelected: (_) => setState(() => _type = key),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _subheader,
                label: context.t('attendance.service_subheader'),
                hintText: context.t('attendance.service_subheader_hint'),
                // A card line, not a paragraph — notes is the field for prose.
                maxLength: 60,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _visitors,
                      label: context.t('attendance.visitor_count'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _children,
                      label: context.t('attendance.children_count'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _notes,
                label: context.t('attendance.notes'),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _isEditing
                              ? context.t('attendance.save_details_action')
                              : context.t('attendance.create_action'),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // A service can be backdated — churches catch up on a week of
      // registers — but one cannot be held in the future.
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.t('attendance.save_failed');

    try {
      final repository = ref.read(attendanceRepositoryProvider);
      final visitors = int.tryParse(_visitors.text.trim()) ?? 0;
      final children = int.tryParse(_children.text.trim()) ?? 0;
      final notes = _notes.text.trim();
      final subheader = _subheader.text.trim();

      if (_isEditing) {
        await repository.updateServiceDetails(
          serviceId: widget.existing!.id,
          date: _date,
          type: _type,
          subheader: subheader,
          visitorCount: visitors,
          childrenCount: children,
          notes: notes,
        );
        navigator.pop();
        return;
      }

      final serviceId = await repository.createService(
        date: _date,
        type: _type,
        subheader: subheader,
        visitorCount: visitors,
        childrenCount: children,
        notes: notes,
        createdBy: ref.read(firebaseAuthProvider).currentUser?.uid ?? '',
      );
      navigator.pop(serviceId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.event_outlined, size: 20, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.expand_more_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
