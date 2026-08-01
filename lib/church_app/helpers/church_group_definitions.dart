import 'package:flutter_application/church_app/models/text_content_defaults.dart';

class ChurchGroupDefinition {
  const ChurchGroupDefinition({
    required this.id,
    required this.labelKey,
  });

  final String id;
  final String labelKey;

  String get label => defaultChurchTextContents[labelKey] ?? labelKey;
}

const churchGroupDefinitions = <ChurchGroupDefinition>[
  ChurchGroupDefinition(id: 'pastors', labelKey: 'groups.pastors'),
  ChurchGroupDefinition(id: 'elders', labelKey: 'groups.elders'),
  ChurchGroupDefinition(
      id: 'carecell_leaders', labelKey: 'groups.carecell_leaders'),
  ChurchGroupDefinition(
      id: 'music_ministry', labelKey: 'groups.music_ministry'),
  ChurchGroupDefinition(
      id: 'media_ministry', labelKey: 'groups.media_ministry'),
  ChurchGroupDefinition(
      id: 'children_ministry', labelKey: 'groups.children_ministry'),
  ChurchGroupDefinition(
      id: 'youth_ministry', labelKey: 'groups.youth_ministry'),
  ChurchGroupDefinition(
      id: 'administration', labelKey: 'groups.administration'),
  ChurchGroupDefinition(id: 'finance', labelKey: 'groups.finance'),
  ChurchGroupDefinition(
      id: 'social_service', labelKey: 'groups.social_service'),
];

String churchGroupLabel(String groupId) {
  for (final group in churchGroupDefinitions) {
    if (group.id == groupId) {
      return group.label;
    }
  }
  return groupId;
}
