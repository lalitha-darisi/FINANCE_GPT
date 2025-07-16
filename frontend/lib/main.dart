import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'login_signup_page.dart'; // <-- Add this line

void main() {
  runApp(const FinanceApp());
}

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OpeningScreen(),
    );
  }
}

class OpeningScreen extends StatelessWidget {
  const OpeningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🌄 Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/background.jpeg', // or bg.jpg (match filename)
              fit: BoxFit.cover,
            ),
          ),

          // 🧩 Main Row
          Row(
            children: [
              // 🔐 Left Side: Empty or could add logo etc.
              const Expanded(flex: 1, child: SizedBox()),

              // 👋 Right Side: Welcome + Animation
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'WELCOME!!',
                        style: TextStyle(
                          fontSize: 45,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Lottie.asset(
                        'assets/animation.json',
                        height: 300,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 👣 Bottom Center: Get Started Button
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginSignUpPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromARGB(255, 97, 75, 53),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  textStyle: const TextStyle(fontSize: 20),
                ),
                child: const Text(
                  'Get Started',
                  style: TextStyle(
                    color: Colors.white, // 👈 Change to any color you want
                    fontWeight: FontWeight.bold, // Optional: make it bold
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}