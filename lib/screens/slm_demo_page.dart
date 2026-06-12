// ─────────────────────────────────────────────────────────────────────────────
// SLM UX 데모 화면.
//
// 실제 모델 호출 없이 더미 응답 + 스트리밍 시뮬레이션으로
// 최종 UX가 어떻게 보일지 미리 확인.
//
// 4가지 시나리오:
//   1. 회상 학습 (양방향): 질문 → 답변 → 평가
//   2. 학습 패턴 발견 (Report 페이지): 통계 → 자연어 코멘트
//   3. 회상 기록 페이지: 누적된 카드 + 패턴 코멘트 목록
//   4. 학습 카드: 작성한 답변이 과목별로 저장된 모습
//
// ── 디자인 노트 ──
// 다른 데모/테스트 페이지와 구분되도록 따뜻한 코랄 크림 팔레트 사용.
// (#fcfaf7 cream / #b86d6d coral / #f3e6e3 coral-tint)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';

// ── 팔레트 (이 페이지 전용) ────────────────────────────────────────────────
const _kBg = Color(0xFFFCFAF7);
const _kBgSurface = Color(0xFFF5F1EC);
const _kCoral = Color(0xFFB86D6D);
const _kCoralLight = Color(0xFFF3E6E3);
const _kCoralEdge = Color(0xFFDCC4C0);
const _kTextPrimary = Color(0xFF3A3733);
const _kTextSecondary = Color(0xFF6B6864);
const _kTextMuted = Color(0xFF9A9690);
const _kBorder = Color(0xFFD8D4CF);

class SlmDemoPage extends StatelessWidget {
  const SlmDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCoral,
        foregroundColor: _kBg,
        elevation: 0,
        title: const Text(
          "SLM UX 데모",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 상단 배너 (다른 페이지와 시각적 구분) ────────────────────────
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kCoralLight.withOpacity(0.55),
              border: Border.all(color: _kCoralEdge),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: _kCoral,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: _kBg,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "SLM 전용 데모",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _kTextPrimary,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "실제 모델 없이 더미 데이터로 UX 미리보기",
                        style: TextStyle(
                          color: _kTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 시점 그룹: 학습 종료 직후 ──────────────────────────────────
          _GroupHeader(
            label: "학습 종료 직후 · 즉시 실행",
            color: _kCoral,
            bg: _kCoralLight,
          ),
          const SizedBox(height: 8),
          _DemoCard(
            icon: Icons.help_outline,
            title: "1. 회상 학습 (할일 완료 시)",
            description:
                "할일을 완료하면 채팅 시트가 자동으로 슬라이드업, SLM이 회상 질문 생성. 답변하면 SLM이 평가.",
            sourceLabel: "SLM 자동",
            sourceIsSlm: true,
            onTap: () => _showRecallDemo(context),
          ),
          _DemoCard(
            icon: Icons.edit_note,
            title: "2. 답변 정리 카드",
            description: "본인이 작성한 답변이 과목별로 카드화되어 누적. 다시 보면서 복습 가능.",
            sourceLabel: "사용자 입력",
            sourceIsSlm: false,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _StudyCardsDemo()),
            ),
          ),

          const SizedBox(height: 16),

