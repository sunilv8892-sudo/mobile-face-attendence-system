# Face Recognition Attendance System Codebook

This document is written as a reconstruction guide.
The goal is not only to describe what the app does, but to explain why each
piece exists, how the pieces fit together, and how a developer could rebuild a
similar app from the explanation alone.

The app is a Flutter-based, offline, camera-driven face recognition attendance
system. It uses:

- live camera frames,
- ML Kit face detection and face mesh data,
- FaceNet-style embeddings,
- KNN-style nearest-neighbor matching,
- local persistence with SharedPreferences,
- CSV export,
- dashboard analytics,
- a rule-based emotion cue model,
- UI styling tuned for a dark, premium dashboard look.

## How To Read This Codebook

The document is organized in the same order a developer would explore the app:

1. App bootstrap.
2. Shared constants and theme.
3. Storage and domain models.
4. ML modules.
5. Each screen.
6. End-to-end runtime flow.

Each section explains:

- what the file is responsible for,
- how the major parts of the file work,
- why those design choices are good here,
- what trade-offs the implementation makes.

## 1. App Bootstrap

### [lib/main.dart](lib/main.dart)

This file is the entry point. It is small, and that is a good thing. The app
should not contain business logic in `main()`; it should only prepare the app
and hand control to the route tree.

#### Imports

The imports tell you the shape of the app immediately.

- `material.dart` gives the Flutter UI framework.
- `database_manager.dart` is loaded early so persistence is ready before the UI
  tries to read from it.
- The screen imports tell you that the app is screen-driven rather than a
  single-page state machine.
- `constants.dart` gives the app-wide theme and route names.

That import list is good because it reveals dependencies clearly and keeps the
bootstrap file thin.

#### Database initialization

The global `DatabaseManager` is created once and initialized before `runApp()`.
That is the right choice because:

- the app needs local data before the first screen renders,
- the home screen reads statistics immediately,
- the attendance and enrollment flows depend on persisted state,
- startup errors can be caught early rather than during navigation.

This is a good pattern for local-first apps. It avoids a situation where the UI
opens before storage is ready and then has to recover from a half-initialized
state.

#### `FaceRecognitionApp`

The widget is stateless, which is also a good choice. The app shell does not
need to own mutable business state because the individual screens already own
their own state.

Inside `MaterialApp`:

- `debugShowCheckedModeBanner: false` keeps the UI clean.
- `title` comes from constants so the name is used consistently.
- `theme` uses the shared dark theme, which keeps every screen visually aligned.
- `initialRoute` starts on the home screen.
- `routes` defines the navigation graph.

The route table is the real architecture map of the app. If you want to rebuild
the app, this is the first place to understand navigation.

## 2. Shared Visual System

### [lib/utils/constants.dart](lib/utils/constants.dart)

This file matters more than it looks like. It is not only a constants bag. It is
the visual and behavioral contract for the entire app.

#### App identity

`appName`, `appVersion`, and `subtitle` define the branding. Keeping them in one
place avoids hard-coded text scattered across the UI.

#### Colors

The color palette is intentionally dark and premium:

- deep navy background,
- indigo primary accent,
- cyan accent,
- emerald success,
- amber warning,
- red error.

This palette is good because it gives the app a strong visual identity while
still keeping text readable on mobile screens.

The theme avoids default Flutter gray-on-white patterns. That matters because a
camera-based attendance app should feel like a focused operational tool, not a
generic sample project.

#### Spacing and shape

The padding and radius constants reduce layout drift. When multiple screens use
the same spacing values, the app feels deliberate instead of pieced together.

#### Shadows and gradients

The shadow and gradient constants are part of the brand language. The cards and
buttons look raised and tactile because the app uses shadow depth as feedback.
That is a good fit for a dashboard-style mobile UI.

#### Recognition thresholds

`similarityThreshold`, `requiredEnrollmentSamples`, and `embeddingDimension` are
not random numbers. They encode how the recognition system is expected to work:

- embeddings should be 128D,
- enrollment should capture multiple samples,
- recognition should reject weak matches.

That makes the app safer than using a single snapshot and a loose threshold.

#### Routes

