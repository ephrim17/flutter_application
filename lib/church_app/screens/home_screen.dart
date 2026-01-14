import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
//import 'home_sections_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //final sections = ref.watch(homeSectionsProvider);

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Home')),
        body: CustomScrollView(
          slivers: [
            //for (final section in sections) ...section.buildSlivers(context),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}