          // ── 시점 그룹: Report 페이지 ────────────────────────────────────
          _GroupHeader(
            label: "Report 페이지 · 별도 시점",
            color: _kTextSecondary,
            bg: const Color(0xFFE8E4DE),
          ),
          const SizedBox(height: 8),
          _DemoCard(
            icon: Icons.insights,
            title: "3. 학습 패턴 발견",
            description:
                "Report 페이지 진입 시, 통계(시간대·과목별 집중도)에서 의미 있는 신호를 자연어 한 줄로 짚어줌.",
            sourceLabel: "SLM 자동",
            sourceIsSlm: true,
            onTap: () => _showPatternDemo(context),
          ),
          _DemoCard(
            icon: Icons.history,
            title: "4. 회상 기록 페이지",
            description: "누적된 회상 카드 / 학습 패턴 코멘트를 다시 보기.",
            sourceLabel: "혼합",
            sourceIsSlm: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _RecallHistoryDemo()),
            ),
          ),
        ],
      ),
    );
  }

  void _showRecallDemo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => const _DummyChatSheet(
          scenario: _ChatScenario.recall,
        ),
      ),
    );
  }

  void _showPatternDemo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => const _DummyChatSheet(
          scenario: _ChatScenario.patternInsight,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 시점 그룹 헤더
// ─────────────────────────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _GroupHeader({
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 데모 카드 (출처 라벨 포함)
// ─────────────────────────────────────────────────────────────────────────────

class _DemoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String sourceLabel;
  final bool sourceIsSlm;
  final VoidCallback onTap;

  const _DemoCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.sourceLabel,
    required this.sourceIsSlm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = sourceIsSlm ? _kCoral : _kTextSecondary;
    final accentBg = sourceIsSlm ? _kCoralLight : const Color(0xFFF0ECE5);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kBg,
        border: Border.all(color: _kBorder, width: 1.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: _kTextPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accentBg,
                              border: Border.all(color: accent, width: 1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              sourceLabel,
                              style: TextStyle(
                                color: accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: const TextStyle(
                          color: _kTextSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: _kTextMuted.withOpacity(0.7)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 더미 채팅 시트 (회상 + 학습 패턴 발견 두 시나리오)
// ─────────────────────────────────────────────────────────────────────────────

enum _ChatScenario { recall, patternInsight }

class _DummyMessage {
  final String role; // 'user' | 'assistant' | 'meta'
  final String content;
  _DummyMessage({required this.role, required this.content});
}

class _DummyChatSheet extends StatefulWidget {
  final _ChatScenario scenario;
  const _DummyChatSheet({required this.scenario});

  @override
  State<_DummyChatSheet> createState() => _DummyChatSheetState();
}

class _DummyChatSheetState extends State<_DummyChatSheet> {
  final List<_DummyMessage> _messages = [];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isStreaming = false;
  bool _awaitingAnswer = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), _start);
  }

  Future<void> _start() async {
    if (widget.scenario == _ChatScenario.recall) {
      _messages.add(_DummyMessage(
        role: "meta",
        content: "수학 - 이차방정식 근의 공식 완료",
      ));
      setState(() {});
      await _streamAssistant(
        "이차방정식 근의 공식이 어떤 원리로 유도되는지 본인 말로 설명해보세요.",
        delayMs: 50,
      );
      setState(() => _awaitingAnswer = true);
    } else {
      _messages.add(_DummyMessage(
        role: "meta",
        content: "Report 페이지 진입 · 이번 주 데이터 분석",
      ));
      setState(() {});
      await _streamAssistant(
        "오후 3시 이후 집중도가 평균보다 25% 낮았어요. "
        "어려운 과목은 오전에 배치해보면 어떨까요?",
        delayMs: 35,
      );
    }
  }

  Future<void> _streamAssistant(String fullText, {int delayMs = 40}) async {
    setState(() {
      _isStreaming = true;
      _messages.add(_DummyMessage(role: "assistant", content: ""));
    });

    for (int i = 0; i < fullText.length; i++) {
      await Future.delayed(Duration(milliseconds: delayMs));
      if (!mounted) return;
      setState(() {
        _messages[_messages.length - 1] = _DummyMessage(
          role: "assistant",
          content: fullText.substring(0, i + 1),
        );
      });
      _scrollToBottom();
    }

    setState(() => _isStreaming = false);
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isStreaming) return;
    _inputController.clear();
    setState(() {
      _messages.add(_DummyMessage(role: "user", content: text));
      _awaitingAnswer = false;
    });
    _scrollToBottom();
    await Future.delayed(const Duration(milliseconds: 500));
    await _streamAssistant(
      "핵심 개념을 잘 짚으셨네요. 양변에 4ac를 더하는 단계까지 정확히 짚으셨어요. "
      "혹시 판별식 D = b² - 4ac까지 함께 알고 계신가요?",
      delayMs: 40,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: _kBg,
              border: Border(
                bottom: BorderSide(color: _kBorder),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: _kCoral),
                const SizedBox(width: 8),
                const Text(
                  "학습 도우미",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _kTextPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kCoralLight,
                    border: Border.all(color: _kCoral, width: 1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "더미 데모",
                    style: TextStyle(
                        fontSize: 11,
                        color: _kCoral,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: _kTextSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: _kBg,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (_, i) => _MessageBubble(message: _messages[i]),
              ),
            ),
          ),
          if (_isStreaming)
            Container(
              color: _kBg,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: const Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: _kCoral,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text("생각 중...",
                      style: TextStyle(color: _kTextMuted, fontSize: 12)),
                ],
              ),
            ),
          if (widget.scenario == _ChatScenario.recall)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: _kBg,
                border: Border(
                  top: BorderSide(color: _kBorder),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      enabled: _awaitingAnswer,
                      style: const TextStyle(color: _kTextPrimary),
                      decoration: InputDecoration(
                        hintText:
                            _awaitingAnswer ? "답변을 입력하세요" : "답변 입력 대기 중...",
                        hintStyle: const TextStyle(color: _kTextMuted),
                        border: const OutlineInputBorder(),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: _kBorder),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: _kCoral, width: 1.6),
                        ),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: _kCoral,
                    onPressed: _awaitingAnswer ? _send : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _DummyMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.role == "meta") {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _kBgSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.content,
            style: const TextStyle(color: _kTextSecondary, fontSize: 12),
          ),
        ),
      );
    }
    final isUser = message.role == "user";
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? _kCoral : _kBgSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser ? _kBg : _kTextPrimary,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 회상 기록 페이지 데모
// ─────────────────────────────────────────────────────────────────────────────

