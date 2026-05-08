// ─────────────────────────────────────────────────────────────────────────────
// ConcentrationService (ML Kit + ONNX 통합)
//
// 카메라 프레임 → google_mlkit_face_detection 으로 face contour + head pose +
// eyeOpenProbability 추출 → 학습 코드와 같은 형태의 10차원 프레임 벡터 →
// 30초 윈도우 → 62차원 통계 → 학습한 ONNX 모델(xgb_model.onnx)로 추론 →
// 집중(1) / 비집중(0) + probability 출력 → 점수 알고리즘 (50/30/20)
//
// face_detection_tflite 와의 차이:
//   - MediaPipe mesh 468점 대신 ML Kit contour ~133점 사용
//   - EAR 은 contour bbox 기반 ×1.4 보정 (sub_develop 검증 hack)
//   - head pose 는 face.headEulerAngleX/Y/Z 직접 받음
//   - iris 없어서 gaze 는 0 강제 (학습 정상 분포 평균값)
//   - MAR 은 contour 기반 (학습 분포 mismatch 가능 → 0.10 강제 ML 입력)
//   - 사용자별 EAR/MAR baseline calibration 그대로 동작
//   - 하품 감지 룰 (baseline ×1.5) 그대로
//   - 점수 알고리즘 (ML 50% + presence 30% + stare 20%) 그대로
//   - ONNX 모델은 그대로 (xgb_model.onnx)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:onnxruntime/onnxruntime.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 학습 데이터 정상값 (face landmark 도구 분포 mismatch 보정용)
// ─────────────────────────────────────────────────────────────────────────────
const double _kNormalMarValue = 0.10;   // 학습 분포 mean ~ 0.10
const double _kNormalGazeValue = 0.0;   // 학습 분포 mean ~ 0

// ─────────────────────────────────────────────────────────────────────────────
// step2_prepare_dataset.py 와 동일한 임계값
// ─────────────────────────────────────────────────────────────────────────────
const double _kEarBlinkThreshold = 0.21;
const int _kEarLongCloseFrames = 10;
const double _kMarYawnThreshold = 0.65;
const double _kGazeOffThreshold = 0.35;

// ─────────────────────────────────────────────────────────────────────────────
// 안정화 / 버퍼 파라미터
// ─────────────────────────────────────────────────────────────────────────────
const int _kBufferMaxFrames = 150;
const int _kMlMinSamples = 45;
const int _kMlConfirmCount = 5;

// ─────────────────────────────────────────────────────────────────────────────
// 집중도 점수 알고리즘 (7주차 발표 자료 기준)
// ─────────────────────────────────────────────────────────────────────────────
const double _kWeightMl = 0.50;
const double _kWeightPresence = 0.30;
const double _kWeightStare = 0.20;
const int _kNormalBlinksPerWindow = 6;

// ── 룰 기반 비집중 감지 ─────────────────────────────────────────────────
const double _kYawnRatio = 1.5;
const int _kYawnMinFrames = 4;
const double _kYawnPenalty = 15.0;

// 오랜 눈 감김 (졸음) 감지 — 2초 이상 눈 감김이면 졸음
// 정상 깜빡임은 0.1~0.3초 → 2초는 확실한 졸음 신호
const int _kLongEyeClosureMinFrames = 20; // 2초 @ 10fps
const double _kLongEyeClosurePenalty = 25.0;

// ML Kit eyeOpenProbability 기반 감김 임계 (0.4 미만 = 감김)
// EAR 보다 카메라 각도/노이즈에 robust
const double _kEyeOpenThreshold = 0.4;

// ── EAR 계산 보정 (sub_develop 검증된 hack) ─────────────────────────────
// ML Kit contour 의 bbox 기반 EAR 은 표준 EAR(MediaPipe Python) 대비 약 70%
// 수준이라 ×1.4 곱해서 학습 분포 (0.25~0.35) 에 맞춤
const double _kEarScale = 1.4;

// ─────────────────────────────────────────────────────────────────────────────
// 결과 객체
// ─────────────────────────────────────────────────────────────────────────────
enum FocusStatus { measuring, focused, medium, distracted }

