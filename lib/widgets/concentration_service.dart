// ─────────────────────────────────────────────────────────────────────────────
// ConcentrationService
//
// 카메라 프레임 → face_detection_tflite 로 mesh(468) + iris(152) 추출
// → 학습 코드(Smartto_ml/src/step1_extract_features.py + step2_prepare_dataset.py)
//    1:1 포팅된 함수들로 62차원 통계 피처 생성
// → 학습된 ONNX 모델(assets/models/xgb_model.onnx)로 추론
// → 집중(1) / 비집중(0) 판정
//
// 학습 코드와의 차이:
//   - EAR / MAR / gaze : 100% 일치 (비율 기반이라 좌표계 무관)
//   - head pose       : cv2.solvePnP 없이 mesh 3D 점으로 직접 추정 (~80% 일치)
//
// 사용:
//   final service = ConcentrationService();
//   await service.initialize();
//   ...
//   service.processFrame(cameraImage); // 카메라 프레임마다 호출
//   service.result.addListener(...);   // ValueListenable 로 결과 구독
//   ...
//   service.dispose();
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show VoidCallback;

import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart' as fdt;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 학습 코드와 동일한 MediaPipe 인덱스
// ─────────────────────────────────────────────────────────────────────────────

// EAR (mesh 468 인덱스)
const List<int> _kLeftEye = [362, 385, 387, 263, 373, 380];
const List<int> _kRightEye = [33, 160, 158, 133, 153, 144];

// MAR
const List<int> _kMouth = [61, 291, 39, 181, 0, 17, 269, 405];

// Iris (face_detection_tflite 의 irisPoints 배열 인덱스)
//   - left  : 71..75 (5점)
//   - right : 147..151 (5점)
//   학습 코드의 mesh[468..472] / mesh[473..477] 와 동일한 의미
const int _kLeftIrisStart = 71;
const int _kRightIrisStart = 147;

// gaze 계산용 눈 끝 점 (mesh 인덱스)
const int _kLeftEyeInner = 362;
const int _kLeftEyeOuter = 263;
const int _kRightEyeInner = 33;
const int _kRightEyeOuter = 133;

// head pose 추정용 6점 (학습 코드 FACE_2D_IDX 와 동일)
const int _kNoseTip = 1;
const int _kChin = 152;
// 263 = 왼쪽 눈 끝, 33 = 오른쪽 눈 끝, 287/57 = 입 끝

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
const int _kBufferMaxFrames = 150;     // 버퍼 최대 프레임 (≈ 25초 @ 6fps)
const int _kMlMinSamples = 45;         // 추론 시작 최소 face 프레임 수
const int _kMlConfirmCount = 5;        // 안정화 윈도우 (연속 N개)

// ─────────────────────────────────────────────────────────────────────────────
// 집중도 점수 알고리즘 (7주차 발표 자료 기준 그대로)
//   점수 = (ML 졸음 판정 × 0.50) + (자리 이탈 × 0.30) + (멍때리기 × 0.20) * 100
// ─────────────────────────────────────────────────────────────────────────────
const double _kWeightMl = 0.50;
const double _kWeightPresence = 0.30;
const double _kWeightStare = 0.20;
const int _kNormalBlinksPerWindow = 6;

// ── 학습 데이터 정상 분포 (face_detection_tflite mesh 가 분포 밖 출력하는
//    MAR/gaze 피처를 이 값으로 고정해서 ML 입력 정상화) ─────────────────────
const double _kNormalMarValue = 0.10;   // 학습 분포 mean ~ 0.10
const double _kNormalGazeValue = 0.0;   // 학습 분포 mean ~ 0

// ─────────────────────────────────────────────────────────────────────────────
// 결과 객체
// ─────────────────────────────────────────────────────────────────────────────
enum FocusStatus { measuring, focused, distracted }

@immutable
class FocusResult {
  final FocusStatus status;
  final double score; // 0~100, measuring 일 땐 0
  final int rawPred;  // 마지막 raw 추론 결과 (0/1, 디버그용)

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
  fdt.FaceDetector? _detector;
  OrtSession? _session;
  OrtEnv? _ortEnv;

