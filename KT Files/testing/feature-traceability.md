# Feature Traceability Matrix

This matrix maps product areas to their most relevant automated coverage. A
blank entry means the area currently relies on manual/integration testing and
is a candidate for future automation.

| Feature | Existing automated coverage | Required manual suite |
|---|---|---|
| Authentication and entry | `production_hardening_test.dart` (OTP error mapping), `widget_test.dart` | AUTH scenarios |
| Navigation and shared UI | `app_bottom_tab_bar_test.dart`, `app_count_badge_test.dart`, `app_modal_bottom_sheet_test.dart`, `app_text_field_test.dart` | NAV scenarios |
| Feeds | `feed_model_test.dart`, `feed_link_utils_test.dart`, `feed_scroll_navigation_test.dart` | FEED scenarios |
| Prayer requests | `prayer_request_model_test.dart` | PRAY scenarios |
| Members | `dashboard_gender_members_screen_test.dart`, `user_quick_card_test.dart`, `contact_launcher_test.dart` | MEMBER scenarios |
| Profile photo | `profile_photo_model_test.dart` | SETTINGS scenarios |
| Faith Engagement | `faith_engagement_models_test.dart` | FAITH scenarios |
| Bible Learning | `learning_module_models_test.dart` | LEARN scenarios |
| For You registry/order | `for_you_section_registry_test.dart` | FORYOU scenarios |
| Studio admin emails | `admin_email_manager_test.dart` | STUDIO scenarios |
| Text policy | `text_content_policy_test.dart` | All visual scenarios |
| Production hardening | `production_hardening_test.dart` | Release smoke suite |
| Home, articles and reading plans | — | HOME/FORYOU scenarios |
| Live Church | — | LIVE scenarios |
| Equipment | — | EQUIP scenarios |
| Notifications | — | NOTIFY scenarios |
| Super Admin | — | SUPER scenarios |

When adding automation, keep pure rules in unit tests, reusable UI in widget
tests, and Firebase authorization/data lifecycle in emulator integration tests.

