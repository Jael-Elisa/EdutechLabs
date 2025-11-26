import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env_config.dart';
import 'app/router.dart';
import 'app/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 Iniciando Edutech Labs...');

  try {
    // Configuración desde env_config
    final config = EnvConfig();
    
    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
    );
    
    print('✅ Supabase inicializado correctamente');
    
  } catch (e) {
    print('❌ Error inicializando Supabase: $e');
    rethrow;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: MaterialApp.router(
        title: 'Edutech Labs',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          return GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            child: child,
          );
        },
      ),
    );
  }
}