@immutable
class FocusResult {
  final FocusStatus status;
  final double score;
  final int rawPred;

  const FocusResult({
    required this.status,
    required this.score,
    this.rawPred = -1,
  });

  static const measuring =
      FocusResult(status: FocusStatus.measuring, score: 0);

  String get statusKr {
    switch (status) {
      case FocusStatus.focused:
        return '집중';
      case FocusStatus.medium:
        return '보통';
      case FocusStatus.distracted:
        return '비집중';
      case FocusStatus.measuring:
        return '측정 중';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ConcentrationService
// ─────────────────────────────────────────────────────────────────────────────
class ConcentrationService {
  FaceDetector? _detector;
  OrtSession? _session;
  OrtEnv? _ortEnv;

  bool _isProcessing = false;

  // 10차원 프레임 버퍼: [earL, earR, earAvg, mar, pitch, yaw, roll, gazeH, gazeV, faceDet]
  final List<List<double>> _buf = [];
  final List<bool> _mlHistory = [];
  bool _stable = true;
  bool _ready = false;
  final List<double> _scoreHistory = [];

  final ValueNotifier<FocusResult> _result =
      ValueNotifier<FocusResult>(FocusResult.measuring);
  ValueListenable<FocusResult> get result => _result;
  FocusResult get currentResult => _result.value;

  double get averageScore01 {
    if (_scoreHistory.isEmpty) return 0.65;
    final sum = _scoreHistory.reduce((a, b) => a + b);
    return (sum / _scoreHistory.length / 100.0).clamp(0.0, 1.0);
  }

  // ── 회전 탐색용 카운터 (외부에서 읽음) ───────────────────────────────────
  int _processCallCount = 0;
  int _faceFoundCount = 0;
  int _faceMissCount = 0;
  int get lastFoundCount => _faceFoundCount;

  // ── 디버그 화면용 진단 getter ─────────────────────────────────────────
  double? get earBaseline => _baselineSamples.isEmpty
      ? null
      : (_baselineSamples.reduce((a, b) => a + b) / _baselineSamples.length);
  double get earThreshold => _effectiveEarThreshold;
  double? get marBaseline => _userMarBaseline;
  double? get marThreshold =>
      _userMarBaseline == null ? null : _userMarBaseline! * _kYawnRatio;
  bool get isYawning => _detectYawn();
  bool get isLongEyeClosure => _detectLongEyeClosure();
  int get currentBlinks => _countBlinksInBuffer();
  int get bufferSize => _buf.length;
  double? get currentEar => _buf.isEmpty ? null : _buf.last[2];
  double? get currentMar =>
      _realMarBuffer.isEmpty ? null : _realMarBuffer.last;
  bool get currentFaceDetected =>
      _buf.isNotEmpty && _buf.last[9] > 0.5;
  bool get isStable => _stable;
  bool get isReadyForInference => _ready;

  // ── 마지막 face 정보 (디버그 overlay 용) ───────────────────────────────
  Face? _lastFace;
  Size? _lastImageSize;
  Face? get lastFace => _lastFace;
  Size? get lastImageSize => _lastImageSize;

  // ── 사용자별 EAR baseline ────────────────────────────────────────────
  final List<double> _baselineSamples = [];
  double? _userEarThreshold;

  void _updateEarBaseline(double earAvg) {
    if (_userEarThreshold != null) return;
    if (earAvg < 0.08) return;
    _baselineSamples.add(earAvg);
    if (_baselineSamples.length >= 60) {
      final mean = _baselineSamples.reduce((a, b) => a + b) /
          _baselineSamples.length;
      _userEarThreshold = mean * 0.92; // 깜빡임 잘 잡히게 느슨
      debugPrint('[CALIBRATION] 사용자 EAR baseline=${mean.toStringAsFixed(3)} '
          '→ 깜빡임 임계값=${_userEarThreshold!.toStringAsFixed(3)}');
    }
  }

  double get _effectiveEarThreshold =>
      _userEarThreshold ?? _kEarBlinkThreshold;

  // ── 사용자별 MAR baseline (하품 감지용) ─────────────────────────────
  final List<double> _realMarBuffer = [];
  final List<double> _marBaselineSamples = [];
  double? _userMarBaseline;

  // ── ML Kit eyeOpenProbability 버퍼 (깜빡임/졸음 감지용) ────────────
  // 카메라 각도/노이즈에 robust — EAR 계산보다 안정적
  // 얼굴 미감지 프레임은 1.0 (떠있음으로 처리, 졸음 트리거 안 됨)
  final List<double> _eyeOpenProbBuffer = [];

  void _updateMarBaseline(double mar) {
    if (_userMarBaseline != null) return;
    if (mar > 0.7) return;
    _marBaselineSamples.add(mar);
    if (_marBaselineSamples.length >= 60) {
      final mean = _marBaselineSamples.reduce((a, b) => a + b) /
          _marBaselineSamples.length;
      _userMarBaseline = mean;
      debugPrint('[CALIBRATION] 사용자 MAR baseline=${mean.toStringAsFixed(3)} '
          '→ 하품 임계값=${(mean * _kYawnRatio).toStringAsFixed(3)}');
    }
  }

  bool _detectYawn() {
    if (_userMarBaseline == null) return false;
    if (_realMarBuffer.length < _kYawnMinFrames) return false;
    final threshold = _userMarBaseline! * _kYawnRatio;
    final recent =
        _realMarBuffer.sublist(_realMarBuffer.length - _kYawnMinFrames);
    return recent.every((m) => m > threshold);
  }

  /// 오랜 눈 감김 (졸음) 감지
  /// ML Kit eyeOpenProbability 기반 — 최근 N프레임 모두 prob < 0.4 이면 졸음
  /// 얼굴 미감지 프레임은 prob 1.0 으로 처리되어 자동 false (졸음 X)
  bool _detectLongEyeClosure() {
    if (_eyeOpenProbBuffer.length < _kLongEyeClosureMinFrames) return false;
    final recent = _eyeOpenProbBuffer
        .sublist(_eyeOpenProbBuffer.length - _kLongEyeClosureMinFrames);
    return recent.every((prob) => prob < _kEyeOpenThreshold);
  }

  // ── 초기화 ──────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    // 1. ONNX 모델 로드
    try {
      OrtEnv.instance.init();
      _ortEnv = OrtEnv.instance;
      final raw = await rootBundle.load('assets/models/xgb_model.onnx');
      final bytes = raw.buffer.asUint8List();
      _session = OrtSession.fromBuffer(bytes, OrtSessionOptions());
      debugPrint('[ConcentrationService] ONNX 모델 로드 완료');
    } catch (e, st) {
      debugPrint('[ConcentrationService] ONNX 로드 실패: $e\n$st');
    }

    // 2. ML Kit Face Detector 초기화
    try {
      _detector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: true,        // contour 점 (눈/입/얼굴 윤곽)
          enableClassification: true,   // eyeOpenProbability 받기 위해
          enableTracking: false,
          performanceMode: FaceDetectorMode.fast,
        ),
      );
      debugPrint('[ConcentrationService] ML Kit FaceDetector 초기화 완료');
    } catch (e, st) {
      debugPrint('[ConcentrationService] FaceDetector 초기화 실패: $e\n$st');
      rethrow;
    }
  }

