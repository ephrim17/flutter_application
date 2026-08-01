import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/helpers/input_validators.dart';
import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/equipment_item_model.dart';
import 'package:flutter_application/church_app/screens/side_drawer/equipment_view_state.dart';
import 'package:flutter_application/church_app/screens/side_drawer/equipment_viewmodel.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

String _equipmentItemCountText(BuildContext context, int count) {
  return context.t(
    count == 1
        ? 'equipment.item_count_singular'
        : 'equipment.item_count_plural',
    parameters: {'count': '$count'},
  );
}

class EquipmentScreen extends ConsumerStatefulWidget {
  const EquipmentScreen({super.key});

  @override
  ConsumerState<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends ConsumerState<EquipmentScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final equipmentState = ref.watch(equipmentViewModelProvider);
    final equipmentItemsAsync = ref.watch(equipmentItemsProvider);
    final equipmentViewModel = ref.read(equipmentViewModelProvider.notifier);
    final theme = Theme.of(context);

    if (!equipmentState.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: AppBarTitle(text: context.t('equipment.title')),
        ),
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: carouselBoxDecoration(context),
            child: Text(
              context.t(
                  'ui.equipment.equipment_management_is_available_only_for_admins'),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(text: context.t('equipment.title')),
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                sliver: SliverToBoxAdapter(
                  child: _EquipmentHeroCard(
                    churchName: equipmentState.churchName,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: GridView.count(
                    crossAxisCount:
                        MediaQuery.of(context).size.width >= 900 ? 4 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _EquipmentSummaryCard(
                        title: context.t('ui.equipment.total_equipment'),
                        value: equipmentState.totalCount.toString(),
                        icon: Icons.inventory_2_outlined,
                        colors: const [Color(0xFF5C9EFF), Color(0xFF4A6BFF)],
                        onTap: () => _showSummaryDetails(
                          context,
                          title: context.t('ui.equipment.all_equipment'),
                          subtitle: context.t(
                              'ui.equipment.every_equipment_item_currently_tracked'),
                          entries: equipmentState.items
                              .map(
                                (item) => _SummaryDetailEntry(
                                  title: item.name,
                                  subtitle:
                                      '${item.category} • ${item.condition} • ${item.location} • ${_equipmentDateLabel(item.purchaseDate)}',
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                      _EquipmentSummaryCard(
                        title: context.t('ui.equipment.categories'),
                        value: '${equipmentState.categoryCount}',
                        icon: Icons.category_outlined,
                        colors: const [Color(0xFF3AC79B), Color(0xFF18A86A)],
                        onTap: () => _showSummaryDetails(
                          context,
                          title: context.t('ui.equipment.equipment_categories'),
                          subtitle: context.t(
                              'ui.equipment.how_your_church_equipment_is_grouped'),
                          entries: equipmentState.categories
                              .where((category) => category != 'All')
                              .map(
                                (category) => _SummaryDetailEntry(
                                  title: category,
                                  subtitle: _equipmentItemCountText(
                                    context,
                                    equipmentState.items
                                        .where(
                                          (item) => item.category == category,
                                        )
                                        .length,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                      _EquipmentSummaryCard(
                        title: context.t('ui.equipment.locations'),
                        value: '${equipmentState.locationCount}',
                        icon: Icons.place_outlined,
                        colors: const [Color(0xFF8E7CFF), Color(0xFF6E54F6)],
                        onTap: () => _showSummaryDetails(
                          context,
                          title: context.t('ui.equipment.equipment_locations'),
                          subtitle: context.t(
                              'ui.equipment.where_each_item_is_currently_kept'),
                          entries: equipmentState.items
                              .map((item) => item.location)
                              .toSet()
                              .map(
                                (location) => _SummaryDetailEntry(
                                  title: location,
                                  subtitle: _equipmentItemCountText(
                                    context,
                                    equipmentState.items
                                        .where(
                                          (item) => item.location == location,
                                        )
                                        .length,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                      _EquipmentSummaryCard(
                        title: context.t('ui.equipment.recent_additions'),
                        value: '${equipmentState.recentCount}',
                        icon: Icons.auto_awesome_outlined,
                        colors: const [Color(0xFFFFA16B), Color(0xFFF47C48)],
                        onTap: () => _showSummaryDetails(
                          context,
                          title:
                              context.t('ui.equipment.recent_additions_7a89'),
                          subtitle: context.t(
                              'ui.equipment.items_added_in_the_last_45_days'),
                          entries: equipmentState.items
                              .where(
                                (item) =>
                                    DateTime.now()
                                        .difference(item.purchaseDate)
                                        .inDays <=
                                    45,
                              )
                              .map(
                                (item) => _SummaryDetailEntry(
                                  title: item.name,
                                  subtitle:
                                      '${item.category} • ${item.condition} • ${item.location} • ${_equipmentDateLabel(item.purchaseDate)}',
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: carouselBoxDecoration(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.t('ui.equipment.find_equipment'),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (equipmentState.activeFilterCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  context.t(
                                    'equipment.active_filter_count',
                                    parameters: {
                                      'count':
                                          '${equipmentState.activeFilterCount}',
                                    },
                                  ),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          variant: AppTextFieldVariant.search,
                          controller: _searchController,
                          onChanged: equipmentViewModel.setQuery,
                          decoration: InputDecoration(
                            hintText: context.t(
                                'ui.equipment.search_by_item_name_category_location_or_notes'),
                            prefixIcon: Padding(
                              padding:
                                  const EdgeInsets.only(left: 10, right: 6),
                              child: Icon(
                                Icons.search_rounded,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            suffixIcon: equipmentState.query.trim().isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      equipmentViewModel.clearQuery();
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.transparent,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: AppDropdownField<String>(
                                labelText: context.t('ui.equipment.category'),
                                initialValue: equipmentState.selectedCategory,
                                items: equipmentState.categories
                                    .map(
                                      (category) => DropdownMenuItem<String>(
                                        value: category,
                                        child: Text(category),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: (value) {
                                  if (value == null) return;
                                  equipmentViewModel.selectCategory(value);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppDropdownField<String>(
                                labelText: context.t('ui.equipment.health'),
                                initialValue: equipmentState.selectedCondition,
                                items: equipmentState.conditions
                                    .map(
                                      (condition) => DropdownMenuItem<String>(
                                        value: condition,
                                        child: Text(condition),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: (value) {
                                  if (value == null) return;
                                  equipmentViewModel.selectCondition(value);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: AppDropdownField<EquipmentSortOption>(
                                labelText: context.t('ui.equipment.sort_by'),
                                initialValue: equipmentState.sortOption,
                                items: EquipmentSortOption.values
                                    .map(
                                      (option) =>
                                          DropdownMenuItem<EquipmentSortOption>(
                                        value: option,
                                        child: Text(
                                          context.t(_sortOptionTextKey(option)),
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: (value) {
                                  if (value == null) return;
                                  equipmentViewModel.selectSortOption(value);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: carouselBoxDecoration(context),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.t('ui.equipment.equipment_list'),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.t(
                                  equipmentState.visibleItems.length == 1
                                      ? 'equipment.item_showing_singular'
                                      : 'equipment.item_showing_plural',
                                  parameters: {
                                    'count':
                                        '${equipmentState.visibleItems.length}',
                                  },
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.68),
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: equipmentState.isSubmitting
                              ? null
                              : () => _showAddEquipmentSheet(context),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(context.t('ui.equipment.add')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (equipmentItemsAsync.isLoading && equipmentState.items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: AppLoadingIndicator()),
                )
              else if (equipmentItemsAsync.hasError &&
                  equipmentState.items.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverToBoxAdapter(
                    child: _EquipmentEmptyState(
                      query: '',
                      category: 'All',
                      message: context
                          .t('ui.equipment.unable_to_load_equipment_right_now'),
                    ),
                  ),
                )
              else if (equipmentState.visibleItems.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverToBoxAdapter(
                    child: _EquipmentEmptyState(
                      query: equipmentState.query,
                      category: equipmentState.selectedCategory,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList.builder(
                    itemCount: equipmentState.visibleItems.length,
                    itemBuilder: (context, index) {
                      final item = equipmentState.visibleItems[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom:
                              index == equipmentState.visibleItems.length - 1
                                  ? 0
                                  : 12,
                        ),
                        child: _EquipmentListCard(
                          item: item,
                          onTap: () => _showEquipmentDetails(context, item),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          if (equipmentState.isSubmitting)
            Positioned.fill(
              child: AbsorbPointer(
                child: Container(
                  color: theme.colorScheme.scrim.withValues(alpha: 0.22),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 22,
                      ),
                      decoration: carouselBoxDecoration(context),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.6),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            context.t('ui.equipment.saving_equipment'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAddEquipmentSheet(BuildContext context) async {
    final form = await showAppModalBottomSheet<EquipmentFormData>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddEquipmentSheet(),
    );

    if (form == null || !context.mounted) return;
    try {
      await ref.read(equipmentViewModelProvider.notifier).addEquipment(form);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('equipment.save_failed', parameters: {'error': '$error'}),
          ),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    _searchController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t('equipment.added', parameters: {'name': form.name}),
        ),
      ),
    );
  }

  void _showEquipmentDetails(BuildContext context, EquipmentItem item) {
    showAppModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _EquipmentDetailRow(
                      label: context.t('ui.equipment.category'),
                      value: item.category),
                  _EquipmentDetailRow(
                    label: context.t('ui.equipment.condition'),
                    value: item.condition,
                  ),
                  _EquipmentDetailRow(
                      label: context.t('ui.equipment.location'),
                      value: item.location),
                  _EquipmentDetailRow(
                    label: context.t('ui.equipment.purchased'),
                    value: _equipmentDateLabel(item.purchaseDate),
                  ),
                  _EquipmentDetailRow(
                    label: context.t('ui.equipment.amount'),
                    value: _amountLabel(item.amount),
                  ),
                  _EquipmentDetailRow(
                    label: context.t('ui.equipment.description'),
                    value: item.description,
                  ),
                  _EquipmentDetailRow(
                    label: context.t('ui.equipment.bill'),
                    value: item.billFileName.trim().isEmpty
                        ? context.t('equipment.not_added')
                        : item.billFileName,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (item.billUrl.trim().isNotEmpty)
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () => _showBillPreview(context, item),
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: Text(context.t('ui.equipment.view_bill')),
                          ),
                        ),
                      if (item.billUrl.trim().isNotEmpty)
                        const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _showEditEquipmentSheet(context, item);
                          },
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(context.t('ui.equipment.edit')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _deleteEquipment(context, item);
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(context.t('ui.equipment.delete_equipment')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditEquipmentSheet(
    BuildContext context,
    EquipmentItem item,
  ) async {
    final form = await showAppModalBottomSheet<EquipmentFormData>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddEquipmentSheet(existingItem: item),
    );

    if (form == null || !context.mounted) return;
    try {
      await ref.read(equipmentViewModelProvider.notifier).updateEquipment(form);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context
                .t('equipment.update_failed', parameters: {'error': '$error'}),
          ),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t('equipment.updated', parameters: {'name': form.name}),
        ),
      ),
    );
  }

  Future<void> _deleteEquipment(
      BuildContext context, EquipmentItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('ui.equipment.delete_equipment_2c00')),
        content: Text(
          context
              .t('equipment.delete_message', parameters: {'name': item.name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.t('ui.equipment.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.t('ui.equipment.delete')),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(equipmentViewModelProvider.notifier).deleteEquipment(item);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context
                .t('equipment.delete_failed', parameters: {'error': '$error'}),
          ),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t('equipment.deleted', parameters: {'name': item.name}),
        ),
      ),
    );
  }

  void _showBillPreview(BuildContext context, EquipmentItem item) {
    showAppModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _BillPreviewSheet(item: item),
    );
  }

  void _showSummaryDetails(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<_SummaryDetailEntry> entries,
  }) {
    showAppModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.72,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                ),
                const SizedBox(height: 16),
                if (entries.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: carouselBoxDecoration(context),
                    child: Text(
                        context.t('ui.equipment.no_details_available_yet')),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: carouselBoxDecoration(context),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              if (entry.subtitle.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  entry.subtitle,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BillPreviewSheet extends StatelessWidget {
  const _BillPreviewSheet({
    required this.item,
  });

  final EquipmentItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final billName =
        item.billFileName.trim().isEmpty ? 'Equipment bill' : item.billFileName;
    final isPreviewableImage = _isImageBill(item.billFileName, item.billUrl);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                billName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${item.name} • ${_amountLabel(item.amount)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: carouselBoxDecoration(context),
                  child: isPreviewableImage
                      ? InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 4,
                          child: Image.network(
                            item.billUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(child: AppLoadingIndicator());
                            },
                            errorBuilder: (_, __, ___) => _BillPreviewFallback(
                              message: context.t(
                                  'ui.equipment.unable_to_preview_this_bill_right_now'),
                            ),
                          ),
                        )
                      : _BillPreviewFallback(
                          message: context.t(
                              'ui.equipment.this_bill_cannot_be_previewed_here_but_you_can_still'),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => Share.share(
                    'Equipment bill for ${item.name}\n${item.billUrl}',
                    subject: billName,
                  ),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: Text(context.t('ui.equipment.share_bill')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillPreviewFallback extends StatelessWidget {
  const _BillPreviewFallback({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 42,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EquipmentHeroCard extends StatelessWidget {
  const _EquipmentHeroCard({
    required this.churchName,
  });

  final String churchName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: welcomeBackCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroPill(
                icon: Icons.inventory_2_outlined,
                label: context.t('ui.equipment.equipment_dashboard'),
                background: Colors.white.withValues(alpha: 0.14),
                foreground: onPrimary,
              ),
              _HeroPill(
                icon: Icons.admin_panel_settings_outlined,
                label: context.t('ui.equipment.admin_only'),
                background: Colors.white.withValues(alpha: 0.14),
                foreground: onPrimary,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            churchName,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: onPrimary,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.t(
                'ui.equipment.track_microphones_screens_instruments_media_gear_furnit'),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: onPrimary.withValues(alpha: 0.88),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _EquipmentSummaryCard extends StatelessWidget {
  const _EquipmentSummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.colors,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: welcomeBackCardDecoration(
          context,
          primaryColor: colors.first,
          secondaryColor: colors.last,
          radius: 24,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.94),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ],
              ),
            ),
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              child: Icon(icon, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryDetailEntry {
  const _SummaryDetailEntry({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;
}

class _EquipmentListCard extends StatelessWidget {
  const _EquipmentListCard({
    required this.item,
    required this.onTap,
  });

  final EquipmentItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
              child: Icon(
                _iconForCategory(item.category),
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetaChip(
                        icon: Icons.category_outlined,
                        text: item.category,
                      ),
                      _ConditionChip(condition: item.condition),
                      _MetaChip(
                        icon: Icons.place_outlined,
                        text: item.location,
                      ),
                      _MetaChip(
                        icon: Icons.calendar_today_outlined,
                        text: _equipmentDateLabel(item.purchaseDate),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConditionChip extends StatelessWidget {
  const _ConditionChip({
    required this.condition,
  });

  final String condition;

  @override
  Widget build(BuildContext context) {
    final palette = _conditionPalette(condition);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(palette.icon, size: 15, color: palette.foreground),
          const SizedBox(width: 6),
          Text(
            condition,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: palette.foreground,
                ),
          ),
        ],
      ),
    );
  }
}

class _EquipmentEmptyState extends StatelessWidget {
  const _EquipmentEmptyState({
    required this.query,
    required this.category,
    this.message,
  });

  final String query;
  final String category;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 36,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            context.t('ui.equipment.no_equipment_found'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            message ??
                (query.trim().isEmpty && category == 'All'
                    ? 'Start by adding your first church asset.'
                    : 'Try a different search or category filter.'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _EquipmentDetailRow extends StatelessWidget {
  const _EquipmentDetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.62),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _AddEquipmentSheet extends StatefulWidget {
  const _AddEquipmentSheet({
    this.existingItem,
  });

  final EquipmentItem? existingItem;

  @override
  State<_AddEquipmentSheet> createState() => _AddEquipmentSheetState();
}

class _AddEquipmentSheetState extends State<_AddEquipmentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _dateController;
  late final TextEditingController _amountController;
  String _category = 'Media';
  String _condition = 'Excellent';
  DateTime _purchaseDate = DateTime.now();
  PickedImageData? _billImage;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    _nameController = TextEditingController(text: item?.name ?? '');
    _locationController = TextEditingController(text: item?.location ?? '');
    _descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    _purchaseDate = item?.purchaseDate ?? DateTime.now();
    _dateController = TextEditingController(
      text: _equipmentDateLabel(_purchaseDate),
    );
    _amountController = TextEditingController(
      text: item != null && item.amount > 0 ? item.amount.toString() : '',
    );
    _category = item?.category ?? 'Media';
    _condition = item?.condition ?? 'Excellent';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existingItem = widget.existingItem;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existingItem == null ? 'Add Equipment' : 'Edit Equipment',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 18),
              AppTextField(
                controller: _nameController,
                label: context.t('ui.equipment.equipment_name'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return context.t('equipment.name_required');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              AppDropdownField<String>(
                labelText: context.t('ui.equipment.category'),
                initialValue: _category,
                items: _equipmentCategories
                    .map(
                      (category) => DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _category = value;
                  });
                },
              ),
              const SizedBox(height: 14),
              AppDropdownField<String>(
                labelText: context.t('ui.equipment.condition'),
                initialValue: _condition,
                items: _equipmentConditions
                    .map(
                      (condition) => DropdownMenuItem<String>(
                        value: condition,
                        child: Text(condition),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _condition = value;
                  });
                },
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _locationController,
                label: context.t('ui.equipment.location_d219'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return context.t('equipment.location_required');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _dateController,
                label: context.t('ui.equipment.purchase_date'),
                readOnly: true,
                suffixIcon: const Icon(Icons.calendar_today_outlined),
                onTap: _pickDate,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _amountController,
                label: context.t('ui.equipment.amount_43dc'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return context.t('equipment.amount_required');
                  }
                  if (InputValidators.parsePositiveAmount(value!) == null) {
                    return context.t('equipment.amount_invalid');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _descriptionController,
                label: context.t('ui.equipment.description_55f8'),
                maxLines: 4,
                minLines: 4,
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: carouselBoxDecoration(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('ui.equipment.bill'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 10),
                    if (_billImage != null)
                      Text(
                        context.t(
                          'equipment.selected_bill',
                          parameters: {'name': _billImage!.name},
                        ),
                      )
                    else if ((existingItem?.billFileName ?? '')
                        .trim()
                        .isNotEmpty)
                      Text(
                        context.t(
                          'equipment.current_bill',
                          parameters: {'name': existingItem!.billFileName},
                        ),
                      )
                    else
                      Text(context.t('ui.equipment.no_bill_added_yet')),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _pickBill,
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: Text(
                        _billImage != null ||
                                (existingItem?.billFileName ?? '')
                                    .trim()
                                    .isNotEmpty
                            ? 'Change bill'
                            : 'Add bill',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(
                    existingItem == null
                        ? 'Save Equipment'
                        : 'Update Equipment',
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _purchaseDate = picked;
      _dateController.text = _equipmentDateLabel(picked);
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final amount =
        InputValidators.parsePositiveAmount(_amountController.text.trim());
    if (amount == null) return;
    Navigator.of(context).pop(
      EquipmentFormData(
        id: widget.existingItem?.id,
        name: _nameController.text.trim(),
        category: _category,
        condition: _condition,
        location: _locationController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? 'No additional notes added yet.'
            : _descriptionController.text.trim(),
        purchaseDate: _purchaseDate,
        amount: amount,
        billImage: _billImage,
        existingBillUrl: widget.existingItem?.billUrl ?? '',
        existingBillFileName: widget.existingItem?.billFileName ?? '',
      ),
    );
  }

  Future<void> _pickBill() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    final picked = await PickedImageData.fromXFile(file);
    if (!mounted || picked == null) return;
    setState(() {
      _billImage = picked;
    });
  }
}

IconData _iconForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'media':
      return Icons.tv_outlined;
    case 'audio':
      return Icons.mic_external_on_outlined;
    case 'lighting':
      return Icons.lightbulb_outline_rounded;
    case 'furniture':
      return Icons.chair_alt_outlined;
    case 'instruments':
      return Icons.piano_outlined;
    default:
      return Icons.inventory_2_outlined;
  }
}

String _equipmentDateLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _amountLabel(double amount) {
  if (amount == amount.roundToDouble()) {
    return 'Rs ${amount.toStringAsFixed(0)}';
  }
  return 'Rs ${amount.toStringAsFixed(2)}';
}

_ConditionPalette _conditionPalette(String condition) {
  switch (condition.toLowerCase()) {
    case 'good':
      return const _ConditionPalette(
        background: Color(0xFFEAF3FF),
        foreground: Color(0xFF2E6BDE),
        icon: Icons.thumb_up_alt_rounded,
      );
    case 'needs attention':
      return const _ConditionPalette(
        background: Color(0xFFFFF2D9),
        foreground: Color(0xFFD48806),
        icon: Icons.error_outline_rounded,
      );
    case 'excellent':
    default:
      return const _ConditionPalette(
        background: Color(0xFFE3FAEE),
        foreground: Color(0xFF198754),
        icon: Icons.verified_rounded,
      );
  }
}

bool _isImageBill(String fileName, String billUrl) {
  final source = '${fileName.toLowerCase()} ${billUrl.toLowerCase()}';
  return source.contains('.png') ||
      source.contains('.jpg') ||
      source.contains('.jpeg') ||
      source.contains('.webp') ||
      source.contains('.gif');
}

String _sortOptionTextKey(EquipmentSortOption option) {
  switch (option) {
    case EquipmentSortOption.newestFirst:
      return 'common.sort_newest_first';
    case EquipmentSortOption.oldestFirst:
      return 'common.sort_oldest_first';
    case EquipmentSortOption.nameAscending:
      return 'common.sort_name_ascending';
    case EquipmentSortOption.categoryAscending:
      return 'common.category';
  }
}

const _equipmentCategories = [
  'Media',
  'Audio',
  'Lighting',
  'Furniture',
  'Instruments',
  'Office',
  'Other',
];

const _equipmentConditions = [
  'Excellent',
  'Good',
  'Needs Attention',
];

class _ConditionPalette {
  const _ConditionPalette({
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
}
