import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/contact_launcher.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/widgets/autoscroll_widget.dart';
import 'package:flutter_application/church_app/widgets/section_header_widget.dart';
import 'package:flutter_application/church_app/screens/side_drawer/pastor/pastor_model.dart';
import 'package:flutter_application/church_app/screens/side_drawer/pastor/pastor_view_state.dart';
import 'package:flutter_application/church_app/screens/side_drawer/pastor/pastor_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PastorWidget extends ConsumerWidget {
  const PastorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pastorStateAsync = ref.watch(pastorViewStateProvider);

    return pastorStateAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          "${context.t('common.error_prefix', fallback: 'Error')}: $e",
        ),
      ),
      data: _PastorList.new,
    );
  }
}

class _PastorList extends StatelessWidget {
  const _PastorList(this.state);
  final PastorViewState state;

  @override
  Widget build(BuildContext context) {
    if (state.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          context.t('pastor.empty_error', fallback: 'Something went wrong'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          text: context.t('pastor.section_title', fallback: 'Our Pastors'),
          padding: 16.0,
        ),
        const SizedBox(
          height: 10,
        ),
        SizedBox(
            height: cardHeight("pastor"),
            child: AutoScrollCarousel(
              height: cardHeight("pastor"),
              itemCount: state.pastors.length,
              viewportFraction: 0.92,
              spacing: 12,
              itemBuilder: (_, i) => _PastorCard(
                pastor: state.pastors[i],
                primaryColor: state.primaryColor,
                secondaryColor: state.secondaryColor,
              ),
            )),
      ],
    );
  }
}

class _PastorCard extends StatelessWidget {
  const _PastorCard({
    required this.pastor,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final Pastor pastor;
  final Color primaryColor;
  final Color secondaryColor;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final imageSize = (width - 32) * 0.30;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Container(
        width: width - 32,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cornerRadius + 4),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryColor,
              secondaryColor,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: imageSize,
              height: imageSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.75),
                  width: 2.5,
                ),
              ),
              child: ClipOval(
                child: pastor.imageUrl.trim().isNotEmpty
                    ? Image.network(
                        pastor.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _PastorAvatarFallback(name: pastor.title),
                      )
                    : _PastorAvatarFallback(name: pastor.title),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pastor.primary) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        'Main',
                        style: textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    pastor.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: pastor.contact.trim().isEmpty
                        ? null
                        : () => launchPhoneCall(context, pastor.contact),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.call_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              pastor.contact.trim().isEmpty
                                  ? 'Contact unavailable'
                                  : pastor.contact,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
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
          ],
        ),
      ),
    );
  }
}

class _PastorAvatarFallback extends StatelessWidget {
  const _PastorAvatarFallback({
    required this.name,
  });

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'P' : name.trim().characters.first;

    return Container(
      color: Colors.white.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        initial.toUpperCase(),
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
