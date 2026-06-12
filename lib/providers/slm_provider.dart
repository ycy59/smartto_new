// ─────────────────────────────────────────────────────────────────────────────
// SlmProvider — Riverpod 통합
//
// 두 가지 provider:
//   - slmServiceProvider       : SlmService 싱글턴
//   - slmDownloadStateProvider : 모델 다운로드 상태 (앱 시작 시 자동 체크)
//
// 앱 lifecycle:
//   1. main.dart 진입 → slmDownloadStateProvider 첫 watch → 자동 다운로드 트리거
//   2. UI에서 진행률 표시
//   3. 다운로드 완료 → isReady = true → 호출자가 SlmService.load() 가능
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/slm_service.dart';

/// SLM 서비스 싱글턴.
/// dispose 시 자동 unload.
final slmServiceProvider = Provider<SlmService>((ref) {
  final service = SlmService();
  ref.onDispose(() => service.unload());
  return service;
});

class SlmDownloadState {
  final bool isDownloading;
  final double progress; // 0.0 ~ 1.0
  final bool isReady;
  final String? error;

  const SlmDownloadState({
    required this.isDownloading,
    required this.progress,
    required this.isReady,
    this.error,
  });

  SlmDownloadState copyWith({
    bool? isDownloading,
    double? progress,
    bool? isReady,
    String? error,
  }) =>
      SlmDownloadState(
        isDownloading: isDownloading ?? this.isDownloading,
        progress: progress ?? this.progress,
        isReady: isReady ?? this.isReady,
        error: error,
      );

  static const idle = SlmDownloadState(
    isDownloading: false,
    progress: 0.0,
    isReady: false,
  );
}

final slmDownloadStateProvider =
    StateNotifierProvider<SlmDownloadNotifier, SlmDownloadState>(
  (ref) => SlmDownloadNotifier(ref),
);

class SlmDownloadNotifier extends StateNotifier<SlmDownloadState> {
  final Ref ref;
  SlmDownloadNotifier(this.ref) : super(SlmDownloadState.idle) {
    _checkAndDownload();
  }

  Future<void> _checkAndDownload() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      state = state.copyWith(
        error: 'SLM은 iOS/Android에서만 지원됩니다.',
        isReady: false,
      );
      return;
    }
    final slm = ref.read(slmServiceProvider);
    if (await slm.isModelDownloaded()) {
      state = state.copyWith(isReady: true, progress: 1.0);
      return;
    }
    await downloadNow();
  }

  /// 사용자가 수동으로 재시도하고 싶을 때.
  Future<void> downloadNow() async {
    final slm = ref.read(slmServiceProvider);
    state = state.copyWith(isDownloading: true, error: null);
    try {
      await slm.downloadModel(
        onProgress: (p) => state = state.copyWith(
          isDownloading: true,
          progress: p,
        ),
      );
      state = state.copyWith(
        isDownloading: false,
        progress: 1.0,
        isReady: true,
      );
    } catch (e) {
      state = state.copyWith(
        isDownloading: false,
        error: e.toString(),
        isReady: false,
      );
    }
  }
}
