import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/widgets/footer_contacts_widget.dart';
import 'package:flutter_application/church_app/widgets/footer_socials_widget.dart';

class FooterSection extends HomeSection {
  @override
  String get id => 'footer';

  @override
  int get order => 100;

  @override
  List<Widget> buildSlivers(BuildContext context) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: const BorderRadius.all(
                Radius.circular(8),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                children: const [
                  FooterContactsWidget(),
                  SizedBox(height: 20),
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
