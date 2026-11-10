import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/church_app/helpers/attendance_stats.dart';
import 'package:flutter_application/church_app/models/attendance_service_model.dart';

/// The four numbers above the service list are the whole point of recording
/// attendance — a church acts on "not seen for three services", not on the
/// register itself. These pin the arithmetic, the edge cases where there is
/// not enough history to say anything yet, and the household expansion that
/// decides who a single tap marks.
AttendanceService _service(
  String id,
  String date,
  List<String> present, {
  String type = 'sunday_worship',
}) {
  return AttendanceService(
    id: id,
    date: DateTime.parse(date),
    type: type,
    present: present,
  );
}

void main() {
  group('attendanceSummary', () {
    test('says nothing at all when no service has been recorded', () {
      final summary = attendanceSummary(
        services: const [],
        activeMemberIds: {'a', 'b'},
      );
      expect(summary.isEmpty, isTrue);
      expect(summary.lastServicePresent, isNull);
      expect(summary.averagePresent, isNull);
      expect(summary.lastServicePercent, isNull);
      expect(summary.absentIds, isEmpty);
    });

    test('counts the most recent service, not the last one added', () {
      final summary = attendanceSummary(
        services: [
          _service('old', '2026-11-01', ['a']),
          _service('new', '2026-11-08', ['a', 'b', 'c']),
          _service('mid', '2026-11-04', ['a', 'b']),
        ],
        activeMemberIds: {'a', 'b', 'c', 'd'},
      );
      expect(summary.lastServicePresent, 3);
    });

    test('averages over the window and rounds', () {
      // 3 and 2 -> 2.5 -> 3.
      final summary = attendanceSummary(
        services: [
          _service('1', '2026-11-08', ['a', 'b', 'c']),
          _service('2', '2026-11-01', ['a', 'b']),
        ],
        activeMemberIds: {'a', 'b', 'c'},
      );
      expect(summary.averagePresent, 3);
    });

    test('the average ignores services older than the window', () {
      final services = [
        for (var week = 0; week < 12; week++)
          _service(
            '$week',
            DateTime(2026, 1, 4)
                .add(Duration(days: 7 * week))
                .toIso8601String(),
            // Newest services are the busy ones; the oldest four are empty
            // and must not drag the average down.
            week >= 4 ? const ['a', 'b', 'c', 'd'] : const [],
          ),
      ];
      final summary = attendanceSummary(
        services: services,
        activeMemberIds: {'a', 'b', 'c', 'd'},
      );
      expect(attendanceAverageWindow, 8);
      expect(summary.averagePresent, 4);
    });

    test('the percentage is of the roster, not of everyone marked', () {
      final summary = attendanceSummary(
        services: [
          // 'guest' is present but not on the roster.
          _service('1', '2026-11-08', ['a', 'b', 'guest']),
        ],
        activeMemberIds: {'a', 'b', 'c', 'd'},
      );
      expect(summary.lastServicePresent, 3);
      expect(summary.lastServicePercent, 50);
    });

    test('an empty roster yields no percentage rather than a divide by zero',
        () {
      final summary = attendanceSummary(
        services: [
          _service('1', '2026-11-08', ['a'])
        ],
        activeMemberIds: const <String>{},
      );
      expect(summary.lastServicePresent, 1);
      expect(summary.lastServicePercent, isNull);
    });
  });

  group('the absence streak', () {
    test('stays empty until enough services exist to miss', () {
      final summary = attendanceSummary(
        services: [
          _service('1', '2026-11-08', ['a']),
          _service('2', '2026-11-01', ['a']),
        ],
        activeMemberIds: {'a', 'b'},
      );
      expect(attendanceAbsenceStreak, 3);
      expect(summary.absentIds, isEmpty,
          reason: 'b cannot have missed three services that never happened');
    });

    test('names only those absent from every one of the last three', () {
      final summary = attendanceSummary(
        services: [
          _service('1', '2026-11-15', ['a']),
          _service('2', '2026-11-08', ['a', 'c']),
          _service('3', '2026-11-01', ['a']),
          _service('4', '2026-10-25', ['b']),
        ],
        activeMemberIds: {'a', 'b', 'c'},
      );
      // 'c' came two services ago, so is not yet a concern; 'b' was last
      // seen outside the window.
      expect(summary.absentIds, ['b']);
      expect(summary.absentCount, 1);
    });

    test('a visitor who never joined the roster is never chased', () {
      final summary = attendanceSummary(
        services: [
          _service('1', '2026-11-15', ['a']),
          _service('2', '2026-11-08', ['a']),
          _service('3', '2026-11-01', ['a', 'guest']),
        ],
        activeMemberIds: {'a'},
      );
      expect(summary.absentIds, isEmpty);
    });

    test('the list is ordered, so the count cannot shuffle between builds', () {
      final summary = attendanceSummary(
        services: [
          _service('1', '2026-11-15', const []),
          _service('2', '2026-11-08', const []),
          _service('3', '2026-11-01', const []),
        ],
        activeMemberIds: {'zoe', 'adam', 'mary'},
      );
      expect(summary.absentIds, ['adam', 'mary', 'zoe']);
    });
  });

  group('sortAttendanceServices', () {
    test('puts the newest first', () {
      final sorted = sortAttendanceServices([
        _service('a', '2026-11-01', const []),
        _service('b', '2026-11-15', const []),
        _service('c', '2026-11-08', const []),
      ]);
      expect(sorted.map((s) => s.id), ['b', 'c', 'a']);
    });

    test('two services on one day keep a stable order', () {
      // A morning and an evening meeting on the same date must not swap
      // places between rebuilds.
      final first = sortAttendanceServices([
        _service('morning', '2026-11-08', const []),
        _service('evening', '2026-11-08', const []),
      ]);
      final second = sortAttendanceServices([
        _service('evening', '2026-11-08', const []),
        _service('morning', '2026-11-08', const []),
      ]);
      expect(first.map((s) => s.id), second.map((s) => s.id));
    });
  });

  group('attendanceTrendServices', () {
    test('reads oldest to newest, the opposite of the list below it', () {
      final bars = attendanceTrendServices([
        _service('a', '2026-11-01', const []),
        _service('b', '2026-11-15', const []),
        _service('c', '2026-11-08', const []),
      ]);
      expect(bars.map((s) => s.id), ['a', 'c', 'b']);
    });

    test('caps at the most recent handful', () {
      final services = [
        for (var day = 1; day <= 20; day++)
          _service(
              '$day', '2026-11-${day.toString().padLeft(2, '0')}', const []),
      ];
      final bars = attendanceTrendServices(services, limit: 12);
      expect(bars, hasLength(12));
      expect(bars.last.id, '20', reason: 'the newest bar is on the right');
      expect(bars.first.id, '9');
    });
  });

  group('attendanceHouseholdIds', () {
    const families = {
      'dad': 'smith',
      'mum': 'smith',
      'kid': 'smith',
      'alone': '',
      'other': 'jones',
    };

    test('marks everyone sharing a family', () {
      expect(
        attendanceHouseholdIds(
          memberId: 'dad',
          familyId: 'smith',
          familyIdByMemberId: families,
        ),
        {'dad', 'mum', 'kid'},
      );
    });

    test('someone with no family is only ever themselves', () {
      // The trap: treating blank as a family would make one tap mark every
      // unlinked member in the church.
      expect(
        attendanceHouseholdIds(
          memberId: 'alone',
          familyId: '',
          familyIdByMemberId: families,
        ),
        {'alone'},
      );
    });

    test('whitespace is not a family either', () {
      expect(
        attendanceHouseholdIds(
          memberId: 'alone',
          familyId: '   ',
          familyIdByMemberId: families,
        ),
        {'alone'},
      );
    });

    test('never reaches into another family', () {
      final household = attendanceHouseholdIds(
        memberId: 'other',
        familyId: 'jones',
        familyIdByMemberId: families,
      );
      expect(household, {'other'});
      expect(household, isNot(contains('dad')));
    });
  });

  group('AttendanceService', () {
    test('total attendance counts members and both headcounts', () {
      final service = AttendanceService(
        id: '1',
        date: DateTime(2026, 11, 8),
        type: 'sunday_worship',
        present: const ['a', 'b'],
        visitorCount: 3,
        childrenCount: 4,
      );
      expect(service.totalAttendance, 9);
    });

    test('the subheader round-trips and is trimmed', () {
      // It is what tells 1st, 2nd and 3rd Sunday worship on one date apart,
      // so a stray space must not render as an indent on the card.
      final service = AttendanceService.fromFirestore('1', const {
        'type': 'sunday_worship',
        'subheader': '  2nd service  ',
      });
      expect(service.subheader, '2nd service');
      expect(service.toMap()['subheader'], '2nd service');
    });

    test('a service stored before the subheader existed reads as empty', () {
      // Every service recorded before this field was added has no such key;
      // the card renders nothing for it rather than the word "null".
      final service = AttendanceService.fromFirestore('1', const {
        'type': 'midweek',
        'present': ['a'],
      });
      expect(service.subheader, isEmpty);
    });

    test('copyWith can set a subheader and can leave it alone', () {
      final base = AttendanceService(
        id: '1',
        date: DateTime(2026, 11, 8),
        type: 'sunday_worship',
        subheader: '1st service',
        present: const ['a'],
      );
      expect(base.copyWith(subheader: '2nd service').subheader, '2nd service');
      expect(base.copyWith(visitorCount: 4).subheader, '1st service');
    });

    test('blank ids in a stored present list are dropped', () {
      final service = AttendanceService.fromFirestore('1', const {
        'type': 'midweek',
        'present': ['a', '', '  ', 'b'],
      });
      expect(service.present, ['a', 'b']);
      expect(service.visitorCount, 0);
    });

    test('every offered service type has a display key', () {
      expect(attendanceServiceTypeKeys, isNotEmpty);
      for (final key in attendanceServiceTypeKeys) {
        expect(key, key.trim());
        expect(key, isNot(contains(' ')));
      }
      expect(
        attendanceServiceTypeKeys.toSet().length,
        attendanceServiceTypeKeys.length,
      );
    });
  });
}
