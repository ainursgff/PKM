import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_vision/flutter_vision.dart';

class YoloService {
  FlutterVision? _vision;
  bool _modelLoaded = false;
  bool get isLoaded => _modelLoaded;

  Completer<void>? _loadCompleter;

  Future<void> loadModel() async {
    if (_modelLoaded) return;

    if (_loadCompleter != null) {
      await _loadCompleter!.future;
      return;
    }

    _loadCompleter = Completer<void>();

    try {
      debugPrint("YOLO ▶ load model start...");

      /// GPU delegate bisa crash di native level (SEGFAULT) pada device budget
      /// (Adreno 610 dll) — tidak bisa di-catch oleh Dart try-catch.
      /// Gunakan CPU langsung untuk stabilitas di semua device.
      _modelLoaded = await _tryLoadModel(useGpu: false);

      if (_modelLoaded) {
        debugPrint("YOLO ✅ model loaded");
      } else {
        debugPrint("YOLO ❌ model gagal dimuat");
        _vision = null;
      }
    } catch (e, s) {
      debugPrint("YOLO ❌ load model error: $e");
      debugPrint("$s");
      _modelLoaded = false;
      _vision = null;
    } finally {
      if (_loadCompleter != null && !_loadCompleter!.isCompleted) {
        _loadCompleter!.complete();
      }
      if (!_modelLoaded) {
        _loadCompleter = null;
      }
    }
  }

  /// Load model dengan opsi GPU on/off
  Future<bool> _tryLoadModel({required bool useGpu}) async {
    try {
      _vision = FlutterVision();

      await _vision!.loadYoloModel(
        labels: 'assets/models/labels.txt',
        modelPath: 'assets/models/yolo.tflite',
        modelVersion: "yolov8",
        quantization: false,
        numThreads: 2,
        useGpu: useGpu,
      );

      debugPrint("YOLO ▶ loaded with ${useGpu ? 'GPU' : 'CPU'}");
      return true;
    } catch (e) {
      debugPrint("YOLO ⚠️ ${useGpu ? 'GPU' : 'CPU'} load failed: $e");
      _vision = null;
      return false;
    }
  }

  /// Deteksi objek pada file gambar.
  /// [knownWidth] dan [knownHeight] bisa diisi jika dimensi sudah diketahui
  /// (menghindari decode gambar ulang).
  Future<List<Map<String, dynamic>>> detect(
    String path, {
    int? knownWidth,
    int? knownHeight,
    double iouThreshold = 0.45,
    double confThreshold = 0.15,
    double classThreshold = 0.15,
  }) async {
    if (_loadCompleter != null && !_loadCompleter!.isCompleted) {
      await _loadCompleter!.future;
    }

    if (!_modelLoaded || _vision == null) {
      debugPrint("YOLO ❌ model not ready");
      return [];
    }

    try {
      final bytes = await File(path).readAsBytes();

      int imageWidth;
      int imageHeight;

      /// Skip decode jika dimensi sudah diketahui dari caller
      if (knownWidth != null && knownHeight != null) {
        imageWidth = knownWidth;
        imageHeight = knownHeight;
      } else {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        imageWidth = frame.image.width;
        imageHeight = frame.image.height;
        frame.image.dispose();
      }

      debugPrint(
        "YOLO ▶ detect image: ${imageWidth}x$imageHeight (${bytes.length} bytes)",
      );

      final results = await _vision!.yoloOnImage(
        bytesList: bytes,
        imageHeight: imageHeight,
        imageWidth: imageWidth,
        iouThreshold: iouThreshold,
        confThreshold: confThreshold,
        classThreshold: classThreshold,
      );

      return _mapResults(results);
    } catch (e, s) {
      debugPrint("YOLO ❌ detect error: $e");
      debugPrint("$s");
      return [];
    }
  }

  List<Map<String, dynamic>> _mapResults(List<dynamic> results) {
    final List<Map<String, dynamic>> mapped = [];

    for (final r in results) {
      try {
        if (r['box'] == null || r['tag'] == null) continue;

        final rawBox = (r['box'] as List);
        if (rawBox.length < 5) continue;

        final x1 = (rawBox[0] as num).toDouble();
        final y1 = (rawBox[1] as num).toDouble();
        final x2 = (rawBox[2] as num).toDouble();
        final y2 = (rawBox[3] as num).toDouble();
        final conf = (rawBox[4] as num).toDouble();
        final tag = r['tag'] as String;

        if (conf < 0.15) continue;

        mapped.add({
          'label': tag,
          'confidence': conf,
          'box': [x1, y1, x2, y2],
        });
      } catch (_) {
        continue;
      }
    }

    return mapped;
  }

  void dispose() {
    _vision?.closeYoloModel();
    _vision = null;
    _modelLoaded = false;
    _loadCompleter = null;
  }
}
