import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/screens/home_screen.dart';
import 'package:color_canvas/screens/login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // Show appropriate screen based on auth state
        if (snapshot.hasData && snapshot.data != null) {
          // User is signed in
          return const HomeScreen();
        } else {
          // User is not signed in
          return const LoginScreen();
        }
      },
    );
  }
}