import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart'
  as mesh;
import 'package:image/image.dart' as img;

/// M1: Face Detection Module using MediaPipe
/// Detects faces in images with high accuracy and speed
///
/// Singleton – heavyweight ML Kit resources are allocated once and reused
/// across screen lifecycles to prevent native memory exhaustion during
/// rapid enroll→home→enroll cycles.
class FaceDetectionModule {
  static const String modelName = 'MediaPipe Face Detection';
  static const double minDetectionConfidence = 0.5;

  // ── Singleton ──
  static final FaceDetectionModule _instance = FaceDetectionModule._internal();
  factory FaceDetectionModule() => _instance;
  FaceDetectionModule._internal();

  FaceDetector? _faceDetector;
  mesh.FaceMeshDetector? _faceMeshDetector;
  bool _isInitialized = false;
  bool _meshEnabled = false;

  /// Initialize MediaPipe face detector (idempotent – safe to call repeatedly)
  Future<void> initialize({bool enableFaceMesh = false}) async {
    if (_isInitialized && _faceDetector != null) {
      if (enableFaceMesh && !_meshEnabled) {
        _faceMeshDetector = mesh.FaceMeshDetector(
          option: mesh.FaceMeshDetectorOptions.faceMesh,
        );
        _meshEnabled = true;
      }
      return;
    }

    // ignore: deprecated_member_use
    _faceDetector = GoogleMlKit.vision.faceDetector(
      FaceDetectorOptions(
        enableContours: true,
        enableClassification: true,
        enableLandmarks: true,
        enableTracking: false,
        minFaceSize: 0.1,
        performanceMode: FaceDetectorMode.fast,
      ),
    );

    if (enableFaceMesh) {
      _faceMeshDetector = mesh.FaceMeshDetector(
        option: mesh.FaceMeshDetectorOptions.faceMesh,
      );
      _meshEnabled = true;
    } else {
      _meshEnabled = false;
    }

    _isInitialized = true;
  }

  /// Detect faces in image
  Future<List<DetectedFace>> detectFaces(Uint8List imageBytes) async {
    final tempPath = await _writeBytesToTempFile(imageBytes);
    try {
      return await detectFacesFromPath(tempPath);
    } finally {
      try {
        await File(tempPath).delete();
      } catch (_) {}
    }
  }

  /// Detect faces using a file path backed input image
  Future<List<DetectedFace>> detectFacesFromPath(String path) async {
    if (_faceDetector == null) await initialize();

    final inputImage = InputImage.fromFilePath(path);
    final faces = await _faceDetector!.processImage(inputImage);

    List<mesh.FaceMesh> meshes = const [];
    if (_meshEnabled && _faceMeshDetector != null) {
      meshes = await _faceMeshDetector!.processImage(inputImage);
    }

    return faces.map((face) {
      final matchedMesh = _matchMesh(face.boundingBox, meshes);
      return DetectedFace.fromMlKitFace(face, faceMesh: matchedMesh);
    }).toList();
  }

  mesh.FaceMesh? _matchMesh(Rect faceBounds, List<mesh.FaceMesh> meshes) {
    if (meshes.isEmpty) return null;
    mesh.FaceMesh? best;
    double bestScore = 0.0;
    for (final current in meshes) {
      final iou = _intersectionOverUnion(faceBounds, current.boundingBox);
      if (iou > bestScore) {
        bestScore = iou;
        best = current;
      }
    }
    return bestScore > 0.05 ? best : null;
  }

  double _intersectionOverUnion(Rect a, Rect b) {
    final left = a.left > b.left ? a.left : b.left;
    final top = a.top > b.top ? a.top : b.top;
    final right = a.right < b.right ? a.right : b.right;
    final bottom = a.bottom < b.bottom ? a.bottom : b.bottom;

    final intersectionW = (right - left).clamp(0.0, double.infinity);
    final intersectionH = (bottom - top).clamp(0.0, double.infinity);
    final intersectionArea = intersectionW * intersectionH;

    final unionArea = a.width * a.height + b.width * b.height - intersectionArea;
    if (unionArea <= 0.0) return 0.0;
    return intersectionArea / unionArea;
  }

