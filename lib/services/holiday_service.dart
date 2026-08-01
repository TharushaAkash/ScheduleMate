import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HolidayService {
  static const String _icsUrl =
      'https://calendar.google.com/calendar/ical/en.lk%23holiday%40group.v.calendar.google.com/public/basic.ics';
  static const String _cacheKey = 'cached_holidays';

  Future<Map<String, String>> loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        return Map<String, String>.from(jsonDecode(cached));
      } catch (e) {
        return {};
      }
    }
    return {};
  }

  Future<Map<String, String>> fetchLatest() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final response = await http.get(Uri.parse(_icsUrl)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final parsed = _parseIcs(response.body);
        if (parsed.isNotEmpty) {
          await prefs.setString(_cacheKey, jsonEncode(parsed));
          return parsed;
        }
      }
    } catch (e) {
      // network error, return empty so we don't overwrite cache with empty
    }
    return {};
  }

  Map<String, String> _parseIcs(String icsData) {
    final Map<String, String> holidays = {};
    final lines = icsData.split('\n');

    bool inEvent = false;
    String? currentDate;
    String? currentSummary;

    for (var line in lines) {
      line = line.trim();
      
      // Some ICS lines can be folded (start with space), but summary usually fits on one line 
      // or we just grab what we need simply.
      if (line == 'BEGIN:VEVENT') {
        inEvent = true;
        currentDate = null;
        currentSummary = null;
      } else if (line == 'END:VEVENT') {
        inEvent = false;
        if (currentDate != null && currentSummary != null) {
          holidays[currentDate] = currentSummary;
        }
      } else if (inEvent) {
        if (line.startsWith('DTSTART;VALUE=DATE:')) {
          final dateStr = line.substring('DTSTART;VALUE=DATE:'.length).trim();
          if (dateStr.length == 8) {
            final yyyy = dateStr.substring(0, 4);
            final mm = dateStr.substring(4, 6);
            final dd = dateStr.substring(6, 8);
            currentDate = '$yyyy-$mm-$dd';
          }
        } else if (line.startsWith('SUMMARY:')) {
          currentSummary = line.substring('SUMMARY:'.length).trim();
        }
      }
    }
    return holidays;
  }
}