class _RecallHistoryDemo extends StatelessWidget {
  const _RecallHistoryDemo();

  static final List<Map<String, dynamic>> _dummy = [
    {
      "trigger": "goal_complete",
      "title": "목표 완료 후 회상",
      "subject": "수학",
      "date": "5/14 14:32",
      "question": "이차방정식 근의 공식이 어떤 원리로 유도되는지 설명해보세요.",
      "answer": "양변에 4ac를 더해서 완전제곱식으로 만들면 됩니다.",
    },
    {
      "trigger": "pattern_insight",
      "title": "학습 패턴 발견",
      "subject": "전체",
      "date": "5/14 13:00",
      "comment": "오후 3시 이후 집중도가 평균보다 25% 낮았어요. 어려운 과목은 오전에 배치해보면 어떨까요?",
    },
    {
      "trigger": "todo_complete",
      "title": "할 일 완료 후 회상",
      "subject": "영어",
      "date": "5/14 11:45",
      "question": "현재완료 시제가 단순 과거와 어떻게 다른지 설명해보세요.",
      "answer": "현재완료는 지금까지 이어지는 영향, 단순 과거는 그 시점에 끝난 사건.",
    },
    {
      "trigger": "goal_complete",
      "title": "목표 완료 후 회상",
      "subject": "한국사",
      "date": "5/13 21:15",
      "question": "프랑스 혁명의 핵심적인 사회적 배경을 설명해보세요.",
      "answer": "구체제의 신분 불평등과 재정 위기.",
    },
    {
      "trigger": "pattern_insight",
      "title": "학습 패턴 발견",
      "subject": "전체",
      "date": "5/13 19:30",
      "comment": "이번 주 영어 학습이 한국사보다 평균 1.5배 길었어요. 균형을 맞춰보면 어떨까요?",
    },
  ];

  IconData _iconFor(String t) => switch (t) {
        "goal_complete" => Icons.flag,
        "todo_complete" => Icons.check_circle,
        "pattern_insight" => Icons.insights,
        _ => Icons.chat,
      };

  Color _colorFor(String t) => switch (t) {
        "goal_complete" => _kCoral,
        "todo_complete" => _kCoral,
        "pattern_insight" => _kTextSecondary,
        _ => _kTextMuted,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCoral,
        foregroundColor: _kBg,
        elevation: 0,
        title: const Text("회상 기록"),
      ),
      body: ListView.separated(
        itemCount: _dummy.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: _kBorder),
        itemBuilder: (_, i) {
          final r = _dummy[i];
          return ListTile(
            tileColor: _kBg,
            leading: CircleAvatar(
              backgroundColor: _colorFor(r["trigger"]).withOpacity(0.15),
              child: Icon(_iconFor(r["trigger"]),
                  color: _colorFor(r["trigger"]), size: 20),
            ),
            title: Text(
              r["title"],
              style: const TextStyle(
                  color: _kTextPrimary, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              "${r["subject"]} · ${r["date"]}",
              style: const TextStyle(color: _kTextSecondary),
            ),
            trailing: const Icon(Icons.chevron_right, color: _kTextMuted),
            onTap: () => showModalBottomSheet(
              context: context,
              backgroundColor: _kBg,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => _RecallDetailDemo(data: r),
            ),
          );
        },
      ),
    );
  }
}

