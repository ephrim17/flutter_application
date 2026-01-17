

//spacing between each widgets in home section
double spacingForOrder(int order) {
  return 20;
}

//height for announcement card
double cardHeight(String id) {
  if (id == "announcements") return 120; // Announcements
  if (id == "events") return 180; // Announcements
  if (id == "pastor") return 220; // Announcements
  return 120;
}