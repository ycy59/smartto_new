// ─────────────────────────────────────────────────────────────────────────────
// SlmService (flutter_gemma + Gemma-2-2B-IT 통합)
//
// ConcentrationService 와 동일한 lifecycle 패턴:
//   - load()      : 모델 로드 (없으면 throw, downloadModel() 먼저 호출 필요)
//   - unload()    : 메모리 해제 (5분 idle 시 자동)
//   - generate()  : 스트리밍 토큰 추론
//   - generateAll(): 전체 응답 한 번에 (환각 검증 후처리용)
//
// 모델 파일:
//   - HuggingFace에 본인 계정으로 .task 파일 업로드 후 _modelUrl 교체
//   - getApplicationSupportDirectory()에 캐싱
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/model.dart'; // ModelType enum
import 'package:path_provider/path_provider.dart';

// flutter_gemma은 iOS/Android만 지원.
bool get _isPlatformSupported => Platform.isAndroid || Platform.isIOS;

class SlmService {
  // ── 설정 ─────────────────────────────────────────────────────────────────
  /// litert-community Gemma2-2B-IT q8 (2.71GB).
  static const String _modelUrl =
      "https://huggingface.co/litert-community/Gemma2-2B-IT/"
      "resolve/main/Gemma2-2B-IT_multi-prefill-seq_q8_ekv1280.task";
  // 필요 시 --dart-define=HF_TOKEN=... 로 주입. 소스에는 토큰을 저장하지 않는다.
  static const String _hfToken = String.fromEnvironment('HF_TOKEN');
  static const String _modelFileName =
      "Gemma2-2B-IT_multi-prefill-seq_q8_ekv1280.task";
  // 이전 버전 모델 파일명 — 앱 시작 시 자동 삭제됨
  static const List<String> _legacyModelFileNames = [
    "Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task",
  ];
  static const Duration _idleUnloadAfter = Duration(minutes: 5);
  static const int _maxTokens = 1280; // ekv1280 모델 KV 캐시 한도 = 1280
  static const double _temperature = 0.5; // 형식 일관성 우선 (0.5~0.7 권장)
  static const int _topK = 40;

  // ── 상태 ─────────────────────────────────────────────────────────────────
  InferenceModel? _model;
  InferenceModelSession? _session;
  Future<void>? _loadFuture;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  Timer? _idleTimer;

  bool get modelReady => _model != null;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;

  // ── 모델 파일 경로 ────────────────────────────────────────────────────────
  /// dev 단계 fallback 경로들 (sandbox 끈 macOS 전용)
  /// 1순위: 프로젝트 assets 폴더 (개발 머신에서 바로 읽음)
  /// 2순위: getApplicationSupportDirectory() (다운로드 받은 모델)
  static const String _devProjectAssetPath =
      "/Users/leeyushin/Desktop/프로젝트/smartto_new/assets/models/"
      "Gemma2-2B-IT_multi-prefill-seq_q8_ekv1280.task";