  void dispose() {
    _detector?.close();
    _session?.release();
    _ortEnv?.release();
    _buf.clear();
    _eyeOpenProbBuffer.clear();
    _mlHistory.clear();
    _scoreHistory.clear();
  }

  void reset() {
    _buf.clear();
    _eyeOpenProbBuffer.clear();
    _mlHistory.clear();
    _scoreHistory.clear();
    _stable = true;
    _ready = false;
    _result.value = FocusResult.measuring;
  }

  // ── 카메라 프레임 처리 ──────────────────────────────────────────────────
  // rotation 파라미터는 호환성 위해 받지만 ML Kit 은 InputImage metadata 로 처리
  Future<void> processFrame(
    CameraImage image, {
    int? sensorOrientation,
  }) async {
    if (_detector == null) return;
    if (_isProcessing) return;
    _isProcessing = true;
    _processCallCount++;

    try {
      final inputImage = _toInputImage(image, sensorOrientation ?? 0);
      if (inputImage == null) {
        _faceMissCount++;
        _appendFrame(_emptyFrame());
        _runInferenceIfReady();
        return;
      }

      final faces = await _detector!.processImage(inputImage);

      if (faces.isEmpty) {
        _faceMissCount++;
        _appendFrame(_emptyFrame());
        // 얼굴 미감지 시 prob 1.0 (떠있음으로 처리 — 졸음 트리거 X)
        _appendEyeOpenProb(1.0);
      } else {
        _faceFoundCount++;
        final face = faces.first;
        _lastFace = face;
        _lastImageSize = Size(image.width.toDouble(), image.height.toDouble());

        final frame = _buildFrameVector(face);
        _updateEarBaseline(frame[2]);

        // 진짜 MAR 측정 (모델 입력은 강제값, 하품 감지에 진짜값)
        final realMar = _computeRealMar(face);
        _realMarBuffer.add(realMar);
        if (_realMarBuffer.length > _kBufferMaxFrames) {
          _realMarBuffer.removeAt(0);
        }
        _updateMarBaseline(realMar);

        // ML Kit 의 eyeOpenProbability — 양 눈 평균 (없으면 fallback)
        final lProb = face.leftEyeOpenProbability;
        final rProb = face.rightEyeOpenProbability;
        final double eyeProb;
        if (lProb != null && rProb != null) {
          eyeProb = (lProb + rProb) / 2;
        } else if (lProb != null) {
          eyeProb = lProb;
        } else if (rProb != null) {
          eyeProb = rProb;
        } else {
          eyeProb = 1.0; // 측정 못 했으면 떠있음으로 가정
        }
        _appendEyeOpenProb(eyeProb);

        _appendFrame(frame);
      }

      if (_processCallCount % 10 == 0) {
        debugPrint('[ConcentrationService] '
            'calls=$_processCallCount  found=$_faceFoundCount  '
            'miss=$_faceMissCount  buf=${_buf.length}');
      }

      _runInferenceIfReady();
    } catch (e, st) {
      debugPrint('[ConcentrationService] processFrame 에러: $e\n$st');
    } finally {
      _isProcessing = false;
    }
  }

