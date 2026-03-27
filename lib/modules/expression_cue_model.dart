import 'dart:math' as math;
import 'dart:ui';

import '../models/face_detection_model.dart';
import 'expression_cue_calibration.dart';

class EmotionDetectionResult {
  final String label;
  final double confidence;
  final Map<String, double> probabilities;
  final bool isFallback;

  const EmotionDetectionResult({
    required this.label,
    required this.confidence,
    required this.probabilities,
    this.isFallback = false,
  });
}

class ExpressionCueModel {
  static const List<String> labels = [
    'Angry',
    'Disgust',
    'Happy',
    'Neutral',
    'Sad',
    'Surprise',
  ];

  final ExpressionCueCalibration calibration;

  const ExpressionCueModel({required this.calibration});

  static Future<ExpressionCueModel> load() async {
    final calibration = await ExpressionCueCalibration.load();
    return ExpressionCueModel(calibration: calibration);
  }

  EmotionDetectionResult predict(DetectedFace face) {
    final smile = _clamp01(face.smilingProbability ?? 0.0);
    final leftEye = _clamp01(face.leftEyeOpenProbability ?? 0.5);
    final rightEye = _clamp01(face.rightEyeOpenProbability ?? 0.5);
    final eyeOpen = ((leftEye + rightEye) / 2.0).clamp(0.0, 1.0).toDouble();

    final faceWidth = math.max(face.width, 1.0);
    final faceHeight = math.max(face.height, 1.0);
    final contours = face.featureContours;
    final mouthOpen = _mouthOpenRatio(contours['upperLip'], contours['lowerLip'], faceHeight);
    final mouthWidth = _mouthWidthRatio(contours['upperLip'], contours['lowerLip'], faceWidth);
    final mouthAspect = mouthWidth > 0.0 ? (mouthOpen / mouthWidth) : mouthOpen;
    final eyeBalance = _eyeBalance(leftEye, rightEye);

    final smileCue = _clamp01((smile * calibration.happySmileWeight) + (mouthWidth * calibration.happyMouthWeight));
    final surpriseCue = _clamp01((mouthOpen * calibration.surpriseMouthWeight) + (eyeOpen * calibration.surpriseEyeWeight) + ((1.0 - smile) * calibration.surpriseSmilePenalty));
    final disgustCue = _clamp01(((1.0 - eyeOpen) * calibration.disgustEyeWeight) + ((1.0 - mouthOpen) * calibration.disgustMouthWeight) + ((1.0 - smile) * calibration.disgustSmilePenalty));
    final neutralCue = _clamp01(((1.0 - smile) * calibration.neutralSmilePenalty) + ((1.0 - mouthOpen) * calibration.neutralMouthPenalty) + ((_centerPenalty(eyeOpen, 0.55) * calibration.neutralEyeReward)));
    final sadCue = _clamp01(((1.0 - smile) * calibration.sadSmilePenalty) + ((1.0 - eyeOpen) * calibration.sadEyePenalty) + ((1.0 - mouthOpen) * calibration.sadMouthPenalty));
    final angryCue = _clamp01(((1.0 - smile) * calibration.angrySmilePenalty) + ((1.0 - eyeOpen) * calibration.angryEyePenalty) + ((1.0 - mouthOpen) * calibration.angryMouthPenalty));
    final fearCue = _clamp01((mouthOpen * 0.50) + (eyeOpen * 0.34) + ((1.0 - smile) * 0.16) + eyeBalance * 0.05);

    final scores = <String, double>{
      'Angry': angryCue,
      'Disgust': disgustCue,
      'Happy': smileCue,
      'Neutral': neutralCue,
      'Sad': sadCue,
      'Surprise': surpriseCue,
    };

    // Strong, simple rules for the four important expressions.
    if (smile >= calibration.happySmileThreshold && mouthOpen <= calibration.happyMouthOpenMax) {
      scores['Happy'] = math.max(scores['Happy']!, 0.94);
      scores['Surprise'] = scores['Surprise']! * 0.35;
    } else if (mouthOpen >= calibration.surpriseMouthOpenMin && eyeOpen >= calibration.surpriseEyeOpenMin && smile < calibration.happySmileThreshold) {
      scores['Surprise'] = math.max(scores['Surprise']!, 0.94);
      scores['Happy'] = scores['Happy']! * 0.55;
    } else if (eyeOpen <= calibration.disgustEyeOpenMax && mouthOpen <= calibration.disgustMouthOpenMax && smile < 0.45) {
      scores['Disgust'] = math.max(scores['Disgust']!, 0.88);
      scores['Neutral'] = scores['Neutral']! * 0.70;
    } else if (mouthOpen <= calibration.neutralMouthOpenMax && smile < calibration.neutralSmileMax && eyeOpen >= calibration.neutralEyeOpenMin) {
      scores['Neutral'] = math.max(scores['Neutral']!, 0.88);
      scores['Surprise'] = scores['Surprise']! * 0.35;
    }

    // Use the face detector's own heuristic label as a weak hint only.
    switch (face.expression) {
      case 'Happy':
      case 'Smiling':
        scores['Happy'] = scores['Happy']! + 0.08;
        break;
      case 'Neutral':
      case 'Serious':
        scores['Neutral'] = scores['Neutral']! + 0.05;
        break;
      case 'Winking':
      case 'Eyes Closed':
        scores['Disgust'] = scores['Disgust']! + 0.04;
        break;
    }

    if (mouthAspect > 0.18 && mouthOpen > calibration.surpriseMouthOpenMin) {
      scores['Surprise'] = scores['Surprise']! + 0.05;
    }

    if (mouthOpen > calibration.happyMouthOpenMax && smile > calibration.happySmileThreshold) {
      scores['Happy'] = scores['Happy']! + 0.03;
      scores['Surprise'] = scores['Surprise']! * 0.88;
    }

    if (mouthOpen < 0.04 && smile < 0.35 && eyeOpen > 0.40) {
      scores['Neutral'] = scores['Neutral']! + 0.08;
    }

    // Angry should be conservative: wide-open eyes should not force Angry.
    if (eyeOpen >= 0.80) {
      scores['Angry'] = scores['Angry']! * 0.45;
      scores['Neutral'] = scores['Neutral']! + 0.08;
      scores['Surprise'] = scores['Surprise']! + 0.05;
    }

    if (smile <= 0.22 && mouthOpen <= 0.08 && eyeOpen >= 0.32 && eyeOpen <= 0.72 && eyeBalance >= 0.72) {
      scores['Angry'] = math.max(scores['Angry']!, 0.82);
      scores['Neutral'] = scores['Neutral']! * 0.84;
      scores['Surprise'] = scores['Surprise']! * 0.80;
    }

    final normalized = _softmax(scores, temperature: calibration.softmaxTemperature);
    var best = normalized.entries.reduce((a, b) => a.value >= b.value ? a : b);

    final neutral = normalized['Neutral'] ?? 0.0;
    if (best.key != 'Neutral' && neutral >= (best.value - 0.03) && neutral >= 0.28) {
      best = MapEntry('Neutral', neutral);
    }

    if (best.key == 'Surprise' && mouthOpen < calibration.surpriseMouthOpenMin * 0.85 && smile > 0.48) {
      final happy = normalized['Happy'] ?? 0.0;
      if (happy >= best.value - 0.05) {
        best = MapEntry('Happy', happy);
      }
    }

    final confidence = best.value.clamp(0.0, 1.0).toDouble();

    return EmotionDetectionResult(
      label: best.key,
      confidence: confidence,
      probabilities: normalized,
    );
  }

