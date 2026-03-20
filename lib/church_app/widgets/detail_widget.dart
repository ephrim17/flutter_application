import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/footer_support_models/contact_item_model.dart';
import 'package:flutter_application/church_app/widgets/footer_contacts_widget.dart';
import 'package:flutter_application/church_app/widgets/shimmer_image.dart';

class DetailWidget extends StatelessWidget {
  const DetailWidget({
    super.key,
    required this.title,
    required this.description,
    this.imageUrl,
    this.contact,
    this.location,
    this.timing,
  });

  final String title;
  final String description;
  final String? imageUrl;
  final String? contact;
  final String? location;
  final String? timing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = (imageUrl ?? '').trim().isNotEmpty;
    final hasLocation = (location ?? '').trim().isNotEmpty;
    final hasTiming = (timing ?? '').trim().isNotEmpty;
    final contactItems = <ContactItem>[
      if ((contact ?? '').trim().isNotEmpty)
        ContactItem(
          id: 'detail-contact',
          label: contact!.trim(),
          type: 'phone',
          action: contact!.trim(),
          order: 0,
          isActive: true,
        ),
      if (hasLocation)
        ContactItem(
          id: 'detail-location',
          label: context.t('common.open_location', fallback: 'Open location'),
          type: 'location',
          action: location!.trim(),
          order: 1,
          isActive: true,
        ),
    ];

    return Scaffold(
      //backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: hasImage ? Colors.white : Colors.black,
          ),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasImage)
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.38,
                      child: ShimmerImage(
                        imageUrl: imageUrl!,
                        aspectRatio: 1,
                        borderRadius: 0,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    SizedBox(height: MediaQuery.sizeOf(context).height * 0.16),
                  Transform.translate(
                    offset: const Offset(0, -24),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                      //decoration: carouselBoxDecoration(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(
                            height: 25,
                          ),
                          Text(
                            title,
                            style: theme.textTheme.headlineMedium
                                ?.copyWith(fontSize: 28),
                          ),
                          if (hasTiming) ...[
                            const SizedBox(height: 12),
                            Text(
                              timing!.trim(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Text(
                            description,
                            style: theme.textTheme.titleMedium?.copyWith(
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (contactItems.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: carouselBoxDecoration(context),
                  child: Row(
                    children: buildContacts(
                      contactItems,
                      context,
                      textStyle: theme.textTheme.bodyMedium?.copyWith(
                        //color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
