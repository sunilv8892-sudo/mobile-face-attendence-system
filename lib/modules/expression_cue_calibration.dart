import 'dart:convert';

import 'package:flutter/services.dart';

class ExpressionCueCalibration {
  static const String assetPath = 'assets/models/expression_cue_calibration.json';

  final double happySmileThreshold;
  final double happyMouthOpenMax;
  final double surpriseMouthOpenMin;
  final double surpriseEyeOpenMin;
  final double disgustEyeOpenMax;
  final double disgustMouthOpenMax;
  final double neutralSmileMax;
  final double neutralMouthOpenMax;
  final double neutralEyeOpenMin;
  final double softmaxTemperature;

  final double happySmileWeight;
  final double happyMouthWeight;
  final double surpriseMouthWeight;
  final double surpriseEyeWeight;
  final double surpriseSmilePenalty;
  final double disgustEyeWeight;
  final double disgustMouthWeight;
  final double disgustSmilePenalty;
  final double neutralSmilePenalty;
  final double neutralMouthPenalty;
  final double neutralEyeReward;
  final double sadSmilePenalty;
  final double sadEyePenalty;
  final double sadMouthPenalty;
  final double angrySmilePenalty;
  final double angryEyePenalty;
  final double angryMouthPenalty;

  const ExpressionCueCalibration({
    required this.happySmileThreshold,
    required this.happyMouthOpenMax,
    required this.surpriseMouthOpenMin,
    required this.surpriseEyeOpenMin,
    required this.disgustEyeOpenMax,
    required this.disgustMouthOpenMax,
    required this.neutralSmileMax,
    required this.neutralMouthOpenMax,
    required this.neutralEyeOpenMin,
    required this.softmaxTemperature,
    required this.happySmileWeight,
    required this.happyMouthWeight,
    required this.surpriseMouthWeight,
    required this.surpriseEyeWeight,
    required this.surpriseSmilePenalty,
    required this.disgustEyeWeight,
    required this.disgustMouthWeight,
    required this.disgustSmilePenalty,
    required this.neutralSmilePenalty,
    required this.neutralMouthPenalty,
    required this.neutralEyeReward,
    required this.sadSmilePenalty,
    required this.sadEyePenalty,
    required this.sadMouthPenalty,
    required this.angrySmilePenalty,
    required this.angryEyePenalty,
    required this.angryMouthPenalty,
  });

  factory ExpressionCueCalibration.defaults() {
    return const ExpressionCueCalibration(
      happySmileThreshold: 0.58,
      happyMouthOpenMax: 0.11,
      surpriseMouthOpenMin: 0.09,
      surpriseEyeOpenMin: 0.40,
      disgustEyeOpenMax: 0.32,
      disgustMouthOpenMax: 0.08,
      neutralSmileMax: 0.42,
      neutralMouthOpenMax: 0.05,
      neutralEyeOpenMin: 0.35,
      softmaxTemperature: 0.75,
      happySmileWeight: 0.72,
      happyMouthWeight: 0.28,
      surpriseMouthWeight: 0.74,
      surpriseEyeWeight: 0.16,
      surpriseSmilePenalty: 0.10,
      disgustEyeWeight: 0.46,
      disgustMouthWeight: 0.34,
      disgustSmilePenalty: 0.20,
      neutralSmilePenalty: 0.38,
      neutralMouthPenalty: 0.34,
      neutralEyeReward: 0.28,
      sadSmilePenalty: 0.44,
      sadEyePenalty: 0.30,
      sadMouthPenalty: 0.26,
      angrySmilePenalty: 0.28,
      angryEyePenalty: 0.18,
      angryMouthPenalty: 0.16,
    );
  }

