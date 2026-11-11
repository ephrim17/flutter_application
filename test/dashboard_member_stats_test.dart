import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/church_app/helpers/dashboard_member_stats.dart';
import 'package:flutter_application/church_app/models/church_membership_model.dart';
import 'package:flutter_application/church_app/models/text_content_defaults.dart';
import 'package:flutter_application/church_app/screens/dashboard/view_models/dashboard_view_state.dart';

/// The member snapshot's four views used to be computed in a Cloud Function
/// with no test suite of any kind, and shipped with `displayGender` missing
/// from its field mapping — so every church's gender view read "Unknown",
/// 100%, for everyone. These pin each bucket, and above all the cases where
/// a field is absent, which is what the bug hid behind.
ChurchMembership _member(
  String id, {
  String name = 'Member',
  String gender = '',
  DateTime? dob,
  String category = '',
  String familyId = '',
  bool solemnized = false,
  String baptismChurch = '',
  bool approved = true,
  List<String> groups = const <String>[],
}) {
  return ChurchMembership.fromFirestore(id, 'church-1', {
    'uid': id,
    'displayName': name,
    'displayGender': gender,
    if (dob != null) 'displayDob': dob,
    'category': category,
    'familyId': familyId,
    'solemnizedBaptism': solemnized,
    'baptismChurchName': baptismChurch,
    'approved': approved,
    'churchGroupIds': groups,
  });
}

Map<String, int> _counts(List<DashboardMemberBucket> buckets) {
  return {for (final bucket in buckets) bucket.id: bucket.count};
}