  double _mouthOpenRatio(
    List<Offset>? upperLip,
    List<Offset>? lowerLip,
    double faceHeight,
  ) {
    if (upperLip == null || lowerLip == null || upperLip.isEmpty || lowerLip.isEmpty) {
      return 0.0;
    }

    final upperY = upperLip.map((point) => point.dy).reduce((a, b) => a + b) / upperLip.length;
    final lowerY = lowerLip.map((point) => point.dy).reduce((a, b) => a + b) / lowerLip.length;
    return ((lowerY - upperY).abs() / faceHeight).clamp(0.0, 1.0).toDouble();
  }

  double _mouthWidthRatio(
    List<Offset>? upperLip,
    List<Offset>? lowerLip,
    double faceWidth,
  ) {
    final points = <Offset>[
      ...?upperLip,
      ...?lowerLip,
    ];
    if (points.isEmpty) return 0.0;
    final minX = points.map((point) => point.dx).reduce(math.min);
    final maxX = points.map((point) => point.dx).reduce(math.max);
    return ((maxX - minX).abs() / faceWidth).clamp(0.0, 1.0).toDouble();
  }

  double _centerPenalty(double value, double center) {
    final distance = (value - center).abs();
    return (1.0 - (distance * 2.2)).clamp(0.0, 1.0).toDouble();
  }

  double _eyeBalance(double leftEye, double rightEye) {
    final diff = (leftEye - rightEye).abs();
    return (1.0 - (diff * 1.8)).clamp(0.0, 1.0).toDouble();
  }

  Map<String, double> _softmax(Map<String, double> scores, {required double temperature}) {
    final maxScore = scores.values.reduce(math.max);
    final exponentials = <String, double>{};
    double total = 0.0;

    for (final entry in scores.entries) {
      final scaled = entry.value / temperature;
      final value = math.exp(scaled - (maxScore / temperature));
      exponentials[entry.key] = value;
      total += value;
    }

    if (total <= 0.0) {
      return {for (final label in labels) label: 1.0 / labels.length};
    }

    return exponentials.map((key, value) => MapEntry(key, value / total));
  }

  double _clamp01(double value) => value.clamp(0.0, 1.0).toDouble();
}
