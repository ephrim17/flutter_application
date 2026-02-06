// Data models
class ReadingPlan {
  final String month;
  final int monthIndex;
  final List<DayPlan> days;

  ReadingPlan({required this.month, required this.monthIndex, required this.days});

  factory ReadingPlan.fromJson(Map<String, dynamic> json) {
    var daysFromJson = json['days'] as List;
    List<DayPlan> daysList = daysFromJson.map((i) => DayPlan.fromJson(i)).toList();
    return ReadingPlan(
      month: json['month'],
      monthIndex: json['monthIndex'],
      days: daysList,
    );
  }
}

class DayPlan {
  final int day;
  final List<Reading> readings;

  DayPlan({required this.day, required this.readings});

  factory DayPlan.fromJson(Map<String, dynamic> json) {
    var readingsFromJson = json['readings'] as List;
    List<Reading> readingsList = readingsFromJson.map((i) => Reading.fromJson(i)).toList();
    return DayPlan(
      day: json['day'],
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
      book: json['book'],
      chapters: json['chapters'],
    );
  }
}