The route names are constants, which prevents typo bugs and makes navigation
more maintainable.

#### Theme

`AppTheme.lightTheme` is actually a dark theme. The naming reflects the app’s
older structure, but the implementation is now a dark Material 3 theme.

Why this is good:

- every component inherits the same color system,
- button and input styling stays consistent,
- the app looks coherent across screens,
- developers can change the look centrally instead of editing every screen.

## 3. Data Layer

### [lib/database/database_manager.dart](lib/database/database_manager.dart)

This is the persistence layer. It uses SharedPreferences as a structured JSON
store rather than a SQL database.

That choice is good for this app because:

- the data model is small,
- the app is offline-first,
- the records are simple to serialize,
- the repository already relies on local device storage,
- the code stays easier to reason about than a full relational setup.

It is also a trade-off:

- simpler than SQLite,
- faster to implement,
- but less suitable for large datasets or complex queries.

#### Singleton design

The manager is a singleton. That is good because the app should not create many
independent storage gateways. One storage manager means one source of truth.

#### Student operations

The student methods create, read, update, and delete records stored under the
`students` key.

The important implementation detail is the generated `id`. New IDs are computed
by scanning existing records and choosing the next integer.

That is a practical choice because SharedPreferences does not auto-generate IDs.

#### Embedding operations

Embeddings are stored under `embeddings` and tied to a `studentId`.

This is the core of the recognition system. The student record is not enough on
its own; the embedding is what allows the app to identify someone later.

The embedding records include:

- the embedding vector,
- the owning student,
- the capture time.

That is good design because embeddings can be traced back to the enrollment
session that created them.

#### Attendance operations

Attendance is stored as records with:

- studentId,
- date,
- time,
- status,
- recordedAt,
- emotion.

The `recordedAt` field is important. It lets the app know when the record was
saved, not just the nominal attendance date.

The manager also reads attendance by student and by date, which is what the
dashboard and export logic need.

#### Subject operations and sessions

Subjects and teacher sessions support the attendance-prep workflow. This is good
because attendance should be attached to a teacher and a subject, not only a raw
student list.

That context is what makes the system usable in a school or class setting.

## 4. Domain Models

You asked for something close to a build-from-scratch guide, so the models matter
as much as the screens.

### Student model

The student model represents enrollment metadata such as name, roll number,
class, gender, age, phone number, and enrollment date.

Why this is good:

- it keeps identity data together,
- it supports both UI display and exports,
- it makes future edits or backups straightforward.

### Embedding model

The embedding model stores the 128D vector that represents a face.

This is the actual machine-readable identity for recognition. The UI sees a
student name, but the matcher sees a vector.

### Attendance model

The attendance model stores status and timestamps.

This is good because the app can compute summaries later without needing to
re-scan faces.

### Subject model

Subjects are separate records. That is the right choice because teachers should
be able to create or pick subjects independently of students.

### Match result model

The match result carries identity type, studentId, and similarity. That is a
clean abstraction because matching is a decision, not just a distance number.

## 5. Face Recognition Modules

### [lib/modules/m1_face_detection.dart](lib/modules/m1_face_detection.dart)

This module handles face detection and face mesh extraction.

#### Why a dedicated module exists

Keeping detection in its own file is good because detection is a separate
responsibility from embedding and matching.

#### Singleton pattern

The detector is a singleton. That is important because ML Kit resources are
heavy, and repeatedly constructing them can waste memory and slow down the app.

#### Initialization

The detector can be initialized with face mesh enabled.

That is useful because:

- attendance needs face boxes,
- expression scoring benefits from mesh contours,
- enrollment can use the same pipeline.

#### Detecting faces

The module supports detection from raw bytes and from a file path.

That flexibility is good because different screens produce images differently.

Attendance uses live camera frames, while some preprocessing paths may use
temporary files.

#### ROI extraction

The `extractFaceROI` method crops the face region out of the source image.

That is a good preprocessing step because recognition models should focus on the
face, not the background.

#### Suitability checks

The module rejects faces that are too small or too rotated.

That is good because embeddings from tiny or side-angled faces tend to be noisy.

### [lib/modules/m2_face_embedding.dart](lib/modules/m2_face_embedding.dart)

