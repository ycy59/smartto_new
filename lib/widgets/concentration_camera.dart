import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:onnxruntime/onnxruntime.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 집중도 측정 결과
// ─────────────────────────────────────────────────────────────────────────────

enum FocusStatus { focused, distracted, measuring }

class FocusResult {
  final FocusStatus status;
  final double score;

  const FocusResult({
    required this.status,
    required this.score,
  });

  String get statusKr {
    switch (status) {
      case FocusStatus.focused:    return '집중 중';
      case FocusStatus.distracted: return '비집중';
      case FocusStatus.measuring:  return '측정 중';
    }
  }

  Color get statusColor {
    switch (status) {
      case FocusStatus.focused:    return const Color(0xFF5AA85A);
      case FocusStatus.distracted: return const Color(0xFFD8645C);
      case FocusStatus.measuring:  return const Color(0xFF999999);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EAR 계산 — ML Kit eye contour 점들의 높이/너비 비율
// 훈련 데이터의 EAR 범위(0.15~0.35)와 동일한 분포를 가짐
// ─────────────────────────────────────────────────────────────────────────────

double _earFromContour(List<dynamic>? pts) {
  if (pts == null || pts.length < 4) return 0.25; // fallback: 열린 눈

  // ML Kit contour points: x, y 접근
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
  final width  = maxX - minX;

  // EAR 근사: 눈 높이 / 눈 너비 × 0.5
  // 열린 눈: ~0.25~0.35 / 감긴 눈: ~0.05~0.12 → 훈련 범위와 일치
  return width < 1.0 ? 0.25 : (height / width) * 0.5;
}

// ─────────────────────────────────────────────────────────────────────────────
// MAR 계산 (입술 윤곽 사용)
// ─────────────────────────────────────────────────────────────────────────────

double _computeMarFromContours(Face face) {
  final upperTop    = face.contours[FaceContourType.upperLipTop]?.points;
  final lowerBottom = face.contours[FaceContourType.lowerLipBottom]?.points;
  final leftCheek   = face.contours[FaceContourType.leftCheek]?.points;
  final rightCheek  = face.contours[FaceContourType.rightCheek]?.points;

  if (upperTop == null || lowerBottom == null ||
      upperTop.isEmpty || lowerBottom.isEmpty) return 0.0;

  final topMid    = upperTop[upperTop.length ~/ 2];
  final bottomMid = lowerBottom[lowerBottom.length ~/ 2];
  final vertical  = (topMid.y - bottomMid.y).abs().toDouble();

  double horizontal = 80.0;
  if (leftCheek != null && rightCheek != null &&
      leftCheek.isNotEmpty && rightCheek.isNotEmpty) {
    horizontal = (leftCheek.last.x - rightCheek.first.x).abs().toDouble();
  }

  return horizontal < 1e-6 ? 0.0 : vertical / horizontal;
}

// ─────────────────────────────────────────────────────────────────────────────
// 클립 통계 피처 — Python step2_prepare_dataset.py 의 compute_clip_features 와
// 완전히 동일한 62-차원 벡터를 생성한다.
//
// 버퍼 프레임 구조 (10-dim):
//   [0] ear_left_scaled   [1] ear_right_scaled  [2] ear_avg_scaled
//   [3] mar               [4] pitch             [5] yaw
//   [6] roll              [7] gaze_h(=0)        [8] gaze_v(=0)
//   [9] face_detected(1/0)
//
// 피처 순서(62개):
//   [0]       face_detection_rate
//   [1..45]   raw 9개 × 5 통계(mean,std,min,max,median)
//   [46]      blink_rate
//   [47]      long_closure_count
//   [48]      long_closure_rate
//   [49]      ear_range
//   [50]      blink_interval_mean
//   [51]      blink_interval_std
//   [52]      yawn_rate
//   [53]      mar_range
//   [54]      head_move_mean
//   [55]      head_move_max
//   [56]      head_move_std
//   [57]      head_down_rate
//   [58]      gaze_h_std
//   [59]      gaze_v_std
//   [60]      gaze_dispersion
//   [61]      off_screen_rate
// ─────────────────────────────────────────────────────────────────────────────

const double _earBlinkThreshold  = 0.21;   // Python 과 동일
const int    _earLongCloseFrames = 10;
const double _marYawnThreshold   = 0.65;
const double _gazeOffThreshold   = 0.35;

/// 정렬된 리스트의 5-통계 반환 (mean, std, min, max, median)
List<double> _stats(List<double> sorted) {
  final n = sorted.length;
  final mean   = sorted.reduce((a, b) => a + b) / n;
  final sq     = sorted.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b);
  final std    = math.sqrt(sq / n);
  final median = n.isOdd ? sorted[n ~/ 2]
                         : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2.0;
  return [mean, std, sorted.first, sorted.last, median];
}

Float32List _computeClipFeatures(List<List<double>> frames) {
  final result = Float32List(62);
  final n = frames.length;
  if (n == 0) return result;

  // ── face_detection_rate ──────────────────────────────────────────────────
  final faceFrames = frames.where((f) => f[9] > 0.5).toList();
  result[0] = faceFrames.length / n;
  if (faceFrames.isEmpty) return result;
  final nf = faceFrames.length;

  // ── 1. 기본 통계: 9개 raw 피처 × 5 통계 → [1..45] ───────────────────────
  for (int c = 0; c < 9; c++) {
    final col = faceFrames.map((f) => f[c]).toList()..sort();
    final s   = _stats(col);
    final base = 1 + c * 5;
    result[base]     = s[0]; // mean
    result[base + 1] = s[1]; // std
    result[base + 2] = s[2]; // min
    result[base + 3] = s[3]; // max
    result[base + 4] = s[4]; // median
  }

  // ── 2. Blink 피처 [46..51] ──────────────────────────────────────────────
  final earAvg    = faceFrames.map((f) => f[2]).toList();
  final blinkMask = earAvg.map((e) => e < _earBlinkThreshold).toList();

  result[46] = blinkMask.where((b) => b).length / nf; // blink_rate

  // long_closure_count / rate
  int longClosures = 0, runLen = 0;
  for (final b in blinkMask) {
    if (b) { runLen++; }
    else   { if (runLen >= _earLongCloseFrames) longClosures++; runLen = 0; }
  }
  if (runLen >= _earLongCloseFrames) longClosures++;
  result[47] = longClosures.toDouble();
  result[48] = (longClosures * _earLongCloseFrames) / nf;

  // ear_range
  result[49] = earAvg.reduce(math.max) - earAvg.reduce(math.min);

  // blink_interval mean/std
  final intervals = <double>[];
  bool inBlink = false; int gap = 0;
  for (final b in blinkMask) {
    if (b) { if (!inBlink && gap > 0) intervals.add(gap.toDouble()); inBlink = true; gap = 0; }
    else   { inBlink = false; gap++; }
  }
  if (intervals.length >= 2) {
    final s = _stats(intervals..sort());
    result[50] = s[0]; // mean
    result[51] = s[1]; // std
  }

  // ── 3. MAR 피처 [52..53] ────────────────────────────────────────────────
  final mar = faceFrames.map((f) => f[3]).toList();
  result[52] = mar.where((m) => m > _marYawnThreshold).length / nf; // yawn_rate
  result[53] = mar.reduce(math.max) - mar.reduce(math.min);         // mar_range

  // ── 4. 머리 움직임 [54..57] ─────────────────────────────────────────────
  if (nf > 1) {
    final movements = <double>[];
    for (int i = 1; i < nf; i++) {
      movements.add(
        (faceFrames[i][4] - faceFrames[i-1][4]).abs() +
        (faceFrames[i][5] - faceFrames[i-1][5]).abs() +
        (faceFrames[i][6] - faceFrames[i-1][6]).abs(),
      );
    }
    final hmMean = movements.reduce((a, b) => a + b) / movements.length;
    final hmSq   = movements.map((v) => (v - hmMean) * (v - hmMean)).reduce((a, b) => a + b);
    result[54] = hmMean;
    result[55] = movements.reduce(math.max);
    result[56] = math.sqrt(hmSq / movements.length);
  }
  // head_down_rate
  result[57] = faceFrames.where((f) => f[4] < -15).length / nf;

  // ── 5. 시선 피처 [58..61] (gaze_h/v=0이므로 std=0, off_screen=0) ─────────
  // ML Kit은 iris 추적 없음 → gaze 피처는 0 유지 (모델 robustness에 의존)

  return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// 집중도 판단 서비스
// ─────────────────────────────────────────────────────────────────────────────

class ConcentrationService {
  OrtSession? _session;

  double _noFaceStart    = 0;
  bool   _faceWasPresent = true;

  // 버퍼: 10-dim 프레임 [earL, earR, earAvg, mar, pitch, yaw, roll, gazeH, gazeV, faceDet]
  final _buf       = <List<double>>[];
  final _mlHistory = <bool>[];
  bool _stableMl   = true;
  bool _mlReady    = false;

  // EAR 스케일: contour 방식이 MediaPipe EAR 대비 약 70% 수준
  // → × 1.4 하면 훈련 범위(0.25~0.35)와 일치
  static const _earScale = 1.4;

  static const _noFaceDuration  = 180.0;
  static const _mlMinSamples    = 45;
  static const _mlConfirmCount  = 5;

  Future<void> loadModel() async {
    try {
      OrtEnv.instance.init();
      final raw   = await rootBundle.load('assets/models/xgb_model.onnx');
      final bytes = raw.buffer.asUint8List();
      _session = OrtSession.fromBuffer(bytes, OrtSessionOptions());
      debugPrint('[ConcentrationService] 모델 로드 완료');
    } catch (e) {
      debugPrint('[ConcentrationService] 모델 없음, rule-based만 사용: $e');
    }
  }

  void dispose() {
    _session?.release();
    OrtEnv.instance.release();
  }

  void reset() {
    _noFaceStart    = 0;
    _faceWasPresent = true;
    _buf.clear();
    _mlHistory.clear();
    _stableMl = true;
    _mlReady  = false;
  }

  FocusResult update({
    required bool   faceDetected,
    required double earLeft,      // 스케일 전 raw EAR
    required double earRight,
    required double mar,
    required double pitch,
    required double yaw,
    required double roll,
    required double now,
  }) {
    // ── 버퍼: 10-dim 프레임 저장, EAR × 1.4 스케일 적용 ────────────────────
    if (faceDetected) {
      final earL   = earLeft  * _earScale;
      final earR   = earRight * _earScale;
      final earAvg = (earL + earR) / 2.0;
      _buf.add([earL, earR, earAvg, mar, pitch, yaw, roll, 0.0, 0.0, 1.0]);
      if (_buf.length > 150) _buf.removeAt(0);
    } else {
      // 얼굴 미감지 프레임도 face_detection_rate 계산을 위해 기록
      _buf.add([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);
      if (_buf.length > 150) _buf.removeAt(0);
    }

    // ── 자리 이탈: 3분 이상 얼굴 없을 때만 ──────────────────────────────────
    bool isAbsent = false;
    if (!faceDetected) {
      if (_faceWasPresent) _noFaceStart = now;
      if (_noFaceStart > 0 && now - _noFaceStart >= _noFaceDuration) {
        isAbsent = true;
      }
    } else {
      _noFaceStart = 0;
    }
    _faceWasPresent = faceDetected;

    // ── 버퍼가 충분히 쌓이면 ready (얼굴 감지된 프레임 기준) ────────────────
    final faceCount = _buf.where((f) => f[9] > 0.5).length;
    if (!_mlReady && faceCount >= _mlMinSamples) {
      _mlReady  = true;
      _stableMl = true; // 기본값: 집중
      debugPrint('[ML] 측정 준비 완료 (face_frames=$faceCount) — 기본 집중 상태로 시작');
    }

    // ── ML 추론 ──────────────────────────────────────────────────────────────
    if (_session != null && faceCount >= _mlMinSamples) {
      try {
        final feats  = _computeClipFeatures(_buf);
        // 피처 진단: earAvg_mean(위치13), blink_rate(위치46)
        debugPrint('[FEAT] earAvg_mean=${feats[13].toStringAsFixed(3)}'
                   '  blink_rate=${feats[46].toStringAsFixed(3)}'
                   '  face_det_rate=${feats[0].toStringAsFixed(2)}');

        final tensor = OrtValueTensor.createTensorWithDataList(
          feats, [1, feats.length],
        );
        final out  = _session!.run(OrtRunOptions(), {'float_input': tensor});
        final pred = (out.first?.value as List<dynamic>).first as int;
        tensor.release();

        _mlHistory.add(pred == 1); // 1=각성, 0=졸음
        if (_mlHistory.length > _mlConfirmCount) _mlHistory.removeAt(0);

        debugPrint('[ML] pred=$pred  history=$_mlHistory  stable=$_stableMl');

        // 비집중 전환: 연속 N번 모두 0일 때만 (집중→비집중은 엄격하게)
        // 집중 복귀: 연속 N번 중 하나라도 1이면 바로 복귀 (관대하게)
        if (_mlHistory.length == _mlConfirmCount) {
          final allDrowsy = _mlHistory.every((v) => !v);
          final anyAlert  = _mlHistory.any((v) => v);
          if (allDrowsy) _stableMl = false; // 전원 졸음 → 비집중
          if (anyAlert)  _stableMl = true;  // 하나라도 각성 → 집중
        }
      } catch (e) {
        // ML 실패해도 기본값(집중) 유지
        debugPrint('[ML] 추론 실패: $e → 집중 유지');
      }
    }

    // ── 상태 & 점수 결정 ────────────────────────────────────────────────────
    // 카메라 방향, 고개 방향 완전 무시
    // 오직: ML 각성 판단 + 자리 이탈 여부
    final FocusStatus status;
    final double score;

    if (!_mlReady) {
      // 아직 데이터 부족 — 측정 중
      status = FocusStatus.measuring;
      score  = 0;
    } else if (isAbsent) {
      status = FocusStatus.distracted;
      score  = 0;
    } else if (_stableMl) {
      status = FocusStatus.focused;
      score  = 90;
    } else {
      status = FocusStatus.distracted;
      score  = 30;
    }

    return FocusResult(status: status, score: score);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 집중도 카메라 위젯
// ─────────────────────────────────────────────────────────────────────────────

class ConcentrationCamera extends StatefulWidget {
  final void Function(FocusResult result)? onFocusUpdate;
  final bool isActive; // 타이머 실행 중일 때만 true

  const ConcentrationCamera({
    super.key,
    this.onFocusUpdate,
    this.isActive = false,
  });

  @override
  State<ConcentrationCamera> createState() => _ConcentrationCameraState();
}

class _ConcentrationCameraState extends State<ConcentrationCamera> {
  CameraController? _camCtrl;
  late final FaceDetector _detector;
  final _service = ConcentrationService();

  bool _ready       = false;
  bool _processing  = false;
  FocusResult _result = const FocusResult(status: FocusStatus.measuring, score: 0);

  @override
  void initState() {
    super.initState();
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,  // eyeOpenProbability + smilingProbability
        enableContours: true,        // 입술 윤곽 (MAR용)
        enableTracking: false,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    _init();
  }

  @override
  void dispose() {
    _camCtrl?.dispose();
    _detector.close();
    _service.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _service.loadModel();
    await _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _camCtrl = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await _camCtrl!.initialize();
      if (!mounted) return;
      setState(() => _ready = true);

      int frameCount = 0;
      _camCtrl!.startImageStream((img) async {
        if (++frameCount % 5 != 0 || _processing) return; // 6fps 처리
        _processing = true;
        try {
          await _processFrame(img);
        } finally {
          _processing = false;
        }
      });
    } catch (e) {
      debugPrint('[ConcentrationCamera] 카메라 오류: $e');
    }
  }

  Future<void> _processFrame(CameraImage img) async {
    try {
      final rotation = InputImageRotationValue.fromRawValue(
        _camCtrl!.description.sensorOrientation,
      ) ?? InputImageRotation.rotation0deg;

      final format = InputImageFormatValue.fromRawValue(img.format.raw);
      if (format == null) return;

      final inputImage = InputImage.fromBytes(
        bytes: img.planes.first.bytes,
        metadata: InputImageMetadata(
          size: Size(img.width.toDouble(), img.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: img.planes.first.bytesPerRow,
        ),
      );

      // 타이머가 멈춰있으면 측정 안 함
      if (!widget.isActive) return;

      final faces = await _detector.processImage(inputImage);
      final now   = DateTime.now().millisecondsSinceEpoch / 1000.0;

      if (faces.isEmpty) {
        final r = _service.update(
          faceDetected: false,
          earLeft: 0, earRight: 0, mar: 0,
          pitch: 0, yaw: 0, roll: 0,
          now: now,
        );
        if (mounted) { setState(() => _result = r); widget.onFocusUpdate?.call(r); }
        return;
      }

      final face = faces.first;

      // contour 기반 EAR 계산 (raw — 스케일링은 ConcentrationService 내부에서)
      final earLeft  = _earFromContour(face.contours[FaceContourType.leftEye]?.points);
      final earRight = _earFromContour(face.contours[FaceContourType.rightEye]?.points);
      final pitch    = face.headEulerAngleX ?? 0.0;
      final yaw      = face.headEulerAngleY ?? 0.0;
      final roll     = face.headEulerAngleZ ?? 0.0;
      final mar      = _computeMarFromContours(face);

      debugPrint('[EAR] raw L=$earLeft  R=$earRight  avg=${(earLeft+earRight)/2}'
                 '  scaled=${((earLeft+earRight)/2*1.4).toStringAsFixed(3)}');

      final r = _service.update(
        faceDetected: true,
        earLeft: earLeft, earRight: earRight, mar: mar,
        pitch: pitch, yaw: yaw, roll: roll,
        now: now,
      );
      if (mounted) { setState(() => _result = r); widget.onFocusUpdate?.call(r); }
    } catch (e) {
      debugPrint('[processFrame] $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 카메라 프리뷰
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 120,
            height: 90,
            child: _ready
                ? CameraPreview(_camCtrl!)
                : Container(
                    color: const Color(0xFFDDDDDD),
                    child: const Center(
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF999999),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        // 집중도 배지
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _result.statusColor.withOpacity(0.13),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  color: _result.statusColor, shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '${_result.statusKr}  ${_result.score.toStringAsFixed(0)}점',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _result.statusColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
