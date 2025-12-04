import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'app/auth_provider.dart';
import 'app/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://iampwosufztefxonbusb.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlhbXB3b3N1Znp0ZWZ4b25idXNiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQxODE5MzAsImV4cCI6MjA3OTc1NzkzMH0.KeFe8Db2jBuSMdqELatv56FEHfyLLqnBtGrIQEhep7E',
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _handleAuthState();
  }

  void _handleAuthState() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      print('Auth state changed: $event');

      if (event == AuthChangeEvent.passwordRecovery) {
        print('Password recovery event detected');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          router.go('/reset-password');
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: MaterialApp.router(
        routerConfig: router,
        title: 'Edutech Labs',
        theme: ThemeData(
          primaryColor: const Color(0xFF1A237E),
          scaffoldBackgroundColor: const Color(0xFF0A0F1C),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1A237E),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1A237E),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          primaryColor: const Color(0xFF1A237E),
          scaffoldBackgroundColor: const Color(0xFF0A0F1C),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1A237E),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1A237E),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
