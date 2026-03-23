import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/contact_launcher.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart'
    hide firestoreProvider;
import 'package:flutter_application/church_app/providers/authentication/super_admin_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/preflow_theme_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/entry/app_entry.dart';
import 'package:flutter_application/church_app/screens/entry/create_auth_account_screen.dart';
import 'package:flutter_application/church_app/screens/entry/login_request_screen.dart';
import 'package:flutter_application/church_app/screens/super_admin/super_admin_home_screen.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/favorites_provider.dart';
import 'package:flutter_application/church_app/services/notification_service.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/church_logo_avatar_widget.dart';
import 'package:flutter_application/church_app/widgets/color_text_widget.dart';
import 'package:flutter_application/church_app/widgets/linear_screen_background_widget.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';
import 'package:flutter_application/church_app/helpers/selected_church_local_storage.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'dart:async';

final userChurchesProvider = FutureProvider<List<Church>>((ref) async {
  final firebaseUser = ref.watch(authStateProvider).value;
  final churches = await ref.watch(churchesProvider.future);
  final uid = firebaseUser?.uid.trim() ?? '';
  if (uid.isEmpty || churches.isEmpty) return const <Church>[];

  final firestore = ref.read(firestoreProvider);
  final membershipChecks = await Future.wait(
    churches.map((church) async {
      final userDoc = await FirestorePaths.churchUserDoc(
        firestore,
        church.id,
        uid,
      ).get();
      return MapEntry(church, userDoc.exists);
    }),
  );

  final userChurches = membershipChecks
      .where((entry) => entry.value)
      .map((entry) => entry.key)
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  return userChurches;
});

class SelectChurchScreen extends ConsumerStatefulWidget {
  const SelectChurchScreen({super.key});

  @override
  ConsumerState<SelectChurchScreen> createState() => _SelectChurchScreenState();
}

class _SelectChurchScreenState extends ConsumerState<SelectChurchScreen> {
  bool _showYourChurches = true;
  bool _showOtherChurches = false;

