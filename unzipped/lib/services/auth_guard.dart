import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:color_canvas/screens/settings_screen.dart';

class AuthGuard {
  static Future<void> ensureSignedIn(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sign in required'),
        content: const Text('Please sign in to save Color Stories and continue.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Later')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sign in')),
        ],
      ),
    );
    if (ok == true) {
      // Route to your existing auth screen or settings sign-in section
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    }
  }
}