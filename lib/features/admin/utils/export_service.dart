import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Utility for converting admin data to CSV strings and writing share-ready files.
/// No external packages required for CSV — pure Dart string building.
class ExportService {
  ExportService._();

  /// Converts a list of meal log maps (with optional `display_name`) to CSV.
  static String mealLogsToCsv(List<Map<String, dynamic>> logs) {
    final sb = StringBuffer();
    sb.writeln('id,user_id,food_id,food_name,servings,confidence,eaten_at');
    for (final log in logs) {
      final id = _cell(log['id']);
      final userId = _cell(log['user_id']);
      final foodId = _cell(log['food_id']);
      final foodName = _cell(log['display_name'] ?? log['food_name']);
      final servings = _cell(log['servings']);
      final confidence = _cell(log['confidence']);
      final eatenAt = _cell(log['eaten_at']);
      sb.writeln('$id,$userId,$foodId,$foodName,$servings,$confidence,$eatenAt');
    }
    return sb.toString();
  }

  /// Converts a list of app_users maps to CSV.
  /// Columns: id, email, role, created_at
  static String userListToCsv(List<Map<String, dynamic>> profiles) {
    final sb = StringBuffer();
    sb.writeln('id,email,role,created_at');
    for (final p in profiles) {
      final id = _cell(p['id']);
      final email = _cell(p['email']);
      final role = _cell(p['role']);
      final createdAt = _cell(p['created_at']);
      sb.writeln('$id,$email,$role,$createdAt');
    }
    return sb.toString();
  }

  /// Writes [content] to a temporary file named [fileName] and returns it.
  /// The caller is responsible for sharing or deleting the file.
  static Future<File> createTempCsvFile(String fileName, String content) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    return file.writeAsString(content);
  }

  /// Wraps a value in CSV-safe quotes and escapes internal quotes.
  static String _cell(dynamic value) {
    if (value == null) return '""';
    final s = value.toString().replaceAll('"', '""');
    return '"$s"';
  }
}
