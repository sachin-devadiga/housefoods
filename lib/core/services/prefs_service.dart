import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  static const String _searchHistoryKey = 'recent_searches';

  /// Saves a search query to the history list
  static Future<void> saveSearchQuery(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_searchHistoryKey) ?? [];
    
    // Remove if already exists to move it to the top
    history.remove(query);
    history.insert(0, query);
    
    // Keep only the last 10 searches
    if (history.length > 10) {
      history = history.sublist(0, 10);
    }
    
    await prefs.setStringList(_searchHistoryKey, history);
  }

  /// Retrieves the stored search history
  static Future<List<String>> getSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_searchHistoryKey) ?? [];
  }

  /// Clears all stored search history
  static Future<void> clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_searchHistoryKey);
  }
}