This module converts a cropped face image into a 128D embedding.

#### Why this module exists

It isolates model inference from the UI. That separation is good because:

- the UI stays readable,
- the model logic can be reused,
- model changes do not force screen rewrites.

#### FaceNet choice

The code uses a FaceNet-style TFLite model. That is a sensible choice for an
offline recognition app because embeddings are compact and easy to compare.

#### Initialization checks

The module reads input and output tensor shapes and validates the output length.

This is good engineering. It prevents silent failures when the model asset is
wrong or replaced with an incompatible file.

#### Preprocessing

The image is resized to the model’s input size and normalized to float values in
the 0 to 1 range.

That is the right type of preprocessing for this kind of model because the
network expects a fixed-size numerical tensor, not raw image bytes.

#### Normalization

The final embedding is L2-normalized.

That is a strong choice because similarity and distance comparisons become more
stable when all vectors live on a comparable scale.

### [lib/modules/m3_face_matching.dart](lib/modules/m3_face_matching.dart)

This is the matching helper module.

#### Important clarification

This is not a trainable classifier. It is nearest-neighbor matching on face
embeddings. The file names it as KNN, but the main runtime behavior is nearest
neighbor + thresholding.

That is good here because the app does not need to train a model every time new
students are added. It just needs to compare vectors.

#### `matchFace()`

This method finds the single closest embedding by Euclidean distance, converts
the distance to a similarity-like score, and accepts the result only if it is
above threshold.

Why this is good:

- simple,
- fast,
- explainable,
- easy to debug,
- works well for local offline apps.

#### `knnMatch()`

This method sorts all embeddings by distance and takes the top K entries.

In practice the app’s attendance flow uses a KNN-inspired validation scheme with
votes and threshold checks. That makes the system more robust than a single raw
distance comparison.

#### Why Euclidean distance

Euclidean distance is straightforward for normalized embeddings. It is easy to
convert into a similarity score using `1 / (1 + distance)`.

That conversion is useful because it gives the UI and logging a score that is
easier to read than a raw distance value.

### [lib/modules/m4_attendance_management.dart](lib/modules/m4_attendance_management.dart)

This module handles higher-level attendance logic.

It is a good design because it sits above raw storage and below the UI. That
keeps report generation and attendance summaries out of the screens.

#### `recordAttendance()`

This method refuses duplicate attendance entries for the same student on the
same day.

That is important because attendance should be idempotent for a given day.

#### `getAttendanceDetails()`

This method assembles student records, counts, and percentages into one object.

That is useful because screens should not have to compute those fields manually
every time they build a tile or dialog.

#### CSV export

The module exports attendance, embeddings, and detailed attendance CSVs.

That is good because it creates a portable output format that teachers or
administrators can inspect outside the app.

### Liveness module

The liveness heuristics file exists to make recognition less naive. It is a
supporting safety step, not a full anti-spoofing system.

## 6. Screens

### [lib/screens/home_screen.dart](lib/screens/home_screen.dart)

The home screen is the app’s dashboard and navigation hub.

#### Why the home screen is important

This is the first user-facing screen, so it needs to establish trust quickly.
The design should say: this is a serious operational tool, not a demo.

#### `initState()` and stats loading

The screen creates its own database manager and attendance module, then loads
statistics.

That is good because the home screen needs current counts every time it opens.

#### Statistics row

The stats chips show:

- total students,
- present today,
- total sessions.

These are the most useful summary numbers for a teacher at a glance.

#### Featured cards

The large cards for Enroll and Attendance are the primary actions.

That is a good UI choice because the app has two main workflows and those
should be visually dominant.

#### Tool grid

The smaller cards expose Expression, Export, Settings, and Database.

That is good because secondary tools should remain accessible but not compete
with the main attendance workflow.

#### Visual style

The layered shadows, gradients, and raised treatment are intentional. They make
the buttons feel physical and tappable, which helps a dashboard-style app feel
finished.

### [lib/screens/enrollment_screen.dart](lib/screens/enrollment_screen.dart)

This screen collects the student identity and face samples.

#### Controllers and fields

The name, roll number, class, age, phone, and gender fields are all separate.

