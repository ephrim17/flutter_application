class AppConfig {
  final List<String> admins;
  final bool membersEnabled;
  final bool eventsEnabled;
  final bool bibleSwipeFetchEnabled;
  final int bibleSwipeFetchVersion;
  final String onboardingTitle;
  final String onboardingSubtitle;
  final String primaryColorHex;
  final String secondaryColorHex;
  final String backgroundColorHex;
  final String cardColorHex;
  final DailyVerseRef dailyVerseRef;
  final PromiseVerseRef promiseVerseRef;
  final PromptSheetModel promptSheet;
  final TextContent textContent;
  final String churchLogo;

  const AppConfig({
    required this.admins,
    required this.membersEnabled,
    required this.eventsEnabled,
    required this.onboardingTitle,
    required this.onboardingSubtitle,
    required this.primaryColorHex,
    required this.secondaryColorHex,
    required this.backgroundColorHex,
    required this.cardColorHex,
    required this.dailyVerseRef,
    required this.promptSheet,
    required this.bibleSwipeFetchEnabled,
    required this.bibleSwipeFetchVersion,
    required this.promiseVerseRef,
    required this.textContent,
    required this.churchLogo
  });

  factory AppConfig.fromFirestore(Map<String, dynamic> data) {
    final features = data['features'] as Map<String, dynamic>? ?? {};
    return AppConfig(
      admins: List<String>.from(data['admins'] ?? []),
      dailyVerseRef:DailyVerseRef.fromMap(data['dailyVerse'] ?? {}),
      promiseVerseRef:PromiseVerseRef.fromMap(data['promiseWord'] ?? {}),
      promptSheet:PromptSheetModel.fromMap(data['promptSheet'] ?? {}),
      membersEnabled: data['features']?['membersEnabled'] ?? false,
      bibleSwipeFetchEnabled: data['features']?['bibleSwipeFetchEnabled'] ?? false,
      bibleSwipeFetchVersion: (features['bibleSwipeVersion'] as num?)?.toInt() ?? 0,
      eventsEnabled: data['features']?['eventsEnabled'] ?? false,
      onboardingTitle: data['onboarding']?['title'] ?? '',
      onboardingSubtitle: data['onboarding']?['subtitle'] ?? '',
      textContent: TextContent.fromMap(data['textContent'] as Map<String, dynamic>?),
      primaryColorHex: data['theme']?['primaryColor'] ?? '#000000',
      secondaryColorHex: data['theme']?['secondaryColor'] ?? '#000000',
      backgroundColorHex: data['theme']?['backgroundColor'] ?? '#000000',
      cardColorHex: data['theme']?['cardBackgroundColor'] ?? '#000000',
      churchLogo: data['churchLogo'] ?? ""
      //logoUrl: data['theme']?['logoUrl'] ?? '',
    );
  }

  bool isAdmin(String email) => admins.contains(email);
}


class DailyVerseRef {
  final String book;
  final int chapter;
  final int verse;

  DailyVerseRef({
    required this.book,
    required this.chapter,
    required this.verse,
  });

   factory DailyVerseRef.fromMap(Map<String, dynamic> map) {
    return DailyVerseRef(
      book: map['book'] as String,
      chapter: map['chapter'] as int,
      verse: map['verse'] as int,
    );
  }
}

class PromiseVerseRef {
  final String book;
  final int chapter;
  final int verse;

  PromiseVerseRef({
    required this.book,
    required this.chapter,
    required this.verse,
  });

   factory PromiseVerseRef.fromMap(Map<String, dynamic> map) {
    return PromiseVerseRef(
      book: map['book'] as String,
      chapter: map['chapter'] as int,
      verse: map['verse'] as int,
    );
  }
}

class PromptSheetModel {
  final String title;
  final String desc;
  final bool enabled;

  PromptSheetModel({
    required this.title,
    required this.desc,
    required this.enabled,
  });

   factory PromptSheetModel.fromMap(Map<String, dynamic> map) {
    return PromptSheetModel(
      title: map['title'] as String,
      desc: map['desc'] as String,
      enabled: map['enabled'] as bool,
    );
  }
}

class TextContent {
  final Map<String, String> _values;

  const TextContent(this._values);

  factory TextContent.fromMap(Map<String, dynamic>? map) {
    final values = <String, String>{...defaultTextContentValues};
    if (map != null) {
      map.forEach((key, value) {
        if (value is String && value.trim().isNotEmpty) {
          values[key] = value;
        }
      });
    }
    return TextContent(values);
  }

  String get(String key, {required String fallback}) {
    return _values[key] ?? fallback;
  }
}

