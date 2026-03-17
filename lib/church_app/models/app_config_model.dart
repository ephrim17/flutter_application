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
  'settings.edit_profile': 'Review Profile',
  'settings.profile_updated': 'Profile updated',
  'settings.delete_account': 'Delete Account',
  'settings.delete_account_subtitle': 'Permanently remove your account and user data',

  // Common
  'common.error_prefix': 'Error',
  'common.proceed': 'Proceed',
  'common.submit': 'Submit',
  'common.unknown_error': 'An unknown error occurred.',
  'common.loading': 'Loading...',
  'common.delete': 'Delete',
  'common.save': 'Save',
  'common.create': 'Create',
  'common.edit': 'Edit',
  'common.description': 'Description',
  'common.title': 'Title',
  'common.content': 'Content',
  'common.enabled': 'Enabled',
  'common.active': 'Active',
  'common.close': 'Close',

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
  'auth.location_label': 'Google Maps Location',
  'auth.location_helper': 'Use current location or paste your Google Maps link',
  'auth.location_required': 'Please enter your location',
  'auth.location_use_current': 'Use Current Location',
  'auth.location_permission_denied': 'Location permission denied',
  'auth.location_permission_denied_forever':
      'Location permission denied permanently. Enable it from settings.',
  'auth.location_service_disabled': 'Location services are disabled',
  'auth.location_fetch_failed': 'Unable to fetch current location',
  'auth.address_label': 'Address',
  'auth.address_helper': 'Enter your address manually',
  'auth.address_required': 'Please enter your address',
  'auth.gender_label': 'Gender',
  'auth.gender_required': 'Please select your gender',
  'auth.category_label': 'Category',
  'auth.category_required': 'Please select your category',
  'auth.family_existing_toggle': 'Use existing family ID',
  'auth.family_id_label': 'Family ID',
  'auth.family_id_required': 'Please select or create a family ID',
  'auth.family_name_label': 'Family Name',
  'auth.family_name_helper': 'Used to generate a new family ID',
  'auth.family_name_required': 'Please enter a family name',
  'auth.individual_family_hint': 'Family ID will be generated automatically',
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

  // Studio
  'studio.title': 'Studio',
  'studio.admin_only': 'Studio is available only for admins.',
  'studio.no_church_selected': 'No church selected.',
  'studio.tab_events': 'Events',
  'studio.tab_announcements': 'Announcements',
  'studio.tab_daily_verse': 'Daily Verse',
  'studio.tab_articles': 'Articles',
  'studio.tab_promise': 'Promise',
  'studio.tab_notifications': 'Notifications',
  'studio.tab_admins': 'Admins',
  'studio.tab_prompt': 'Prompt',
  'studio.add_event': 'Add event',
  'studio.no_events': 'No events yet.',
  'studio.add_announcement': 'Add announcement',
  'studio.no_announcements': 'No announcements yet.',
  'studio.add_article': 'Add article',
  'studio.no_articles': 'No articles yet.',
  'studio.delete_title': 'Delete',
  'studio.delete_confirm_remove_prefix': 'Remove',
  'studio.event_type_prefix': 'Type',
  'studio.event_contact_prefix': 'Contact',
  'studio.event_location_prefix': 'Location',
  'studio.announcement_priority_prefix': 'Priority',
  'studio.edit_item_prefix': 'Edit',
  'studio.notification_title': 'Church Topic Notification',
  'studio.notification_topic_prefix': 'Topic',
  'studio.notification_title_label': 'Notification title',
  'studio.notification_body_label': 'Notification body',
  'studio.notification_queued': 'Notification request queued',
  'studio.notification_send': 'Send Notification',
  'studio.admins_hint': 'Enter one admin email per line.',
  'studio.admins_label': 'Admin emails',
  'studio.admins_updated': 'Admins updated',
  'studio.admins_save': 'Save Admins',
  'studio.prompt_title': 'Prompt Sheet',
  'studio.prompt_updated': 'Prompt updated',
  'studio.prompt_save': 'Save Prompt',
  'studio.announcement_create': 'Create announcement',
  'studio.announcement_edit': 'Edit announcement',
  'studio.announcement_body': 'Body',
  'studio.announcement_upload_image': 'Upload image',
  'studio.announcement_replace_image': 'Replace image',
  'studio.announcement_change_image': 'Change image',
  'studio.priority_label': 'Priority',
  'studio.event_create': 'Create event',
  'studio.event_edit': 'Edit event',
  'studio.event_type': 'Type',
  'studio.event_type_family': 'family',
  'studio.event_type_kids': 'kids',
  'studio.event_type_youth': 'youth',
  'studio.event_contact': 'Contact',
  'studio.event_location': 'Location',
  'studio.event_timing': 'Timing',
  'studio.article_create': 'Create article',
  'studio.article_edit': 'Edit article',
  'studio.verse_book': 'Book',
  'studio.verse_chapter': 'Chapter',
  'studio.verse_verse': 'Verse',
};