  Future<String> _writeBytesToTempFile(Uint8List bytes) async {
    final tempDir = Directory.systemTemp;
    final file = File(
      '${tempDir.path}/face_detection_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Extract face ROI from image
  Uint8List extractFaceROI(Uint8List imageBytes, DetectedFace face) {
    final image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('Failed to decode image');

    final rect = face.boundingBox;
    final x = rect.left.toInt().clamp(0, image.width);
    final y = rect.top.toInt().clamp(0, image.height);
    final width = rect.width.toInt().clamp(0, image.width - x);
    final height = rect.height.toInt().clamp(0, image.height - y);

    if (width <= 0 || height <= 0) {
      throw Exception('Invalid face bounding box');
    }

    final cropped = img.copyCrop(
      image,
      x: x,
      y: y,
      width: width,
      height: height,
    );
    return Uint8List.fromList(img.encodeJpg(cropped));
  }

  /// Check if face is suitable for embedding (good quality, proper angle, etc.)
  bool isFaceSuitableForEmbedding(DetectedFace face) {
    // Check face size (should be large enough)
    final rect = face.boundingBox;
    final faceArea = rect.width * rect.height;
    if (faceArea < 10000) return false; // Too small

    // Check face angle (should be mostly frontal)
    if (face.headEulerAngleY != null && face.headEulerAngleY!.abs() > 30) {
      return false;
    }
    if (face.headEulerAngleZ != null && face.headEulerAngleZ!.abs() > 15) {
      return false;
    }

    return true;
  }

  /// Dispose resources.
  /// NOTE: As a singleton the detector is normally kept alive for the entire
  /// app session. Call this only on true app shutdown if needed.
  void dispose() {
    _faceDetector?.close();
    _faceMeshDetector?.close();
    _faceDetector = null;
    _faceMeshDetector = null;
    _isInitialized = false;
    _meshEnabled = false;
  }
}

/// Detected face model
class DetectedFace {
  final Rect boundingBox;
  final double? headEulerAngleY; // Left-right rotation
  final double? headEulerAngleZ; // Up-down rotation
  final double? smilingProbability;
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;
  final List<Offset> landmarks;
  final Map<String, List<Offset>> featureContours;
  final List<Offset> meshPoints;
  final List<List<int>> meshTriangles;

  DetectedFace({
    required this.boundingBox,
    this.headEulerAngleY,
    this.headEulerAngleZ,
    this.smilingProbability,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
    required this.landmarks,
    this.featureContours = const {},
    this.meshPoints = const [],
    this.meshTriangles = const [],
  });

  /// Determine facial expression from classification probabilities
  String get expression {
    final smile = smilingProbability ?? 0.0;
    final leftEye = leftEyeOpenProbability ?? 0.5;
    final rightEye = rightEyeOpenProbability ?? 0.5;
    final eyesOpen = (leftEye + rightEye) / 2;

    // Both eyes closed
    if (eyesOpen < 0.3) return 'Eyes Closed';
    // Winking (one eye open, one closed)
    if ((leftEye < 0.3 && rightEye > 0.6) || (rightEye < 0.3 && leftEye > 0.6)) return 'Winking';
    // High smile
    if (smile > 0.8) return 'Happy';
    // Moderate smile
    if (smile > 0.5) return 'Smiling';
    // Low smile with squinted eyes
    if (smile < 0.2 && eyesOpen < 0.5) return 'Sad';
    // Very low smile
    if (smile < 0.15) return 'Serious';
    // Default
    return 'Neutral';
  }

  factory DetectedFace.fromMlKitFace(
    Face face, {
    mesh.FaceMesh? faceMesh,
  }) {
    return DetectedFace(
      boundingBox: face.boundingBox,
      headEulerAngleY: face.headEulerAngleY,
      headEulerAngleZ: face.headEulerAngleZ,
      smilingProbability: face.smilingProbability,
      leftEyeOpenProbability: face.leftEyeOpenProbability,
      rightEyeOpenProbability: face.rightEyeOpenProbability,
      landmarks: [],
      featureContours: _extractFeatureContours(face, faceMesh: faceMesh),
      meshPoints: _extractMeshPoints(faceMesh),
      meshTriangles: _extractMeshTriangles(faceMesh),
    );
  }

  static Map<String, List<Offset>> _extractFeatureContours(
    Face face, {
    mesh.FaceMesh? faceMesh,
  }) {
    List<Offset> readContour(FaceContourType type) {
      final contour = face.contours[type];
      if (contour == null || contour.points.isEmpty) {
        return const <Offset>[];
      }
      return contour.points
          .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
          .toList(growable: false);
    }

    List<Offset> readMeshContour(mesh.FaceMeshContourType type) {
      if (faceMesh == null) return const <Offset>[];
      final contour = faceMesh.contours[type];
      if (contour == null || contour.isEmpty) return const <Offset>[];
      return contour
          .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
          .toList(growable: false);
    }

    final leftEye = readMeshContour(mesh.FaceMeshContourType.leftEye).isNotEmpty
        ? readMeshContour(mesh.FaceMeshContourType.leftEye)
        : readContour(FaceContourType.leftEye);
    final rightEye = readMeshContour(mesh.FaceMeshContourType.rightEye).isNotEmpty
        ? readMeshContour(mesh.FaceMeshContourType.rightEye)
        : readContour(FaceContourType.rightEye);

    final meshUpperLip = [
      ...readMeshContour(mesh.FaceMeshContourType.upperLipTop),
      ...readMeshContour(mesh.FaceMeshContourType.upperLipBottom),
    ];
    final meshLowerLip = [
      ...readMeshContour(mesh.FaceMeshContourType.lowerLipTop),
      ...readMeshContour(mesh.FaceMeshContourType.lowerLipBottom),
    ];

    final upperLip = [
      ...(meshUpperLip.isNotEmpty ? meshUpperLip : <Offset>[]),
      if (meshUpperLip.isEmpty) ...readContour(FaceContourType.upperLipTop),
      if (meshUpperLip.isEmpty) ...readContour(FaceContourType.upperLipBottom),
    ];
    final lowerLip = [
      ...(meshLowerLip.isNotEmpty ? meshLowerLip : <Offset>[]),
      if (meshLowerLip.isEmpty) ...readContour(FaceContourType.lowerLipTop),
      if (meshLowerLip.isEmpty) ...readContour(FaceContourType.lowerLipBottom),
    ];
    final leftCheek = readContour(FaceContourType.leftCheek);
    final rightCheek = readContour(FaceContourType.rightCheek);
    final faceOval = readMeshContour(mesh.FaceMeshContourType.faceOval);
    final noseBridge = readMeshContour(mesh.FaceMeshContourType.noseBridge);

    final result = <String, List<Offset>>{};
    if (leftEye.isNotEmpty) result['leftEye'] = leftEye;
    if (rightEye.isNotEmpty) result['rightEye'] = rightEye;
    if (upperLip.isNotEmpty) result['upperLip'] = upperLip;
    if (lowerLip.isNotEmpty) result['lowerLip'] = lowerLip;
    if (leftCheek.isNotEmpty) result['leftCheek'] = leftCheek;
    if (rightCheek.isNotEmpty) result['rightCheek'] = rightCheek;
    if (faceOval.isNotEmpty) result['faceOval'] = faceOval;
    if (noseBridge.isNotEmpty) result['noseBridge'] = noseBridge;
    return result;
  }

  static List<Offset> _extractMeshPoints(mesh.FaceMesh? faceMesh) {
    if (faceMesh == null || faceMesh.points.isEmpty) return const <Offset>[];
    return faceMesh.points
        .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
        .toList(growable: false);
  }

  static List<List<int>> _extractMeshTriangles(mesh.FaceMesh? faceMesh) {
    if (faceMesh == null || faceMesh.triangles.isEmpty) {
      return const <List<int>>[];
    }

    return faceMesh.triangles
        .where((triangle) => triangle.points.length == 3)
        .map((triangle) => <int>[
              triangle.points[0].index,
              triangle.points[1].index,
              triangle.points[2].index,
            ])
        .toList(growable: false);
  }
}
