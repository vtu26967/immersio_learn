import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:immersio_learn/firebase_options.dart';
import 'package:immersio_learn/screens/home/home_screen.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/lesson_provider.dart';
import 'screens/splash/splash_screen.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
);
  runApp(const ImmersioLearnApp());
}

class ImmersioLearnApp extends StatelessWidget {
  const ImmersioLearnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LessonProvider()),
      ],
      child: MaterialApp(
        title: 'ImmersioLearn',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
