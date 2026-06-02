import 'package:flutter_tts/flutter_tts.dart';

/// Singleton TTS service for turn-by-turn voice navigation.
/// Uses Indonesian language by default.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _enabled = true;

  bool get isEnabled => _enabled;
  set isEnabled(bool v) => _enabled = v;

  Future<void> _init() async {
    if (_initialized) return;
    await _tts.setLanguage('id-ID');
    await _tts.setSpeechRate(0.9);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _initialized = true;
  }

  Future<void> speak(String text) async {
    if (!_enabled) return;
    await _init();
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> speakInstruction(String instruction, {int step = 0}) async {
  if (!_enabled) return;
  final cleaned = instruction
      .replaceAllMapped(RegExp(r'\d+(\.\d+)? km'), (m) {
        return '${m.group(0)!.replaceAll('.', ',')} kilometer';
      })
      .replaceAllMapped(RegExp(r'\d+ m\b'), (m) {
        final meters = m.group(0)!.replaceAll(' m', '');
        return '$meters meter';
      });
  await speak(cleaned);
}

  Future<void> stop() async {
    await _tts.stop();
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}