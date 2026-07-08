import 'dart:math';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MusicService — singleton background music manager
//
// Usage:
//   await MusicService.instance.init();
//   MusicService.instance.playHome();
//   MusicService.instance.playTraining();
//   MusicService.instance.setEnabled(false);
// ─────────────────────────────────────────────────────────────────────────────

enum MusicContext { home, training }

class MusicService {
  MusicService._();
  static final instance = MusicService._();

  static const _prefKey = 'music_enabled';

  static const _homeSongs = [
    'assets/music/home_song1.mp3',
    'assets/music/home_song2.mp3',
  ];
  static const _trainingSong = 'assets/music/chill_mode.mp3';

  final _player = AudioPlayer();
  bool _enabled = true;
  MusicContext? _currentContext;
  bool _initialized = false;

  bool get enabled => _enabled;

  // ── Init: load pref, don't start playing yet ────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefKey) ?? true;
  }

  // ── Toggle music on/off and persist ─────────────────────────────────────
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);

    if (!_enabled) {
      await _player.stop();
    } else {
      // Resume whichever context was active
      if (_currentContext == MusicContext.training) {
        await playTraining();
      } else {
        await playHome();
      }
    }
  }

  // ── Play a random home song on loop ─────────────────────────────────────
  Future<void> playHome() async {
    _currentContext = MusicContext.home;
    if (!_enabled) return;

    // Already playing home — don't restart
    if (_player.playing &&
        _player.processingState != ProcessingState.idle &&
        _currentContext == MusicContext.home) {
      return;
    }

    final song = _homeSongs[Random().nextInt(_homeSongs.length)];
    await _player.stop();
    await _player.setAsset(song);
    await _player.setLoopMode(LoopMode.one);
    await _player.setVolume(0.5);
    _player.play(); // fire-and-forget, runs in background
  }

  // ── Play the training song on loop ──────────────────────────────────────
  Future<void> playTraining() async {
    _currentContext = MusicContext.training;
    if (!_enabled) return;

    await _player.stop();
    await _player.setAsset(_trainingSong);
    await _player.setLoopMode(LoopMode.one);
    await _player.setVolume(0.5);
    _player.play();
  }

  // ── Stop all music ───────────────────────────────────────────────────────
  Future<void> stop() async {
    await _player.stop();
  }

  // ── Dispose (call from app lifecycle if needed) ──────────────────────────
  Future<void> dispose() async {
    await _player.dispose();
  }
}