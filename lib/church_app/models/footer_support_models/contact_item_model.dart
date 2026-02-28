class ContactItem {
  final String id;
  final String label;
  final String type;
  final String action;
  final int order;
  final bool isActive;

  ContactItem({
    required this.id,
    required this.label,
    required this.type,
    required this.action,
    required this.order,
    required this.isActive,
  });

  factory ContactItem.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return ContactItem(
      id: id,
      label: data['label'] ?? '',
      type: data['type'] ?? '',
      action: data['action'] ?? '',
      order: data['order'] ?? 0,
      isActive: data['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'type': type,
      'action': action,
      'order': order,
      'isActive': isActive,
    };
  }
}