  Future<String> _modelPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return "${dir.path}/$_modelFileName";
  }

  /// 모델이 어느 경로든 존재하는지 확인.
  Future<bool> isModelDownloaded() async {
    if (!_isPlatformSupported) return false;
    if (await File(_devProjectAssetPath).exists()) return true;
    final path = await _modelPath();
    return File(path).exists();
  }

  /// 구 모델 파일 삭제 — 앱 시작 시 1회 호출.
  Future<void> cleanupLegacyModels() async {
    if (!_isPlatformSupported) return;
    final dir = await getApplicationDocumentsDirectory();
    for (final name in _legacyModelFileNames) {
      final file = File("${dir.path}/$name");
      if (await file.exists()) {
        await file.delete();
        debugPrint("[SlmService] 구 모델 삭제 완료: $name");
      }
    }
  }

  /// 실제로 로드에 사용할 경로 결정.
  Future<String> _resolveLoadPath() async {
    if (await File(_devProjectAssetPath).exists()) {
      debugPrint("[SlmService] dev 로컬 에셋 경로 사용: $_devProjectAssetPath");
      return _devProjectAssetPath;
    }
    final p = await _modelPath();
    debugPrint("[SlmService] application support 경로 사용: $p");
    return p;
  }

  // ── 다운로드 ──────────────────────────────────────────────────────────────
  Future<void> downloadModel({
    void Function(double progress)? onProgress,
  }) async {
    if (!_isPlatformSupported) return;
    if (await isModelDownloaded()) return;
    if (_isDownloading) return;

    _isDownloading = true;
    _downloadProgress = 0.0;
    final path = await _modelPath();

    try {
      await Dio(
        BaseOptions(
          receiveTimeout: const Duration(minutes: 30),
          connectTimeout: const Duration(seconds: 30),
          headers: _hfToken.isNotEmpty
              ? {'Authorization': 'Bearer $_hfToken'}
              : null,
        ),
      ).download(
        _modelUrl,
        path,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _downloadProgress = received / total;
            onProgress?.call(_downloadProgress);
          }
        },
      );
      debugPrint("[SlmService] 모델 다운로드 완료: $path");
    } catch (e) {
      // 부분 파일 정리
      final file = File(path);
      if (await file.exists()) await file.delete();
      debugPrint("[SlmService] 다운로드 실패: $e");
      rethrow;
    } finally {
      _isDownloading = false;
    }
  }

  // ── 로드 ──────────────────────────────────────────────────────────────────
  Future<void> load() async {
    if (_model != null) return;
    final activeLoad = _loadFuture;
    if (activeLoad != null) {
      await activeLoad;
      return;
    }

    final pendingLoad = _load();
    _loadFuture = pendingLoad;
    try {
      await pendingLoad;
    } finally {
      _loadFuture = null;
    }
  }

  Future<void> _load() async {
    if (!_isPlatformSupported) {
      throw UnsupportedError(
        'flutter_gemma은 iOS/Android만 지원합니다. macOS에서는 SLM을 사용할 수 없습니다.',
      );
    }
    if (_model != null) return;
    if (!await isModelDownloaded()) {
      throw StateError(
        "모델 파일이 없습니다. 먼저 downloadModel()을 호출하세요.",
      );
    }

    final path = await _resolveLoadPath();
    final gemma = FlutterGemmaPlugin.instance;
    await gemma.modelManager.setModelPath(path);
    _model = await gemma.createModel(
      modelType: ModelType.gemmaIt,
      maxTokens: _maxTokens,
    );
    // 세션은 generate()에서 lazy 생성.
    // load() 직후 바로 close→recreate 하면 XNNPACK delegate 충돌 발생.
    debugPrint("[SlmService] 모델 로드 완료");
  }

  /// KV 캐시 리셋 — 새로운 추론 전에 호출해 토큰 누적 overflow 방지.
  Future<void> resetSession() async {
    await _session?.close();
    _session = null;
  }

  Future<void> unload() async {
    _idleTimer?.cancel();
    await _session?.close();
    await _model?.close();
    _session = null;
    _model = null;
    debugPrint("[SlmService] 모델 unload");
  }

  // ── 추론 ──────────────────────────────────────────────────────────────────
  /// 스트리밍 토큰 (회상 질문, UI에 실시간 표시 좋음).
  Stream<String> generate(String prompt) async* {
    _resetIdleTimer();
    if (_model == null) {
      throw StateError("SLM not loaded. Call load() first.");
    }
    // lazy 생성 — generateAll()이 호출 전 세션을 닫아 리셋하므로 여기서는 생성만 담당.
    _session ??= await _model!.createSession(
      temperature: _temperature,
      topK: _topK,
    );
    try {
      await _session!.addQueryChunk(Message.text(text: prompt, isUser: true));
      await for (final token in _session!.getResponseAsync()) {
        yield token;
      }
    } catch (e) {
      await _session?.close();
      _session = null;
      rethrow;
    }
  }

  /// 전체 응답 한 번에 (환각 검증 후처리에 유리).
  /// 호출마다 세션 리셋 — KV 캐시 누적으로 인한 토큰 overflow 방지.
  Future<String> generateAll(String prompt) async {
    await resetSession();
    final buffer = StringBuffer();
    await for (final token in generate(prompt)) {
      buffer.write(token);
    }
    return buffer.toString();
  }

  // ── 환각 방지 후처리 ─────────────────────────────────────────────────────
  /// 시계열 코칭 출력 검증.
  /// session duration 초과한 시간대 언급 시 "중간쯤"으로 대체.
  String validateSessionCoachingOutput(String text, int durationMinutes) {
    final pattern = RegExp(r"(\d+)분쯤");
    return text.replaceAllMapped(pattern, (match) {
      final mentioned = int.tryParse(match.group(1) ?? "");
      if (mentioned == null) return match.group(0)!;
      if (mentioned > durationMinutes) return "중간쯤";
      return match.group(0)!;
    });
  }

  /// 회상 질문 출력 검증.
  /// 이모지/특수문자 제거 + "설명해보세요" 마무리 강제.
  /// 통과 못 하면 빈 문자열 반환 → 호출자가 fallback 사용.
  String validateRecallQuestion(String text) {
    final cleaned = text
        .replaceAll(
          RegExp(
            r"[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{1F000}-\u{1F02F}]",
            unicode: true,
          ),
          "",
        )
        .trim();
    if (!cleaned.contains("해보세요")) return "";
    return cleaned;
  }

  // ── idle 자동 unload ─────────────────────────────────────────────────────
  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleUnloadAfter, () async {
      debugPrint("[SlmService] 5분 idle → unload");
      await unload();
    });
  }
}