const Map<String, String> defaultTextContentValues = {
  // Feed screen / modal
  'feed.error_load': 'Unable to load feed',
  'feed.no_church_selected': 'No church selected',
  'feed.retry': 'Retry',
  'feed.no_posts': 'No posts yet',
  'feed.create_title': 'Create Post',
  'feed.edit_title': 'Edit Post',
  'feed.cancel': 'Cancel',
  'feed.add_image_optional': 'Add Image (Optional)',
  'feed.validation_all_fields_required': 'All fields are required',
  'feed.post_action': 'Post',
  'feed.update_action': 'Update',
  'feed.delete_action': 'Delete Post',
  'feed.delete_confirm_title': 'Delete post?',
  'feed.delete_confirm_message':
      'This will permanently delete the post and its image.',

  // Settings
  'settings.title': 'Settings',
  'settings.dark_mode': 'Dark Mode',
  'settings.prayer_reminders': 'Prayer Reminders',
  'settings.prayer_daily_at_prefix': 'Daily at',
  'settings.prayer_reminders_subtitle_off': 'Enable daily prayer reminder',
  'settings.edit_reminder_time': 'Edit Reminder Time',
  'settings.clear_local_data': 'Clear All Local Data',
  'settings.confirm': 'Confirm',
  'settings.clear_confirm_message':
      'Are you sure you want to clear all local data?',
  'settings.cancel': 'Cancel',
  'settings.clear': 'Clear',
  'settings.local_data_cleared': 'All local data cleared',
  'settings.prayer_schedule_failed': 'Failed to schedule reminder',

  // Common
  'common.error_prefix': 'Error',
  'common.proceed': 'Proceed',
  'common.submit': 'Submit',
  'common.unknown_error': 'An unknown error occurred.',

  // Auth / entry
  'auth.login': 'Login',
  'auth.request_access': 'Request Access',
  'auth.forgot_password': 'Forgot Password ?',
  'auth.forgot_password_title': 'Forgot Password',
  'auth.email_label': 'Email',
  'auth.email_invalid': 'Please enter a valid email.',
  'auth.send_reset_email': 'Send Reset Email',
  'auth.reset_email_sent': 'Password reset email sent. Check your inbox.',
  'auth.login_validation': 'Please fill all fields (password min 6 chars)',
  'auth.name_label': 'Your Name',
  'auth.name_helper': 'Name should have only characters, not numbers',
  'auth.name_required': 'Please enter your name',
  'auth.name_min_length': 'Name must be at least 3 characters',
  'auth.email_address_label': 'Email Address',
  'auth.email_required': 'Please enter your email',
  'auth.email_address_invalid': 'Please enter a valid email address',
  'auth.phone_label': 'Phone Number',
  'auth.phone_required': 'Please enter your phone number',
  'auth.phone_invalid': 'Enter a valid 10-digit phone number',
  'auth.dob_label': 'Date of Birth',
  'auth.dob_hint': 'Select your date of birth',
  'auth.dob_required': 'Please select your date of birth',
  'auth.password_label': 'Password',
  'auth.password_helper': 'Min 8 chars, 1 uppercase, 1 number',
  'auth.password_required': 'Please enter a password',
  'auth.password_min_length': 'Password must be at least 8 characters',
  'auth.password_uppercase_required': 'Include at least one uppercase letter',
  'auth.password_number_required': 'Include at least one number',
  'auth.confirm_password_label': 'Confirm Password',
  'auth.confirm_password_helper': 'Password and Confirm passwords must be same',
  'auth.confirm_password_required': 'Please confirm your password',
  'auth.passwords_mismatch': 'Passwords do not match',
  'auth_entry.welcome': 'Welcome',
  'auth_entry.continue': 'Continue',

  // Church selection
  'church.select_subtitle': 'Select your church to proceed further',
  'church.select_button': 'Select Church',
  'church.error_loading': 'Error loading churches',
  'church.none_available': 'No churches available',

  // Drawer
  'drawer.title': 'Church',
  'drawer.error_loading_user': 'Error loading user',
  'drawer.logout': 'Logout',

  // Members
  'members.title': 'All Members ',
  'members.error_loading': 'Error loading members',
  'members.none': 'No members found',

  // Favorites
  'favorites.title': 'Favorites',
  'favorites.none': 'No Favorites yet',
  'favorites.removed': 'Removed from favorites',
  'favorites.share_english': 'Share in English',
  'favorites.share_tamil': 'Share in Tamil',

  // Prayer requests
  'prayer.my_requests_title': 'My Prayer Requests',
  'prayer.all_requests_title': 'All Prayer Requests',
  'prayer.my_requests_tab': 'My Requests',
  'prayer.all_requests_tab': 'All Requests',
  'prayer.none': 'No prayer requests yet',
  'prayer.by_loading': 'By: Loading...',
  'prayer.by_unknown': 'By: Unknown',
  'prayer.expires_prefix': 'Expires',
  'prayer.modal_title': 'Prayer Request',
  'prayer.title_label': 'Title',
  'prayer.title_required': 'Title required',
  'prayer.description_label': 'Description',
  'prayer.description_required': 'Description required',
  'prayer.submit_anonymous': 'Submit anonymously',
  'prayer.select_expiry_date': 'Select expiry date',
  'prayer.expiry_prefix': 'Expiry',
  'prayer.select_expiry_required': 'Please select expiry date',
  'prayer.saved_success': 'Prayer request saved successfully',

  // About
  'about.our_mission': 'Our Mission',
  'about.our_community': 'Our Community',
  'about.our_values': 'Our Values',

  // Events / announcements / pastors
  'events.title': 'Events',
  'events.section_title': 'Events',
  'events.none': 'No Events',
  'announcements.section_title': 'Announcements',
  'announcements.none': 'No announcements',
  'pastor.section_title': 'Our Pastors',
  'pastor.empty_error': 'Something went wrong',

  // Bible / reading plan
  'bible.title': 'Holy Bible',
  'bible_swipe.title': 'Bible Swipes',
  'reading_plan.title': 'Bible in a year',

  // Onboarding / bootstrap
  'onboarding.get_started': 'Get Started',
  'onboarding.next': 'Next',
  'app.bootstrap_failed': 'Bootstrap Launch failed',

  // Church tab
  'church_tab.app_title': 'TNBM',
  'church_tab.home': 'Home',
  'church_tab.for_you': 'For You',
  'church_tab.feeds': 'Feeds',
};