That is good because enrollment data is structured. If you separated them later,
you would lose clarity and make validation harder.

#### Camera setup

The screen requests camera permission, enumerates available cameras, and prefers
the front camera.

That is a good enrollment choice because the front camera usually makes it
easier for a person to center their face while entering data.

#### Brightness boost

The screen can increase application brightness on the front camera.

That is a practical mobile UX improvement because face capture often happens in
indoor or low-light conditions.

#### Sample capture loop

The screen captures multiple embeddings instead of only one.

This is a strong design decision. Multiple samples reduce the risk of a bad
single capture dominating the student template.

#### Why medium resolution

The enrollment camera uses medium resolution to balance quality and speed.

That is a good trade-off because enrollment should be reliable but should not
make the app sluggish or memory-heavy.

### [lib/screens/attendance_prep_screen.dart](lib/screens/attendance_prep_screen.dart)

This screen is the gate before live attendance starts.

#### Why this screen exists

It collects teacher and subject context before opening the scanner.

That is good because attendance should always be attached to a class context,
not recorded as anonymous face matches.

#### Subject selection

The screen loads existing subjects and lets the user create a new one.

This is useful because classes change, but the app should still normalize how
subject data is stored.

#### Navigation behavior

After validation, the screen pushes to `AttendanceScreen` with the teacher and
subject.

That is clean because the scanner does not need to ask for class metadata again.

### [lib/screens/attendance_screen.dart](lib/screens/attendance_screen.dart)

This is the most important runtime screen in the app.

It does real-time attendance detection, matching, confirmation, and local
recording.

#### High-level responsibilities

The screen does all of the following:

- initializes camera and detection modules,
- loads enrolled students and embeddings,
- starts live image streaming automatically,
- detects faces in each frame,
- generates embeddings,
- matches faces to known students,
- confirms attendance with cooldown and consecutive detection rules,
- speaks confirmation aloud,
- stores emotion context,
- paints overlays on top of the camera feed.

That is a lot of work, so the internal structure matters.

#### Why live image streaming is used

The screen uses live image stream processing instead of repeated shutter-style
captures.

That is a better choice because:

- it keeps the preview smoother,
- it reduces visible pauses,
- it is more natural for scanning multiple people,
- it avoids repeatedly interrupting the camera pipeline.

#### `initState()` and `_initialize()`

Initialization creates all of the dependencies once:

- database manager,
- TTS engine,
- face detector,
- embedding module,
- shared emotion model,
- student records,
- student embeddings,
- KNN training set.

That is good because the screen should be ready before scanning starts.

#### Loading embeddings

The screen loads every enrolled student’s embeddings into memory.

That is an acceptable choice because the app is offline and the data size is
small enough for local vector matching.

#### `_rebuildKnnTrainingSet()`

This creates the in-memory set of samples used for matching.

That is useful because repeated matching should not repeatedly rebuild the same
lists from storage.

#### Camera initialization

The screen requests camera permission, chooses a preferred camera, and sets up
the controller.

The preferred choice is the front camera, which is usually better for face
attendance because users naturally face it.

#### Medium resolution for attendance

The attendance screen also uses medium resolution.

That is a deliberate trade-off between accuracy and speed. High resolution can
make live scanning heavy without adding enough practical benefit.

#### Automatic scanning

The scanner starts automatically once the camera is ready.

That is a better UX than forcing the user to tap a second scan button, because
attendance should begin as soon as the session is open.

#### Stream throttling

The image stream is throttled with a scan interval.

That is a good performance safeguard because the app should not process every
single frame if doing so would overload the device.

#### `_processLiveFrame()`

This converts the camera image, rotates it to the sensor orientation, converts
it to JPEG bytes, and sends it to the face detector.

That pipeline is good because each step has a single responsibility:

- raw camera format to image buffer,
- orientation correction,
- detection-ready bytes,
- face detection,
- attendance logic.

#### Face filtering

Faces smaller than a minimum size are ignored.

That is important because very small faces produce poor embeddings and noisy
emotion signals.

#### Per-face processing

Each face is processed independently.

That is the correct design for classroom or group attendance because multiple
people may appear in the same frame.