  Future<void> _handleLogout(BuildContext context) async {
    final navigator = Navigator.of(context);
    ref.read(forcePreflowThemeProvider.notifier).state = true;
    await ChurchLocalStorage().clearChurch();
    await ChurchLocalStorage().clearSubscribedChurchTopic();
    await ref.read(favoritesProvider.notifier).clearAll();
    ref.read(selectedChurchProvider.notifier).state = null;
    await ref.read(superAdminEntryModeProvider.notifier).clear();
    ref.invalidate(currentChurchIdProvider);
    ref.invalidate(appUserProvider);
    ref.invalidate(getCurrentUserProvider);
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    navigator.pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => const CreateAuthAccountScreen(
          initialLoginMode: true,
        ),
      ),
      (route) => false,
    );
  }

  Future<bool> _showRequestAccessPrompt(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              context.t(
                'auth.user_not_found_title',
                fallback: 'User not found',
              ),
            ),
            content: Text(
              context.t(
                'auth.no_account_found_request_access',
                fallback:
                    'No account was found for this church. Do you want to request access?',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  context.t('settings.cancel', fallback: 'Cancel'),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  context.t('auth.request_access', fallback: 'Request Access'),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _handleContinue(
    BuildContext context,
    Church selectedChurch,
  ) async {
    final firebaseUser = ref.read(firebaseAuthProvider).currentUser;
    if (firebaseUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'auth.login_subtitle',
              fallback: 'Sign in with your Church Connect account to continue.',
            ),
          ),
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final userDoc = await FirestorePaths.churchUserDoc(
        ref.read(firestoreProvider),
        selectedChurch.id,
        firebaseUser.uid,
      ).get();

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (userDoc.exists) {
        final appUser = AppUser.fromFirestore(
          userDoc.id,
          userDoc.data() as Map<String, dynamic>? ?? <String, dynamic>{},
        );
        if (!context.mounted) return;

        await ref.read(superAdminEntryModeProvider.notifier).setMode(
              SuperAdminEntryMode.normal,
            );
        if (!context.mounted) return;
        ref.read(selectedChurchProvider.notifier).state = selectedChurch;
        ref.read(forcePreflowThemeProvider.notifier).state = !appUser.approved;
        ref.invalidate(currentChurchIdProvider);
        unawaited(syncNotificationTopicIfAuthorized(ref));

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AppEntry(initialUser: appUser),
          ),
        );
        return;
      }

      final shouldRequest = await _showRequestAccessPrompt(context);
      if (!context.mounted || !shouldRequest) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LoginRequestScreen(
            churchId: selectedChurch.id,
            churchName: selectedChurch.name,
            churchLogo: selectedChurch.logo,
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? error.code)),
      );
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final churchesAsync = ref.watch(churchesProvider);
    final userChurchesAsync = ref.watch(userChurchesProvider);
    final firebaseUser = ref.watch(authStateProvider).value;
    final isSuperAdmin = ref.watch(isSuperAdminProvider).maybeWhen(
          data: (value) => value && firebaseUser != null,
          orElse: () => false,
        );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: AppBarTitle(text: ''),
        centerTitle: true,
        actions: [
          if (isSuperAdmin)
            IconButton(
              tooltip: context.t(
                'super_admin.open_dashboard',
                fallback: 'Open Super Admin',
              ),
              onPressed: () async {
                await ref.read(superAdminEntryModeProvider.notifier).setMode(
                      SuperAdminEntryMode.superAdmin,
                    );
                if (!context.mounted) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const SuperAdminHomeScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.admin_panel_settings_outlined),
            ),
          IconButton(
            tooltip: context.t('drawer.logout', fallback: 'Logout'),
            onPressed: () => _handleLogout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: LinearScreenBackground(
        solidBackground: true,
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
                                context.t(
                                  'church.welcome_home',
                                  fallback: 'Welcome Home',
                                ),
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
                                context.t(
                                  'church.select_helper',
                                  fallback:
                                      "We'll help you find a local congregation to stay connected with services, events, and news.",
                                ),
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
                        _buildChurchSections(
                          context,
                          churchesAsync: churchesAsync,
                          userChurchesAsync: userChurchesAsync,
                        ),
                        const Spacer(),
                        const SizedBox(height: 16),
                        Center(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.t(
                                      'church.register_coming_soon',
                                      fallback:
                                          'Register your church coming soon',
                                    ),
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

  Widget _buildChurchSections(
    BuildContext context, {
    required AsyncValue<List<Church>> churchesAsync,
    required AsyncValue<List<Church>> userChurchesAsync,
  }) {
    if (churchesAsync.isLoading || userChurchesAsync.isLoading) {
      return Container(
        decoration: carouselBoxDecoration(context),
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (churchesAsync.hasError || userChurchesAsync.hasError) {
      return Container(
        decoration: carouselBoxDecoration(context),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t(
                'church.directory_title',
                fallback: 'Churches',
              ),
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              context.t(
                'church.directory_load_error',
                fallback: 'We could not load the church list right now.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    final allChurches = churchesAsync.asData?.value ?? const <Church>[];
    final userChurches = userChurchesAsync.asData?.value ?? const <Church>[];
    final memberChurchIds = userChurches.map((church) => church.id).toSet();
    final otherChurches = allChurches
        .where((church) => !memberChurchIds.contains(church.id))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChurchSectionCard(
          title: context.t(
            'church.your_churches_title',
            fallback: 'Your Churches',
          ),
          subtitle: userChurches.isEmpty
              ? context.t(
                  'church.your_churches_empty_subtitle',
                  fallback:
                      "Churches you follow and you're part of will show here.",
                )
              : context.t(
                  'church.your_churches_subtitle',
                  fallback: "Churches you follow and you're part of.",
                ),
          count: userChurches.length,
          isExpanded: _showYourChurches,
          onToggle: () {
            setState(() {
              _showYourChurches = !_showYourChurches;
            });
          },
          onOpen: userChurches.isEmpty
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _ChurchDirectoryScreen(
                        title: context.t(
                          'church.your_churches_title',
                          fallback: 'Your Churches',
                        ),
                        churches: userChurches,
                        emptyMessage: context.t(
                          'church.your_churches_empty_state',
                          fallback:
                              'You are not part of any church yet. Use the section below to explore other churches.',
                        ),
                        onChurchTap: (directoryContext, church) =>
                            _showChurchDetailsSheet(
                          directoryContext,
                          ref,
                          church,
                          isMemberChurch: true,
                        ),
                      ),
                    ),
                  ),
          child: userChurches.isEmpty
              ? _EmptyChurchState(
                  message: context.t(
                    'church.your_churches_empty_state',
                    fallback:
                        'You are not part of any church yet. Use the section below to explore other churches.',
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 14),
        _ChurchSectionCard(
          title: context.t(
            'church.other_churches_title',
            fallback: 'Other Churches',
          ),
          subtitle: context.t(
            'church.other_churches_subtitle',
            fallback:
                'Explore other churches. Tapping one lets you submit a request form, and once an admin approves it, enrollment will be smoother.',
          ),
          count: otherChurches.length,
          isExpanded: _showOtherChurches,
          onToggle: () {
            setState(() {
              _showOtherChurches = !_showOtherChurches;
            });
          },
          onOpen: otherChurches.isEmpty
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _ChurchDirectoryScreen(
                        title: context.t(
                          'church.other_churches_title',
                          fallback: 'Other Churches',
                        ),
                        churches: otherChurches,
                        emptyMessage: context.t(
                          'church.other_churches_empty_state',
                          fallback:
                              'You already belong to every available church in the directory.',
                        ),
                        onChurchTap: (directoryContext, church) =>
                            _showChurchDetailsSheet(
                          directoryContext,
                          ref,
                          church,
                          isMemberChurch: false,
                        ),
                      ),
                    ),
                  ),
          child: otherChurches.isEmpty
              ? _EmptyChurchState(
                  message: context.t(
                    'church.other_churches_empty_state',
                    fallback:
                        'You already belong to every available church in the directory.',
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _showChurchDetailsSheet(
    BuildContext context,
    WidgetRef ref,
    Church church, {
    required bool isMemberChurch,
  }) {
    final parentContext = context;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Material(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: FractionallySizedBox(
              heightFactor: 0.5,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ChurchLogoAvatar(
                          logo: church.logo,
                          size: 52,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                church.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_rounded,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _valueOrFallback(church.pastorName),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ChurchDetailRow(
                              icon: Icons.person_outline,
                              label: context.t(
                                'church.detail_pastor',
                                fallback: 'Pastor',
                              ),
                              value: _valueOrFallback(church.pastorName),
                            ),
                            _ChurchDetailRow(
                              icon: Icons.email_outlined,
                              label: context.t(
                                'church.detail_email',
                                fallback: 'Email',
                              ),
                              value: _valueOrFallback(church.email),
                            ),
                            _ChurchDetailRow(
                              icon: Icons.phone_outlined,
                              label: context.t(
                                'church.detail_contact',
                                fallback: 'Contact',
                              ),
                              value: _valueOrFallback(church.contact),
                              onActionTap: church.contact.trim().isEmpty
                                  ? null
                                  : () => launchPhoneCall(context, church.contact),
                            ),
                            _ChurchDetailRow(
                              icon: Icons.location_on_outlined,
                              label: context.t(
                                'church.detail_address',
                                fallback: 'Address',
                              ),
                              value: _valueOrFallback(church.address),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SolidButton(
                      label: isMemberChurch
                          ? context.t(
                              'church.select_action',
                              fallback: 'Select Church',
                            )
                          : context.t(
                              'auth.request_access',
                              fallback: 'Request Access',
                            ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        if (!parentContext.mounted) return;
                        if (isMemberChurch) {
                          _handleContinue(parentContext, church);
                          return;
                        }

                        Navigator.of(parentContext).push(
                          MaterialPageRoute(
                            builder: (_) => LoginRequestScreen(
                              churchId: church.id,
                              churchName: church.name,
                              churchLogo: church.logo,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChurchSectionCard extends StatelessWidget {
  const _ChurchSectionCard({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.isExpanded,
    required this.onToggle,
    this.onOpen,
    required this.child,
  });

  final String title;
  final String subtitle;
  final int count;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback? onOpen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: carouselBoxDecoration(context),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(cornerRadius),
            onTap: onOpen ?? onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$title ',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$count church${count == 1 ? '' : 'es'}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded && onOpen == null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: child,
            ),
          ],
        ],
      ),
    );
  }
}

class _ChurchDirectoryScreen extends StatefulWidget {
  const _ChurchDirectoryScreen({
    required this.title,
    required this.churches,
    required this.emptyMessage,
    required this.onChurchTap,
  });

  final String title;
  final List<Church> churches;
  final String emptyMessage;
  final void Function(BuildContext context, Church church) onChurchTap;

  @override
  State<_ChurchDirectoryScreen> createState() => _ChurchDirectoryScreenState();
}

class _ChurchDirectoryScreenState extends State<_ChurchDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Church> get _filteredChurches {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.churches;

    return widget.churches.where((church) {
      return church.name.toLowerCase().contains(query) ||
          church.pastorName.toLowerCase().contains(query) ||
          church.address.toLowerCase().contains(query) ||
          church.email.toLowerCase().contains(query) ||
          church.contact.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final filteredChurches = _filteredChurches;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _query = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: context.t(
                    'common.search',
                    fallback: 'Search',
                  ),
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.search_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  suffixIcon: _query.isEmpty
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
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.4,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: filteredChurches.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        widget.emptyMessage,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filteredChurches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final church = filteredChurches[index];
                      return _ChurchCoverCard(
                        church: church,
                        onTap: () => widget.onChurchTap(context, church),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChurchState extends StatelessWidget {
  const _EmptyChurchState({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: carouselBoxDecoration(context),
      padding: const EdgeInsets.all(18),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
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

    final row = Padding(
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
        ],
      ),
    );

    if (onActionTap == null) return row;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onActionTap,
      child: row,
    );
  }
}

class _ChurchCoverCard extends StatelessWidget {
  const _ChurchCoverCard({
    required this.church,
    required this.onTap,
  });

  final Church church;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(cornerRadius),
      onTap: onTap,
      child: Ink(
        decoration: carouselBoxDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(cornerRadius),
              ),
              child: _ChurchCoverImage(logoUrl: church.logo),
            ),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x18000000),
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: _PastorAvatar(
                        imageUrl: church.pastorPhoto,
                        size: 68,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _valueOrFallback(church.pastorName),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18.0
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Transform.translate(
                offset: const Offset(0, -14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      church.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ChurchPreviewLine(
                      icon: Icons.email_outlined,
                      text: _valueOrFallback(church.email),
                    ),
                    const SizedBox(height: 8),
                    _ChurchPreviewLine(
                      icon: Icons.phone_outlined,
                      text: _valueOrFallback(church.contact),
                    ),
                    const SizedBox(height: 8),
                    _ChurchPreviewLine(
                      icon: Icons.location_on_outlined,
                      text: _valueOrFallback(church.address),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PastorAvatar extends StatelessWidget {
  const _PastorAvatar({
    required this.imageUrl,
    required this.size,
  });

  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl.trim();

    if (trimmedUrl.isEmpty) {
      return _PastorAvatarFallback(size: size);
    }

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          trimmedUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _PastorAvatarFallback(size: size),
        ),
      ),
    );
  }
}

class _PastorAvatarFallback extends StatelessWidget {
  const _PastorAvatarFallback({
    required this.size,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
      child: Icon(
        Icons.person_rounded,
        size: size * 0.42,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

class _ChurchCoverImage extends StatelessWidget {
  const _ChurchCoverImage({
    required this.logoUrl,
  });

  final String logoUrl;

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl.trim().isNotEmpty;

    if (hasLogo) {
      return SizedBox(
        height: 156,
        width: double.infinity,
        child: Image.network(
          logoUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _ChurchCoverFallback(),
        ),
      );
    }

    return const _ChurchCoverFallback();
  }
}

class _ChurchCoverFallback extends StatelessWidget {
  const _ChurchCoverFallback();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: 156,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary.withValues(alpha: 0.85),
            colors.secondary.withValues(alpha: 0.72),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.church_rounded,
          size: 42,
          color: Colors.white.withValues(alpha: 0.88),
        ),
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