  /// CameraImage → ML Kit InputImage 변환
  InputImage? _toInputImage(CameraImage image, int sensorOrientation) {
    try {
      final rotation =
          InputImageRotationValue.fromRawValue(sensorOrientation) ??
              InputImageRotation.rotation0deg;

      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      // iOS BGRA8888 또는 yuv420 → 첫 plane bytes 사용
      // ML Kit 이 자동 처리
      return InputImage.fromBytes(
        bytes: image.planes.first.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    } catch (e) {
      debugPrint('[ConcentrationService] InputImage 변환 실패: $e');
      return null;
    }
  }

  void _appendFrame(List<double> v) {
    _buf.add(v);
    if (_buf.length > _kBufferMaxFrames) _buf.removeAt(0);
  }

  void _appendEyeOpenProb(double p) {
    _eyeOpenProbBuffer.add(p);
    if (_eyeOpenProbBuffer.length > _kBufferMaxFrames) {
      _eyeOpenProbBuffer.removeAt(0);
    }
  }

  List<double> _emptyFrame() => List<double>.filled(10, 0.0);

  // ── 한 프레임 10차원 벡터 (학습 양식) ─────────────────────────────────
  // [earL, earR, earAvg, mar, pitch, yaw, roll, gazeH, gazeV, faceDet]
  // MAR/gaze 는 강제 정상값 (학습 분포 mismatch 회피)
  // pitch/yaw/roll 은 ML Kit 직접 받음 (정확)
  List<double> _buildFrameVector(Face face) {
    // EAR (contour bbox 기반 + ×1.4 보정)
    final earLRaw = _earFromContour(face.contours[FaceContourType.leftEye]?.points);
    final earRRaw = _earFromContour(face.contours[FaceContourType.rightEye]?.points);
    final earL = earLRaw * _kEarScale;
    final earR = earRRaw * _kEarScale;
    final earAvg = (earL + earR) / 2.0;

    // head pose (ML Kit 직접)
    final pitch = (face.headEulerAngleX ?? 0).toDouble();
    final yaw = (face.headEulerAngleY ?? 0).toDouble();
    final roll = (face.headEulerAngleZ ?? 0).toDouble();

    return [
      earL, earR, earAvg,
      _kNormalMarValue,                     // MAR 강제 정상값
      pitch, yaw, roll,                     // head pose 직접
      _kNormalGazeValue, _kNormalGazeValue, // gaze 강제 0
      1.0,                                  // face_detected
    ];
  }

  // ─── EAR 계산 (sub_develop 검증된 식) ──────────────────────────────
  // contour 점들의 bbox height/width 비율 × 0.5
  double _earFromContour(List<dynamic>? pts) {
    if (pts == null || pts.length < 4) return 0.25;
    final ys = pts.map((p) => (p.y as num).toDouble()).toList();
    final xs = pts.map((p) => (p.x as num).toDouble()).toList();
    double minY = ys[0], maxY = ys[0];
    double minX = xs[0], maxX = xs[0];
    for (int i = 1; i < ys.length; i++) {
      if (ys[i] < minY) minY = ys[i];
      if (ys[i] > maxY) maxY = ys[i];
      if (xs[i] < minX) minX = xs[i];
      if (xs[i] > maxX) maxX = xs[i];
    }
    final height = maxY - minY;
    final width = maxX - minX;
    return width < 1.0 ? 0.25 : (height / width) * 0.5;
  }

  // ─── 진짜 MAR (sub_develop 식, 하품 감지 baseline 학습용) ──────────
  // upperLipTop 중간점 ↔ lowerLipBottom 중간점, 양 볼 사이 거리
  double _computeRealMar(Face face) {
    final upperTop = face.contours[FaceContourType.upperLipTop]?.points;
    final lowerBottom =
        face.contours[FaceContourType.lowerLipBottom]?.points;
    final leftCheek = face.contours[FaceContourType.leftCheek]?.points;
    final rightCheek = face.contours[FaceContourType.rightCheek]?.points;

    if (upperTop == null || lowerBottom == null ||
        upperTop.isEmpty || lowerBottom.isEmpty) {
      return 0.0;
    }

    final topMid = upperTop[upperTop.length ~/ 2];
    final bottomMid = lowerBottom[lowerBottom.length ~/ 2];
    final vertical = (topMid.y - bottomMid.y).abs().toDouble();

    double horizontal = 80.0;
    if (leftCheek != null && rightCheek != null &&
        leftCheek.isNotEmpty && rightCheek.isNotEmpty) {
      horizontal =
          (leftCheek.last.x - rightCheek.first.x).abs().toDouble();
    }
    return horizontal < 1e-6 ? 0.0 : vertical / horizontal;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 62차원 통계 피처 (step2_prepare_dataset.py 와 동일)
  // ─────────────────────────────────────────────────────────────────────────
  Float32List _computeClipFeatures(List<List<double>> frames) {
    final result = Float32List(62);
    final n = frames.length;
    if (n == 0) return result;

    final faceFrames = frames.where((f) => f[9] > 0.5).toList();
    result[0] = faceFrames.length / n;
    if (faceFrames.length < 5) return result;
    final nf = faceFrames.length;

    // 9개 raw × 5 통계
    for (int c = 0; c < 9; c++) {
      final col = faceFrames.map((f) => f[c]).toList()..sort();
      final s = _stats(col);
      final base = 1 + c * 5;
      result[base] = s.mean;
      result[base + 1] = s.std;
      result[base + 2] = s.min;
      result[base + 3] = s.max;
      result[base + 4] = s.median;
    }

    // Blink 피처
    final earAvg = faceFrames.map((f) => f[2]).toList();
    final earThreshold = _effectiveEarThreshold;
    final blinkMask = earAvg.map((e) => e < earThreshold).toList();
    result[46] = blinkMask.where((b) => b).length / nf;

    int longClosures = 0, runLen = 0;
    for (final b in blinkMask) {
      if (b) {
        runLen++;
      } else {
        if (runLen >= _kEarLongCloseFrames) longClosures++;
        runLen = 0;
      }
    }
    if (runLen >= _kEarLongCloseFrames) longClosures++;
    result[47] = longClosures.toDouble();
    result[48] = (longClosures * _kEarLongCloseFrames) / nf;
    result[49] = earAvg.reduce(math.max) - earAvg.reduce(math.min);

    final intervals = <double>[];
    bool inBlink = false;
    int gap = 0;
    for (final b in blinkMask) {
      if (b) {
        if (!inBlink && gap > 0) intervals.add(gap.toDouble());
        inBlink = true;
        gap = 0;
      } else {
        inBlink = false;
        gap++;
      }
    }
    if (intervals.length >= 2) {
      final s = _stats(intervals..sort());
      result[50] = s.mean;
      result[51] = s.std;
    }

    // MAR
    final mar = faceFrames.map((f) => f[3]).toList();
    result[52] = mar.where((m) => m > _kMarYawnThreshold).length / nf;
    result[53] = mar.reduce(math.max) - mar.reduce(math.min);

    // Head movement
    if (nf > 1) {
      final movements = <double>[];
      for (int i = 1; i < nf; i++) {
        movements.add(
          (faceFrames[i][4] - faceFrames[i - 1][4]).abs() +
              (faceFrames[i][5] - faceFrames[i - 1][5]).abs() +
              (faceFrames[i][6] - faceFrames[i - 1][6]).abs(),
        );
      }
      final hmMean = movements.reduce((a, b) => a + b) / movements.length;
      final hmSq = movements
          .map((v) => (v - hmMean) * (v - hmMean))
          .reduce((a, b) => a + b);
      result[54] = hmMean;
      result[55] = movements.reduce(math.max);
      result[56] = math.sqrt(hmSq / movements.length);
    }
    result[57] = faceFrames.where((f) => f[4] < -15).length / nf;

    // Gaze
    final gazeH = faceFrames.map((f) => f[7]).toList();
    final gazeV = faceFrames.map((f) => f[8]).toList();
    result[58] = _stats(gazeH..sort()).std;
    result[59] = _stats(gazeV..sort()).std;
    final gazeDist = <double>[];
    for (int i = 0; i < faceFrames.length; i++) {
      final h = faceFrames[i][7];
      final v = faceFrames[i][8];
      gazeDist.add(math.sqrt(h * h + v * v));
    }
    result[60] = _stats(gazeDist..sort()).std;
    result[61] = gazeDist.where((d) => d > _kGazeOffThreshold).length / nf;

    return result;
  }

  ({double mean, double std, double min, double max, double median}) _stats(
      List<double> sorted) {
    final n = sorted.length;
    final mean = sorted.reduce((a, b) => a + b) / n;
    final sq = sorted
        .map((v) => (v - mean) * (v - mean))
        .reduce((a, b) => a + b);
    final std = math.sqrt(sq / n);
    final median = n.isOdd
        ? sorted[n ~/ 2]
        : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2.0;
    return (
      mean: mean,
      std: std,
      min: sorted.first,
      max: sorted.last,
      median: median,
    );
  }

  /// 30초 버퍼에서 깜빡임 (눈 감김 → 뜸) rising edge 카운트
  /// ML Kit eyeOpenProbability 기반 — 카메라 각도 영향 적음
  int _countBlinksInBuffer() {
    int count = 0;
    bool prevClosed = false;
    for (final prob in _eyeOpenProbBuffer) {
      final closed = prob < _kEyeOpenThreshold;
      if (closed && !prevClosed) count++;
      prevClosed = closed;
    }
    return count;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ONNX 추론 + 안정화 + 점수 산정 (50/30/20)
  // ─────────────────────────────────────────────────────────────────────────
  void _runInferenceIfReady() {
    final faceCount = _buf.where((f) => f[9] > 0.5).length;
    if (!_ready && faceCount >= _kMlMinSamples) {
      _ready = true;
      _stable = true;
      debugPrint('[ConcentrationService] 측정 준비 완료 (face=$faceCount)');
    }

    final session = _session;
    if (session == null || faceCount < _kMlMinSamples) {
      _publishResult();
      return;
    }

    try {
      final feats = _computeClipFeatures(_buf);
      final tensor = OrtValueTensor.createTensorWithDataList(
        feats,
        [1, feats.length],
      );
      final out = session.run(OrtRunOptions(), {'float_input': tensor});

      int pred = -1;
      double probAlert = 0.5;
      try {
        final rawLabel = out.first?.value;
        if (rawLabel is List && rawLabel.isNotEmpty) {
          final v = rawLabel.first;
          if (v is num) pred = v.toInt();
          if (v is List && v.isNotEmpty && v.first is num) {
            pred = (v.first as num).toInt();
          }
        }
        if (out.length > 1) {
          final rawProb = out[1]?.value;
          probAlert = _extractClass1Prob(rawProb) ?? probAlert;
        }
      } catch (e) {
        debugPrint('[ConcentrationService] 출력 파싱 실패: $e');
      }
      tensor.release();

      if (pred >= 0) {
        _mlHistory.add(pred == 1);
        if (_mlHistory.length > _kMlConfirmCount) _mlHistory.removeAt(0);

        if (_mlHistory.length == _kMlConfirmCount) {
          final allDrowsy = _mlHistory.every((v) => !v);
          final anyAlert = _mlHistory.any((v) => v);
          if (allDrowsy) _stable = false;
          if (anyAlert) _stable = true;
        }

        // 점수 산정 (7주차 발표 알고리즘)
        final isDrowsy = pred == 0;
        final mlConfidence = isDrowsy ? (1.0 - probAlert) : probAlert;
        final mlScoreRaw = isDrowsy ? (1.0 - mlConfidence) : mlConfidence;

        // presence: 최근 5초 윈도우 (자리 이탈 즉각 반영)
        const presenceWindowFrames = 30;
        final recentBuf = _buf.length > presenceWindowFrames
            ? _buf.sublist(_buf.length - presenceWindowFrames)
            : _buf;
        final recentFace = recentBuf.where((f) => f[9] > 0.5).length;
        final presenceRatio =
            recentBuf.isEmpty ? 1.0 : recentFace / recentBuf.length;

        // stare: 정상 깜빡임 비율
        final blinkCount = _countBlinksInBuffer();
        final blinkRatio =
            (blinkCount / _kNormalBlinksPerWindow).clamp(0.0, 1.0);

        final baseScore = (_kWeightMl * mlScoreRaw +
                _kWeightPresence * presenceRatio +
                _kWeightStare * blinkRatio) *
            100;

        // 룰 기반 페널티 (하품 + 오랜 눈 감김)
        // 둘 다 트리거되어도 max 만 적용 (이중 처벌 방지, 같은 피로 신호)
        final yawnDetected = _detectYawn();
        final yawnPenalty = yawnDetected ? _kYawnPenalty : 0.0;
        final longClosure = _detectLongEyeClosure();
        final closurePenalty =
            longClosure ? _kLongEyeClosurePenalty : 0.0;
        final penalty = math.max(yawnPenalty, closurePenalty);

        final clampedScore =
            (baseScore - penalty).clamp(0.0, 100.0);
        _scoreHistory.add(clampedScore);

        if (_scoreHistory.length % 10 == 1) {
          final realMarMean = _realMarBuffer.isEmpty
              ? 0.0
              : _realMarBuffer.reduce((a, b) => a + b) /
                  _realMarBuffer.length;
          debugPrint(
            '[FEAT] face_rate=${feats[0].toStringAsFixed(2)} '
            'ear_avg_mean=${feats[13].toStringAsFixed(3)} '
            'mar(real)=${realMarMean.toStringAsFixed(3)} '
            'blink_rate=${feats[46].toStringAsFixed(3)} '
            '${_userMarBaseline != null ? "mar_baseline=${_userMarBaseline!.toStringAsFixed(3)}" : "mar_baseline=학습 중"}',
          );
        }

        debugPrint('[SCORE] ml=${(mlScoreRaw * _kWeightMl * 100).toStringAsFixed(1)} '
            'presence=${(presenceRatio * _kWeightPresence * 100).toStringAsFixed(1)} '
            'stare=${(blinkRatio * _kWeightStare * 100).toStringAsFixed(1)} '
            '${yawnDetected ? "🥱-$yawnPenalty " : ""}'
            '${longClosure ? "😴-$closurePenalty " : ""}'
            '→ ${clampedScore.toStringAsFixed(1)}점 '
            '(blinks=$blinkCount/6 stable=$_stable)');
      }

      _publishResult(
        rawPred: pred,
        score: _scoreHistory.isEmpty ? 50.0 : _scoreHistory.last,
      );
    } catch (e, st) {
      debugPrint('[ConcentrationService] 추론 실패: $e\n$st');
      _publishResult();
    }
  }

  double? _extractClass1Prob(dynamic rawProb) {
    if (rawProb == null) return null;
    try {
      if (rawProb is List && rawProb.isNotEmpty) {
        final first = rawProb.first;
        if (first is Map) {
          for (final k in first.keys) {
            if (k == 1 || k == '1' || (k is num && k.toInt() == 1)) {
              final v = first[k];
              if (v is num) return v.toDouble();
            }
          }
          if (first.length >= 2) {
            final v = first.values.elementAt(1);
            if (v is num) return v.toDouble();
          }
        }
        if (first is List && first.length >= 2) {
          final v = first[1];
          if (v is num) return v.toDouble();
        }
        if (first is num) return first.toDouble();
      }
    } catch (_) {}
    return null;
  }

  // 집중도 점수 임계 (3단계)
  //   70~100 집중   (초록)
  //   40~69  보통   (주황)
  //   0~39   비집중 (빨강)
  static const double focusedThreshold = 70.0;
  static const double mediumThreshold = 40.0;

  /// 평균 집중도 기반 다음 세션 추천 (7주차 발표 자료 알고리즘)
  ///
  /// - 70점 이상: 집중 +5분 (사용자 max 안에서) / 휴식 = 집중 ÷ 5
  /// - 40~69점 : 집중 유지 / 휴식 = 집중 ÷ 5
  /// - 40점 미만: 집중 -5분 (최소 25분) / 휴식 최소 10분 보장
  ///
  /// 반환: (focusMinutes, breakMinutes) — 다음 세션 추천 시간
  ({int focusMinutes, int breakMinutes}) recommendNextSession({
    required int currentFocusMinutes,
    required int maxFocusMinutes,
    int minFocusMinutes = 25,
    int minBreakMinutes = 5,
  }) {
    final avgScore = (averageScore01 * 100).clamp(0.0, 100.0);

    int recFocus;
    int recBreak;

    if (avgScore >= focusedThreshold) {
      // 집중 잘함 → 다음 집중 +5분 (max 한도 내)
      recFocus = (currentFocusMinutes + 5).clamp(minFocusMinutes, maxFocusMinutes);
      recBreak = (recFocus / 5).floor().clamp(minBreakMinutes, 60);
    } else if (avgScore >= mediumThreshold) {
      // 보통 → 현재 유지
      recFocus = currentFocusMinutes;
      recBreak = (recFocus / 5).floor().clamp(minBreakMinutes, 60);
    } else {
      // 부진 → 다음 집중 -5분 (최소 보장), 휴식 최소 10분
      recFocus = (currentFocusMinutes - 5).clamp(minFocusMinutes, maxFocusMinutes);
      recBreak = math.max(10, (recFocus / 5).floor()).clamp(10, 60);
    }

    return (focusMinutes: recFocus, breakMinutes: recBreak);
  }

  void _publishResult({int rawPred = -1, double score = 0}) {
    final FocusStatus status;
    final double finalScore;
    if (!_ready) {
      status = FocusStatus.measuring;
      finalScore = 0;
    } else {
      finalScore = score.clamp(0.0, 100.0);
      if (finalScore >= focusedThreshold) {
        status = FocusStatus.focused;
      } else if (finalScore >= mediumThreshold) {
        status = FocusStatus.medium;
      } else {
        status = FocusStatus.distracted;
      }
    }
    _result.value = FocusResult(
      status: status,
      score: finalScore,
      rawPred: rawPred,
    );
  }
}

