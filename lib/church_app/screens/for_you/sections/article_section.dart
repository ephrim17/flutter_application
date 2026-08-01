import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/helpers/date_formatter.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/models/for_you_section_models/article_model.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/article_provider.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/app_profile_avatar.dart';
import 'package:flutter_application/church_app/widgets/card_Link_button_widget.dart';
import 'package:flutter_application/church_app/widgets/color_text_widget.dart';
import 'package:flutter_application/church_app/widgets/section_header_widget.dart';
import 'package:flutter_application/church_app/widgets/user_quick_card_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ArticleSection implements MasterSection {
  const ArticleSection();

  @override
  String get id => 'article';

  @override
  int get order => 30;

  @override
  List<Widget> buildSlivers(BuildContext context) {
    //final width = MediaQuery.of(context).size.width;
    return [
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            SectionHeader(
              text: context.t('for_you.article.section_title'),
              padding: 16.0,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CardLinkButtonWidget(
                title: context.t(
                    'ui.article_section.browse_article_notes_and_open_the_full_message'),
                buttonText: context.t('articles.view_articles'),
                iconStyle: Icon(
                  Icons.menu_book_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ArticleListScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            //const ArticleSectionWidget(),
          ],
        ),
      ),
    ];
  }
}

class ArticleSectionWidget extends ConsumerWidget {
  const ArticleSectionWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articlesAsync = ref.watch(articlesProvider);

    return articlesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: AppLoadingIndicator(size: 72)),
      ),
      error: (e, _) => Text(
        '${context.t('common.error_prefix')}: $e',
      ),
      data: (articles) {
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: articles.length,
          itemBuilder: (context, index) {
            return ArticleCard(article: articles[index]);
          },
        );
      },
    );
  }
}

class ArticleListScreen extends StatelessWidget {
  const ArticleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          text: context.t('for_you.article.section_title'),
        ),
      ),
      body: const SingleChildScrollView(
        child: ArticleSectionWidget(),
      ),
    );
  }
}

class ArticleCard extends StatelessWidget {
  final Article article;

  const ArticleCard({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: carouselBoxDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ArticleAuthorHeader(article: article),
            const Divider(height: 22),
            ColorText(badgeText: article.title),
            const SizedBox(height: 10),
            Text(
              article.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ArticleDetailPage(article: article),
                    ),
                  );
                },
                child: ColorText(
                  badgeText: "Read More",
                  fontSize: 13,
                )),
          ],
        ),
      ),
    );
  }
}

class ArticleDetailPage extends StatelessWidget {
  final Article article;

  const ArticleDetailPage({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: AppBarTitle(text: "")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ArticleAuthorHeader(article: article),
              const SizedBox(height: 24),
              Text(
                article.title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                article.content,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArticleAuthorHeader extends ConsumerWidget {
  const _ArticleAuthorHeader({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authorName = article.createdByName.isNotEmpty
        ? article.createdByName
        : 'Church admin';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showArticleAuthorDetails(context, ref, article),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              AppProfileAvatar(
                name: authorName,
                imageUrl: article.createdByProfilePhotoUrl,
                radius: 21,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.10),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (article.createdAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        humanFormatDate(article.createdAt!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showArticleAuthorDetails(
  BuildContext context,
  WidgetRef ref,
  Article article,
) async {
  final churchId = ref.read(currentChurchIdProvider).value?.trim() ?? '';
  final firestore = ref.read(firestoreProvider);
  AppUser? author;
  var churchName = '';
  var churchPastorName = '';

  if (churchId.isNotEmpty) {
    final results = await Future.wait([
      if (article.createdByUid.isNotEmpty)
        FirestorePaths.churchUserDoc(
          firestore,
          churchId,
          article.createdByUid,
        ).get(),
      FirestorePaths.churchDoc(firestore, churchId).get(),
    ]);

    var resultIndex = 0;
    if (article.createdByUid.isNotEmpty) {
      final userSnapshot = results[resultIndex++];
      if (userSnapshot.exists) {
        author = AppUser.fromFirestore(
          userSnapshot.id,
          userSnapshot.data() as Map<String, dynamic>,
        );
      }
    }

    final churchSnapshot = results[resultIndex];
    if (churchSnapshot.exists) {
      final church = Church.fromFirestore(
        churchSnapshot.id,
        churchSnapshot.data() as Map<String, dynamic>? ?? const {},
      );
      churchName = church.name;
      churchPastorName = church.pastorName;
    }
  }

  author ??= AppUser.fromJson({
    'uid': article.createdByUid,
    'name': article.createdByName.isNotEmpty
        ? article.createdByName
        : 'Church admin',
    'email': article.createdByEmail,
    'profilePhotoUrl': article.createdByProfilePhotoUrl,
    'role': 'admin',
    'approved': true,
  });

  if (!context.mounted) return;
  await showUserQuickCardWithChurch(
    context,
    author,
    churchName: churchName,
    churchPastorName: churchPastorName,
  );
}
