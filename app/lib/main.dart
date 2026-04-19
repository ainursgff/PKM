import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'halaman/reels.dart';
import 'halaman/camera/camera.dart';
import 'halaman/detail_makanan.dart';
import 'config.dart';

import 'partials/navbar.dart';
import 'partials/bottom.dart';
import 'partials/flash.dart';

void main() {
  runApp(const MyApp());
}

String get imageBase => ServerConfig.imageBase;

/// Resolve gambar: jika sudah URL lengkap, pakai langsung. Jika nama file, tambahkan imageBase.
String resolveImageUrl(String? foto) {
  if (foto == null || foto.isEmpty) return '';
  if (foto.startsWith('http')) return foto;
  return '$imageBase$foto';
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SmartCooks',

      theme: ThemeData(fontFamily: 'Montserrat', useMaterial3: true),

      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  int _selectedIndex = 0;

  /// STATE USER LOGIN
  Map<String, dynamic>? user;

  List<Map<String, dynamic>> makanan = [];
  List<Map<String, dynamic>> trending = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward();

    loadMakanan();
  }

  Future<void> loadMakanan() async {
    try {
      final raw = await ApiService.getMakanan();

      final List<Map<String, dynamic>> data = raw
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();

      final trendingVideo = data
          .where((m) => (m['url_video'] ?? '').toString().isNotEmpty)
          .toList();

      setState(() {
        makanan = data;
        trending = trendingVideo;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("ERROR LOAD MAKANAN: $e");

      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF6ED),

      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,

          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// NAVBAR
                NavbarSmartCooks(
                  user: user,

                  onLogin: (u) {
                    setState(() {
                      user = u;
                    });

                    /// SAPA USER SETELAH LOGIN
                    final namaUser = u['nama'] ?? "Chef";

                    FlashMessage.success(
                      context,
                      "Selamat datang di SmartCooks, $namaUser! 👋",
                    );
                  },

                  onLogout: () {
                    setState(() {
                      user = null;
                    });

                    FlashMessage.warning(
                      context,
                      "Anda telah logout dari SmartCooks",
                    );
                  },
                ),

                const SizedBox(height: 20),

                buildTrending(),

                const SizedBox(height: 25),

                buildGrid(),

                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ),

      /// BOTTOM NAVIGATION
      bottomNavigationBar: BottomNavSmartCooks(
        selectedIndex: _selectedIndex,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraPage()),
            );
            return;
          }

          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  Widget buildTrending() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            "Trending",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          height: 110,

          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),

                  itemCount: trending.length,

                  itemBuilder: (context, index) {
                    final item = trending[index];

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReelsPage(
                              videos: trending,
                              startIndex: index,
                              user: user,
                            ),
                          ),
                        );
                      },

                      child: Container(
                        width: 90,
                        margin: const EdgeInsets.only(right: 14),

                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.center,

                              children: [
                                Container(
                                  width: 72,
                                  height: 72,

                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.orange,
                                      width: 3,
                                    ),
                                  ),

                                  child: ClipOval(
                                    child: Image.network(
                                      resolveImageUrl(item['foto_utama']?.toString()),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),

                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),

                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.play_arrow,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            Text(
                              item['nama_makanan'] ?? "",
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,

                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget buildGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),

      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),

        itemCount: makanan.length,

        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          childAspectRatio: 0.8,
        ),

        itemBuilder: (context, index) {
          final item = makanan[index];

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetailMakananPage(makanan: item),
                ),
              );
            },
            child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              color: Colors.white,

              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(25),
                  ),

                  child: Image.network(
                    resolveImageUrl(item['foto_utama']?.toString()),
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(12),

                  child: Text(
                    item['nama_makanan'] ?? "",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          );
        },
      ),
    );
  }
}
