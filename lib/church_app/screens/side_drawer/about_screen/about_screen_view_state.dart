import 'package:flutter_application/church_app/models/side_drawer_models/about_model.dart';

class AboutScreenViewState {

  final String title;
  final String tagline;
  final String description;
  final String mission;
  final String community;
  final String values;
  
  const AboutScreenViewState({
    required this.title,
    required this.tagline,
    required this.description,
    required this.mission,
    required this.community,
    required this.values,
  });

  factory AboutScreenViewState.fromModel(AboutModel about) {
    return AboutScreenViewState(
      title: about.title,
      tagline: about.tagline,
      description: about.description,
      mission: about.mission,
      community: about.community,
      values: about.values,
    );
  }
}
