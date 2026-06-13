import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../services/alarm_service.dart';

// ─────────────────────────────────────────────
// 동적 효과 헬퍼 (file-private)
// ─────────────────────────────────────────────
class _FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _FadeSlideIn({required this.child, this.delay = Duration.zero});

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, 0.06),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _PressableScale({required this.child, this.onTap});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 색상 토큰 (file-private)
// ─────────────────────────────────────────────
const _kAccent = Color(0xFFD97068);

Color _bgColor(bool isDark) =>
    isDark ? const Color(0xFF121212) : const Color(0xFFF7F4F2);
Color _cardColor(bool isDark) =>
    isDark ? const Color(0xFF1E1E1E) : Colors.white;
Color _cardBorder(bool isDark) =>
    isDark ? const Color(0xFF2E2E2E) : const Color(0xFFEEEEEE);
Color _dividerColor(bool isDark) =>
    isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0);
Color _primaryText(bool isDark) =>
    isDark ? Colors.white : const Color(0xFF1A1A1A);
Color _secondaryText(bool isDark) =>
    isDark ? const Color(0xFF9A9A9A) : const Color(0xFF888888);
Color _mutedText(bool isDark) =>
    isDark ? const Color(0xFF666666) : const Color(0xFFCCCCCC);

// ─────────────────────────────────────────────
// AlarmSettingsScreen
// ─────────────────────────────────────────────
class AlarmSettingsScreen extends ConsumerStatefulWidget {
  const AlarmSettingsScreen({super.key});

  @override
  ConsumerState<AlarmSettingsScreen> createState() =>
      _AlarmSettingsScreenState();
}

class _AlarmSettingsScreenState extends ConsumerState<AlarmSettingsScreen> {
  final _alarm = AlarmService();

  late AlarmMode _mode;
  late double _volume;
  late String _soundAsset;
  bool _isPreviewing = false;

  @override
  void initState() {
    super.initState();
    _mode = _alarm.mode;
    _volume = _alarm.volume;
    _soundAsset = _alarm.soundAsset;
  }

  Future<void> _onModeChanged(AlarmMode m) async {
    await _alarm.setMode(m);
    setState(() => _mode = m);
  }

  void _onVolumePreviewChanged(double v) {
    setState(() => _volume = v.clamp(0.0, 1.0));
  }

  Future<void> _persistVolume(double v) async {
    await _alarm.setVolume(v);
    if (mounted) {
      setState(() => _volume = _alarm.volume);
    }
  }

  Future<void> _onSoundChanged(String asset) async {
    await _alarm.setSoundAsset(asset);
    setState(() => _soundAsset = asset);
  }

