import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/members_provider.dart';
import 'package:flutter_application/church_app/services/side_drawer/members_repository.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersProvider);
    final isAdmin = ref.watch(isAdminProvider);

    final firebaseUser = ref.watch(firebaseAuthProvider).currentUser;
    final currentUid = firebaseUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          text: context.t('members.title', fallback: 'Members'),
        ),
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(
            context.t('members.error_loading', fallback: 'Error loading members'),
          ),
        ),
        data: (members) {
          if (members.isEmpty) {
            return Center(
              child: Text(
                context.t('members.none', fallback: 'No members found'),
              ),
            );
          }

          return ListView.separated(
            itemCount: members.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final m = members[index];

              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                  ),
                ),
                title: Text(m.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.email),
                    Text(m.phone),
                  ],
                ),
                trailing: (isAdmin && m.uid != currentUid)
                    ? Switch(
                        value: m.approved,
                        onChanged: (val) async {
                          final churchId =
                              await ref.read(currentChurchIdProvider.future);

                          final repo = MembersRepository(
                            firestore: ref.read(firestoreProvider),
                            churchId: churchId!,
                          );

                          await repo.approveMember(m.uid, val);
                        },
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
