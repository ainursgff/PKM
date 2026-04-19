import 'dart:io';

import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../ai_models/yolo_service.dart';
import '../../config.dart';
import 'edit.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with TickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? cameras;
  int selectedCameraIndex = 0;

  final YoloService _yolo = YoloService();
  final ImagePicker _imagePicker = ImagePicker();

  bool isCapturing = false;
  bool isDetecting = false;
  bool _isSwitchingCamera = false;

  String? capturedPath;
  Size? _scanSourceSize;

  List<Map<String, dynamic>> detections = [];
  List<String> confirmedIngredients = [];

  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _baseZoom = 1.0;
  DateTime? _lastZoomTime;

  FlashMode _flashMode = FlashMode.off;

  /// Tap-to-focus
  Offset? _focusPoint;
  bool _showFocusIndicator = false;
  late AnimationController _focusAnim;

  late AnimationController _shutterAnim;
  late Animation<double> _shutterScale;

  /// Scanning animation controller
  late AnimationController _scanAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    _shutterAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _shutterScale = Tween<double>(
      begin: 1.0,
      end: 0.88,
    ).animate(CurvedAnimation(parent: _shutterAnim, curve: Curves.easeInOut));

    _scanAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _focusAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _initEverything();
  }

  Future<void> _initEverything() async {
    await initCamera();
    _yolo.loadModel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _yolo.dispose();
    _shutterAnim.dispose();
    _scanAnim.dispose();
    _focusAnim.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _controller?.dispose();
      _controller = null; 
    } else if (state == AppLifecycleState.resumed) {
      if (_controller != null) return; // Mencegah double-inits jika hanya inactive!
      _createCameraController().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> initCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras == null || cameras!.isEmpty) return;

      selectedCameraIndex = cameras!.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (selectedCameraIndex == -1) selectedCameraIndex = 0;

      await _createCameraController();

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("ERROR CAMERA INIT: $e");
    }
  }

  Future<void> _createCameraController() async {
    if (cameras == null || cameras!.isEmpty) return;

    _controller = CameraController(
      cameras![selectedCameraIndex],
      ResolutionPreset.veryHigh, // CameraX: aman di semua GPU, kualitas HD untuk deteksi optimal
      enableAudio: false,
    );

    await _controller!.initialize();

    _minZoom = await _controller!.getMinZoomLevel();
    _maxZoom = await _controller!.getMaxZoomLevel();
    _currentZoom = _minZoom;
    await _controller!.setZoomLevel(_currentZoom);

    await _controller!.setFlashMode(_flashMode);
  }

  Future<void> switchCamera() async {
    if (_isSwitchingCamera) return;
    if (cameras == null || cameras!.length < 2) return;

    _isSwitchingCamera = true;

    try {
      selectedCameraIndex = (selectedCameraIndex + 1) % cameras!.length;

      await _controller?.dispose();
      await _createCameraController();

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("ERROR SWITCH CAMERA: $e");
    } finally {
      _isSwitchingCamera = false;
    }
  }

  void _onScaleStart(ScaleStartDetails _) {
    _baseZoom = _currentZoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final newZoom = (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);
    if (newZoom == _currentZoom) return;

    setState(() => _currentZoom = newZoom);

    // Throttle IPC Panggilan Native Android (Mencegah I/Camera spam refreshPreviewCaptureSession)
    final now = DateTime.now();
    if (_lastZoomTime == null || now.difference(_lastZoomTime!).inMilliseconds > 100) {
      _lastZoomTime = now;
      _controller?.setZoomLevel(_currentZoom);
    }
  }

  /// Tap-to-focus: fokus + exposure di titik yang di-tap
  void _onTapToFocus(TapUpDetails details, BoxConstraints constraints) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      _focusPoint = details.localPosition;
      _showFocusIndicator = true;
    });

    _focusAnim.forward(from: 0.0);

    /// Hanya set FocusMode.auto (continuous autofocus) — aman di semua device.
    /// setFocusPoint() dan setExposurePoint() bisa crash native (SEGFAULT)
    /// pada beberapa device budget (Vivo, Realme dll) karena bug camera HAL.
    try {
      await _controller!.setFocusMode(FocusMode.auto);
    } catch (e) {
      debugPrint("FOCUS ERROR: $e");
    }

    /// Sembunyikan indikator setelah 1.5 detik
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showFocusIndicator = false);
    });
  }

  void _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    FlashMode next;

    switch (_flashMode) {
      case FlashMode.off:
        next = FlashMode.torch;
        break;
      case FlashMode.torch:
        next = FlashMode.auto;
        break;
      case FlashMode.auto:
        next = FlashMode.always;
        break;
      case FlashMode.always:
        next = FlashMode.off;
        break;
    }

    try {
      await _controller!.setFlashMode(next);
      setState(() => _flashMode = next);
    } catch (e) {
      debugPrint("ERROR FLASH: $e");
    }
  }

  IconData get _flashIcon {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off_rounded;
      case FlashMode.torch:
        return Icons.flash_on_rounded;
      case FlashMode.auto:
        return Icons.flash_auto_rounded;
      case FlashMode.always:
        return Icons.flash_on_rounded;
    }
  }

  List<String> _extractConfirmedIngredients(List<Map<String, dynamic>> items) {
    return items
        .map((e) => e['label'].toString().replaceAll('_', ' ').toUpperCase())
        .toSet()
        .toList();
  }

  Future<void> _runDetection(
    String imagePath, {
    int? knownWidth,
    int? knownHeight,
  }) async {
    if (!mounted) return;
    setState(() => isDetecting = true);
    _scanAnim.repeat();

    try {
      final results = await _yolo.detect(
        imagePath,
        knownWidth: knownWidth,
        knownHeight: knownHeight,
      );

      debugPrint("DETEKSI YOLO BERHASIL: ${results.length} objek");

      if (!mounted) return;
      setState(() {
        detections = results;
        confirmedIngredients = _extractConfirmedIngredients(results);
        isDetecting = false;
      });
      _scanAnim.stop();
    } catch (e) {
      debugPrint("ERROR YOLO: $e");
      if (!mounted) return;
      setState(() => isDetecting = false);
      _scanAnim.stop();
    }
  }

  Future<void> takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (isCapturing) return;

    _shutterAnim.forward().then((_) => _shutterAnim.reverse());

    setState(() => isCapturing = true);

    try {
      final image = await _controller!.takePicture();
      debugPrint("Foto diambil: ${image.path}");

      if (!mounted) return;

      /// Decode gambar 1x untuk ambil dimensi ASLI (tanpa swap!)
      /// Koordinat YOLO backend selalu relatif terhadap dimensi asli gambar.
      /// Swap W/H akan merusak mapping bounding box untuk foto landscape.
      final imageFile = File(image.path);
      final fileSize = await imageFile.length();
      final bytes = await imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final imgW = frame.image.width.toDouble();
      final imgH = frame.image.height.toDouble();
      final shotSize = Size(imgW, imgH);
      frame.image.dispose();

      debugPrint("📸 Image: ${imgW.toInt()}x${imgH.toInt()}, ${(fileSize / 1024).toStringAsFixed(1)} KB, path: ${image.path}");


      if (!mounted) return;
      setState(() {
        capturedPath = image.path;
        _scanSourceSize = shotSize;
      });

      /// Pass dimensi ASLI ke YOLO — jangan pernah di-swap
      await _runDetection(
        image.path,
        knownWidth: imgW.toInt(),
        knownHeight: imgH.toInt(),
      );
    } catch (e) {
      debugPrint("ERROR TAKE PICTURE: $e");
      if (!mounted) return;
      setState(() => isCapturing = false);
    } finally {
      if (mounted) {
        setState(() => isCapturing = false);
      }
    }
  }

  Future<void> pickFromGallery() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image == null) return;

      if (!mounted) return;

      setState(() {
        isCapturing = true;
        isDetecting = true;
      });

      try {
        /// Decode gambar 1x untuk ambil dimensi ASLI
        final bytes = await File(image.path).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final imgW = frame.image.width.toDouble();
        final imgH = frame.image.height.toDouble();
        final shotSize = Size(imgW, imgH);
        frame.image.dispose();


        if (!mounted) return;

        setState(() {
          capturedPath = image.path;
          _scanSourceSize = shotSize;
          isCapturing = false;
        });

        /// Pass dimensi ASLI ke YOLO
        await _runDetection(
          image.path,
          knownWidth: imgW.toInt(),
          knownHeight: imgH.toInt(),
        );
      } catch (e) {
        debugPrint("ERROR YOLO GALERI: $e");
        if (!mounted) return;
        setState(() {
          isCapturing = false;
          isDetecting = false;
        });
      }
    } catch (e) {
      debugPrint("ERROR PICK GALLERY: $e");
      if (!mounted) return;
      setState(() {
        isCapturing = false;
        isDetecting = false;
      });
    }
  }

  void retake() {
    setState(() {
      capturedPath = null;
      _scanSourceSize = null;
      detections = [];
      confirmedIngredients = [];
      isDetecting = false;
      isCapturing = false;
    });
  }

  Future<void> _generateRecipe() async {
    if (confirmedIngredients.isEmpty) return;

    // Tampilkan popup loading UI
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: const [
            CircularProgressIndicator(color: Color(0xFFF57C00)),
            SizedBox(width: 20),
            Expanded(
              child: Text(
                "Meracik Resep AI...",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final response = await http.post(
        Uri.parse('${ServerConfig.apiBase}/ai/generate-recipe'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"bahan_bahan": confirmedIngredients}),
      );

      if (!mounted) return;
      Navigator.pop(context); // Tutup dialog loading

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final idResep = data['id_resep'];
        final recipeData = data['data'];

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              "✨ Resep AI Selesai",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              "Berhasil membuat: ${recipeData['nama_makanan']}\n\nResep ini telah dikarantina (Sandbox) menunggu persetujuan Admin.\nID Resep: $idResep",
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  retake(); // Restart camera setelah selesai
                },
                child: const Text(
                  "Tutup",
                  style: TextStyle(
                    color: Color(0xFFF57C00),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal: ${response.body}")));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Tutup dialog loading
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error koneksi: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (capturedPath != null) return _buildPreview();
    return _buildCamera();
  }

  Widget _buildCamera() {
    final isReady = _controller != null && _controller!.value.isInitialized;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        top: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
              if (isReady)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                  child: SizedBox.expand(
                    child: CameraPreview(_controller!),
                  ),
                ),

            if (!isReady)
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFF57C00),
                  strokeWidth: 2.5,
                ),
              ),

            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  _glassButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                    size: 40,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.document_scanner_rounded,
                          color: Color(0xFFF57C00),
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          "Scan Bahan",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _glassButton(icon: _flashIcon, onTap: _toggleFlash, size: 40),
                  const SizedBox(width: 8),
                  _glassButton(
                    icon: Icons.info_outline_rounded,
                    onTap: _showInfoDialog,
                    size: 40,
                  ),
                ],
              ),
            ),

            if (isReady && _currentZoom > _minZoom)
              Positioned(
                top: MediaQuery.of(context).padding.top + 68,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _currentZoom > _minZoom ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${_currentZoom.toStringAsFixed(1)}x",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            if (isReady)
              IgnorePointer(
                child: Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.72,
                    height: MediaQuery.of(context).size.width * 0.72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFF57C00).withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Stack(children: [..._buildCorners()]),
                  ),
                ),
              ),

            if (isReady)
              Positioned(
                bottom: 185,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "Arahkan kamera ke bahan makanan",
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            if (isReady)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onScaleStart: _onScaleStart,
                      onScaleUpdate: _onScaleUpdate,
                      onTapUp: (details) => _onTapToFocus(details, constraints),
                    );
                  },
                ),
              ),

            /// Focus indicator
            if (isReady && _showFocusIndicator && _focusPoint != null)
              Positioned(
                left: _focusPoint!.dx - 30,
                top: _focusPoint!.dy - 30,
                child: AnimatedBuilder(
                  animation: _focusAnim,
                  builder: (context, child) {
                    final scale = 1.4 - (0.4 * _focusAnim.value);
                    final opacity = 0.3 + (0.7 * _focusAnim.value);
                    return Transform.scale(
                      scale: scale,
                      child: Opacity(opacity: opacity, child: child),
                    );
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFF57C00),
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.center_focus_strong_rounded,
                        color: Color(0xFFF57C00),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),

            Positioned(
              bottom: 36,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _glassButton(
                      icon: Icons.photo_library_rounded,
                      onTap: pickFromGallery,
                      size: 52,
                    ),
                    _buildShutterButton(),
                    _glassButton(
                      icon: Icons.cameraswitch_rounded,
                      onTap: switchCamera,
                      size: 52,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShutterButton() {
    return GestureDetector(
      onTap: isCapturing ? null : takePicture,
      child: ScaleTransition(
        scale: _shutterScale,
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF57C00).withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isCapturing
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF57C00), Color(0xFFFF9800)],
                    ),
              color: isCapturing ? Colors.grey.shade800 : null,
            ),
            child: isCapturing
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Icon(
                    Icons.camera_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final sourceSize = _scanSourceSize ?? const Size(1, 1);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: const Color(0xFF0A0A0A))),

          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(File(capturedPath!), fit: BoxFit.contain),
                if (detections.isNotEmpty && !isDetecting)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: BoundingBoxPainter(
                          detections,
                          sourceSize: sourceSize,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: const Alignment(0, -0.3),
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: const Alignment(0, 0.3),
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _glassButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: retake,
                  size: 40,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: Color(0xFFF57C00),
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        "Hasil Scan",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 40),
              ],
            ),
          ),

          /// Scanning Animation
          if (isDetecting) _buildScanningOverlay(),

          if (!isDetecting)
            Positioned(
              bottom: 36,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  if (confirmedIngredients.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(
                            0xFFF57C00,
                          ).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFF57C00,
                                      ).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.restaurant_rounded,
                                      color: Color(0xFFF57C00),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    "Bahan (${confirmedIngredients.length})",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => EditIngredientsSheet(
                                      initialIngredients: confirmedIngredients,
                                      onSave: (newList) {
                                        setState(() {
                                          confirmedIngredients = newList;
                                        });
                                      },
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: Color(0xFFF57C00),
                                ),
                                label: const Text(
                                  "Edit",
                                  style: TextStyle(color: Color(0xFFF57C00)),
                                ),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ...confirmedIngredients.map(
                            (label) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF57C00),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (confirmedIngredients.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_off_rounded,
                            color: Colors.white38,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Tidak ada bahan terdeteksi.",
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                OutlinedButton(
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) =>
                                          EditIngredientsSheet(
                                            initialIngredients:
                                                confirmedIngredients,
                                            onSave: (newList) {
                                              setState(() {
                                                confirmedIngredients = newList;
                                              });
                                            },
                                          ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFFF57C00),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 0,
                                    ),
                                    minimumSize: const Size(0, 30),
                                  ),
                                  child: const Text(
                                    "Tambah Manual",
                                    style: TextStyle(
                                      color: Color(0xFFF57C00),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  const Text(
                    "Apakah bahan sudah sesuai?",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          label: const Text(
                            "Ulang",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: retake,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF57C00),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.auto_awesome, size: 20),
                          label: const Text(
                            "Buat Resep",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: _generateRecipe,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Scanning animation overlay — pulse + scan line
  Widget _buildScanningOverlay() {
    return Center(
      child: AnimatedBuilder(
        animation: _scanAnim,
        builder: (context, child) {
          final pulseScale = 1.0 + (_scanAnim.value * 0.08);
          final opacity = 0.6 + (0.4 * (1.0 - (_scanAnim.value * 2 - 1).abs()));

          return Transform.scale(
            scale: pulseScale,
            child: Opacity(opacity: opacity, child: child),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFF57C00).withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF57C00).withValues(alpha: 0.15),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  color: const Color(0xFFF57C00),
                  strokeWidth: 3,
                  value: null,
                  backgroundColor: const Color(
                    0xFFF57C00,
                  ).withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "Mendeteksi bahan...",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "AI sedang menganalisis gambar",
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 44,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.45),
      ),
    );
  }

  List<Widget> _buildCorners() {
    const color = Color(0xFFF57C00);
    const len = 22.0;
    const thickness = 3.0;

    return [
      Positioned(
        top: 0,
        left: 0,
        child: _corner(color, len, thickness, topLeft: true),
      ),
      Positioned(
        top: 0,
        right: 0,
        child: _corner(color, len, thickness, topRight: true),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        child: _corner(color, len, thickness, bottomLeft: true),
      ),
      Positioned(
        bottom: 0,
        right: 0,
        child: _corner(color, len, thickness, bottomRight: true),
      ),
    ];
  }

  Widget _corner(
    Color color,
    double len,
    double thickness, {
    bool topLeft = false,
    bool topRight = false,
    bool bottomLeft = false,
    bool bottomRight = false,
  }) {
    return SizedBox(
      width: len,
      height: len,
      child: CustomPaint(
        painter: _CornerPainter(
          color: color,
          thickness: thickness,
          topLeft: topLeft,
          topRight: topRight,
          bottomLeft: bottomLeft,
          bottomRight: bottomRight,
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFF57C00),
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              "Scan Bahan Makanan",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(icon: Icons.zoom_in, text: "Pinch untuk zoom"),
            SizedBox(height: 8),
            _InfoRow(icon: Icons.camera_alt, text: "Ambil foto bahan makanan"),
            SizedBox(height: 8),
            _InfoRow(icon: Icons.auto_awesome, text: "AI mendeteksi otomatis"),
            SizedBox(height: 8),
            _InfoRow(
              icon: Icons.photo_library,
              text: "Atau pilih foto dari galeri",
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Mengerti",
              style: TextStyle(
                color: Color(0xFFF57C00),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool topLeft, topRight, bottomLeft, bottomRight;

  _CornerPainter({
    required this.color,
    required this.thickness,
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    if (topLeft) {
      canvas.drawLine(Offset(0, h * 0.4), const Offset(0, 0), paint);
      canvas.drawLine(const Offset(0, 0), Offset(w * 0.4, 0), paint);
    }
    if (topRight) {
      canvas.drawLine(Offset(w, h * 0.4), Offset(w, 0), paint);
      canvas.drawLine(Offset(w, 0), Offset(w * 0.6, 0), paint);
    }
    if (bottomLeft) {
      canvas.drawLine(Offset(0, h * 0.6), Offset(0, h), paint);
      canvas.drawLine(Offset(0, h), Offset(w * 0.4, h), paint);
    }
    if (bottomRight) {
      canvas.drawLine(Offset(w, h * 0.6), Offset(w, h), paint);
      canvas.drawLine(Offset(w, h), Offset(w * 0.6, h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFF57C00), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final Size sourceSize;

  static const List<Color> classColors = [
    Color(0xFFFF6B35),
    Color(0xFF00C853),
    Color(0xFF2979FF),
    Color(0xFFFF1744),
    Color(0xFFAA00FF),
    Color(0xFFFFD600),
    Color(0xFF00E5FF),
    Color(0xFFFF4081),
    Color(0xFF76FF03),
  ];

  BoundingBoxPainter(this.detections, {required this.sourceSize});

  @override
  void paint(Canvas canvas, Size size) {
    if (sourceSize.width <= 0 || sourceSize.height <= 0) return;

    final fitted = applyBoxFit(BoxFit.contain, sourceSize, size);
    final destRect = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );

    final scaleX = destRect.width / sourceSize.width;
    final scaleY = destRect.height / sourceSize.height;

    final Map<String, int> labelColorIndex = {};
    int nextColor = 0;
    for (var det in detections) {
      final label = det['label'].toString();
      if (!labelColorIndex.containsKey(label)) {
        labelColorIndex[label] = nextColor;
        nextColor++;
      }
    }

    for (var det in detections) {
      final label = det['label'].toString();
      final colorIdx = labelColorIndex[label]! % classColors.length;
      final classColor = classColors[colorIdx];

      final paintBox = Paint()
        ..color = classColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      final paintTextBg = Paint()..color = classColor;

      final box = (det['box'] as List).cast<double>();
      final x1 = box[0];
      final y1 = box[1];
      final x2 = box[2];
      final y2 = box[3];

      final left = destRect.left + x1 * scaleX;
      final top = destRect.top + y1 * scaleY;
      final right = destRect.left + x2 * scaleX;
      final bottom = destRect.top + y2 * scaleY;
      final rect = Rect.fromLTRB(left, top, right, bottom);

      _drawCornerBox(canvas, rect, paintBox, cornerLen: 12);

      final labelText =
          "${label.replaceAll('_', ' ').toUpperCase()} ${(det['confidence'] * 100).toStringAsFixed(0)}%";

      final textSpan = TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final bgWidth = textPainter.width + 8;
      final bgHeight = textPainter.height + 4;

      double labelLeft = rect.left;
      if (labelLeft + bgWidth > destRect.right) {
        labelLeft = destRect.right - bgWidth;
      }
      if (labelLeft < destRect.left) labelLeft = destRect.left;

      double labelTop = rect.top - bgHeight - 2;
      if (labelTop < destRect.top) labelTop = rect.top + 2;
      if (labelTop + bgHeight > destRect.bottom) {
        labelTop = destRect.bottom - bgHeight;
      }

      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(labelLeft, labelTop, bgWidth, bgHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(bgRect, paintTextBg);
      textPainter.paint(canvas, Offset(labelLeft + 4, labelTop + 2));
    }
  }

  void _drawCornerBox(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    double cornerLen = 14,
  }) {
    final path = Path();

    path.moveTo(rect.left, rect.top + cornerLen);
    path.lineTo(rect.left, rect.top);
    path.lineTo(rect.left + cornerLen, rect.top);

    path.moveTo(rect.right - cornerLen, rect.top);
    path.lineTo(rect.right, rect.top);
    path.lineTo(rect.right, rect.top + cornerLen);

    path.moveTo(rect.right, rect.bottom - cornerLen);
    path.lineTo(rect.right, rect.bottom);
    path.lineTo(rect.right - cornerLen, rect.bottom);

    path.moveTo(rect.left + cornerLen, rect.bottom);
    path.lineTo(rect.left, rect.bottom);
    path.lineTo(rect.left, rect.bottom - cornerLen);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return !listEquals(oldDelegate.detections, detections) ||
        oldDelegate.sourceSize != sourceSize;
  }
}
