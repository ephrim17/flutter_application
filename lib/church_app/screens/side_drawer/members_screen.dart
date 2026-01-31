import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/services/side_drawer/members_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = MembersRepository();
   final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: repo.getMembers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No members found'));
          }

          final members = snapshot.data!;

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
                trailing: isAdmin
                    ? Switch(
                        value: m.approved,
                        onChanged: (val) {
                          repo.approveMember(m.uid, val);
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
