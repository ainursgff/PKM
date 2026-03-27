import 'package:flutter/material.dart';

class FlashMessage {

  static void success(BuildContext context, String message) {
    _show(context, message);
  }

  static void error(BuildContext context, String message) {
    _show(context, message, isError: true);
  }

  static void warning(BuildContext context, String message) {
    _show(context, message, isWarning: true);
  }

  static void _show(
    BuildContext context,
    String message, {
    bool isError = false,
    bool isWarning = false,
  }) {

    final overlay = Overlay.of(context);

    late OverlayEntry entry;

    entry = OverlayEntry(

      builder: (context) {

        final width = MediaQuery.of(context).size.width;

        return Positioned(

          /// posisi sedikit lebih turun dari navbar
          top: MediaQuery.of(context).padding.top + 70,

          left: width * 0.08,
          right: width * 0.08,

          child: Material(
            color: Colors.transparent,

            child: TweenAnimationBuilder(
              duration: const Duration(milliseconds: 350),
              tween: Tween(begin: -20.0, end: 0.0),

              builder: (context, value, child) {

                return Transform.translate(
                  offset: Offset(0, value),
                  child: child,
                );

              },

              child: Container(

                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),

                decoration: BoxDecoration(

                  /// warna mengikuti navbar smartcooks
                  gradient: isError
                      ? const LinearGradient(
                          colors: [
                            Color(0xFFD32F2F),
                            Color(0xFFB71C1C)
                          ],
                        )
                      : const LinearGradient(
                          colors: [
                            Color(0xFFFF9800),
                            Color(0xFFFF6A00)
                          ],
                        ),

                  borderRadius: BorderRadius.circular(18),

                  boxShadow: [

                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0,6),
                    )

                  ],
                ),

                child: Row(

                  crossAxisAlignment: CrossAxisAlignment.center,

                  children: [

                    Container(

                      padding: const EdgeInsets.all(6),

                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),

                      child: Icon(
                        isError
                            ? Icons.error_outline
                            : Icons.waving_hand_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),

                    const SizedBox(width: 12),

                    /// TEXT RESPONSIVE
                    Expanded(
                      child: Text(
                        message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,

                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ),

                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);

    /// auto hide
    Future.delayed(const Duration(seconds: 3)).then((_) {
      entry.remove();
    });
  }
}