import 'package:flutter/material.dart';

import '../halaman/login.dart';
import '../halaman/register.dart';

class NavbarSmartCooks extends StatelessWidget {

  final Map<String,dynamic>? user;
  final Function(Map<String,dynamic>) onLogin;
  final VoidCallback onLogout;

  const NavbarSmartCooks({
    super.key,
    required this.user,
    required this.onLogin,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),

      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFF8C00),
            Color(0xFFFF5E00),
          ],
        ),

        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),

      child: Column(
        children: [

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [

              const SizedBox(width: 30),

              Row(
                children: const [

                  Icon(
                    Icons.local_dining,
                    color: Colors.white,
                    size: 22,
                  ),

                  SizedBox(width: 6),

                  Text(
                    "SmartCooks",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                ],
              ),

              PopupMenuButton<String>(

                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.white,
                ),

                onSelected: (value) async {

                  /// LOGIN
                  if(value == "login"){

                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginPage(),
                      ),
                    );

                    if(result != null){
                      onLogin(result);
                    }

                  }

                  /// REGISTER
                  if(value == "register"){

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegisterPage(),
                      ),
                    );

                  }

                  /// LOGOUT
                  if(value == "logout"){
                    onLogout();
                  }

                  /// FAQ
                  if(value == "faq"){

                    showDialog(
                      context: context,
                      builder: (_) => const AlertDialog(
                        title: Text("FAQ"),
                        content: Text(
                          "SmartCooks adalah aplikasi resep modern dengan video reels memasak."
                        ),
                      ),
                    );

                  }

                  /// TENTANG
                  if(value == "about"){

                    showDialog(
                      context: context,
                      builder: (_) => const AlertDialog(
                        title: Text("Tentang Kami"),
                        content: Text(
                          "SmartCooks dibuat untuk mempermudah menemukan resep makanan melalui video."
                        ),
                      ),
                    );

                  }

                },

                itemBuilder: (context) {

                  /// JIKA BELUM LOGIN
                  if(user == null){

                    return [

                      const PopupMenuItem(
                        value: "login",
                        child: Row(
                          children: [
                            Icon(Icons.login,size:18),
                            SizedBox(width:10),
                            Text("Login"),
                          ],
                        ),
                      ),

                      const PopupMenuItem(
                        value: "register",
                        child: Row(
                          children: [
                            Icon(Icons.app_registration,size:18),
                            SizedBox(width:10),
                            Text("Register"),
                          ],
                        ),
                      ),

                      const PopupMenuDivider(),

                      const PopupMenuItem(
                        value: "faq",
                        child: Row(
                          children: [
                            Icon(Icons.help_outline,size:18),
                            SizedBox(width:10),
                            Text("FAQ"),
                          ],
                        ),
                      ),

                      const PopupMenuItem(
                        value: "about",
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,size:18),
                            SizedBox(width:10),
                            Text("Tentang Kami"),
                          ],
                        ),
                      ),

                    ];

                  }

                  /// JIKA SUDAH LOGIN
                  return [

                    PopupMenuItem(
                      enabled: false,
                      child: Text(
                        "Halo, ${user!['nama']}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),

                    const PopupMenuDivider(),

                    const PopupMenuItem(
                      value: "faq",
                      child: Row(
                        children: [
                          Icon(Icons.help_outline,size:18),
                          SizedBox(width:10),
                          Text("FAQ"),
                        ],
                      ),
                    ),

                    const PopupMenuItem(
                      value: "about",
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,size:18),
                          SizedBox(width:10),
                          Text("Tentang Kami"),
                        ],
                      ),
                    ),

                    const PopupMenuDivider(),

                    const PopupMenuItem(
                      value: "logout",
                      child: Row(
                        children: [
                          Icon(Icons.logout,size:18),
                          SizedBox(width:10),
                          Text("Logout"),
                        ],
                      ),
                    ),

                  ];

                },
              ),

            ],
          ),

          const SizedBox(height: 12),

          Container(
            height: 42,

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),

            child: const TextField(
              decoration: InputDecoration(
                hintText: "Cari makanan...",
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.orange,
                ),
                border: InputBorder.none,
              ),
            ),
          ),

        ],
      ),
    );
  }
}