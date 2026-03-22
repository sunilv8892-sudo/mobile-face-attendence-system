# Emotion AI Pipeline

This project uses an offline emotion pipeline for the **Emotion AI** screen.

It does **not** depend on cloud APIs and it does **not** require manual training to work.

## What It Detects

The pipeline targets the 6 standard emotion labels already used in the app:

- Angry
- Disgust
- Happy
- Neutral
- Sad
- Surprise

The decision logic is built around face cues, not UI logic.

## Best Current Approach

The current implementation uses:

1. On-device face detection and face mesh landmarks
2. Smile and eye-open probabilities from the detector
3. Mouth, eye, and face geometry cues
4. Short temporal smoothing so one bad frame does not flip the label
5. Automatic low-light frame boost before detection

This is the best fit for a mobile offline emotion screen when you want:

- no training step
- no cloud dependency
- fast results
- cue-based labels that match the expressions you actually care about

## How It Works

### 1. Frame Capture

The camera captures a frame from the Emotion AI screen.

### 2. Low-Light Boost

If the frame is dim, the pipeline applies a light correction pass before face detection.

This helps the detector keep working in darker scenes by lifting contrast and brightness slightly.

### 3. Face Detection

The app runs local face detection and face mesh extraction on the device.

The detector provides:

- face bounding boxes
- smile probability
- left and right eye-open probability
- lip and eye contours
- face mesh points

### 4. Emotion Cue Extraction

The emotion model does not guess from a generic classifier.

It uses simple expression cues:

- Smile and cheek shape -> Happy
- Open mouth and open eyes -> Surprise
- Tight or squinted face -> Disgust
- Relaxed face and closed mouth -> Neutral

### 5. Temporal Stabilization

The screen keeps a short rolling history of recent predictions.

That prevents flicker and stops one unstable frame from becoming the visible result.

## Low-Light Behavior

Low light is handled with an automatic pre-detection boost.

That means the current pipeline is already better than the raw camera feed in dim scenes.

Still, the usual rules apply:

- moderate lighting is best
- extreme darkness will always reduce face landmark quality
- strong backlight can still hurt accuracy

## What Was Removed

The old emotion stack was removed from the active Emotion AI path.

That included the heavy classifier-based approach and placeholder emotion states that caused noisy output.

The current screen now focuses on direct facial cues and stable display behavior.

## Files Involved

- [lib/screens/expression_detection_screen.dart](lib/screens/expression_detection_screen.dart)
- [lib/modules/expression_cue_model.dart](lib/modules/expression_cue_model.dart)
- [lib/modules/expression_cue_calibration.dart](lib/modules/expression_cue_calibration.dart)
- [lib/models/face_detection_model.dart](lib/models/face_detection_model.dart)

## Usage

Open the **Emotion AI** tool from the app and start scanning.

The pipeline will:

- detect the face
- boost low-light frames when needed
- read smile, mouth, and eye cues
- stabilize the result over a few frames
- show the best emotion label instead of a placeholder

## Notes

- No manual training is required for the current pipeline.
- The system is fully offline.
- If you want even better accuracy later, the next upgrade would be a dedicated on-device landmark-based temporal model.
