
import 'package:flutter/material.dart';
import 'map_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() =>
      _SignupScreenState();
}

class _SignupScreenState
    extends State<SignupScreen> {

  final name =
  TextEditingController();

  final email =
  TextEditingController();

  final password =
  TextEditingController();

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:
      const Color(0xFFF7F1E8),

      body: SafeArea(

        child: SingleChildScrollView(

          padding:
          const EdgeInsets.all(28),

          child: Column(

            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [

              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(
                  Icons.arrow_back,
                ),
              ),

              const SizedBox(height: 20),

              const Text(

                "GET STARTED",

                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5C4632),
                ),
              ),

              const SizedBox(height: 10),

              const Text(

                "Create your account",

                style: TextStyle(
                  color: Color(0xFF8A6F58),
                ),
              ),

              const SizedBox(height: 40),

              _buildField("Name", name),

              const SizedBox(height: 20),

              _buildField("Email", email),

              const SizedBox(height: 20),

              _buildField(
                "Password",
                password,
                obscure: true,
              ),

              const SizedBox(height: 40),

              GestureDetector(

                onTap: () {

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                      const MapScreen(),
                    ),
                  );
                },

                child: Container(

                  height: 60,

                  decoration: BoxDecoration(

                    color: const Color(
                        0xFFD6BFA7),

                    borderRadius:
                    BorderRadius.circular(18),
                  ),

                  child: const Center(

                    child: Text(

                      "Sign Up",

                      style: TextStyle(
                        fontWeight:
                        FontWeight.bold,
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
      String hint,
      TextEditingController c, {
        bool obscure = false,
      }) {

    return TextField(

      controller: c,

      obscureText: obscure,

      decoration: InputDecoration(

        hintText: hint,

        filled: true,

        fillColor: Colors.white,

        border: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}