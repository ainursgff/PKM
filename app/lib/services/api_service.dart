import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class ApiService {
  static String get baseUrl => ServerConfig.apiBase;

  /// ===============================
  /// GET MAKANAN
  /// ===============================
  static Future<List<dynamic>> getMakanan() async {
    final response = await http.get(Uri.parse("$baseUrl/makanan"));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception("Gagal mengambil data makanan");
  }

  /// ===============================
  /// LOGIN
  /// ===============================
  static Future<Map?> login(String email, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/login"),

      headers: {"Content-Type": "application/json"},

      body: jsonEncode({"email": email, "password": password}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    return null;
  }

  /// ===============================
  /// REGISTER
  /// ===============================
  static Future<Map?> register(
    String nama,
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/register"),

      headers: {"Content-Type": "application/json"},

      body: jsonEncode({"nama": nama, "email": email, "password": password}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    return null;
  }
}
