import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/contact_launcher.dart';
import 'package:flutter_application/church_app/helpers/selected_church_local_storage.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/screens/auth_options_screen.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/church_logo_avatar_widget.dart';
import 'package:flutter_application/church_app/widgets/color_text_widget.dart';
import 'package:flutter_application/church_app/widgets/linear_screen_background_widget.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SelectChurchScreen extends ConsumerWidget {
  const SelectChurchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedChurch = ref.watch(selectedChurchProvider);

    /// ✅ PRELOAD churches here
    final churchesAsync = ref.watch(churchesProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: AppBarTitle(text: ''),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: LinearScreenBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 6),
                        Center(
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x12000000),
                                  blurRadius: 24,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: SizedBox.expand(
                                child: Image.asset(
                                  'assets/images/appLogo.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          decoration: carouselBoxDecoration(context),
                          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                          child: Column(
                            children: [
                              Text(
                                'Welcome Home.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                context.t(
                                  'church.select_subtitle',
                                  fallback:
                                      'Select your church to proceed further',
                                ),
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "We'll help you find a local congregation to stay connected with services, events, and news.",
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(height: 1.45),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        if (selectedChurch == null)
                          SolidButton(
                            label: context.t(
                              'church.select_button',
                              fallback: 'Select Church',
                            ),
                            onPressed: () {
                              _showChurchBottomSheet(
                                context,
                                ref,
                                churchesAsync,
                              );
                            },
                          ),
                        if (selectedChurch != null) ...[
                          Container(
                            decoration: carouselBoxDecoration(context),
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selected Church',
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    ChurchLogoAvatar(
                                      logo: selectedChurch.logo,
                                      size: 48,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            selectedChurch.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () {
                                        ref
                                            .read(
                                                selectedChurchProvider.notifier)
                                            .state = null;
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SolidButton(
                            label: context.t(
                              'auth_entry.continue',
                              fallback: 'Continue',
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AuthOptionsScreen(
                                    churchId: selectedChurch.id,
                                    churchName: selectedChurch.name,
                                    churchLogo: selectedChurch.logo,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                        const Spacer(),
                        const SizedBox(height: 16),
                        Center(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Register your church coming soon',
                                  ),
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: _RegisterChurchText(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showChurchBottomSheet(
    BuildContext context,
    WidgetRef ref,
    AsyncValue churchesAsync,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return churchesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Text(
              context.t(
                'church.error_loading',
                fallback: 'Error loading churches',
              ),
            ),
          ),
          data: (churches) {
            if (churches.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    context.t(
                      'church.none_available',
                      fallback: 'No churches available',
                    ),
                  ),
                ),
              );
            }

            return _ChurchPickerSheet(
              churches: churches,
              onChurchTap: (church) => _showChurchDetailsSheet(
                context,
                ref,
                church,
              ),
            );
          },
        );
      },
    );
  }

  void _showChurchDetailsSheet(
    BuildContext context,
    WidgetRef ref,
    Church church,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ChurchLogoAvatar(
                      logo: church.logo,
                      size: 48,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            church.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _valueOrFallback(church.pastorName),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _ChurchDetailRow(
                  icon: Icons.person_outline,
                  label: 'Pastor',
                  value: _valueOrFallback(church.pastorName),
                ),
                _ChurchDetailRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: _valueOrFallback(church.email),
                ),
                _ChurchDetailRow(
                  icon: Icons.phone_outlined,
                  label: 'Contact',
                  value: _valueOrFallback(church.contact),
                  onActionTap: church.contact.trim().isEmpty
                      ? null
                      : () => launchPhoneCall(context, church.contact),
                ),
                _ChurchDetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Address',
                  value: _valueOrFallback(church.address),
                ),
                const SizedBox(height: 8),
                SolidButton(
                  label: context.t(
                    'church.select_action',
                    fallback: 'Select Church',
                  ),
                  onPressed: () async {
                    final storage = ChurchLocalStorage();

                    await storage.saveChurch(
                      id: church.id,
                      name: church.name,
                    );

                    ref.read(selectedChurchProvider.notifier).state = church;
                    ref.invalidate(currentChurchIdProvider);

                    if (!context.mounted) return;
                    Navigator.of(context)
                      ..pop()
                      ..pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChurchPickerSheet extends StatefulWidget {
  const _ChurchPickerSheet({
    required this.churches,
    required this.onChurchTap,
  });

  final List<Church> churches;
  final ValueChanged<Church> onChurchTap;

  @override
  State<_ChurchPickerSheet> createState() => _ChurchPickerSheetState();
}

class _ChurchPickerSheetState extends State<_ChurchPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredChurches = _filterChurches(widget.churches, _query);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.96,
      minChildSize: 0.85,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose a church',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${filteredChurches.length} of ${widget.churches.length} churches',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _query = value.trim().toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search by church, pastor, email or address',
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _query = '';
                                });
                              },
                              icon: const Icon(Icons.clear),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: filteredChurches.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No churches match your search'),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: filteredChurches.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final church = filteredChurches[index];

                        return InkWell(
                          borderRadius: BorderRadius.circular(cornerRadius),
                          onTap: () => widget.onChurchTap(church),
                          child: Ink(
                            decoration: carouselBoxDecoration(context),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ChurchLogoAvatar(
                                    logo: church.logo,
                                    size: 46,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          church.name,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        _ChurchPreviewLine(
                                          icon: Icons.person_outline,
                                          text: _valueOrFallback(
                                            church.pastorName,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(
                                    Icons.chevron_right,
                                    color: theme.colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _RegisterChurchText extends StatelessWidget {
  const _RegisterChurchText();

  @override
  Widget build(BuildContext context) {
    return ColorText(
      badgeText: context.t(
        'church.register_your_church',
        fallback: 'Register your church',
      ),
      fontSize: 16,
    );
  }
}

class _ChurchDetailRow extends StatelessWidget {
  const _ChurchDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onActionTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
          if (onActionTap != null) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: onActionTap,
              tooltip: 'Call',
              icon: Icon(
                Icons.call_outlined,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChurchPreviewLine extends StatelessWidget {
  const _ChurchPreviewLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

String _valueOrFallback(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? 'Not provided' : trimmed;
}

List<Church> _filterChurches(List<Church> churches, String query) {
  if (query.isEmpty) return churches;

  return churches.where((church) {
    final haystacks = [
      church.name,
      church.pastorName,
      church.email,
      church.contact,
      church.address,
    ].map((value) => value.toLowerCase());

    return haystacks.any((value) => value.contains(query));
  }).toList();
}
