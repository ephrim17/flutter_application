import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/go_further_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/widgets/church_logo_avatar_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';

class GoFurtherScreen extends ConsumerStatefulWidget {
  const GoFurtherScreen({super.key});

  @override
  ConsumerState<GoFurtherScreen> createState() => _GoFurtherScreenState();
}

class _GoFurtherScreenState extends ConsumerState<GoFurtherScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      ref.read(goFurtherPaginationControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paginationState = ref.watch(goFurtherPaginationControllerProvider);
    final currentChurchId = ref.watch(currentChurchIdProvider).value;
    final currentChurchAsync = ref.watch(
      churchByIdProvider(currentChurchId ?? ''),
    );
    final isAdmin = ref.watch(isAdminProvider);

    final visibleChurches = _visibleChurches(
      paginationState.churches,
      _query,
    );

    _ensureEnoughDiscoverableChurches(
      state: paginationState,
      visibleCount: visibleChurches.length,
    );

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await ref
              .read(goFurtherPaginationControllerProvider.notifier)
              .refresh();
          if ((currentChurchId ?? '').trim().isNotEmpty) {
            ref.invalidate(churchByIdProvider(currentChurchId!));
          }
        },
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Container(
              height: 54,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: AppTextField(
                variant: AppTextFieldVariant.search,
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _query = value;
                  });
                },
                decoration: InputDecoration(
                  hintText:
                      'Search churches with Facebook, Instagram or YouTube...',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 10, right: 6),
                    child: Icon(
                      Icons.search_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  suffixIcon: _query.trim().isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _query = '';
                            });
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
                      color: theme.colorScheme.primary.withValues(alpha: 0.35),
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
            ),
            const SizedBox(height: 16),
            if (isAdmin)
              currentChurchAsync.maybeWhen(
                data: (church) {
                  if (church == null || church.hasAnySocialLinks) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(cornerRadius),
                      onTap: () => _showChurchDiscoveryEditor(church),
                      child: Ink(
                        decoration: carouselBoxDecoration(context),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.12),
                                ),
                                child: Icon(
                                  Icons.campaign_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Add your social media entry to display the church here.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            if (paginationState.isInitialLoading &&
                paginationState.churches.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (paginationState.errorMessage != null &&
                paginationState.churches.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: carouselBoxDecoration(context),
                child: Text(
                  'Unable to load churches right now.\n${paginationState.errorMessage}',
                  textAlign: TextAlign.center,
                ),
              )
            else if (visibleChurches.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: carouselBoxDecoration(context),
                child: Text(
                  paginationState.hasMore
                      ? 'Looking for churches with social presence...'
                      : 'No churches with Facebook, Instagram, or YouTube links match your search yet.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...List.generate(visibleChurches.length, (index) {
                final church = visibleChurches[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == visibleChurches.length - 1 ? 0 : 14,
                  ),
                  child: _GoFurtherChurchCard(
                    church: church,
                    isCurrentChurch: church.id == currentChurchId,
                    canEditCurrentChurch:
                        isAdmin && church.id == currentChurchId,
                    onEditCurrentChurch: church.id == currentChurchId
                        ? () => _showChurchDiscoveryEditor(church)
                        : null,
                    onTap: () => _showChurchDetails(church),
                  ),
                );
              }),
            if (paginationState.isLoadingMore) ...[
              const SizedBox(height: 14),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  List<Church> _visibleChurches(List<Church> churches, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    return churches.where((church) {
      if (!church.hasAnySocialLinks) return false;
      if (normalizedQuery.isEmpty) return true;

      return church.name.toLowerCase().contains(normalizedQuery) ||
          church.pastorName.toLowerCase().contains(normalizedQuery) ||
          church.address.toLowerCase().contains(normalizedQuery);
    }).toList(growable: false);
  }

  void _ensureEnoughDiscoverableChurches({
    required GoFurtherPaginationState state,
    required int visibleCount,
  }) {
    if (state.isInitialLoading || state.isLoadingMore || !state.hasMore) return;
    if (_query.trim().isNotEmpty) return;
    if (visibleCount >= 8) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(goFurtherPaginationControllerProvider.notifier).loadMore();
    });
  }

  Future<void> _showChurchDetails(Church church) {
    return showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    ChurchLogoAvatar(logo: church.logo, size: 58),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        church.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _GoFurtherDetailRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Pastor',
                  value: _valueOrFallback(church.pastorName),
                ),
                _GoFurtherDetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Address',
                  value: _valueOrFallback(church.address),
                ),
                _GoFurtherDetailRow(
                  icon: Icons.phone_outlined,
                  label: 'Contact',
                  value: _valueOrFallback(church.contact),
                ),
                _GoFurtherDetailRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: _valueOrFallback(church.email),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (church.facebookLink.trim().isNotEmpty)
                      _SocialActionChip(
                        label: 'Facebook',
                        icon: Icons.facebook,
                        onTap: () => _openSocialLink(church.facebookLink),
                      ),
                    if (church.instagramLink.trim().isNotEmpty)
                      _SocialActionChip(
                        label: 'Instagram',
                        icon: Icons.camera_alt_outlined,
                        onTap: () => _openSocialLink(church.instagramLink),
                      ),
                    if (church.youtubeLink.trim().isNotEmpty)
                      _SocialActionChip(
                        label: 'YouTube',
                        icon: Icons.play_circle_outline_rounded,
                        onTap: () => _openSocialLink(church.youtubeLink),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showChurchDiscoveryEditor(Church church) {
    return showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ChurchDiscoveryEditorSheet(
        church: church,
        onSaved: () async {
          ref.invalidate(churchByIdProvider(church.id));
          await ref
              .read(goFurtherPaginationControllerProvider.notifier)
              .refresh();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Church social details updated'),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openSocialLink(String rawLink) async {
    final normalized = _normalizeUrl(rawLink);
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _GoFurtherChurchCard extends StatelessWidget {
  const _GoFurtherChurchCard({
    required this.church,
    required this.isCurrentChurch,
    required this.canEditCurrentChurch,
    this.onEditCurrentChurch,
    required this.onTap,
  });

  final Church church;
  final bool isCurrentChurch;
  final bool canEditCurrentChurch;
  final VoidCallback? onEditCurrentChurch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(cornerRadius),
      onTap: onTap,
      child: Ink(
        decoration: carouselBoxDecoration(context),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChurchLogoAvatar(logo: church.logo, size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          church.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (isCurrentChurch)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Current church',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            if (canEditCurrentChurch &&
                                onEditCurrentChurch != null)
                              InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: onEditCurrentChurch,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'Edit',
                                    style:
                                        theme.textTheme.labelMedium?.copyWith(
                                      color: theme.colorScheme.secondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _PastorPhotoAvatar(
                    photoUrl: church.pastorPhoto,
                    size: 42,
                    onTap: () => _showPastorPhotoPreview(context, church),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _GoFurtherPreviewLine(
                      icon: Icons.person_outline_rounded,
                      text: _valueOrFallback(church.pastorName),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _GoFurtherPreviewLine(
                icon: Icons.location_on_outlined,
                text: _valueOrFallback(church.address),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (church.facebookLink.trim().isNotEmpty)
                    const _SocialBadge(
                      icon: Icons.facebook,
                      label: 'Facebook',
                    ),
                  if (church.instagramLink.trim().isNotEmpty)
                    const _SocialBadge(
                      icon: Icons.camera_alt_outlined,
                      label: 'Instagram',
                    ),
                  if (church.youtubeLink.trim().isNotEmpty)
                    const _SocialBadge(
                      icon: Icons.play_circle_outline_rounded,
                      label: 'YouTube',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showPastorPhotoPreview(
    BuildContext context, Church church) async {
  final photoUrl = church.pastorPhoto.trim();
  if (photoUrl.isEmpty) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.person_rounded,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                church.pastorName.trim().isEmpty ? 'Pastor' : church.pastorName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PastorPhotoAvatar extends StatelessWidget {
  const _PastorPhotoAvatar({
    required this.photoUrl,
    this.size = 42,
    this.onTap,
  });

  final String photoUrl;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final trimmed = photoUrl.trim();
    final theme = Theme.of(context);

    return InkWell(
      onTap: trimmed.isEmpty ? null : onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.primary.withValues(alpha: 0.10),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.14),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: trimmed.isEmpty
            ? Icon(
                Icons.person_rounded,
                color: theme.colorScheme.primary,
                size: size * 0.5,
              )
            : Image.network(
                trimmed,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.person_rounded,
                  color: theme.colorScheme.primary,
                  size: size * 0.5,
                ),
              ),
      ),
    );
  }
}

class _GoFurtherPreviewLine extends StatelessWidget {
  const _GoFurtherPreviewLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _GoFurtherDetailRow extends StatelessWidget {
  const _GoFurtherDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialBadge extends StatelessWidget {
  const _SocialBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialActionChip extends StatelessWidget {
  const _SocialActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
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
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _ChurchDiscoveryEditorSheet extends ConsumerStatefulWidget {
  const _ChurchDiscoveryEditorSheet({
    required this.church,
    required this.onSaved,
  });

  final Church church;
  final Future<void> Function() onSaved;

  @override
  ConsumerState<_ChurchDiscoveryEditorSheet> createState() =>
      _ChurchDiscoveryEditorSheetState();
}

class _ChurchDiscoveryEditorSheetState
    extends ConsumerState<_ChurchDiscoveryEditorSheet> {
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
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Church Discovery Details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'Update your church details and add Facebook, Instagram, or YouTube links so the church can appear here.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            _EditorField(
              controller: _nameController,
              label: 'Church name',
            ),
            _EditorField(
              controller: _pastorController,
              label: 'Pastor name',
            ),
            _EditorField(
              controller: _addressController,
              label: 'Address',
            ),
            _EditorField(
              controller: _contactController,
              label: 'Contact',
            ),
            _EditorField(
              controller: _emailController,
              label: 'Email',
            ),
            _EditorField(
              controller: _facebookController,
              label: 'Facebook link',
            ),
            _EditorField(
              controller: _instagramController,
              label: 'Instagram link',
            ),
            _EditorField(
              controller: _youtubeController,
              label: 'YouTube link',
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
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _valueOrFallback(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? 'Not available yet' : trimmed;
}

String _normalizeUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return 'https://$trimmed';
}
