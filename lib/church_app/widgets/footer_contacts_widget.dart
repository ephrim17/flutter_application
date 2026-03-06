import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/footer_support_models/contact_item_model.dart';
import 'package:flutter_application/church_app/providers/footer/footer_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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
      children: [
        const SizedBox(
          height: 10,
        ),
        Row(
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

  List<Widget> buildContacts(
    List<ContactItem> contacts,
    BuildContext context,
  ) {
    return contacts.map((contact) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onContactTap(context, contact),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _iconForType(contact.type),
                  const SizedBox(height: 8),
                  Text(
                    contact.label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Future<void> _onContactTap(BuildContext context, ContactItem contact) async {
    final raw = (contact.action.isNotEmpty ? contact.action : contact.label).trim();
    if (raw.isEmpty) return;

    final uri = _buildContactUri(contact.type, raw);
    if (uri == null) return;

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open contact action')),
      );
    }
  }

  Uri? _buildContactUri(String type, String value) {
    switch (type.toLowerCase()) {
      case 'email':
        if (value.startsWith('mailto:')) return Uri.parse(value);
        return Uri.parse('mailto:$value');
      case 'phone':
        if (value.startsWith('tel:')) return Uri.parse(value);
        return Uri.parse('tel:$value');
      case 'location':
        if (value.startsWith('http://') || value.startsWith('https://')) {
          return Uri.parse(value);
        }
        return Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(value)}',
        );
      default:
        if (value.startsWith('http://') || value.startsWith('https://')) {
          return Uri.parse(value);
        }
        return null;
    }
  }
}
