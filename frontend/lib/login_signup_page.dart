import 'package:flutter/material.dart';
import 'user_home_page.dart'; // Make sure this exists
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart'; // Make sure config.dart is in the same lib/ folder

class LoginSignUpPage extends StatefulWidget {
  const LoginSignUpPage({super.key});

  @override
  State<LoginSignUpPage> createState() => _LoginSignUpPageState();
}

class _LoginSignUpPageState extends State<LoginSignUpPage> {
  bool isLogin = true;

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🔲 Background Color
           Positioned.fill(
      child: Image.asset(
        'assets/bg2.jpg', // ✅ Replace with your actual image path
        fit: BoxFit.cover,
      ),
    ),
          // 🧾 Login/Signup Form
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 10),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLogin ? 'Login' : 'Sign Up',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (!isLogin) ...[
                      TextField(
                        controller: firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 15),
                    ],

                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),

                    if (!isLogin)
                      TextField(
                        controller: confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),

                    const SizedBox(height: 25),

                    // 🔘 Login or SignUp Button
                    ElevatedButton(
                      onPressed: () async {
  final email = emailController.text.trim();
  final password = passwordController.text.trim();

  if (isLogin) {
    // 🔐 Login API Call
    final response = await http.post(
      Uri.parse("$baseUrl/api/user/login"),
      //Uri.parse("http://127.0.0.1:8000/api/user/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    if (response.statusCode == 200) {
  final json = jsonDecode(response.body);
  final userId = json['user_id'];

  if (userId == null) {
    print("❌ user_id is null in response: ${response.body}");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Login failed: Missing user ID.")),
    );
    return;
  }

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => UserHomePage(userId: userId),
    ),
  );
}

else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed: ${response.body}")),
      );
    }
  } else {
    // 📝 Signup API Call
    final fname = firstNameController.text.trim();
    final lname = lastNameController.text.trim();
    final confirm = confirmPasswordController.text.trim();

    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match.")),
      );
      return;
    }

    final response = await http.post(
      Uri.parse("$baseUrl/api/user/register"),
      //Uri.parse("http://127.0.0.1:8000/api/user/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "first_name": fname,
        "last_name": lname,
        "email": email,
        "password": password
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sign up successful! Please log in.")),
      );
      setState(() {
        isLogin = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Signup failed: ${response.body}")),
      );
    }
  }
},

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(255, 97, 75, 53),
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      ),
                      child: Text(
                        isLogin ? 'Login' : 'Sign Up',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    TextButton(
                      onPressed: () {
                        setState(() {
                          isLogin = !isLogin;
                        });
                      },
                      child: Text(
                        isLogin
                            ? "Don't have an account? Sign Up"
                            : "Already have an account? Login",
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 🏠 Back to Home Button
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // or push to OpeningScreen if needed
                      },
                      icon: const Icon(Icons.home),
                      label: const Text("Back to Home"),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}