void main() {
  group('dashboardGenderBuckets', () {
    test('splits male and female instead of collecting everyone as unknown',
        () {
      // The exact shape of the production bug: 18 members, every one with a
      // gender on file, all reported as Unknown.
      final members = [
        for (var i = 0; i < 14; i++) _member('m$i', gender: 'male'),
        for (var i = 0; i < 4; i++) _member('f$i', gender: 'female'),
      ];
      expect(
          _counts(dashboardGenderBuckets(members)), {'male': 14, 'female': 4});
    });

    test('is case and whitespace insensitive', () {
      final members = [
        _member('a', gender: 'Male'),
        _member('b', gender: ' FEMALE '),
      ];
      expect(
          _counts(dashboardGenderBuckets(members)), {'male': 1, 'female': 1});
    });

    test('only members with no usable gender land in unknown', () {
      final members = [
        _member('a', gender: 'male'),
        _member('b', gender: ''),
        _member('c', gender: 'prefer not to say'),
      ];
      expect(
          _counts(dashboardGenderBuckets(members)), {'male': 1, 'unknown': 2});
    });

    test('an empty bucket is not drawn at all', () {
      // "Female: 0" reads as a finding; absence should simply be absent.
      final buckets = dashboardGenderBuckets([_member('a', gender: 'male')]);
      expect(buckets.map((b) => b.id), ['male']);
    });

    test('no members yields no buckets, not a 100% unknown slice', () {
      expect(dashboardGenderBuckets(const []), isEmpty);
    });
  });

  group('dashboardMemberAge', () {
    final asOf = DateTime(2026, 11, 10);

    test('counts whole years, not year subtraction', () {
      // Birthday not yet reached this year.
      expect(dashboardMemberAge(DateTime(2000, 12, 25), asOf: asOf), 25);
      // Birthday already passed.
      expect(dashboardMemberAge(DateTime(2000, 1, 5), asOf: asOf), 26);
      // Birthday today counts.
      expect(dashboardMemberAge(DateTime(2000, 11, 10), asOf: asOf), 26);
    });

    test('no date of birth is null, which is not zero', () {
      // "We don't know" and "a newborn" must not share a bucket.
      expect(dashboardMemberAge(null, asOf: asOf), isNull);
    });

    test('a date in the future is treated as unknown, not negative', () {
      expect(dashboardMemberAge(DateTime(2030, 1, 1), asOf: asOf), isNull);
    });
  });

  group('dashboardAgeBuckets', () {
    final asOf = DateTime(2026, 11, 10);

    test('places each band, and missing DOB in unknown', () {
      final members = [
        _member('child', dob: DateTime(2020, 1, 1)),
        _member('youth', dob: DateTime(2008, 1, 1)),
        _member('adult', dob: DateTime(1995, 1, 1)),
        _member('senior', dob: DateTime(1950, 1, 1)),
        _member('nodob'),
      ];
      expect(_counts(dashboardAgeBuckets(members, asOf: asOf)), {
        'children': 1,
        'youth': 1,
        'adults': 1,
        'seniors': 1,
        'unknown': 1,
      });
    });

    test('each band boundary falls on the expected side', () {
      // Bands are children <=12, youth 13-24, adults 25-59, seniors 60+.
      // Both edges of every band, so an off-by-one cannot hide.
      const expected = {
        12: 'children',
        13: 'youth',
        24: 'youth',
        25: 'adults',
        59: 'adults',
        60: 'seniors',
      };
      for (final entry in expected.entries) {
        final dob = DateTime(asOf.year - entry.key, asOf.month, asOf.day);
        final buckets = dashboardAgeBuckets(
          [_member('${entry.key}', dob: dob)],
          asOf: asOf,
        );
        expect(
          buckets.single.id,
          entry.value,
          reason: 'age ${entry.key} belongs in ${entry.value}',
        );
      }
    });

    test('every member is counted exactly once, never twice or not at all', () {
      final members = [
        _member('a', dob: DateTime(2014, 11, 10)),
        _member('b', dob: DateTime(2013, 11, 10)),
        _member('c', dob: DateTime(2001, 11, 10)),
        _member('d', dob: DateTime(1966, 11, 10)),
        _member('e'),
      ];
      final buckets = dashboardAgeBuckets(members, asOf: asOf);
      expect(
        buckets.fold<int>(0, (sum, bucket) => sum + bucket.count),
        members.length,
      );
    });
  });

  group('dashboardFamilyModeBuckets', () {
    test('keeps an unrecognised category apart from an unset one', () {
      // Collapsing these would hide a data-entry problem behind a blank.
      final members = [
        _member('a', category: 'family'),
        _member('b', category: 'individual'),
        _member('c', category: 'visitor'),
        _member('d'),
      ];
      expect(_counts(dashboardFamilyModeBuckets(members)), {
        'family': 1,
        'individual': 1,
        'other': 1,
        'unspecified': 1,
      });
    });
  });

  group('dashboardSolemnizedBuckets', () {
    test('splits on the flag', () {
      final members = [
        _member('a', solemnized: true),
        _member('b'),
        _member('c'),
      ];
      expect(_counts(dashboardSolemnizedBuckets(members)),
          {'solemnized': 1, 'not_solemnized': 2});
    });
  });

  group('dashboardMemberCounts', () {
    test('counts approvals, categories and group participation', () {
      final members = [
        _member('a', category: 'family', approved: true, groups: ['g1']),
        _member('b', category: 'individual', approved: true),
        _member('c', approved: false, groups: ['g1', 'g2']),
        _member('d', approved: true),
      ];
      final counts = dashboardMemberCounts(members);
      expect(counts.memberCount, 4);
      expect(counts.approvedMembers, 3);
      expect(counts.pendingApprovals, 1);
      expect(counts.familyCount, 1);
      expect(counts.individualCount, 1);
      expect(counts.membersWithGroups, 2);
      expect(counts.groupParticipationRate, 50);
    });

    test('an empty church divides by nothing', () {
      final counts = dashboardMemberCounts(const []);
      expect(counts.memberCount, 0);
      expect(counts.groupParticipationRate, 0);
    });
  });

  group('every bucket a chart can draw has a label and a colour', () {
    // The label key is built at runtime
    // (`dashboard.<mode>_bucket.<id>`), so nothing that scans source for
    // literal keys can see it — `text_content_policy_test` included. A
    // tidy-up that deletes "unused" defaults would silently leave segments
    // labelled with their raw id. This asserts the real contract by
    // generating members that populate every bucket of every view.
    final everyBucket = <ChurchMembership>[
      _member('m',
          gender: 'male',
          category: 'family',
          solemnized: true,
          dob: DateTime(1990, 1, 1),
          familyId: 'family_a'),
      _member('f',
          gender: 'female', category: 'individual', dob: DateTime(2015, 1, 1)),
      _member('u', category: 'visitor', dob: DateTime(2008, 1, 1)),
      _member('s', gender: 'male', dob: DateTime(1950, 1, 1)),
      _member('n'),
    ];

    final bucketsByMode = {
      DashboardMemberChartMode.gender: dashboardGenderBuckets(everyBucket),
      DashboardMemberChartMode.age: dashboardAgeBuckets(everyBucket),
      DashboardMemberChartMode.family: dashboardFamilyModeBuckets(everyBucket),
      DashboardMemberChartMode.solemnized:
          dashboardSolemnizedBuckets(everyBucket),
    };

    test('a label default exists for each one', () {
      for (final entry in bucketsByMode.entries) {
        expect(entry.value, isNotEmpty, reason: '${entry.key.name} drew none');
        for (final bucket in entry.value) {
          final key = dashboardBucketLabelKey(entry.key, bucket.id);
          expect(
            defaultChurchTextContents[key],
            isNotNull,
            reason: 'Missing text content for $key',
          );
        }
      }
    });

    test('each view gives its segments distinct colours', () {
      // Two segments sharing a colour makes the chart unreadable, and the
      // old label-keyed lookup silently returned grey for everything.
      for (final entry in bucketsByMode.entries) {
        final colors = entry.value
            .map((bucket) => dashboardBucketColor(entry.key, bucket.id))
            .toList();
        expect(
          colors.toSet().length,
          colors.length,
          reason: '${entry.key.name} reuses a colour across segments',
        );
      }
    });
  });
}
