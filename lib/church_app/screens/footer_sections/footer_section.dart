import 'package:flutter/material.dart';
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
        // Horizontal insets come from `HomeCardAlign`, so the footer ends on
        // the same edges as the cards above it instead of stretching to the
        // window on a desktop width. The gap above it is the screen's one
        // between-section gap, like every other section.
        child: HomeCardAlign(
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
