import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/footer_support/contact_item_model.dart';
import 'package:flutter_application/church_app/providers/footer/footer_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Icon _iconForType(String type) {
  switch (type) {
    case 'email':
      return const Icon(Icons.email);
    case 'phone':
      return const Icon(Icons.phone);
    case 'location':
      return const Icon(Icons.location_on);
    default:
      return const Icon(Icons.link);
  }
}

class FooterContactsWidget extends ConsumerWidget {
  const FooterContactsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(footerContactsProvider);

    return Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text("Reach us via",
          style: Theme.of(context).textTheme.titleMedium,),
          const SizedBox(
            height: 10,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: contactsAsync.when(
              loading: () => const [CircularProgressIndicator()],
              error: (e, _) => [Text('Error: $e')],
              data: (contacts) {
                return buildContacts(contacts, context);
              },
            ),
          ),
        ],
      );
  }

  List<Column> buildContacts(List<ContactItem> contacts, BuildContext context) {
    return contacts.map((contact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _iconForType(contact.type),
          const SizedBox(height: 8),
          Text(
            contact.label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      );
    }).toList();
  }
}
