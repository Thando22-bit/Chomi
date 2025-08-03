import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:camera/camera.dart';

import 'firebase_options.dart';
import 'theme_provider.dart';

// Screens
import 'welcome_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import 'feed_screen.dart';
import 'streaming_screen.dart';
import 'mingle_screen.dart';
import 'chats_screen.dart';
import 'chomi_hustle_screen.dart';
import 'notifications_screen.dart';
import 'profile_setup_page.dart';
import 'bank_details_screen.dart';
import 'settings_screen.dart';
import 'liveStream_screen.dart';

// Hustle Features
import 'job_post_screen.dart';
import 'business_advertise_screen.dart';
import 'brief_cv_screen.dart';
import 'live_stream_screen.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  cameras = await availableCameras();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CHOMI',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.orange,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
      ),
      themeMode: Provider.of<ThemeProvider>(context).themeMode,
      home: const SplashScreen(), // ✅ Start at splash
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/bankDetails': (context) => const BankDetailsScreen(),
        '/settings': (context) => const SettingsScreen(),

        '/profileSetup': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final userId = args?['userId'];
          if (userId == null) {
            return const Scaffold(
                body: Center(child: Text("No userId provided")));
          }
          return ProfileSetupPage(userId: userId);
        },

        '/jobPost': (context) => const JobPostScreen(),
        '/businessAdvertise': (context) => const BusinessAdvertiseScreen(),
        '/briefCV': (context) => const BriefCVScreen(),

        '/liveStream': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          if (args == null ||
              !args.containsKey('streamId') ||
              !args.containsKey('cameraController')) {
            return const Scaffold(
                body: Center(child: Text("Invalid stream data")));
          }
          return LiveStreamScreen(
            streamId: args['streamId'],
            cameraController: args['cameraController'],
          );
        },

        '/chatScreen': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final receiverId = args?['receiverId'];
          final receiverName = args?['receiverName'];
          if (receiverId == null || receiverName == null) {
            return const Scaffold(
                body: Center(child: Text("Invalid chat data")));
          }
          return ChatsScreen(
            otherUserId: receiverId,
            otherUserName: receiverName,
          );
        },
      },
    );
  }
}

/// ✅ Minimal SplashScreen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Fade-in effect
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    _checkLogin();
  }

  Future<void> _checkLogin() async {
    await Future.delayed(const Duration(seconds: 3)); // splash duration
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // ✅ White background
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Image.asset(
            'assets/avatar.png', // ✅ Your logo
            width: 140,
            height: 140,
          ),
        ),
      ),
    );
  }
}



