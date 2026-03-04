import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/selected_church_local_storage.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/screens/auth_options_screen.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SelectChurchScreen extends ConsumerWidget {
  const SelectChurchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedChurch = ref.watch(selectedChurchProvider);

    /// ✅ PRELOAD churches here
    final churchesAsync = ref.watch(churchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          text: context.t('auth_entry.welcome', fallback: 'Welcome'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.church, size: 72),
            const SizedBox(height: 16),
            Text(
              context.t(
                'church.select_subtitle',
                fallback: 'Select your church to proceed further',
              ),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            /// 🔹 If no church selected → show button
            if (selectedChurch == null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _showChurchBottomSheet(
                      context,
                      ref,
                      churchesAsync,
                    );
                  },
                  child: Text(
                    context.t('church.select_button', fallback: 'Select Church'),
                  ),
                ),
              ),

            /// 🔹 If church selected → show options
            if (selectedChurch != null) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.church),
                  title: Text(selectedChurch.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      ref.read(selectedChurchProvider.notifier).state = null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AuthOptionsScreen(
                          churchId: selectedChurch.id,
                          churchName: selectedChurch.name,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    context.t('common.proceed', fallback: 'Proceed'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showChurchBottomSheet(
    BuildContext context,
    WidgetRef ref,
    AsyncValue churchesAsync,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return churchesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Text(
              context.t(
                'church.error_loading',
                fallback: 'Error loading churches',
              ),
            ),
          ),
          data: (churches) {
            if (churches.isEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    context.t(
                      'church.none_available',
                      fallback: 'No churches available',
                    ),
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: churches.length,
              itemBuilder: (context, index) {
                final church = churches[index];

                return ListTile(
                  leading: const Icon(Icons.church),
                  title: Text(church.name),
                  onTap: () async {
                    final storage = ChurchLocalStorage();

                    await storage.saveChurch(
                      id: church.id,
                      name: church.name,
                    );

                    ref.read(selectedChurchProvider.notifier).state = church;

                    Navigator.pop(context);
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
