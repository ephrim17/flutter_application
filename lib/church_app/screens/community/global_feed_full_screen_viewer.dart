import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/church_app/screens/community/community_full_screen_viewer.dart'
    show CommunityViewerPageView;

/// Reached from `SelectChurchScreen`'s app-bar action — the same
/// Reels-style swipeable viewer `CommunityFullScreenViewer` uses, but
/// global-only: no "Your Church" segment to switch to (there isn't one —
/// nobody using this is necessarily inside a church) and no create-post
/// button (posting is church-scoped only, from inside Community).
class GlobalFeedFullScreenViewer extends StatelessWidget {
  const GlobalFeedFullScreenViewer({super.key, this.initialPostId});

  /// Which post to open on — null starts at the top of the feed.
  final String? initialPostId;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CommunityViewerPageView(
                  churchId: '',
                  isGlobal: true,
                  initialPostId: initialPostId,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