#### Attendance confirmation logic

The screen does not mark attendance on one noisy frame.

Instead it uses:

- consecutive detections,
- cooldown timing,
- similarity threshold checks,
- stage-2 verification against stored embeddings,
- ambiguity rejection when the top candidates are too close.

This is good engineering because face matching is probabilistic. A real app
should resist false positives rather than trying to be over-eager.

#### TTS confirmation

When attendance is marked, the app can speak the student name.

That is a useful accessibility and feedback feature because users hear a clear
confirmation rather than wondering whether the scan succeeded.

#### Emotion capture at mark time

The screen stores the current emotion for the student when attendance is marked.

That is a nice extra because it lets the record carry context without changing
the main attendance logic.

#### Overlay rendering

The overlay arrays store face rectangles, names, colors, and emotions.

That keeps rendering separate from recognition. Recognition decides what is true;
the overlay only visualizes the decision.

### [lib/screens/expression_detection_screen.dart](lib/screens/expression_detection_screen.dart)

This screen is a live expression lab. It is separate from attendance so emotion
research does not interfere with attendance marking.

#### Why it uses a separate screen

Separation is good here because emotion detection and attendance have different
goals:

- attendance cares about identity,
- this screen cares about expression classification,
- each workflow deserves its own tuning and UI.

#### Live stream + throttling

Like attendance, this screen uses live streaming with a controlled scan rate.

That is good because facial-expression UX feels much better when preview motion
is continuous.

#### Warmup period

The screen waits briefly after start before making decisions.

That is good because camera exposure, face detection, and model state can be
unstable in the first second.

#### Emotion pipeline

The screen detects faces, filters out tiny ones, evaluates the cue model, and
then stabilizes the result.

That is a good structure because the app does not blindly trust a single frame.

#### Expression overrides

The code applies conservative overrides for edge cases such as wide-open eyes
and ambiguous mouth shapes.

That is a pragmatic choice because cue-based emotion systems can over-trigger if
one cue dominates too strongly.

#### Why the model is rule-based

The expression model is not a learned deep classifier in this project. It is a
cue-scored decision system.

That is good here because:

- the app already runs on-device,
- it is easier to explain,
- it is easier to tune by hand,
- it can be adjusted without retraining a model.

#### Overlay and log

The screen paints face boxes and expression labels, and it keeps a rolling log
of recognized states.

That makes the screen useful as both a live demo and a debugging tool.

### [lib/screens/database_screen.dart](lib/screens/database_screen.dart)

This screen is the reporting dashboard.

#### Why it exists

It answers the question: what happened after all the scanning?

That is why it shows:

- summary statistics,
- attendance history by date,
- per-student attendance,
- enrolled student records.

#### Snapshot-based calculation

The screen builds an attendance snapshot from students and all attendance
records.

That is a good architectural choice because it centralizes reporting logic and
prevents each UI tile from querying the database separately.

#### Why the dashboard was rewritten

The current implementation fixes the statistics so the overview, enrolled list,
and history all come from the same snapshot.

That is better than mixing ad hoc calculations because it keeps the counts
consistent across the page.

#### Attendance history grouping

Records are grouped by date and deduplicated per student per date, with the most
recent record winning.

That is the correct choice because attendance should reflect the final state for
that day, not every intermediate duplicate scan.

#### Percentage logic

The student percentage is calculated as present divided by total classes.

That is a sensible attendance metric because it answers the real question: how
often was this student marked present across all recorded sessions?

#### UI contrast

The cards are intentionally dark with light text.

That works because the app theme is dark and camera-centric, and high contrast
improves readability.

#### Delete student behavior

Deleting a student also removes their embeddings.

That is good data hygiene because orphan embeddings would otherwise pollute the
matching pool.

### [lib/screens/export_screen.dart](lib/screens/export_screen.dart)

This screen handles export and file management.

#### Why export is a separate screen

Keeping export in its own screen is good because reporting is a distinct admin
task. It should not clutter the attendance or home flow.

#### Export directory

The screen uses a shared export directory helper.

That is good because all exported files end up in the same predictable place.

#### Saved files list

The screen scans the export directory and displays saved CSV and JSON files.

