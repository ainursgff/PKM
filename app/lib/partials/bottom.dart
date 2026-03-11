import 'package:flutter/material.dart';

class BottomNavSmartCooks extends StatelessWidget {

  final int selectedIndex;
  final Function(int) onTap;

  const BottomNavSmartCooks({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(vertical: 10),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),

        boxShadow: [

          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )

        ],
      ),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [

          _navItem(Icons.home, 0),
          _navItem(Icons.camera_alt, 1),
          _navItem(Icons.favorite, 2),

        ],
      ),
    );
  }

  Widget _navItem(IconData icon, int index) {

    return IconButton(

      icon: Icon(
        icon,
        size: 28,
        color: selectedIndex == index
            ? Colors.orange
            : Colors.grey.shade400,
      ),

      onPressed: () {
        onTap(index);
      },
    );
  }
}