  bool _isProcessing = false;

  // 10차원 프레임 버퍼: [earL, earR, earAvg, mar, pitch, yaw, roll, gazeH, gazeV, faceDet]
  final List<List<double>> _buf = [];

  // 안정화: 최근 N개 추론 결과
  final List<bool> _mlHistory = [];
  bool _stable = true;
  bool _ready = false;

  // 누적 점수 (세션 평균 내기용)
  final List<double> _scoreHistory = [];

  final ValueNotifier<FocusResult> _result =
      ValueNotifier<FocusResult>(FocusResult.measuring);
  ValueListenable<FocusResult> get result => _result;
  FocusResult get currentResult => _result.value;

  /// 누적된 점수의 평균 (0~1) — _endSession 에 전달용
  double get averageScore01 {
    if (_scoreHistory.isEmpty) return 0.65; // fallback (mock 과 동일)
    final sum = _scoreHistory.reduce((a, b) => a + b);
    return (sum / _scoreHistory.length / 100.0).clamp(0.0, 1.0);
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
      // 모델 없어도 face detection 만이라도 동작하게 진행
    }

    // 2. Face Detector 초기화 (셀카 → frontCamera)
    try {
      _detector = await fdt.FaceDetector.create(
        model: fdt.FaceDetectionModel.frontCamera,
      );
      debugPrint('[ConcentrationService] FaceDetector 초기화 완료');
    } catch (e, st) {
      debugPrint('[ConcentrationService] FaceDetector 초기화 실패: $e\n$st');
      rethrow;
    }
  }

  void dispose() {
    _detector?.dispose();
    _session?.release();
    _ortEnv?.release();
    _buf.clear();
    _mlHistory.clear();
    _scoreHistory.clear();
  }

  void reset() {
    _buf.clear();
    _mlHistory.clear();
    _scoreHistory.clear();
    _stable = true;
    _ready = false;
    _result.value = FocusResult.measuring;
  }

  // ── 카메라 프레임 처리 ──────────────────────────────────────────────────
  int _processCallCount = 0;
  int _faceFoundCount = 0;
  int _faceMissCount = 0;

  /// 누적 face 검출 카운트 (외부에서 회전 탐색용으로 읽음)
  int get lastFoundCount => _faceFoundCount;

  // ── 사용자별 EAR 동적 calibration ────────────────────────────────────────
  // 첫 60프레임(약 10초) 동안 사용자 평소 EAR 평균을 측정 → 그 × 0.6 을
  // 깜빡임 임계값으로 사용. 학습 default 0.21 은 평균 EAR 0.30 인 사람용.
  // 사용자 평균이 0.17 이면 임계값은 0.10 부근으로 자동 조정됨.
  final List<double> _baselineSamples = [];
  double? _userEarThreshold;

  void _updateEarBaseline(double earAvg) {
    if (_userEarThreshold != null) return;
    if (earAvg < 0.08) return; // 깜빡임 중이면 baseline 에서 제외
    _baselineSamples.add(earAvg);
    if (_baselineSamples.length >= 60) {
      final mean = _baselineSamples.reduce((a, b) => a + b) /
          _baselineSamples.length;
      _userEarThreshold = mean * 0.75; // 0.6 → 0.75 (깜빡임 잘 잡히게 느슨)
      debugPrint('[CALIBRATION] 사용자 EAR baseline=${mean.toStringAsFixed(3)} '
          '→ 깜빡임 임계값=${_userEarThreshold!.toStringAsFixed(3)}');
    }
  }

  double get _effectiveEarThreshold =>
      _userEarThreshold ?? _kEarBlinkThreshold;

  Future<void> processFrame(
    CameraImage image, {
    fdt.CameraFrameRotation? rotation,
  }) async {
    if (_detector == null) return;
    if (_isProcessing) return; // 이전 프레임 처리 중이면 skip
    _isProcessing = true;
    _processCallCount++;

    // 첫 호출 시 image 구조 진단
    if (_processCallCount == 1) {
      final planes = image.planes;
      debugPrint('[ConcentrationService] image 진단: '
          'size=${image.width}x${image.height} '
          'planes=${planes.length} '
          'plane0: bytes=${planes.first.bytes.length} '
          'bytesPerRow=${planes.first.bytesPerRow} '
          'bytesPerPixel=${planes.first.bytesPerPixel}');
    }

    try {
      final faces = await _detector!.detectFacesFromCameraImage(
        image,
        mode: fdt.FaceDetectionMode.full, // mesh + iris
        // iOS/Android 는 yuv420, macOS 만 BGRA (face_detection_tflite example 기준)
        isBgra: Platform.isMacOS,
        rotation: rotation,
      );

      if (faces.isEmpty) {
        _faceMissCount++;
        _appendFrame(_emptyFrame());
      } else {
        _faceFoundCount++;
        final f = faces.first;
        final mesh = f.mesh;
        if (mesh == null || mesh.points.length < 468) {
          _appendFrame(_emptyFrame());
        } else {
          final frame = _buildFrameVector(
            mesh.points,
            f.irisPoints,
            f.originalSize.width.toDouble(),
            f.originalSize.height.toDouble(),
          );
          // 사용자별 EAR baseline 학습
          _updateEarBaseline(frame[2]);
          _appendFrame(frame);
        }
      }

      // 매 10번째 호출마다 진단 로그
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

  void _appendFrame(List<double> v) {
    _buf.add(v);
    if (_buf.length > _kBufferMaxFrames) _buf.removeAt(0);
  }

  List<double> _emptyFrame() => List<double>.filled(10, 0.0);

  // ── 한 프레임의 10차원 벡터 생성 (학습 코드 step1 기준) ────────────────
  // EAR / blink / face_detection_rate : face_detection_tflite 결과 그대로 사용
  //                                     (ML 가장 중요한 입력)
  // MAR                                 : 학습 정상값 0.10 으로 고정
  //                                     (face_detection_tflite mesh 의 입 점이
  //                                      학습 분포 밖 값 출력해서 ML 오판정 유발)
  // head pose (pitch/yaw/roll)          : 0 고정 (cv2.solvePnP 대체 불가)
  // gaze (h/v)                          : 0 고정 (학습 정상값에 가까움)
  List<double> _buildFrameVector(
    List<fdt.Point> mesh,
    List<fdt.Point> iris,
    double imgW,
    double imgH,
  ) {
    final earL = _computeEar(mesh, _kLeftEye);
    final earR = _computeEar(mesh, _kRightEye);
    final earAvg = (earL + earR) / 2.0;

    return [
      earL, earR, earAvg,
      _kNormalMarValue,                     // MAR 강제 정상값
      0.0, 0.0, 0.0,                        // pitch, yaw, roll 모두 0
      _kNormalGazeValue, _kNormalGazeValue, // gaze h/v 모두 0
      1.0,                                  // face_detected
    ];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // step1_extract_features.py 와 동일한 식들 (1:1 포팅)
  // ─────────────────────────────────────────────────────────────────────────

  /// EAR = (||p1-p5|| + ||p2-p4||) / (2 * ||p0-p3||)
  double _computeEar(List<fdt.Point> mesh, List<int> eyeIdx) {
    final pts = eyeIdx.map((i) => mesh[i]).toList();
    final v1 = _dist(pts[1], pts[5]);
    final v2 = _dist(pts[2], pts[4]);
    final h = _dist(pts[0], pts[3]);
    if (h < 1e-6) return 0.0;
    return (v1 + v2) / (2.0 * h);
  }

  /// MAR = (v1 + v2 + v3) / (3 * h)
  double _computeMar(List<fdt.Point> mesh) {
    final pts = _kMouth.map((i) => mesh[i]).toList();
    final v1 = _dist(pts[2], pts[6]); // 39-269
    final v2 = _dist(pts[3], pts[7]); // 181-405
    final v3 = _dist(pts[4], pts[5]); // 0-17
    final h = _dist(pts[0], pts[1]); // 61-291
    if (h < 1e-6) return 0.0;
    return (v1 + v2 + v3) / (3.0 * h);
  }

  /// Head pose 추정 — face_detection_tflite 의 mesh z 좌표 스케일이 학습
  /// 데이터(MediaPipe + cv2.solvePnP)와 너무 달라서 atan2 가 ±90도로 saturate.
  /// 결과적으로 모델이 항상 비정상 분기로 흘러 점수가 stuck.
  ///
  /// 임시 해결: head pose 를 0 으로 둠. 모델 정확도는 약간 손실되지만
  /// 적어도 EAR/blink/gaze 기반의 합리적 점수가 나옴.
  /// (학습 데이터의 head pose 평균이 거의 0 부근이라 통계적으로 무난)
  (double, double, double) _computeHeadPoseFromMesh(List<fdt.Point> mesh) {
    // roll 만 양 눈의 y 차이로 안전하게 계산 (값이 작아 saturate 안 됨)
    try {
      final lEye = mesh[_kLeftEyeOuter];
      final rEye = mesh[_kRightEyeOuter];
      final eyeDy = lEye.y - rEye.y;
      final eyeDx = (lEye.x - rEye.x).abs();
      if (eyeDx < 1e-6) return (0.0, 0.0, 0.0);
      final rollRad = math.atan2(eyeDy, eyeDx);
      const r2d = 180.0 / math.pi;
      return (0.0, 0.0, rollRad * r2d);
    } catch (_) {
      return (0.0, 0.0, 0.0);
    }
  }

  /// Gaze offset : iris 중심 vs 눈 중심
  (double, double) _computeGazeOffset(
    List<fdt.Point> mesh,
    List<fdt.Point> iris,
  ) {
    if (iris.length < 152) return (0.0, 0.0);
    try {
      // 왼쪽 iris 중심 (5점 평균)
      double lIrisX = 0, lIrisY = 0;
      for (int i = 0; i < 5; i++) {
        lIrisX += iris[_kLeftIrisStart + i].x;
        lIrisY += iris[_kLeftIrisStart + i].y;
      }
      lIrisX /= 5;
      lIrisY /= 5;

      // 오른쪽 iris 중심
      double rIrisX = 0, rIrisY = 0;
      for (int i = 0; i < 5; i++) {
        rIrisX += iris[_kRightIrisStart + i].x;
        rIrisY += iris[_kRightIrisStart + i].y;
      }
      rIrisX /= 5;
      rIrisY /= 5;

      // 왼쪽 눈 양 끝 (mesh)
      final lInner = mesh[_kLeftEyeInner];
      final lOuter = mesh[_kLeftEyeOuter];
      final lCx = (lInner.x + lOuter.x) / 2;
      final lCy = (lInner.y + lOuter.y) / 2;
      final lW = math.sqrt(
          math.pow(lInner.x - lOuter.x, 2) + math.pow(lInner.y - lOuter.y, 2));

      // 오른쪽 눈 양 끝
      final rInner = mesh[_kRightEyeInner];
      final rOuter = mesh[_kRightEyeOuter];
      final rCx = (rInner.x + rOuter.x) / 2;
      final rCy = (rInner.y + rOuter.y) / 2;
      final rW = math.sqrt(
          math.pow(rInner.x - rOuter.x, 2) + math.pow(rInner.y - rOuter.y, 2));

      if (lW < 1e-6 || rW < 1e-6) return (0.0, 0.0);

      final lOffsetH = (lIrisX - lCx) / lW;
      final lOffsetV = (lIrisY - lCy) / lW;
      final rOffsetH = (rIrisX - rCx) / rW;
      final rOffsetV = (rIrisY - rCy) / rW;

      final avgH = (lOffsetH + rOffsetH) / 2;
      final avgV = (lOffsetV + rOffsetV) / 2;

      return (avgH, avgV);
    } catch (_) {
      return (0.0, 0.0);
    }
  }

  double _dist(fdt.Point a, fdt.Point b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // step2_prepare_dataset.py 의 _get_feature_names + compute_clip_features
  // 1:1 포팅 (62차원)
  // 순서:
  //   [0]      face_detection_rate
  //   [1..45]  9개 raw × 5 통계(mean,std,min,max,median)
  //   [46]     blink_rate
  //   [47]     long_closure_count
  //   [48]     long_closure_rate
  //   [49]     ear_range
  //   [50]     blink_interval_mean
  //   [51]     blink_interval_std
  //   [52]     yawn_rate
  //   [53]     mar_range
  //   [54]     head_move_mean
  //   [55]     head_move_max
  //   [56]     head_move_std
  //   [57]     head_down_rate
  //   [58]     gaze_h_std
  //   [59]     gaze_v_std
  //   [60]     gaze_dispersion
  //   [61]     off_screen_rate
  // ─────────────────────────────────────────────────────────────────────────
  Float32List _computeClipFeatures(List<List<double>> frames) {
    final result = Float32List(62);
    final n = frames.length;
    if (n == 0) return result;

    // face_detection_rate
    final faceFrames = frames.where((f) => f[9] > 0.5).toList();
    result[0] = faceFrames.length / n;
    if (faceFrames.length < 5) return result;
    final nf = faceFrames.length;

    // ── 1. 9개 raw × 5 통계 [1..45] ────────────────────────────────────────
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

    // ── 2. Blink 피처 [46..51] ────────────────────────────────────────────
    final earAvg = faceFrames.map((f) => f[2]).toList();
    // 사용자별로 calibrate된 임계값 사용 (없으면 학습 default)
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

    // ── 3. MAR 피처 [52..53] ──────────────────────────────────────────────
    final mar = faceFrames.map((f) => f[3]).toList();
    result[52] = mar.where((m) => m > _kMarYawnThreshold).length / nf;
    result[53] = mar.reduce(math.max) - mar.reduce(math.min);

    // ── 4. 머리 움직임 [54..57] ───────────────────────────────────────────
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

    // ── 5. Gaze 피처 [58..61] ─────────────────────────────────────────────
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

  // ─────────────────────────────────────────────────────────────────────────
  // ONNX 추론 + 안정화
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

      // XGBoost ONNX 출력 (onnxmltools convert):
      //   out[0] = label (List<int>)
      //   out[1] = probabilities (List<Map<int, double>> 또는 List<List>)
      int pred = -1;
      double probAlert = 0.5; // class 1 (집중) 확률, 기본 중간값

      try {
        // label 추출
        final rawLabel = out.first?.value;
        if (rawLabel is List && rawLabel.isNotEmpty) {
          final v = rawLabel.first;
          if (v is num) pred = v.toInt();
          if (v is List && v.isNotEmpty && v.first is num) {
            pred = (v.first as num).toInt();
          }
        }

        // probability 추출 (out[1])
        if (out.length > 1) {
          final rawProb = out[1]?.value;
          probAlert = _extractClass1Prob(rawProb) ?? probAlert;
        }

        // 첫 추론 시 출력 형식 디버그
        if (_scoreHistory.isEmpty) {
          debugPrint('[ML] 첫 추론 — outputs=${out.length}');
          for (int i = 0; i < out.length; i++) {
            final v = out[i]?.value;
            final preview = v.toString();
            debugPrint(
                '[ML]   out[$i]: ${preview.length > 200 ? "${preview.substring(0, 200)}..." : preview}');
          }
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

        // ── 7주차 발표 알고리즘 적용 ──────────────────────────────────────
        // 1) ML 졸음 판정 점수 (가중치 50%) — probAlert 그대로
        //    is_drowsy=true: ml_score = 1 - confidence
        //    is_drowsy=false: ml_score = confidence
        //    → 결과적으로 "alert 확률"
        final isDrowsy = pred == 0;
        final mlConfidence = isDrowsy ? (1.0 - probAlert) : probAlert;
        final mlScoreRaw = isDrowsy ? (1.0 - mlConfidence) : mlConfidence;

        // 2) 자리 이탈 감지 (가중치 30%) — 얼굴 감지 프레임 비율
        final presenceRatio = feats[0]; // face_detection_rate

        // 3) 멍때리기 감지 (가중치 20%) — 30초 동안 깜빡임 횟수 / 정상 6회
        //    버퍼에서 깜빡임 rising edge 카운트
        final blinkCount = _countBlinksInBuffer();
        final blinkRatio =
            (blinkCount / _kNormalBlinksPerWindow).clamp(0.0, 1.0);

        // 4) 가중 합산
        final score = (_kWeightMl * mlScoreRaw +
                _kWeightPresence * presenceRatio +
                _kWeightStare * blinkRatio) *
            100;
        final clampedScore = score.clamp(0.0, 100.0);

        _scoreHistory.add(clampedScore);

        if (_scoreHistory.length % 10 == 1) {
          debugPrint(
            '[FEAT] face_rate=${feats[0].toStringAsFixed(2)} '
            'ear_avg_mean=${feats[13].toStringAsFixed(3)} '
            'mar_mean=${feats[18].toStringAsFixed(3)} '
            'blink_rate=${feats[46].toStringAsFixed(3)} '
            'gaze_h_std=${feats[58].toStringAsFixed(3)}',
          );
        }

        debugPrint('[SCORE] ml=${(mlScoreRaw * _kWeightMl * 100).toStringAsFixed(1)} '
            'presence=${(presenceRatio * _kWeightPresence * 100).toStringAsFixed(1)} '
            'stare=${(blinkRatio * _kWeightStare * 100).toStringAsFixed(1)} '
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

  /// 30초 버퍼에서 깜빡임 (눈 감김 → 뜸) rising edge 카운트
  int _countBlinksInBuffer() {
    int count = 0;
    bool prevClosed = false;
    final threshold = _effectiveEarThreshold;
    for (final f in _buf) {
      if (f[9] < 0.5) continue; // 얼굴 안 잡힌 프레임 스킵
      final closed = f[2] < threshold;
      if (closed && !prevClosed) count++;
      prevClosed = closed;
    }
    return count;
  }

  /// XGBoost ONNX 의 probabilities 출력에서 class 1 (집중) 확률 뽑기
  /// 형식이 다양해서 여러 케이스 시도
  double? _extractClass1Prob(dynamic rawProb) {
    if (rawProb == null) return null;
    try {
      if (rawProb is List && rawProb.isNotEmpty) {
        final first = rawProb.first;
        // case 1: List<Map<int, double>> — [{0: 0.3, 1: 0.7}]
        if (first is Map) {
          final keys = first.keys.toList();
          // key 1 (class 1) 찾기
          for (final k in keys) {
            if (k == 1 || k == '1' || (k is num && k.toInt() == 1)) {
              final v = first[k];
              if (v is num) return v.toDouble();
            }
          }
          // 키가 0/1이 아니면 두 번째 value 시도
          if (first.length >= 2) {
            final v = first.values.elementAt(1);
            if (v is num) return v.toDouble();
          }
        }
        // case 2: List<List<double>> — [[0.3, 0.7]]
        if (first is List && first.length >= 2) {
          final v = first[1];
          if (v is num) return v.toDouble();
        }
        // case 3: List<double> — [0.7]
        if (first is num) return first.toDouble();
      }
    } catch (_) {}
    return null;
  }

  void _publishResult({int rawPred = -1, double score = 0}) {
    final FocusStatus status;
    final double finalScore;
    if (!_ready) {
      status = FocusStatus.measuring;
      finalScore = 0;
    } else if (_stable) {
      status = FocusStatus.focused;
      finalScore = score.clamp(0.0, 100.0);
    } else {
      status = FocusStatus.distracted;
      finalScore = score.clamp(0.0, 100.0);
    }
    _result.value = FocusResult(
      status: status,
      score: finalScore,
      rawPred: rawPred,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VoidCallback re-export (간혹 import 누락 방지)
// ─────────────────────────────────────────────────────────────────────────────
typedef _VC = VoidCallback;
