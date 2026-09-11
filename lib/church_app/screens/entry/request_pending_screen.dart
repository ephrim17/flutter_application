import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/services/notification_service.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/church_logo_avatar_widget.dart';
import 'package:flutter_application/church_app/widgets/linear_screen_background_widget.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Shown after requesting access to a church, and again if the person comes
/// back to a church they already have a pending row in — replaces a bare
/// "already requested" snackbar with somewhere to actually land. Lets them
/// opt into an approval push+email (`notifyMemberOnApproval` in functions)
/// instead of having to keep reopening the app to check.
class RequestPendingScreen extends ConsumerStatefulWidget {
  const RequestPendingScreen({
    super.key,
    required this.churchId,
    required this.churchName,
    this.churchLogo = '',
    this.initiallyNotifying = false,
  });

  final String churchId;
  final String churchName;
  final String churchLogo;
  final bool initiallyNotifying;

  @override
  ConsumerState<RequestPendingScreen> createState() =>
      _RequestPendingScreenState();
}

class _RequestPendingScreenState extends ConsumerState<RequestPendingScreen> {
  late bool _notifying;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _notifying = widget.initiallyNotifying;
  }

  Future<void> _enableNotify() async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      await handleNotificationSetup(
        context: context,
        container: ProviderScope.containerOf(context, listen: false),
      );
      if (!mounted) return;
      await ref.read(authRepositoryProvider).setNotifyOnApproval(
            churchId: widget.churchId,
            uid: uid,
            value: true,
          );
      if (!mounted) return;
      setState(() => _notifying = true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: AppBarTitle(text: context.t('church.request_pending_title')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: LinearScreenBackground(
        solidBackground: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: ChurchLogoAvatar(logo: widget.churchLogo, size: 72),
                ),
                const SizedBox(height: 16),
                Icon(
                  Icons.hourglass_top_rounded,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.churchName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  context.t('church.request_pending_subtitle'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _notifying
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _notifying
                              ? context.t('church.request_pending_will_notify')
                              : context.t('church.request_pending_notify_hint'),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (!_notifying)
                  SolidButton(
                    label: context.t('church.request_pending_notify_action'),
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _enableNotify,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
