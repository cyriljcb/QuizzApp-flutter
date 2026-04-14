import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';

class ApiService {
  static Future<List<String>> getAvailableThemes() async {
    final uri = Uri.parse('${AppConstants.baseUrl}/api/questions/themes');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<String>();
    }

    throw Exception('Impossible de charger les thèmes (${response.statusCode})');
  }
}