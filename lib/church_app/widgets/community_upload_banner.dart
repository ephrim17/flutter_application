import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/providers/community_upload_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Floating, non-blocking upload status. Instagram and LinkedIn both close
/// the composer the instant you tap Post/Share and show progress like this
/// instead of a blocking modal — this mirrors that.
class CommunityUploadBanner extends ConsumerStatefulWidget {
  const CommunityUploadBanner({super.key});

  @override
  ConsumerState<CommunityUploadBanner> createState() =>
      _CommunityUploadBannerState();
}

class _CommunityUploadBannerState
    extends ConsumerState<CommunityUploadBanner> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communityUploadControllerProvider);

    ref.listen<CommunityUploadState>(communityUploadControllerProvider,
        (previous, next) {
      if (next.status == CommunityUploadStatus.success ||
          next.status == CommunityUploadStatus.error) {
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          // Don't clear a newer upload that may have started since.
          if (ref.read(communityUploadControllerProvider).status ==
              next.status) {
            ref.read(communityUploadControllerProvider.notifier).dismiss();
          }
        });
      }
    });

    if (state.status == CommunityUploadStatus.idle) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isUploading = state.status == CommunityUploadStatus.uploading;
    final isError = state.status == CommunityUploadStatus.error;
    final label = switch (state.status) {
      CommunityUploadStatus.uploading => context.t('ui.feed.posting'),
      CommunityUploadStatus.success => context.t('ui.feed.posted'),
      CommunityUploadStatus.error =>
        state.errorMessage ?? context.t('ui.feed.post_failed'),
      CommunityUploadStatus.idle => '',
    };

    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Material(
            elevation: 6,
            shadowColor: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(999),
            color: theme.colorScheme.surface,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isUploading)
                    SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  else
                    Icon(
                      isError
                          ? Icons.error_outline_rounded
                          : Icons.check_circle_rounded,
                      size: 18,
                      color: isError ? theme.colorScheme.error : Colors.green,
                    ),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
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
}
