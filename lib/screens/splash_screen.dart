
import 'dart:async';
import 'package:flutter/material.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() =>
      _SplashScreenState();
}

class _SplashScreenState
    extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();

    Timer(
      const Duration(seconds: 3),
          () {

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
            const WelcomeScreen(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:
      const Color(0xFFF7F1E8),

      body: Center(

        child: Column(

          mainAxisAlignment:
          MainAxisAlignment.center,

          children: [

            Container(

              width: 130,
              height: 130,

              decoration: BoxDecoration(

                color: Colors.white,

                borderRadius:
                BorderRadius.circular(35),

                boxShadow: [

                  BoxShadow(
                    color: Colors.brown
                        .withOpacity(0.1),
                    blurRadius: 25,
                  ),
                ],
              ),

              child: const Icon(
                Icons.navigation_rounded,
                size: 70,
                color: Color(0xFFD6BFA7),
              ),
            ),

            const SizedBox(height: 30),

            const Text(

              "FastestWay",

              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5C4632),
              ),
            ),

            const SizedBox(height: 10),

            const Text(

              "Smart Navigation Assistant",

              style: TextStyle(
                color: Color(0xFF8A6F58),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}