import 'package:flutter/material.dart';
import '../services/alarm_service.dart';

class AlarmSettingsScreen extends StatefulWidget {
  const AlarmSettingsScreen({super.key});

  @override
  State<AlarmSettingsScreen> createState() => _AlarmSettingsScreenState();
}

class _AlarmSettingsScreenState extends State<AlarmSettingsScreen> {
  final _alarm = AlarmService();

  late AlarmMode _mode;
  late double _volume;
  late String _soundAsset;
  bool _isPreviewing = false;

  static const _kBg     = Color(0xFFF8F8F8);
  static const _kText1  = Color(0xFF222222);

  @override
  void initState() {
    super.initState();
    _mode       = _alarm.mode;
    _volume     = _alarm.volume;
    _soundAsset = _alarm.soundAsset;
  }

  Future<void> _onModeChanged(AlarmMode m) async {
    await _alarm.setMode(m);
    setState(() => _mode = m);
  }

  Future<void> _onVolumeChanged(double v) async {
    await _alarm.setVolume(v);
    setState(() => _volume = v);
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
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _kText1),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '알람 설정',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _kText1,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false, // AppBar가 위쪽 Safe Area 처리
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            _SectionLabel('알람 모드'),
            _ModeSelector(current: _mode, onChanged: _onModeChanged),
            const SizedBox(height: 20),
            _SectionLabel('소리 설정'),
            _Card(
              children: [
                _VolumeRow(
                  volume: _volume,
                  enabled: _soundActive,
                  onChanged: _soundActive ? _onVolumeChanged : null,
                ),
                _Divider(),
                _SoundPickerRow(
                  current: _soundAsset,
                  enabled: _soundActive,
                  onChanged: _soundActive ? _onSoundChanged : null,
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_soundActive) ...[
              _SectionLabel('테스트'),
              _Card(
                children: [
                  _PreviewRow(
                    isPreviewing: _isPreviewing,
                    onTap: _togglePreview,
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            if (_mode == AlarmMode.vibrationOnly ||
                _mode == AlarmMode.soundAndVibration) ...[
              _SectionLabel('진동'),
              _Card(
                children: [
                  _InfoRow(
                    icon: Icons.vibration,
                    label: '진동 패턴',
                    value: '짧게 3회',
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ), // SafeArea
    );
  }
}

// ── 섹션 타이틀 ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF999999),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── 카드 컨테이너 ─────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(children: children),
    );
  }
}

// ── 구분선 ────────────────────────────────────────────────────────────────────
class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1, thickness: 1,
      color: Color(0xFFF0F0F0),
      indent: 14, endIndent: 14,
    );
  }
}

// ── 모드 선택 세그먼트 ────────────────────────────────────────────────────────
class _ModeSelector extends StatelessWidget {
  final AlarmMode current;
  final ValueChanged<AlarmMode> onChanged;
  const _ModeSelector({required this.current, required this.onChanged});

  static const _modes = [
    (mode: AlarmMode.silent,            icon: Icons.notifications_off_outlined,    label: '무음'),
    (mode: AlarmMode.vibrationOnly,     icon: Icons.vibration,                     label: '진동'),
    (mode: AlarmMode.soundOnly,         icon: Icons.volume_up_outlined,            label: '소리'),
    (mode: AlarmMode.soundAndVibration, icon: Icons.notifications_active_outlined, label: '소리+진동'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: _modes.map((m) {
          final isSelected = current == m.mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(m.mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 68, // 고정 높이 → 텍스트 길이 무관하게 동일
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFE05B5B) : const Color(0xFFF4F4F4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      m.icon,
                      size: 22,
                      color: isSelected ? Colors.white : const Color(0xFF888888),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      m.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF666666),
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
  const _VolumeRow({required this.volume, required this.enabled, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.volume_up_outlined,
                  size: 20,
                  color: enabled ? const Color(0xFF444444) : const Color(0xFFCCCCCC)),
              const SizedBox(width: 10),
              Text(
                '알람 볼륨',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: enabled ? const Color(0xFF222222) : const Color(0xFFCCCCCC),
                ),
              ),
              const Spacer(),
              Text(
                '${(volume * 100).round()}%',
                style: TextStyle(
                  fontSize: 13,
                  color: enabled ? const Color(0xFF888888) : const Color(0xFFCCCCCC),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: enabled ? const Color(0xFFE05B5B) : const Color(0xFFDDDDDD),
              inactiveTrackColor: const Color(0xFFEEEEEE),
              thumbColor: enabled ? const Color(0xFFE05B5B) : const Color(0xFFCCCCCC),
              overlayColor: const Color(0x22E05B5B),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: volume,
              min: 0.0,
              max: 1.0,
              onChanged: enabled ? onChanged : null,
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
  const _SoundPickerRow({required this.current, required this.enabled, this.onChanged});

  String get _currentLabel =>
      kAlarmSounds.firstWhere((s) => s.asset == current,
          orElse: () => kAlarmSounds.first).label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => _showSoundPicker(context) : null,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.music_note_outlined,
                size: 20,
                color: enabled ? const Color(0xFF444444) : const Color(0xFFCCCCCC)),
            const SizedBox(width: 10),
            Text(
              '알람 사운드',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: enabled ? const Color(0xFF222222) : const Color(0xFFCCCCCC),
              ),
            ),
            const Spacer(),
            Text(
              _currentLabel,
              style: TextStyle(
                fontSize: 13,
                color: enabled ? const Color(0xFF888888) : const Color(0xFFCCCCCC),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right,
                size: 18,
                color: enabled ? const Color(0xFFCCCCCC) : const Color(0xFFEEEEEE)),
          ],
        ),
      ),
    );
  }

  void _showSoundPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '알람 사운드 선택',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...kAlarmSounds.map((s) {
              final isSelected = s.asset == current;
              return ListTile(
                leading: Icon(Icons.music_note,
                    color: isSelected ? const Color(0xFFE05B5B) : const Color(0xFF888888)),
                title: Text(
                  s.label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? const Color(0xFFE05B5B) : const Color(0xFF222222),
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Color(0xFFE05B5B))
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
  const _PreviewRow({required this.isPreviewing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(
              isPreviewing ? Icons.stop_circle_outlined : Icons.play_circle_outlined,
              size: 22,
              color: const Color(0xFFE05B5B),
            ),
            const SizedBox(width: 10),
            Text(
              isPreviewing ? '재생 중... (탭하여 정지)' : '알람 미리듣기',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF222222),
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
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF444444)),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222))),
          const Spacer(),
          Text(value,
              style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
        ],
      ),
    );
  }
}
