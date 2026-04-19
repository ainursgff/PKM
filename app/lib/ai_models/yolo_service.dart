import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class YoloService {
  bool _modelLoaded = false;
  bool get isLoaded => _modelLoaded;

  Future<void> loadModel() async {
    // Karena diproses di Backend, kita tidak perlu memuat model lokal.
    // Kita cukup set true agar CameraController tahu siap memotret.
    debugPrint("YOLO ▶ Ping server...");
    _modelLoaded = true;
    debugPrint("YOLO ✅ API Ready");
  }

  /// Deteksi menggunakan Backend API
  Future<List<Map<String, dynamic>>> detect(
    String path, {
    int? knownWidth,
    int? knownHeight,
    double iouThreshold = 0.45,
    double confThreshold = 0.15,
    double classThreshold = 0.15,
  }) async {
    if (!_modelLoaded) {
      debugPrint("YOLO ❌ service not ready");
      return [];
    }

    try {
      final file = File(path);
      final fileSize = await file.length();
      final ext = path.split('.').last.toLowerCase();
      debugPrint("YOLO ▶ sending image to API: $path");
      debugPrint("YOLO ▶ file size: ${(fileSize / 1024).toStringAsFixed(1)} KB, ext: $ext");

      final url = Uri.parse('${ServerConfig.apiBase}/detect');
      final request = http.MultipartRequest('POST', url);

      request.files.add(await http.MultipartFile.fromPath('image', path));

      final streamedRes = await request.send();
      final response = await http.Response.fromStream(streamedRes);

      if (response.statusCode == 200) {
        final List<dynamic> jsonArr = jsonDecode(response.body);

        final List<Map<String, dynamic>> results = [];
        for (var item in jsonArr) {
          final rawBox = item['box'] as List;
          final box = rawBox.map((v) => (v as num).toDouble()).toList();

          results.add({
            'label': item['label'],
            'confidence': (item['confidence'] as num).toDouble(),
            'box': box,
          });
        }

        debugPrint("YOLO ✅ API returned ${results.length} objects");
        return results;
      } else {
        debugPrint(
          "YOLO ❌ Server error: ${response.statusCode} - ${response.body}",
        );
        return [];
      }
    } catch (e, s) {
      debugPrint("YOLO ❌ detect error: $e");
      debugPrint("$s");
      return [];
    }
  }

  void dispose() {
    _modelLoaded = false;
  }
}
