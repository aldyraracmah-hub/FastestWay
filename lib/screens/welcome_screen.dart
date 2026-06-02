
import 'package:flutter/material.dart';
import 'signin_screen.dart';
import 'signup_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF7F1E8),

      body: SafeArea(

        child: Stack(

          children: [

            Positioned(
              top: -120,
              right: -80,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD6BFA7)
                      .withOpacity(0.35),
                ),
              ),
            ),

            Padding(

              padding:
              const EdgeInsets.all(28),

              child: Column(

                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [

                  const Spacer(),

                  const Text(

                    "Welcome!",

                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5C4632),
                    ),
                  ),

                  const SizedBox(height: 14),

                  const Text(

                    "Find the fastest route\n"
                        "and smartest navigation\n"
                        "for your journey.",

                    style: TextStyle(
                      fontSize: 18,
                      color: Color(0xFF8A6F58),
                      height: 1.5,
                    ),
                  ),

                  const Spacer(),

                  Row(

                    children: [

                      Expanded(

                        child: GestureDetector(

                          onTap: () {

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                const SignupScreen(),
                              ),
                            );
                          },

                          child: Container(

                            height: 65,

                            decoration: BoxDecoration(

                              color: const Color(
                                  0xFFE5D3BF),

                              borderRadius:
                              BorderRadius.circular(24),
                            ),

                            child: const Center(

                              child: Text(

                                "sign up",

                                style: TextStyle(
                                  color: Color(0xFF5C4632),
                                  fontWeight:
                                  FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      Expanded(

                        child: GestureDetector(

                          onTap: () {

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                const SigninScreen(),
                              ),
                            );
                          },

                          child: Container(

                            height: 65,

                            decoration: BoxDecoration(

                              color: const Color(
                                  0xFF5C4632),

                              borderRadius:
                              BorderRadius.circular(24),
                            ),

                            child: const Center(

                              child: Text(

                                "sign in",

                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight:
                                  FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

