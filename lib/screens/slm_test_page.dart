// ─────────────────────────────────────────────────────────────────────────────
// SLM 테스트 화면.
//
// 목적:
//   - 모델 다운로드 상태 시각화
//   - 수동 로드/언로드
//   - 3종 프롬프트 (회상 질문, 답변 평가, 시계열 코칭) 실제 호출 테스트
//   - 출력을 실시간 스트리밍으로 표시
//
// 통합 전 검증 단계에서 쓰는 화면. 실제 출시 시엔 제거하거나 디버그 빌드에서만 노출.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/slm_provider.dart';
import '../widgets/prompts/slm_prompts.dart';

class SlmTestPage extends ConsumerStatefulWidget {
  const SlmTestPage({super.key});

  @override
  ConsumerState<SlmTestPage> createState() => _SlmTestPageState();
}

class _SlmTestPageState extends ConsumerState<SlmTestPage> {
  String _output = "";
  bool _isGenerating = false;
  Duration? _lastDuration;
  int _tokenCount = 0;

  Future<void> _runTest(String label, String prompt) async {
    setState(() {
      _output = "";
      _isGenerating = true;
      _lastDuration = null;
      _tokenCount = 0;
    });

    final slm = ref.read(slmServiceProvider);
    final stopwatch = Stopwatch()..start();

    try {
      if (!slm.modelReady) {
        await slm.load();
      }
      await for (final token in slm.generate(prompt)) {
        setState(() {
          _output += token;
          _tokenCount++;
        });
      }
    } catch (e) {
      setState(() => _output = "[$label 실패]\n$e");
    } finally {
      stopwatch.stop();
      setState(() {
        _isGenerating = false;
        _lastDuration = stopwatch.elapsed;
      });
    }
  }

  Future<void> _testRecallQuestion() => _runTest(
        "회상 질문",
        SlmPrompts.recallQuestion(
          subject: "수학",
          title: "이차방정식 근의 공식",
          mode: "study",
        ),
      );

  Future<void> _testSessionCoaching() => _runTest(
        "시계열 코칭",
        SlmPrompts.sessionCoaching(
          subject: "수학",
          durationMinutes: 25,
          avgScorePercent: 72,
          patternDescription: "초반 0.85였다가 15분쯤부터 0.5로 하락",
        ),
      );

  Future<void> _testEvaluate() => _runTest(
        "답변 평가",
        SlmPrompts.evaluateAnswer(
          question: "이차방정식 근의 공식이 어떤 원리로 유도되는지 설명해보세요.",
          userAnswer: "양변에 4ac를 더해서 완전제곱식으로 만들면 됩니다.",
        ),
      );

  Future<void> _unload() async {
    final slm = ref.read(slmServiceProvider);
    await slm.unload();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(slmDownloadStateProvider);
    final slm = ref.read(slmServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("SLM 테스트")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 다운로드 상태 ──────────────────────────────
            _Section(
              title: "1. 모델 다운로드 상태",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_downloadStatusText(downloadState)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: downloadState.progress,
                    minHeight: 8,
                  ),
                  const SizedBox(height: 8),
                  if (downloadState.error != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "에러: ${downloadState.error}\n\n"
                        "→ slm_service.dart의 _modelUrl을 본인 HuggingFace URL로 교체하세요.",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: downloadState.isDownloading
                            ? null
                            : () => ref
                                .read(slmDownloadStateProvider.notifier)
                                .downloadNow(),
                        child: const Text("다시 시도"),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── 모델 로드 상태 ──────────────────────────────
            _Section(
              title: "2. 모델 로드",
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: slm.modelReady ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(slm.modelReady ? "로드됨" : "로드 안 됨"),
                  const Spacer(),
                  if (slm.modelReady)
                    TextButton(
                      onPressed: _unload,
                      child: const Text("Unload"),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── 프롬프트 테스트 ──────────────────────────────
            _Section(
              title: "3. 프롬프트 테스트",
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: _isGenerating || !downloadState.isReady
                        ? null
                        : _testRecallQuestion,
                    child: const Text("회상 질문"),
                  ),
                  ElevatedButton(
                    onPressed: _isGenerating || !downloadState.isReady
                        ? null
                        : _testEvaluate,
                    child: const Text("답변 평가"),
                  ),
                  ElevatedButton(
                    onPressed: _isGenerating || !downloadState.isReady
                        ? null
                        : _testSessionCoaching,
                    child: const Text("시계열 코칭"),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── 출력 ──────────────────────────────────────
            _Section(
              title: "4. 출력",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 120),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _output.isEmpty
                          ? (_isGenerating ? "생성 중..." : "버튼을 눌러 테스트하세요.")
                          : _output,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_lastDuration != null)
                    Text(
                      "추론 시간: ${_lastDuration!.inMilliseconds}ms / "
                      "토큰: $_tokenCount개 / "
                      "속도: ${_tokenCount > 0 && _lastDuration!.inMilliseconds > 0 ? (_tokenCount * 1000 / _lastDuration!.inMilliseconds).toStringAsFixed(1) : '0'} tok/s",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _downloadStatusText(SlmDownloadState s) {
    if (s.isReady) return "다운로드 완료 ✓";
    if (s.isDownloading) {
      return "다운로드 중... ${(s.progress * 100).toStringAsFixed(1)}%";
    }
    if (s.error != null) return "다운로드 실패";
    return "대기 중";
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
