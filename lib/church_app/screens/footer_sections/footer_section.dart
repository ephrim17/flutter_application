import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/screens/for_you/for_you_card_layout.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/widgets/footer_contacts_widget.dart';
import 'package:flutter_application/church_app/widgets/footer_socials_widget.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';

class FooterSection extends MasterSection {
  @override
  String get id => 'footer';

  @override
  int get order => 100;

  @override
  List<Widget> buildSlivers(BuildContext context) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          // Horizontal only: the gap above the footer is the screen's one
          // between-section gap, like every other section.
          padding: const EdgeInsets.symmetric(
            horizontal: forYouSidePadding,
          ),
          child: Container(
            width: double.infinity,
            decoration: carouselBoxDecoration(context),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  FooterContactsWidget(),
                  FooterSocialIconsWidget(),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }
}