class _RecallDetailDemo extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RecallDetailDemo({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${data["subject"]} · ${data["date"]}",
            style: const TextStyle(color: _kTextSecondary),
          ),
          const SizedBox(height: 16),
          if (data["question"] != null) ...[
            const Text("질문",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: _kTextPrimary)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kBgSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                data["question"],
                style: const TextStyle(color: _kTextPrimary),
              ),
            ),
            const SizedBox(height: 12),
            const Text("내 답변",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: _kTextPrimary)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kCoralLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                data["answer"] ?? "",
                style: const TextStyle(color: _kTextPrimary),
              ),
            ),
          ] else if (data["comment"] != null) ...[
            const Text("코멘트",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: _kTextPrimary)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kBgSurface,
                border: Border.all(color: _kBorder),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                data["comment"],
                style: const TextStyle(color: _kTextPrimary, height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 과목별 학습 카드 데모
// ─────────────────────────────────────────────────────────────────────────────

class _StudyCardsDemo extends StatelessWidget {
  const _StudyCardsDemo();

  static final List<Map<String, dynamic>> _subjects = [
    {
      "name": "수학",
      "color": _kCoral,
      "summary": "회상 카드 3장 · 평균 집중도 78%",
      "insight": "수학은 풀이 과정을 설명하는 답변이 많았어요. 다음엔 공식이 등장하는 이유까지 말로 정리해보면 좋아요.",
      "cards": [
        {
          "type": "recall",
          "title": "이차방정식 근의 공식",
          "q": "이차방정식 근의 공식이 어떤 원리로 유도되는지 설명해보세요.",
          "a": "양변에 4ac를 더해서 완전제곱식으로 만들면 됩니다.",
          "feedback": "완전제곱식이라는 핵심을 잘 짚으셨네요. 판별식이 왜 등장하는지도 함께 정리하면 더 좋아요.",
          "date": "5/14",
          "focus": "82%",
        },
        {
          "type": "recall",
          "title": "미적분 기본정리",
          "q": "미적분 기본정리가 왜 미분과 적분을 연결하는지 설명해보세요.",
          "a": "적분의 도함수가 원함수라는 점.",
          "feedback": "미분과 적분의 역관계를 잘 잡으셨어요. 정적분의 누적량 관점도 함께 떠올리면 더 단단해져요.",
          "date": "5/12",
          "focus": "74%",
        },
        {
          "type": "recall",
          "title": "삼각함수 항등식",
          "q": "삼각함수의 항등식이 어떻게 유도되는지 설명해보세요.",
          "a": "단위원에서 좌표를 이용해서 유도.",
          "feedback": "단위원을 기준으로 설명한 점이 좋아요. sin과 cos가 좌표로 대응되는 이유까지 덧붙여보세요.",
          "date": "5/10",
          "focus": "79%",
        },
      ],
    },
    {
      "name": "영어",
      "color": _kTextSecondary,
      "summary": "회상 카드 2장 · 평균 집중도 71%",
      "insight": "영어는 문법 형태를 잘 기억하고 있어요. 예문 하나를 직접 만들어보는 방식이 특히 잘 맞아 보여요.",
      "cards": [
        {
          "type": "recall",
          "title": "현재완료 시제",
          "q": "현재완료 시제가 단순 과거와 어떻게 다른지 설명해보세요.",
          "a": "현재완료는 지금까지 이어지는 영향, 단순 과거는 그 시점에 끝난 사건.",
          "feedback":
              "시간의 연결감을 잘 설명하셨어요. since와 for를 함께 비교하면 실제 문제에서 더 빨리 판단할 수 있어요.",
          "date": "5/14",
          "focus": "76%",
        },
        {
          "type": "recall",
          "title": "가정법 과거완료",
          "q": "가정법 과거완료의 형태와 의미를 설명해보세요.",
          "a": "had p.p. + would have p.p. 형식이고 과거 사실 반대 상상.",
          "feedback": "형태와 의미를 모두 잡으셨어요. if절과 주절의 시제가 왜 달라지는지도 한 번 더 설명해보세요.",
          "date": "5/13",
          "focus": "66%",
        },
      ],
    },
    {
      "name": "한국사",
      "color": Color(0xFF8a7a5a),
      "summary": "회상 카드 1장 · 평균 집중도 69%",
      "insight": "한국사는 원인과 결과를 연결하는 답변이 필요해요. 사건을 시간 순서로 3단계만 나눠보면 복습 효과가 좋아요.",
      "cards": [
        {
          "type": "recall",
          "title": "프랑스 혁명",
          "q": "프랑스 혁명의 핵심적인 사회적 배경을 설명해보세요.",
          "a": "구체제의 신분 불평등과 재정 위기.",
          "feedback": "신분 불평등과 재정 위기라는 큰 원인을 잘 짚으셨어요. 시민 계급의 성장도 함께 연결해보면 좋아요.",
          "date": "5/13",
          "focus": "69%",
        },
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCoral,
        foregroundColor: _kBg,
        elevation: 0,
        title: const Text("내 학습 카드"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: _subjects.map((s) {
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: _kBg,
              border: Border.all(color: _kBorder),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: s["color"] as Color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        s["name"],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _kTextPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "${(s["cards"] as List).length}장",
                        style: const TextStyle(color: _kTextSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s["summary"] as String,
                    style: const TextStyle(
                      color: _kTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kCoralLight.withOpacity(0.5),
                      border: Border.all(color: _kCoralEdge),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.insights,
                                color: s["color"] as Color, size: 16),
                            const SizedBox(width: 6),
                            const Text(
                              "SLM 과목 인사이트",
                              style: TextStyle(
                                color: _kTextPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s["insight"] as String,
                          style: const TextStyle(
                            color: _kTextSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...((s["cards"] as List).map((c) => _SubjectStudyCard(
                        subject: s["name"] as String,
                        color: s["color"] as Color,
                        card: c as Map<String, dynamic>,
                      ))),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SubjectStudyCard extends StatelessWidget {
  final String subject;
  final Color color;
  final Map<String, dynamic> card;

  const _SubjectStudyCard({
    required this.subject,
    required this.color,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kBgSurface,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => showModalBottomSheet(
            context: context,
            backgroundColor: _kBg,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            builder: (_) => _SubjectCardDetailSheet(
              subject: subject,
              color: color,
              card: card,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      card["date"] as String,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      card["title"] as String,
                      style: const TextStyle(
                        color: _kTextPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    "집중 ${card["focus"]}",
                    style: const TextStyle(
                      color: _kTextMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right,
                    color: _kTextMuted,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                card["q"] as String,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: _kTextPrimary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                card["a"] as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _kTextSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectCardDetailSheet extends StatelessWidget {
  final String subject;
  final Color color;
  final Map<String, dynamic> card;

  const _SubjectCardDetailSheet({
    required this.subject,
    required this.color,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "$subject · ${card["title"]}",
                    style: const TextStyle(
                      color: _kTextPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: _kTextSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Text(
              "${card["date"]} · 집중 ${card["focus"]}",
              style: const TextStyle(color: _kTextSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _DetailBlock(
              label: "SLM 회상 질문",
              text: card["q"] as String,
              background: _kBgSurface,
            ),
            const SizedBox(height: 12),
            _DetailBlock(
              label: "내 답변",
              text: card["a"] as String,
              background: _kCoralLight.withOpacity(0.45),
            ),
            const SizedBox(height: 12),
            _DetailBlock(
              label: "SLM 피드백",
              text: card["feedback"] as String,
              background: _kBg,
              borderColor: _kCoralEdge,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  final String label;
  final String text;
  final Color background;
  final Color? borderColor;

  const _DetailBlock({
    required this.label,
    required this.text,
    required this.background,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _kTextPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: background,
            border: Border.all(color: borderColor ?? _kBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: _kTextPrimary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
