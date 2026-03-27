# Face Recognition Attendance System

This project is a Flutter-based offline face recognition attendance system.
It combines face enrollment, attendance marking, expression detection,
local persistence, CSV export, and dashboard analytics in one mobile app.

The app is designed to run without a backend server. All core state lives on
the device using `SharedPreferences` and exported files. ML inference is done
on-device using camera frames, face detection, face embeddings, and a custom
expression cue model.

## What The App Does

The app supports the full attendance workflow:

1. Enroll a student with face data.
2. Store that student's embeddings locally.
3. Start an attendance session by entering teacher and subject details.
4. Scan faces from the camera feed.
5. Match detected faces against saved embeddings.
6. Mark attendance and store the session locally.
7. View dashboard summaries and attendance history.
8. Export attendance CSV files and backup/restore the local database.

## High-Level Architecture

The app is organized into five main layers:

1. UI screens in `lib/screens/`.
2. ML and attendance logic in `lib/modules/`.
3. Local data models in `lib/models/`.
4. SharedPreferences-backed storage in `lib/database/`.
5. Shared constants, exports, and UI helpers in `lib/utils/` and `lib/widgets/`.

The app is intentionally offline-first. There is no API server, no cloud sync,
and no backend dependency. That keeps the recognition flow fast and predictable
on the target device.

## Main Entry Point

- `lib/main.dart` is the active application entry point.
- It initializes `DatabaseManager` at startup.
- It opens `HomeScreen` as the first visible route.
- The app route table points to all major screens from there.

## Screen Flow

The normal user flow is:

1. Open the app from `lib/main.dart`.
2. Land on `HomeScreen`.
3. Tap `Enroll` to add a student face.
4. Tap `Attendance` to enter teacher and subject details.
5. Start attendance from `AttendancePrepScreen`.
6. The app opens `AttendanceScreen` and starts live scanning.
7. Marked attendance is saved locally and can be exported.
8. Use `DatabaseScreen` to review stats, history, and enrolled students.

## File System Map

### Root Files

- `README.md` - Main project guide.
- `pubspec.yaml` - Flutter package config, dependencies, and assets.
- `analysis_options.yaml` - Dart analysis rules.
- `lib/main.dart` - Active app entry point.
- `00_START_HERE.md` - Quick project orientation.
- `EMOTION_RECOGNITION_README.md` - Expression-screen guide.

### `lib/screens/`

- `home_screen.dart` - Home dashboard and navigation hub.
- `enrollment_screen.dart` - Student enrollment and embedding capture.
- `attendance_prep_screen.dart` - Teacher/subject setup before attendance.
- `attendance_screen.dart` - Live attendance scanning and marking.
- `expression_detection_screen.dart` - Emotion detection and live expression log.
- `database_screen.dart` - Attendance dashboard, enrolled students, and history.
- `export_screen.dart` - Export and reporting screen.
- `settings_screen.dart` - Settings, backup, restore, cleanup, and app config.
- `main_app.dart` - Removed legacy alternate entry point.
- `attendance_screen_stub.dart` - Removed legacy placeholder screen.
- `export_screen_backup.dart` - Removed legacy backup export implementation.

### `lib/modules/`

- `m1_face_detection.dart` - Face detection wrapper around ML Kit / MediaPipe-style face detection.
- `m2_face_embedding.dart` - Face embedding generation using the TFLite model.
- `m3_face_matching.dart` - Matching helpers and similarity utilities.
- `m4_attendance_management.dart` - Attendance statistics, export helpers, and session logic.
- `m5_liveness_detection.dart` - Eye aspect ratio and liveness-style heuristics.
- `expression_cue_model.dart` - Rule-based emotion classifier built from face cues.
- `expression_cue_calibration.dart` - Calibration loader and default thresholds.

### `lib/database/`

- `database_manager.dart` - SharedPreferences-backed persistence layer.
- `database_connection.dart` - Database connection helper / compatibility layer.
- `face_recognition_database.dart` - Deprecated legacy file, kept only as historical code and removed from active flow.

### `lib/models/`

- `student_model.dart` - Student data model.
- `attendance_model.dart` - Attendance record, session, and status models.
- `subject_model.dart` - Subject model.
- `embedding_model.dart` - Face embedding model.
- `face_detection_model.dart` - Face detection result and face geometry model.
- `match_result_model.dart` - Matching result model.

### `lib/utils/`

- `constants.dart` - Colors, gradients, route names, text styles, thresholds, and theme config.
- `theme.dart` - App theme helpers.
- `export_utils.dart` - Shared export directory helper.
- `csv_export_service.dart` - CSV generation service.

### `lib/widgets/`

- `animated_background.dart` - Shared animated background used by the screens.

### Assets

- `assets/models/` - Runtime models and calibration files.
- `assets/icons/vision_id.png` - App icon and branding image.
- `assets/lottie/success.json` - Success animation.

