# Face Recognition Attendance System

This repository now includes a detailed codebook instead of only a normal README.
If you want the deep explanation first, open [FACE_RECOGNITION_CODEBOOK.md](FACE_RECOGNITION_CODEBOOK.md).

This app is a fully offline Flutter face-recognition attendance system.
It enrolls students, stores embeddings locally, scans live camera frames,
marks attendance, logs emotion context, and exports records without a backend.

## Start Here

1. Read [FACE_RECOGNITION_CODEBOOK.md](FACE_RECOGNITION_CODEBOOK.md) for the full architectural walk-through.
2. Open [lib/main.dart](lib/main.dart) to see the active entry point and route table.
3. Use [lib/screens/home_screen.dart](lib/screens/home_screen.dart) as the navigation map for the app.

## What The Codebook Covers

The codebook explains:

1. Every active screen and what each widget block is doing.
2. The recognition pipeline from camera frame to embedding to match.
3. The storage model and why SharedPreferences is used here.
4. Why the app uses KNN-style nearest-neighbor matching.
5. The dashboard logic, export flow, settings flow, and emotion pipeline.

## Active Entry Points

- [lib/main.dart](lib/main.dart)
- [lib/screens/home_screen.dart](lib/screens/home_screen.dart)
- [lib/screens/attendance_prep_screen.dart](lib/screens/attendance_prep_screen.dart)
- [lib/screens/attendance_screen.dart](lib/screens/attendance_screen.dart)

## Note

The earlier long README has been replaced by the codebook so the project can
serve as a teaching document as well as an app repository.