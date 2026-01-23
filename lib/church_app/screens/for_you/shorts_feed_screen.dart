import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/shorts_provider.dart';
import 'package:flutter_application/church_app/widgets/shorts_player.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ShortsFeedScreen extends ConsumerStatefulWidget {
  const ShortsFeedScreen({super.key});

  @override
  ConsumerState<ShortsFeedScreen> createState() => _ShortsFeedScreenState();
}

class _ShortsFeedScreenState extends ConsumerState<ShortsFeedScreen> {
  final PageController _pageController = PageController(initialPage: 0);

   bool _isExiting = false;

  Future<bool> _handleBack() async {
    if (_isExiting) return false;
    _isExiting = true;

    // Small delay allows player to detach cleanly
    await Future.delayed(const Duration(milliseconds: 150));

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final shorts = ref.watch(shortsProvider);

    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: shorts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (shortsList) => PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: shortsList.length,
            itemBuilder: (context, index) {
              final short = shortsList[index];
              return ShortsPlayerItem(short, showSwipeHint: index == 0,);
            },
          ),
        ),
      ),
    );
  }
}