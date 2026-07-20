import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/memory_model.dart';

class StorageService {
  static const String _key = 'memories_data';

  static Future<void> saveMemories(List<MemoryModel> memories) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(memories.map((m) => m.toJson()).toList());
    await prefs.setString(_key, encodedData);
  }

  static Future<List<MemoryModel>> loadMemories() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_key);
    if (data == null) return [];
    
    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((item) => MemoryModel.fromMap(item)).toList(); // Necesitaremos un .fromMap en tu modelo
  }
}