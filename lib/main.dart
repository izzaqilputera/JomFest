import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth_gate.dart';
import 'theme.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBIvmtHOxgWxfR2vBNATLDGrQIjLAh5vb8",
      appId: "1:93626469616:android:8971bd658d1370e6c8c635",
      messagingSenderId: "93626469616",
      projectId: "jomfestt",
      storageBucket: "jomfestt.firebasestorage.app",
    ),
  );
  runApp(const JomFestApp());
}

class JomFestApp extends StatelessWidget {
  const JomFestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JomFest',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const AuthGate(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.festival, size: 80, color: AppColors.white),
            const SizedBox(height: 16),
            const Text(
              'JomFest',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Discover festivals near you',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}