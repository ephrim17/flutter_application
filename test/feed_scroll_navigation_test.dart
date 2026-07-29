import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/feed_scroll_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('moves between older and latest feed posts', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ListView.builder(
                controller: controller,
                itemCount: 20,
                itemBuilder: (_, index) => SizedBox(
                  height: 100,
                  child: Text('Post $index'),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: FeedScrollNavigation(
                  controller: controller,
                  latestLabel: 'Latest',
                  olderLabel: 'Older posts',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Older posts'), findsOneWidget);
    await tester.tap(find.text('Older posts'));
    await tester.pumpAndSettle();

    expect(controller.offset, controller.position.maxScrollExtent);
    expect(find.text('Latest'), findsOneWidget);

    await tester.tap(find.text('Latest'));
    await tester.pumpAndSettle();

    expect(controller.offset, controller.position.minScrollExtent);
    expect(find.text('Older posts'), findsOneWidget);
  });
}
