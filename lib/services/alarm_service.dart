import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

enum AlarmMode {
  silent,
  vibrationOnly,
  soundOnly,
  soundAndVibration,
}

extension AlarmModeX on AlarmMode {
  String get key => name;
  String get label {
    switch (this) {
      case AlarmMode.silent:
        return '무음';
      case AlarmMode.vibrationOnly:
        return '진동';
      case AlarmMode.soundOnly:
        return '소리';
      case AlarmMode.soundAndVibration:
        return '소리+진동';
    }
  }
}

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final AudioPlayer _player = AudioPlayer();

  AlarmMode _mode = AlarmMode.soundAndVibration;
  double _volume = 0.8;
  String _soundAsset = 'sounds/alarm_bell.mp3';

  AlarmMode get mode => _mode;
  double get volume => _volume;
  String get soundAsset => _soundAsset;

  static const _kMode = 'alarm_mode';
  static const _kVolume = 'alarm_volume';
  static const _kSound = 'alarm_sound';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(_kMode);
    if (modeStr != null) {
      _mode = AlarmMode.values.firstWhere(
        (m) => m.key == modeStr,
        orElse: () => AlarmMode.soundAndVibration,
      );
    }
    _volume = prefs.getDouble(_kVolume) ?? 0.8;
    _soundAsset = prefs.getString(_kSound) ?? 'sounds/alarm_bell.mp3';
  }

  Future<void> setMode(AlarmMode mode) async {
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMode, mode.key);
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kVolume, _volume);
  }

  Future<void> setSoundAsset(String assetPath) async {
    _soundAsset = assetPath;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSound, assetPath);
  }

  Future<void> play() async {
    final playSound =
        _mode == AlarmMode.soundOnly || _mode == AlarmMode.soundAndVibration;
    final playVibrate = _mode == AlarmMode.vibrationOnly ||
        _mode == AlarmMode.soundAndVibration;

    if (playSound) {
      try {
        await _player.stop();
      } catch (_) {}
      await _player.setVolume(_volume);
      await _player.play(AssetSource(_soundAsset));
    }

    if (playVibrate) {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        Vibration.vibrate(pattern: [0, 400, 200, 400, 200, 400]);
      }
    }
  }

  Future<void> stop() async {
    await _player.stop();
    await Vibration.cancel();
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}

// ── 선택 가능한 알람 사운드 목록 ────────────────────────────────────────────
// assets/sounds/ 에 파일을 추가할 때마다 여기도 업데이트
const List<({String asset, String label})> kAlarmSounds = [
  (asset: 'sounds/alarm_bell.mp3', label: '벨 (기본)'),
];
