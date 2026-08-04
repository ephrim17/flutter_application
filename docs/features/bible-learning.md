# Bible Learning

## Purpose and authority

Bible Learning is a small ordered learning platform. Global content and every
church-specific override are managed only by enabled super admins. Church
admins do not author modules.

## Content model

- A module has title, description, enabled state, sections, final MCQ exam and
  passing percentage.
- Each section has title, description, multiple ordered Bible passages and
  ordered resources.
- Resource types are images, embedded YouTube videos, external links and
  multiple PDFs.
- Images open in the shared paged/zoomable viewer. PDFs open in-app. YouTube
  starts inline and offers an explicit full-screen landscape experience.
- Learners complete sections in order. The final exam unlocks only after every
  section is complete.
- Passing the final exam completes the module and unlocks the next module.
  Failed exams can be retaken; passed exams cannot be taken again.
- Completed modules remain open so every section can be reviewed. The exam card
  becomes non-tappable and says the final exam passed/module completed.

## Global and church-specific resolution

- Global definitions: `learning_modules/{moduleId}`.
- Church control: `churches/{churchId}/learning_config/main`.
- Super admin can disable learning for one church, disable global inheritance,
  hide a global module, define a church order, add a church-only module or copy
  and customize a global module.
- A church copy replaces only its source module for that church. Reverting uses
  the current global module again. No other church is affected.

## Progress and results

- Progress: `churches/{churchId}/users/{uid}/learning_progress/progress`.
- Final-exam attempts: `churches/{churchId}/learning_results/{resultId}`.
- Every pass/fail attempt stores user footprint, answers, score, total, pass
  status, attempt number and timestamp.
- Super admin can review results grouped under each church.

## Storage

- Global resources: `learning_modules/{moduleId}/{sectionId}/...`.
- Church-owned resources:
  `churches/{churchId}/learning_modules/{moduleId}/{sectionId}/...`.
- Customization copies files into church ownership so future global update or
  deletion cannot break that church's course.

## Technical map

- Member UI: `sections/learning_path_section.dart`.
- Super-admin UI: `learning_modules_admin_screen.dart`,
  `church_learning_setup_screen.dart`, `learning_results_admin_screen.dart`.
- Model/provider/repository: `learning_module_models.dart`,
  `learning_module_providers.dart`, `learning_module_repository.dart`.
- Shared media: `adaptive_youtube_player.dart`,
  `app_image_gallery_viewer.dart`, `pdfrx` viewer.

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| LEARN-01 | Church learning disabled | No member learning card/catalogue; other churches unaffected. |
| LEARN-02 | Global + hidden + customized + church-only modules | Resolved catalogue contains the correct church-specific set/order. |
| LEARN-03 | Locked progression | Only first available module/section opens until prerequisites complete. |
| LEARN-04 | Section with multiple passages | Ordered passages and verse bounds display correctly. |
| LEARN-05 | Multiple images | Each opens, pages and zooms without excessive memory/crash. |
| LEARN-06 | Multiple PDFs | Each opens in-app, supports retry/error and does not spin indefinitely. |
| LEARN-07 | YouTube/external link | Inline video is smooth; explicit full screen rotates landscape; return restores portrait; link asks confirmation. |
| LEARN-08 | Android file upload | Image/PDF bytes upload without unable-to-read-file or `_dependents` crash. |
| LEARN-09 | Complete all lessons | Final exam unlocks only after final lesson completion. |
| LEARN-10 | Fail exam | Attempt is recorded, module remains incomplete and Retake is available. |
| LEARN-11 | Pass exam | Result says Module completed; next module unlocks. |
| LEARN-12 | Open completed module | All sections are reviewable; final exam is non-tappable and cannot be replayed. |
| LEARN-13 | Results overview | Super admin sees correct church/user/attempt/score/pass data. |
| LEARN-14 | Customize then change/delete global | Church copy and files remain unchanged. |
| LEARN-15 | Delete module/resource | Only owned records/files are removed; progress/result handling is deliberate. |
| LEARN-16 | Poor network/large media | Loading indicators terminate into content or actionable error; scrolling remains smooth. |

