import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import '../../constants/app_colors.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  int _rating = 0;
  final Set<String> _selectedTags = {};
  final _feedbackController = TextEditingController();
  bool _isLoading = false;

  final List<String> _tags = [
    "Visual",
    "Audio",
    "Controls",
    "Performance",
    "Content",
  ];

  void _submit() async {
    setState(() => _isLoading = true);
    await Future.delayed(
      const Duration(seconds: 1),
    ); // Simulate network request
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Thank you for your feedback!")),
      );
      Navigator.pop(context); // Go back to where it was (Home or Lesson List)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Iconsax.close_circle),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: GlassCard(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Iconsax.star1,
                    size: 48,
                    color: Colors.amber,
                  ).animate().scale(duration: 500.ms).fadeIn(),
                  const SizedBox(height: 16),
                  const Text(
                        "How was your learning experience?",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                      .animate()
                      .slideY(begin: 0.5, end: 0, duration: 500.ms)
                      .fadeIn(),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < _rating ? Iconsax.star1 : Icons.star_border,
                          color: index < _rating
                              ? Colors.amber
                              : AppColors.textSecondary,
                          size: 36,
                        ),
                        onPressed: () {
                          setState(() {
                            _rating = index + 1;
                          });
                        },
                      );
                    }),
                  ).animate().scale(delay: 200.ms),
                  const SizedBox(height: 32),
                  const Text(
                    "What did you like?",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tags.map((tag) {
                      final isSelected = _selectedTags.contains(tag);
                      return ChoiceChip(
                        label: Text(tag),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedTags.add(tag);
                            } else {
                              _selectedTags.remove(tag);
                            }
                          });
                        },
                        selectedColor: AppColors.primary.withOpacity(0.2),
                        backgroundColor: Colors.white.withOpacity(0.05),
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primary : Colors.white,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                          ),
                        ),
                      );
                    }).toList(),
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 24),
                  TextField(
                        controller: _feedbackController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: "Add your feedback...",
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      )
                      .animate()
                      .slideX(begin: 0.2, end: 0, duration: 400.ms)
                      .fadeIn(delay: 400.ms),
                  const SizedBox(height: 32),
                  GradientButton(
                    text: "Submit",
                    onPressed: _submit,
                    isLoading: _isLoading,
                  ).animate().scale(delay: 500.ms, duration: 400.ms).fadeIn(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
