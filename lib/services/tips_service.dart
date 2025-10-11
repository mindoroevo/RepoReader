import 'package:shared_preferences/shared_preferences.dart';

class TipsService {
  static Future<bool> shouldShow(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('pref:tips:$key') ?? false);
  }

  static Future<void> markShown(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref:tips:$key', true);
  }
}

