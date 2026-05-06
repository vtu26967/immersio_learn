import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../constants/app_colors.dart';
import '../../widgets/animated_background.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late StreamSubscription<User?> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          if (user != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                    Iconsax
                        .radar5, // Placeholder for 3d_cube_scan which might not exist in iconsax package, radar5 used in Login too
                    size: 100,
                    color: AppColors.primary,
                  )
                  .animate()
                  .scale(duration: 1.seconds, curve: Curves.easeOutBack)
                  .then()
                  .shimmer(duration: 2.seconds, color: Colors.white),
              const SizedBox(height: 24),
              const Text(
                "ImmersioLearn",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ).animate().fadeIn(delay: 500.ms, duration: 1.seconds).slideY(),
              const SizedBox(height: 16),
              const Text(
                "Visualize. Experience. Understand.",
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  letterSpacing: 1,
                ),
              ).animate().fadeIn(delay: 1.seconds, duration: 1.seconds),
            ],
          ),
        ),
      ),
    );
  }
}
