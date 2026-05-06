import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';

class AnimatedBackground extends StatelessWidget {
  final Widget child;

  const AnimatedBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background color
        Container(color: AppColors.background),
        // Animated glowing orbs
        Positioned(
          top: -100,
          left: -100,
          child:
              Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.15),
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  )
                  .animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  )
                  .scale(
                    duration: 4.seconds,
                    begin: const Offset(1, 1),
                    end: const Offset(1.2, 1.2),
                  )
                  .moveX(duration: 5.seconds, begin: 0, end: 30),
        ),
        Positioned(
          bottom: -50,
          right: -50,
          child:
              Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondary.withOpacity(0.15),
                      gradient: RadialGradient(
                        colors: [
                          AppColors.secondary.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  )
                  .animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  )
                  .scale(
                    duration: 6.seconds,
                    begin: const Offset(1.2, 1.2),
                    end: const Offset(1, 1),
                  )
                  .moveY(duration: 4.seconds, begin: 0, end: -40),
        ),
        // Content
        SafeArea(child: child),
      ],
    );
  }
}