  Future<void> _togglePreview() async {
    if (_isPreviewing) {
      await _alarm.stop();
      setState(() => _isPreviewing = false);
    } else {
      setState(() => _isPreviewing = true);
      await _alarm.play();
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        await _alarm.stop();
        setState(() => _isPreviewing = false);
      }
    }
  }

  bool get _soundActive =>
      _mode == AlarmMode.soundOnly || _mode == AlarmMode.soundAndVibration;

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    final bg = _bgColor(isDark);
    final showVibration = _mode == AlarmMode.vibrationOnly ||
        _mode == AlarmMode.soundAndVibration;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: _PressableScale(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.arrow_back_ios_new,
                size: 18, color: _primaryText(isDark)),
          ),
        ),
        title: Text(
          '알람 설정',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _primaryText(isDark),
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            _SectionLabel('알람 모드', isDark: isDark),
            _FadeSlideIn(
              child: _ModeSelector(
                current: _mode,
                onChanged: _onModeChanged,
                isDark: isDark,
              ),
            ),
            const SizedBox(height: 22),
            _SectionLabel('소리 설정', isDark: isDark),
            _FadeSlideIn(
              delay: const Duration(milliseconds: 90),
              child: _Card(
                isDark: isDark,
                children: [
                  _VolumeRow(
                    volume: _volume,
                    enabled: _soundActive,
                    onChanged: _soundActive ? _onVolumePreviewChanged : null,
                    onChangeEnd: _soundActive ? _persistVolume : null,
                    isDark: isDark,
                  ),
                  _Divider(isDark: isDark),
                  _SoundPickerRow(
                    current: _soundAsset,
                    enabled: _soundActive,
                    onChanged: _soundActive ? _onSoundChanged : null,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (_soundActive) ...[
              _SectionLabel('테스트', isDark: isDark),
              _FadeSlideIn(
                delay: const Duration(milliseconds: 180),
                child: _Card(
                  isDark: isDark,
                  children: [
                    _PreviewRow(
                      isPreviewing: _isPreviewing,
                      onTap: _togglePreview,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
            ],
            if (showVibration) ...[
              _SectionLabel('진동', isDark: isDark),
              _FadeSlideIn(
                delay: const Duration(milliseconds: 180),
                child: _Card(
                  isDark: isDark,
                  children: [
                    _InfoRow(
                      icon: Icons.vibration,
                      label: '진동 패턴',
                      value: '짧게 3회',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── 섹션 타이틀 ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const _SectionLabel(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _secondaryText(isDark),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── 카드 컨테이너 ─────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final List<Widget> children;
  final bool isDark;
  const _Card({required this.children, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder(isDark)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(children: children),
    );
  }
}

// ── 구분선 ────────────────────────────────────────────────────────────────────
class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: _dividerColor(isDark),
      indent: 14,
      endIndent: 14,
    );
  }
}

// ── 모드 선택 세그먼트 ────────────────────────────────────────────────────────
class _ModeSelector extends StatelessWidget {
  final AlarmMode current;
  final ValueChanged<AlarmMode> onChanged;
  final bool isDark;
  const _ModeSelector({
    required this.current,
    required this.onChanged,
    required this.isDark,
  });

  static const _modes = [
    (
      mode: AlarmMode.silent,
      icon: Icons.notifications_off_outlined,
      label: '무음'
    ),
    (mode: AlarmMode.vibrationOnly, icon: Icons.vibration, label: '진동'),
    (mode: AlarmMode.soundOnly, icon: Icons.volume_up_outlined, label: '소리'),
    (
      mode: AlarmMode.soundAndVibration,
      icon: Icons.notifications_active_outlined,
      label: '소리+진동'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder(isDark)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: _modes.map((m) {
          final isSelected = current == m.mode;
          return Expanded(
            child: _PressableScale(
              onTap: () => onChanged(m.mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 70,
                decoration: BoxDecoration(
                  color: isSelected
                      ? _kAccent
                      : (isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFF4F4F4)),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _kAccent.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      m.icon,
                      size: 22,
                      color: isSelected ? Colors.white : _secondaryText(isDark),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      m.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                ? const Color(0xFFB0B0B0)
                                : const Color(0xFF666666)),
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── 볼륨 슬라이더 ─────────────────────────────────────────────────────────────
class _VolumeRow extends StatelessWidget {
  final double volume;
  final bool enabled;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final bool isDark;
  const _VolumeRow({
    required this.volume,
    required this.enabled,
    this.onChanged,
    this.onChangeEnd,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = enabled ? _primaryText(isDark) : _mutedText(isDark);
    final iconColor = enabled
        ? (isDark ? const Color(0xFFCFCFCF) : const Color(0xFF444444))
        : _mutedText(isDark);
    final valueColor = enabled ? _secondaryText(isDark) : _mutedText(isDark);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.volume_up_outlined, size: 20, color: iconColor),
              const SizedBox(width: 10),
              Text(
                '알람 볼륨',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  '${(volume * 100).round()}%',
                  key: ValueKey((volume * 100).round()),
                  style: TextStyle(
                    fontSize: 13,
                    color: valueColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: enabled
                  ? _kAccent
                  : (isDark
                      ? const Color(0xFF3A3A3A)
                      : const Color(0xFFDDDDDD)),
              inactiveTrackColor:
                  isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE),
              thumbColor: enabled ? _kAccent : _mutedText(isDark),
              overlayColor: _kAccent.withValues(alpha: 0.16),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: volume,
              onChanged: enabled ? onChanged : null,
              onChangeEnd: enabled ? onChangeEnd : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 알람 사운드 선택 ──────────────────────────────────────────────────────────
class _SoundPickerRow extends StatelessWidget {
  final String current;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final bool isDark;
  const _SoundPickerRow({
    required this.current,
    required this.enabled,
    this.onChanged,
    required this.isDark,
  });

  String get _currentLabel => kAlarmSounds
      .firstWhere((s) => s.asset == current, orElse: () => kAlarmSounds.first)
      .label;

  @override
  Widget build(BuildContext context) {
    final labelColor = enabled ? _primaryText(isDark) : _mutedText(isDark);
    final iconColor = enabled
        ? (isDark ? const Color(0xFFCFCFCF) : const Color(0xFF444444))
        : _mutedText(isDark);
    final valueColor = enabled ? _secondaryText(isDark) : _mutedText(isDark);

    return _PressableScale(
      onTap: enabled ? () => _showSoundPicker(context) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.music_note_outlined, size: 20, color: iconColor),
            const SizedBox(width: 10),
            Text(
              '알람 사운드',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: labelColor,
                letterSpacing: -0.2,
              ),
            ),
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.2),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Text(
                _currentLabel,
                key: ValueKey(_currentLabel),
                style: TextStyle(
                  fontSize: 13,
                  color: valueColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: _mutedText(isDark)),
          ],
        ),
      ),
    );
  }

  void _showSoundPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF555555) : const Color(0xFFD0D0D0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '알람 사운드 선택',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _primaryText(isDark),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 14),
            ...kAlarmSounds.map((s) {
              final isSelected = s.asset == current;
              return ListTile(
                leading: Icon(Icons.music_note,
                    color: isSelected ? _kAccent : _secondaryText(isDark)),
                title: Text(
                  s.label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? _kAccent : _primaryText(isDark),
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: _kAccent)
                    : null,
                onTap: () {
                  onChanged?.call(s.asset);
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── 미리듣기 ──────────────────────────────────────────────────────────────────
class _PreviewRow extends StatelessWidget {
  final bool isPreviewing;
  final VoidCallback onTap;
  final bool isDark;
  const _PreviewRow({
    required this.isPreviewing,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                isPreviewing
                    ? Icons.stop_circle_outlined
                    : Icons.play_circle_outlined,
                key: ValueKey(isPreviewing),
                size: 22,
                color: _kAccent,
              ),
            ),
            const SizedBox(width: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                isPreviewing ? '재생 중... (탭하여 정지)' : '알람 미리듣기',
                key: ValueKey(isPreviewing),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _primaryText(isDark),
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 정보 표시 행 ──────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color:
                  isDark ? const Color(0xFFCFCFCF) : const Color(0xFF444444)),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _primaryText(isDark),
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: _secondaryText(isDark),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
