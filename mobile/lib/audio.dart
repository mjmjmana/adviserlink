import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppAudio {
  static const _soundPreference = 'adviserlink_sound';
  static final _notificationPlayer = AudioPlayer();
  static final _bookingAlarmPlayer = AudioPlayer();
  static bool _enabled = true;

  static bool get enabled => _enabled;

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _enabled = preferences.getBool(_soundPreference) ?? true;
  }

  static Future<void> setEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_soundPreference, enabled);
    _enabled = enabled;
  }

  static Future<void> playNotification() =>
      _play(_notificationPlayer, 'sounds/elegant-notification-sound.ogg');

  static Future<void> playBookingAlarm() =>
      _play(_bookingAlarmPlayer, 'sounds/booking-alarm.mp3');

  static Future<void> playNotificationSafely() =>
      _playSafely(playNotification, 'notification');

  static Future<void> playBookingAlarmSafely() =>
      _playSafely(playBookingAlarm, 'booking alarm');

  static Future<void> _play(AudioPlayer player, String asset) async {
    if (!_enabled) return;
    await player.stop();
    await player.play(AssetSource(asset));
  }

  static Future<void> _playSafely(
    Future<void> Function() play,
    String soundName,
  ) async {
    try {
      await play();
    } on Exception catch (error, stackTrace) {
      debugPrint('Could not play AdviserLink $soundName: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
