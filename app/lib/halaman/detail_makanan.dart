import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config.dart';

class DetailMakananPage extends StatefulWidget {
  final Map<String, dynamic> makanan;

  const DetailMakananPage({super.key, required this.makanan});

  @override
  State<DetailMakananPage> createState() => _DetailMakananPageState();
}

class _DetailMakananPageState extends State<DetailMakananPage>
    with TickerProviderStateMixin {
  bool isFavorited = false;
  bool isDescExpanded = false;

  late AnimationController _heartAnim;
  late AnimationController _slideAnim;
  late Animation<Offset> _slideOffset;
  late Animation<double> _fadeCurve;

  @override
  void initState() {
    super.initState();

    _heartAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideOffset = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideAnim, curve: Curves.easeOutCubic));

    _fadeCurve = CurvedAnimation(parent: _slideAnim, curve: Curves.easeOut);

    _slideAnim.forward();
  }

  @override
  void dispose() {
    _heartAnim.dispose();
    _slideAnim.dispose();
    super.dispose();
  }

  void _toggleFavorite() {
    setState(() => isFavorited = !isFavorited);
    if (isFavorited) {
      _heartAnim.forward(from: 0.0);
    }
  }

  String get _imageUrl {
    final foto = widget.makanan['foto_utama']?.toString() ?? '';
    if (foto.isEmpty) return '';
    if (foto.startsWith('http')) return foto;
    return '${ServerConfig.imageBase}$foto';
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.makanan;
    final nama = m['nama_makanan'] ?? 'Resep';
    final deskripsi = m['deskripsi'] ?? '';
    final pencipta = m['pencipta'] ?? 'SmartCooks';
    final imageUrl = _imageUrl;

    final List bahanList = m['bahan_bahan'] ?? [];
    final List langkahList = m['langkah'] ?? [];
    final int waktuMasak = m['waktu_masak'] ?? 0;
    final String kesulitan = m['tingkat_kesulitan'] ?? '-';
    final int kalori = m['kalori'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF6ED),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ═══════════════════════════════════════
          // HERO IMAGE + JUDUL
          // ═══════════════════════════════════════
          SliverAppBar(
            expandedHeight: 360,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFFFF7A00),
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gambar
                  imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _placeholderImage(),
                        )
                      : _placeholderImage(),

                  // Gradient overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.45, 1.0],
                          colors: [
                            Colors.black.withValues(alpha: 0.15),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.72),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Judul
                  Positioned(
                    bottom: 22,
                    left: 22,
                    right: 70,
                    child: Text(
                      nama,
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.2,
                        shadows: const [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 16,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ═══════════════════════════════════════
          // BODY
          // ═══════════════════════════════════════
          SliverToBoxAdapter(
            child: SlideTransition(
              position: _slideOffset,
              child: FadeTransition(
                opacity: _fadeCurve,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── PENCIPTA + DESKRIPSI + FAVORIT ──────
                    _buildCreatorAndDesc(pencipta, deskripsi),

                    // ─── STATISTIK ──────────────────────
                    if (waktuMasak > 0 || kalori > 0)
                      _buildStatsBar(waktuMasak, kesulitan, kalori),

                    // ─── BAHAN-BAHAN ────────────────────
                    if (bahanList.isNotEmpty) _buildBahanSection(bahanList),

                    // ─── LANGKAH-LANGKAH ────────────────
                    if (langkahList.isNotEmpty)
                      _buildLangkahSection(langkahList),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // PENCIPTA + DESKRIPSI (GABUNGAN)
  // ═══════════════════════════════════════════════
  Widget _buildCreatorAndDesc(String pencipta, String deskripsi) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
          topLeft: Radius.circular(4),
          topRight: Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: Avatar + Nama + Favorit
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF9800), Color(0xFFE65100)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF9800).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      pencipta.isNotEmpty
                          ? pencipta[0].toUpperCase()
                          : 'S',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Nama + label
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pencipta,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pencipta.toLowerCase().contains('ai')
                            ? '🤖 Resep AI'
                            : '👨‍🍳 Pencipta Resep',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tombol Favorit
                ScaleTransition(
                  scale: Tween<double>(begin: 1.0, end: 1.25).animate(
                    CurvedAnimation(
                      parent: _heartAnim,
                      curve: Curves.elasticOut,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(50),
                      onTap: _toggleFavorite,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFavorited
                              ? const Color(0xFFFFEBEE)
                              : Colors.grey.shade50,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: Icon(
                            isFavorited
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            key: ValueKey(isFavorited),
                            color: isFavorited
                                ? const Color(0xFFE53935)
                                : Colors.grey.shade400,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Deskripsi (di bawah pencipta, dalam card yang sama)
          if (deskripsi.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Divider(height: 1, color: Colors.grey.shade100),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: AnimatedCrossFade(
                firstChild: _descPreview(deskripsi),
                secondChild: _descFull(deskripsi),
                crossFadeState: isDescExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 280),
                sizeCurve: Curves.easeInOut,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: GestureDetector(
                onTap: () =>
                    setState(() => isDescExpanded = !isDescExpanded),
                child: Row(
                  children: [
                    Text(
                      isDescExpanded ? 'Sembunyikan' : 'Selengkapnya',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFE65100),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: isDescExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else
            const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _descPreview(String text) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.dmSans(
        fontSize: 13.5,
        height: 1.65,
        color: const Color(0xFF555555),
      ),
    );
  }

  Widget _descFull(String text) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 13.5,
        height: 1.65,
        color: const Color(0xFF555555),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // STATISTIK BAR
  // ═══════════════════════════════════════════════
  Widget _buildStatsBar(int waktu, String kesulitan, int kalori) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _statItem(Icons.timer_outlined, '$waktu mnt', 'Waktu'),
            _vertDivider(),
            _statItem(Icons.signal_cellular_alt_rounded,
                _cap(kesulitan), 'Level'),
            _vertDivider(),
            _statItem(
                Icons.local_fire_department_rounded, '$kalori kal', 'Kalori'),
          ],
        ),
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFFF57C00)),
        ),
        const SizedBox(height: 7),
        Text(value,
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: const Color(0xFF2D2D2D))),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.dmSans(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _vertDivider() =>
      Container(width: 1, height: 40, color: Colors.grey.shade100);

  // ═══════════════════════════════════════════════
  // BAHAN-BAHAN
  // ═══════════════════════════════════════════════
  Widget _buildBahanSection(List items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Bahan-bahan', Icons.shopping_basket_outlined,
              count: items.length),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, indent: 60, color: Colors.grey.shade100),
              itemBuilder: (_, i) {
                final b = items[i];
                final nama = b['nama'] ?? '';
                final jumlah = b['jumlah'] ?? '';
                final isUtama = (b['tipe'] ?? 'utama') == 'utama';

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      // Icon bahan
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isUtama
                              ? const Color(0xFFFFF3E0)
                              : const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          isUtama ? Icons.egg_outlined : Icons.eco_outlined,
                          size: 18,
                          color: isUtama
                              ? const Color(0xFFF57C00)
                              : const Color(0xFF66BB6A),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Nama bahan
                      Expanded(
                        child: Text(
                          nama,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: const Color(0xFF2D2D2D),
                          ),
                        ),
                      ),

                      // Jumlah
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF6ED),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFFFE0B2),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          jumlah,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFE65100),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // LANGKAH-LANGKAH (TIMELINE)
  // ═══════════════════════════════════════════════
  Widget _buildLangkahSection(List items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Langkah Memasak', Icons.menu_book_rounded),
          const SizedBox(height: 14),
          ...items.asMap().entries.map((entry) {
            final idx = entry.key;
            final step = entry.value is String
                ? entry.value
                : (entry.value['deskripsi_step'] ?? '');
            return _stepTile(idx + 1, step, isLast: idx == items.length - 1);
          }),
        ],
      ),
    );
  }

  Widget _stepTile(int number, String text, {bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline rail
          SizedBox(
            width: 38,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF9800), Color(0xFFE65100)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF9800).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$number',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2.5,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFFFF9800).withValues(alpha: 0.35),
                            const Color(0xFFFF9800).withValues(alpha: 0.06),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.035),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                text,
                style: GoogleFonts.dmSans(
                  fontSize: 13.5,
                  height: 1.65,
                  color: const Color(0xFF444444),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // SHARED HELPERS
  // ═══════════════════════════════════════════════
  Widget _sectionHeader(String title, IconData icon, {int? count}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFF7A00).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFFFF7A00)),
        ),
        const SizedBox(width: 10),
        Text(
          count != null ? '$title ($count)' : title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1A1A),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _placeholderImage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF8C00), Color(0xFFE65100)],
        ),
      ),
      child: const Center(
        child:
            Icon(Icons.restaurant_menu, size: 80, color: Colors.white30),
      ),
    );
  }

  String _cap(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
