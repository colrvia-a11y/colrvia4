import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';

class AuthDialog extends StatefulWidget {
  final VoidCallback onAuthSuccess;

  const AuthDialog({super.key, required this.onAuthSuccess});

  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isSignIn = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential;
      
      if (_isSignIn) {
        userCredential = await FirebaseService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        userCredential = await FirebaseService.createUserWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
        
        // Create user profile for new users
        if (userCredential.user != null) {
          final profile = UserProfile(
            id: userCredential.user!.uid,
            email: userCredential.user!.email!,
            displayName: userCredential.user!.displayName ?? '',
            plan: 'free',
            paletteCount: 0,
            createdAt: DateTime.now(),
          );
          
          await FirebaseService.createUserProfile(profile);
        }
      }

      if (mounted) {
        widget.onAuthSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isSignIn ? 'Signed in successfully' : 'Account created successfully'),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email.';
          break;
        case 'wrong-password':
          message = 'Wrong password provided.';
          break;
        case 'email-already-in-use':
          message = 'An account already exists with this email.';
          break;
        case 'weak-password':
          message = 'The password provided is too weak.';
          break;
        case 'invalid-email':
          message = 'The email address is not valid.';
          break;
        default:
          message = e.message ?? 'Authentication failed';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isSignIn ? 'Sign In' : 'Create Account'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter your email';
                }
                if (!value!.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              obscureText: _obscurePassword,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter your password';
                }
                if (!_isSignIn && (value?.length ?? 0) < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            
            if (!_isSignIn) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                obscureText: _obscureConfirmPassword,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
            
            const SizedBox(height: 16),
            
            TextButton(
              onPressed: () => setState(() => _isSignIn = !_isSignIn),
              child: Text(
                _isSignIn 
                    ? 'Don\'t have an account? Sign up' 
                    : 'Already have an account? Sign in',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _authenticate,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isSignIn ? 'Sign In' : 'Create Account'),
        ),
      ],
    );
  }
}