### Platform Folders

- `android/` - Android build and manifest files.
- `ios/` - iOS build and app configuration.
- `web/` - Web shell files.
- `windows/` - Windows desktop shell.
- `linux/` - Linux desktop shell.
- `macos/` - macOS desktop shell.

## Core Dependencies

Declared in `pubspec.yaml`:

- `camera` - Live camera preview and frame capture.
- `google_ml_kit` - Face detection.
- `google_mlkit_face_mesh_detection` - Face mesh contours.
- `tflite_flutter` - Embedding model inference.
- `image` - Frame decoding, cropping, and encoding.
- `shared_preferences` - Local data persistence.
- `permission_handler` - Camera and storage permission requests.
- `flutter_tts` - Spoken attendance confirmation.
- `sqlite3_flutter_libs` and `drift` - Present in the project, but the active runtime storage in this version is SharedPreferences-backed.
- `path_provider` and `path` - File export directories.
- `pdf` and `share_plus` - Export and sharing utilities.
- `google_fonts` - Typography.
- `lottie` - Animated UI feedback.
- `file_picker` - Backup/restore file selection.
- `screen_brightness` - Flash/light boost for front camera assistance.

## Runtime Environment

Recommended environment:

- Flutter SDK compatible with Dart `^3.10.7`.
- Android device or emulator with camera support.
- Enough device storage for the APK and exported files.
- Camera permission enabled.

Practical note:

- The active debug APK can be large because the app ships with ML assets and
	camera/ML dependencies.
- On low-storage devices, installation may fail until space is freed.

## How To Run

### First Time Setup

1. Install Flutter and make sure `flutter doctor` is clean enough to build.
2. Clone or open the workspace.
3. Run `flutter pub get`.
4. Make sure the target Android device has free storage.
5. Enable camera permission on the device if prompted.

### Run In Debug

```bash
flutter run
```

### Build APK

```bash
flutter build apk
```

If install space is tight, build a split APK by ABI:

```bash
flutter build apk --split-per-abi
```

## Data Storage Model

The app stores its live data in `SharedPreferences` through `DatabaseManager`.
The important keys are:

- `students` - student records.
- `embeddings` - face embedding vectors for each student.
- `attendance` - attendance records.
- `subjects` - subject list.
- `teacherSessions` - teacher and subject session metadata.
- Session-specific attendance keys created by attendance submission.

### What Each Store Contains

#### Students

Each student record includes:

- id
- name
- roll number
- class
- gender
- age
- phone number
- enrollment date

#### Embeddings

Each embedding record includes:

- id
- studentId
- vector
- captureDate

These vectors are what the matcher uses to identify a person later.

#### Attendance

Each attendance record includes:

- id
- studentId
- date
- time
- status
- recordedAt
- emotion

#### Teacher Sessions

Each teacher session includes:

- id
- teacherName
- subjectId
- subjectName
- date
- createdAt

## Why The Modules Exist

### `m1_face_detection.dart`

This module wraps the face detector and face mesh extraction. It produces the
face geometry and contour data used by the recognition and expression logic.

### `m2_face_embedding.dart`

This module turns a cropped face image into a numeric embedding vector. Those
vectors are then compared against stored student templates.

### `m3_face_matching.dart`

This module compares embeddings and chooses the closest match using similarity
metrics and threshold logic.

### `m4_attendance_management.dart`

This module calculates attendance details, session summaries, exports, and
system statistics from the persisted records.

### `m5_liveness_detection.dart`

This module adds simple liveness-style heuristics based on eye geometry.
It helps keep the recognition pipeline less naive.

### `expression_cue_model.dart`

This module is the expression engine. It does not train a neural network at
runtime. Instead it scores facial cues such as:

- eye openness
- mouth openness
- mouth width
- smile probability
- eye balance
- face contour hints

Then it converts those cue scores into one label.

### `expression_cue_calibration.dart`

This module loads calibration values from `assets/models/expression_cue_calibration.json`.
If the JSON is missing or invalid, it falls back to built-in defaults.

## Screen-by-Screen Explanation

### Home Screen

`home_screen.dart` is the navigation hub.

It shows:

- App branding.
- Live summary chips for students, present count, and sessions.
- Primary cards for enrollment and attendance.
- Tool cards for expression detection, export, settings, and database.
- Feature highlights.

The home screen is intentionally styled as a polished dashboard because it is
the first place the user sees after launch.

### Enrollment Screen

`enrollment_screen.dart` captures a face, generates embeddings, and stores the
student record.

It is responsible for:

- asking for student details,
- using the camera to capture the face,
- extracting embeddings,
- saving the student and embeddings locally.

### Attendance Prep Screen

`attendance_prep_screen.dart` is the entry screen before marking attendance.

It collects:

- teacher name,
- subject selection,
- new subject creation.

When the user taps `Start Attendance`, it opens the active attendance screen.

### Attendance Screen

`attendance_screen.dart` is the live attendance engine.

It does the following:

1. Opens the camera.
2. Detects faces in the live feed.
3. Crops each face.
4. Generates embeddings.
5. Matches them against enrolled students.
6. Applies cooldown and consecutive confirmation rules.
7. Marks attendance locally.
8. Stores the detected emotion at mark time.
9. Saves the session and generates CSV output.

This screen also handles front-camera light boost and camera switching.

### Expression Detection Screen

`expression_detection_screen.dart` streams the camera and labels expressions
using the cue model.

It includes:

- live camera preview,
- face overlay,
- temporal stabilization,
- emotion logging,
- confidence handling,
- expression badge rendering.

The current implementation uses live image streaming so the preview stays
smooth while scanning.

### Database Screen

`database_screen.dart` provides the attendance dashboard.

It shows:

- overview statistics,
- attendance history by date,
- student attendance detail cards,
- enrolled student list,
- per-student attendance percentages.

This screen reads from the same local storage used by the rest of the app and
rebuilds its own snapshot of records for display.

### Export Screen

`export_screen.dart` handles export operations and report generation.

### Settings Screen

`settings_screen.dart` provides:

- backup creation,
- restore from backup,
- merge backup data,
- cleanup actions,
- app configuration.

## How Recognition Works

The recognition pipeline is deliberately layered.

### Step 1: Camera Frame

The camera provides live frames or captured images.

### Step 2: Face Detection

The face detector finds one or more faces and gives bounding boxes plus face
mesh data when available.

### Step 3: Face Crop

The app crops the face region so embedding generation sees only the face.

### Step 4: Embedding Generation

`m2_face_embedding.dart` turns the crop into a vector.

### Step 5: Student Matching

The vector is compared to stored templates. The app rejects weak matches using
threshold and verification logic rather than simply returning the closest face.

### Step 6: Attendance Commit

When the match passes validation, the student is marked present and the record
is saved locally.

## How Expression Detection Works

The expression system is a rule-based cue scorer, not a plain placeholder label.

It uses:

- smile probability,
- eye openness,
- mouth opening,
- mouth width,
- eye balance,
- contour hints from the face mesh.

The model then produces a probability table across:

- Angry
- Disgust
- Happy
- Neutral
- Sad
- Surprise

Temporal stabilization prevents one noisy frame from flipping the label.

## CSV and Export Behavior

CSV export is intentionally shared through `export_utils.dart` so all export
features point to the same folder.

Exports are written to a consistent `FaceAttendanceExports` directory under the
platform-appropriate external or documents folder.

The app can generate:

- attendance CSV files,
- subject-specific summaries,
- backup JSON files,
- report files from the export screen.

## Why Some Old Files Were Removed

The following legacy files were removed because they were not part of the active
app flow anymore:

- `lib/main_app.dart`
- `lib/screens/attendance_screen_stub.dart`
- `lib/screens/export_screen_backup.dart`
- `test_yolo_shape.dart`

These were placeholder, backup, or alternate-entry files that were no longer
used by `lib/main.dart` and the active route table.

## Building And Running Notes

### Android

- Make sure the device has enough free storage.
- Grant camera permission.
- If install fails, uninstall the previous build and retry.

### iOS

- Open the project in Xcode if you need signing changes.
- Camera permission must be present in the app plist.

### Desktop / Web

The project includes desktop and web shells, but the main target is the mobile
camera workflow.

## Troubleshooting

### Camera Does Not Open

- Check permissions.
- Confirm the device has a camera.
- Restart the app after granting permission.

### Recognition Is Slow

- Use a device with a stronger CPU/GPU.
- Make sure the camera feed is well lit.
- Keep the face centered and not too far away.

### Attendance Percentage Looks Wrong

- The dashboard is based on the stored attendance snapshot.
- If you restore old data, percentages will reflect whatever records were
	imported.

### Installation Fails On Android

- Free device storage.
- Remove older builds from the device.
- Use split APK build output when needed.

## Project Hygiene

If you want to keep the repo clean, the normal safe cleanup targets are:

- `build/`
- `.dart_tool/`
- older backup screens or test files that are not part of the active route table
- duplicate historical documentation if you no longer need change history

## Current Active App Entry

- Active launch file: `lib/main.dart`
- Active home route: `HomeScreen`
- Attendance setup screen: `AttendancePrepScreen`
- Attendance scanning screen: `AttendanceScreen`

## Short Version Of The App Logic

The app is a local, offline face attendance system.
It enrolls faces, stores embeddings, scans live camera frames, matches them to
saved students, writes attendance locally, and exports the results when needed.

The entire design favors offline reliability and on-device processing over a
server-based workflow.