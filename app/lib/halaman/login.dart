import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../partials/flash.dart';
import 'register.dart';
import '../main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();

  bool loading = false;

  Future<void> login() async {

    /// VALIDASI FORM
    if(email.text.isEmpty || password.text.isEmpty){

      FlashMessage.warning(
        context,
        "Email dan password wajib diisi"
      );

      return;
    }

    setState(() {
      loading = true;
    });

    try{

      final res = await ApiService.login(
        email.text.trim(),
        password.text.trim(),
      );

      setState(() {
        loading = false;
      });

      if(res != null){

        FlashMessage.success(
          context,
          "Login berhasil"
        );

        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pop(context, res["user"]);
        });

      }else{

        FlashMessage.error(
          context,
          "Email atau password salah"
        );

      }

    }catch(e){

      setState(() {
        loading = false;
      });

      FlashMessage.error(
        context,
        "Terjadi kesalahan server"
      );

    }

  }

  @override
  Widget build(BuildContext context) {

return Scaffold(

  backgroundColor: const Color(0xFFFFF6ED),

  appBar: AppBar(
    title: const Text("Login"),
    backgroundColor: Colors.orange,

    leading: IconButton(
      icon: const Icon(Icons.arrow_back),

      onPressed: () {

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MyApp()),
          (route) => false,
        );

      },
    ),
  ),

  body: Center(

        child: SingleChildScrollView(

          child: Container(

            padding: const EdgeInsets.all(30),
            margin: const EdgeInsets.all(20),

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),

              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20
                )
              ]
            ),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [

                /// ICON
                const Icon(
                  Icons.restaurant_menu,
                  size: 60,
                  color: Colors.orange,
                ),

                const SizedBox(height: 10),

                /// TITLE
                const Text(
                  "SmartCooks",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange
                  ),
                ),

                const SizedBox(height: 30),

                /// EMAIL
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,

                  decoration: InputDecoration(
                    labelText: "Email",
                    prefixIcon: const Icon(Icons.email),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                /// PASSWORD
                TextField(
                  controller: password,
                  obscureText: true,

                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// LOGIN BUTTON
                SizedBox(
                  width: double.infinity,

                  child: ElevatedButton(

                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 14),

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)
                      )
                    ),

                    onPressed: loading ? null : login,

                    child: loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "LOGIN",
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),

                const SizedBox(height: 15),

                /// REGISTER
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    const Text("Belum punya akun?"),

                    TextButton(

                      onPressed: () {

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterPage(),
                          ),
                        );

                      },

                      child: const Text(
                        "Register",
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),

                  ],
                )

              ],
            ),
          ),
        ),
      ),
    );
  }
}