  static Future<ExpressionCueCalibration> load() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return ExpressionCueCalibration.fromJson(data);
    } catch (_) {
      return ExpressionCueCalibration.defaults();
    }
  }

  factory ExpressionCueCalibration.fromJson(Map<String, dynamic> json) {
    final defaults = ExpressionCueCalibration.defaults();

    double read(String key, double fallback) {
      final value = json[key];
      if (value is num) return value.toDouble();
      return fallback;
    }

    return ExpressionCueCalibration(
      happySmileThreshold: read('happy_smile_threshold', defaults.happySmileThreshold),
      happyMouthOpenMax: read('happy_mouth_open_max', defaults.happyMouthOpenMax),
      surpriseMouthOpenMin: read('surprise_mouth_open_min', defaults.surpriseMouthOpenMin),
      surpriseEyeOpenMin: read('surprise_eye_open_min', defaults.surpriseEyeOpenMin),
      disgustEyeOpenMax: read('disgust_eye_open_max', defaults.disgustEyeOpenMax),
      disgustMouthOpenMax: read('disgust_mouth_open_max', defaults.disgustMouthOpenMax),
      neutralSmileMax: read('neutral_smile_max', defaults.neutralSmileMax),
      neutralMouthOpenMax: read('neutral_mouth_open_max', defaults.neutralMouthOpenMax),
      neutralEyeOpenMin: read('neutral_eye_open_min', defaults.neutralEyeOpenMin),
      softmaxTemperature: read('softmax_temperature', defaults.softmaxTemperature),
      happySmileWeight: read('happy_smile_weight', defaults.happySmileWeight),
      happyMouthWeight: read('happy_mouth_weight', defaults.happyMouthWeight),
      surpriseMouthWeight: read('surprise_mouth_weight', defaults.surpriseMouthWeight),
      surpriseEyeWeight: read('surprise_eye_weight', defaults.surpriseEyeWeight),
      surpriseSmilePenalty: read('surprise_smile_penalty', defaults.surpriseSmilePenalty),
      disgustEyeWeight: read('disgust_eye_weight', defaults.disgustEyeWeight),
      disgustMouthWeight: read('disgust_mouth_weight', defaults.disgustMouthWeight),
      disgustSmilePenalty: read('disgust_smile_penalty', defaults.disgustSmilePenalty),
      neutralSmilePenalty: read('neutral_smile_penalty', defaults.neutralSmilePenalty),
      neutralMouthPenalty: read('neutral_mouth_penalty', defaults.neutralMouthPenalty),
      neutralEyeReward: read('neutral_eye_reward', defaults.neutralEyeReward),
      sadSmilePenalty: read('sad_smile_penalty', defaults.sadSmilePenalty),
      sadEyePenalty: read('sad_eye_penalty', defaults.sadEyePenalty),
      sadMouthPenalty: read('sad_mouth_penalty', defaults.sadMouthPenalty),
      angrySmilePenalty: read('angry_smile_penalty', defaults.angrySmilePenalty),
      angryEyePenalty: read('angry_eye_penalty', defaults.angryEyePenalty),
      angryMouthPenalty: read('angry_mouth_penalty', defaults.angryMouthPenalty),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'happy_smile_threshold': happySmileThreshold,
      'happy_mouth_open_max': happyMouthOpenMax,
      'surprise_mouth_open_min': surpriseMouthOpenMin,
      'surprise_eye_open_min': surpriseEyeOpenMin,
      'disgust_eye_open_max': disgustEyeOpenMax,
      'disgust_mouth_open_max': disgustMouthOpenMax,
      'neutral_smile_max': neutralSmileMax,
      'neutral_mouth_open_max': neutralMouthOpenMax,
      'neutral_eye_open_min': neutralEyeOpenMin,
      'softmax_temperature': softmaxTemperature,
      'happy_smile_weight': happySmileWeight,
      'happy_mouth_weight': happyMouthWeight,
      'surprise_mouth_weight': surpriseMouthWeight,
      'surprise_eye_weight': surpriseEyeWeight,
      'surprise_smile_penalty': surpriseSmilePenalty,
      'disgust_eye_weight': disgustEyeWeight,
      'disgust_mouth_weight': disgustMouthWeight,
      'disgust_smile_penalty': disgustSmilePenalty,
      'neutral_smile_penalty': neutralSmilePenalty,
      'neutral_mouth_penalty': neutralMouthPenalty,
      'neutral_eye_reward': neutralEyeReward,
      'sad_smile_penalty': sadSmilePenalty,
      'sad_eye_penalty': sadEyePenalty,
      'sad_mouth_penalty': sadMouthPenalty,
      'angry_smile_penalty': angrySmilePenalty,
      'angry_eye_penalty': angryEyePenalty,
      'angry_mouth_penalty': angryMouthPenalty,
    };
  }
}