That is practical because users can see what already exists before generating or
sharing anything new.

#### Share and delete

Sharing and deleting exported files from the app is convenient and reduces the
need to use a file manager.

#### Why fixed attendance filenames are useful

The general attendance export uses a stable file name.

That is good for administrators because the latest register is easy to find and
does not create a clutter of near-duplicate filenames.

### [lib/screens/settings_screen.dart](lib/screens/settings_screen.dart)

This is the control room of the app.

#### Why settings exists

The app has enough operational features that it needs a place for backup,
restore, toggles, and system info.

#### Settings data summary

The screen counts students, embeddings, attendance, subjects, sessions, and
approximate data size.

That is good because it tells the user how much the local database contains.

#### TTS toggle

Speech feedback can be enabled or disabled.

That is a good usability choice because some users want spoken feedback and
others want silent operation.

#### Backup and restore

The app can export the SharedPreferences data into a JSON backup and restore it
later.

That is essential in an offline-first app because there is no backend copy of
the data.

#### Why file picker is used

Restoring from a file picker is the right approach because the user should be
able to choose a specific backup file from storage.

## 7. Runtime Flow

The app’s full behavior can be reconstructed as a pipeline:

1. `main.dart` starts the app and initializes storage.
2. `HomeScreen` loads summary stats and offers navigation.
3. `EnrollmentScreen` captures students and saves embeddings.
4. `AttendancePrepScreen` selects teacher and subject context.
5. `AttendanceScreen` scans live faces and marks attendance.
6. `DatabaseScreen` summarizes attendance history and enrolled students.
7. `ExportScreen` writes CSV/JSON files and shares them.
8. `SettingsScreen` backs up, restores, and configures the app.

That flow is good because it matches a real operational workflow instead of a
toy demo.

## 8. Why This Architecture Works

### Offline-first design

The app does not need a server to function. That is a major strength.

Benefits:

- less latency,
- fewer failure points,
- better privacy,
- easier field deployment,
- usable in poor connectivity environments.

### Separation of concerns

The code is split into bootstrap, storage, ML, and screen layers.

That is good because each layer changes for a different reason.

### Local embeddings instead of cloud identity

Face embeddings stored locally are compact and efficient.

That is a good fit because the app’s audience is likely using a single device or
a small local workflow, not a large centralized identity system.

### KNN-style matching instead of a trainable classifier

This is a practical decision.

Why it is good:

- enrollment is immediate,
- no training pipeline is needed,
- new students can be added incrementally,
- the logic is easy to explain and debug.

### Manual confidence rules

The app does not trust one score alone. It uses thresholds, voting, and
verification.

That is exactly what a robust recognition app should do.

### Dark premium UI

The visual design is not accidental.

It gives the app a serious tool-like look and makes the camera workflow feel
intentional rather than generic.

## 9. If You Were Rebuilding This App

If someone were rebuilding the app from scratch, the order should be:

1. Build the storage layer and models.
2. Build the face detection module.
3. Build the embedding module.
4. Build the matching logic.
5. Build the enrollment screen.
6. Build the attendance-prep screen.
7. Build the attendance scanner.
8. Build the dashboard.
9. Build export and settings.
10. Polish the theme and visuals.

That is the safest order because each layer depends on the one below it.

## 10. Repository Notes

The project has also been cleaned to remove obvious stale placeholders and old
backup files that were not part of the active route flow.

The current active app entry point is [lib/main.dart](lib/main.dart).

The current primary user entry flow is:

- [lib/screens/home_screen.dart](lib/screens/home_screen.dart)
- [lib/screens/attendance_prep_screen.dart](lib/screens/attendance_prep_screen.dart)
- [lib/screens/attendance_screen.dart](lib/screens/attendance_screen.dart)

## 11. Short Summary

This app is an offline face recognition attendance system built around:

- camera streaming,
- face detection,
- 128D embeddings,
- Euclidean nearest-neighbor matching,
- local attendance persistence,
- dashboard analytics,
- export and backup support,
- optional emotion logging.

The codebase is reasonably modular, the visual system is coherent, and the
offline architecture is a strong fit for attendance use cases.