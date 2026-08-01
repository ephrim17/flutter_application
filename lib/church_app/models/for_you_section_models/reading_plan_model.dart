// Data models
class ReadingPlan {
  final String month;
  final int monthIndex;
  final List<DayPlan> days;

  ReadingPlan(
      {required this.month, required this.monthIndex, required this.days});

  factory ReadingPlan.fromJson(Map<String, dynamic> json) {
    final daysFromJson = json['days'] as Iterable? ?? const [];
    final daysList = daysFromJson
        .whereType<Map>()
        .map((item) => DayPlan.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    return ReadingPlan(
      month: json['month']?.toString().trim() ?? '',
      monthIndex: (json['monthIndex'] as num?)?.toInt() ?? 0,
      days: daysList,
    );
  }
}

class DayPlan {
  final int day;
  final List<Reading> readings;

  DayPlan({required this.day, required this.readings});

  factory DayPlan.fromJson(Map<String, dynamic> json) {
    final readingsFromJson = json['readings'] as Iterable? ?? const [];
    final readingsList = readingsFromJson
        .whereType<Map>()
        .map((item) => Reading.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    return DayPlan(
      day: (json['day'] as num?)?.toInt() ?? 0,
      readings: readingsList,
    );
  }
}

class Reading {
  final String book;
  final String chapters;

  Reading({required this.book, required this.chapters});

  factory Reading.fromJson(Map<String, dynamic> json) {
    return Reading(
      book: json['book']?.toString().trim() ?? '',
      chapters: json['chapters']?.toString().trim() ?? '',
    );
  }
}
