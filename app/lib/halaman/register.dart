import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../partials/flash.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>{

  final TextEditingController nama = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();

  bool loading = false;

  /// VALIDASI FORMAT EMAIL
  bool validEmail(String emailText){

    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');

    return regex.hasMatch(emailText);

  }

  Future<void> register() async {

    /// VALIDASI FIELD KOSONG
    if(nama.text.isEmpty ||
        email.text.isEmpty ||
        password.text.isEmpty){

      FlashMessage.warning(
        context,
        "Semua field wajib diisi"
      );

      return;
    }

    /// VALIDASI FORMAT EMAIL
    if(!validEmail(email.text.trim())){

      FlashMessage.warning(
        context,
        "Format email tidak valid"
      );

      return;
    }

    /// VALIDASI PASSWORD
    if(password.text.length < 6){

      FlashMessage.warning(
        context,
        "Password minimal 6 karakter"
      );

      return;
    }

    setState(() {
      loading = true;
    });

    try{

      final res = await ApiService.register(
        nama.text.trim(),
        email.text.trim(),
        password.text.trim(),
      );

      setState(() {
        loading = false;
      });

      if(res != null){

        FlashMessage.success(
          context,
          "Register berhasil, silakan login"
        );

        Navigator.pop(context);

      }else{

        FlashMessage.error(
          context,
          "Register gagal"
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
  Widget build(BuildContext context){

    return Scaffold(

      backgroundColor: const Color(0xFFFFF6ED),

      appBar: AppBar(
        title: const Text("Register"),
        backgroundColor: Colors.orange,
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
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20
                )
              ]
            ),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [

                const Text(
                  "Buat Akun SmartCooks",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold
                  ),
                ),

                const SizedBox(height: 25),

                /// INPUT NAMA
                TextField(
                  controller: nama,

                  decoration: InputDecoration(
                    labelText: "Nama",
                    prefixIcon: const Icon(Icons.person),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                /// INPUT EMAIL
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

                /// INPUT PASSWORD
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

                /// BUTTON REGISTER
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
                
                    onPressed: loading ? null : register,

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
                            "REGISTER",
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
const SizedBox(height: 15),

/// LINK KE LOGIN
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [

    const Text("Sudah punya akun?"),

    TextButton(

      onPressed: () {

        Navigator.pop(context);

      },

      child: const Text(
        "Login",
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