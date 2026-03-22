class ChurchGroupDefinition {
  const ChurchGroupDefinition({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

const churchGroupDefinitions = <ChurchGroupDefinition>[
  ChurchGroupDefinition(id: 'pastors', label: 'Pastors'),
  ChurchGroupDefinition(id: 'elders', label: 'Elders'),
  ChurchGroupDefinition(id: 'carecell_leaders', label: 'Carecell Leaders'),
  ChurchGroupDefinition(id: 'music_ministry', label: 'Music Ministry'),
  ChurchGroupDefinition(id: 'media_ministry', label: 'Media Ministry'),
  ChurchGroupDefinition(id: 'children_ministry', label: 'Children Ministry'),
  ChurchGroupDefinition(id: 'youth_ministry', label: 'Youth Ministry'),
  ChurchGroupDefinition(id: 'administration', label: 'Administration'),
  ChurchGroupDefinition(id: 'finance', label: 'Finance'),
  ChurchGroupDefinition(id: 'social_service', label: 'Social Service'),
];

String churchGroupLabel(String groupId) {
  for (final group in churchGroupDefinitions) {
    if (group.id == groupId) {
      return group.label;
    }
  }
  return groupId;
}
