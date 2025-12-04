import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  String? get userRole => currentUser?.userMetadata?['role'] as String?;
  String? get userFullName =>
      currentUser?.userMetadata?['full_name'] as String?;
  String? get userEmail => currentUser?.email;

  Future<void> signUp(
    String email,
    String password,
    String fullName,
    String role,
  ) async {
    try {
      print('🔐 Iniciando registro para: $email');

      final AuthResponse response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName.trim(), 'role': role},
      ).timeout(const Duration(seconds: 30));

      if (response.user == null) {
        throw Exception('No se pudo crear el usuario');
      }

      print('✅ Usuario creado en Auth: ${response.user!.id}');

      try {
        await _createUserProfile(response.user!.id, email, fullName, role);
      } catch (e) {
        print('⚠️ Error creando perfil: $e');
      }
    } on TimeoutException {
      throw Exception(
        'Tiempo de espera agotado. Verifica tu conexión a internet.',
      );
    } on AuthException catch (e) {
      throw Exception(_parseAuthError(e.message));
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }

    notifyListeners();
  }

  Future<void> _createUserProfile(
    String userId,
    String email,
    String fullName,
    String role,
  ) async {
    await _supabase.from('profiles').insert({
      'id': userId,
      'email': email.trim(),
      'full_name': fullName.trim(),
      'role': role,
      'created_at': DateTime.now().toIso8601String(),
    }).timeout(const Duration(seconds: 15));

    print('✅ Perfil creado en base de datos');
  }

  Future<void> signIn(String email, String password) async {
    try {
      print('🔐 Iniciando sesión para: $email');

      final AuthResponse response = await _supabase.auth
          .signInWithPassword(email: email.trim(), password: password)
          .timeout(const Duration(seconds: 30));

      if (response.user == null) {
        throw Exception('No se pudo iniciar sesión');
      }

      print('✅ Login exitoso: ${response.user!.id}');
    } on TimeoutException {
      throw Exception(
        'Tiempo de espera agotado. Verifica tu conexión a internet.',
      );
    } on AuthException catch (e) {
      throw Exception(_parseAuthError(e.message));
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }

    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut().timeout(const Duration(seconds: 10));
      print('✅ Sesión cerrada');
    } catch (e) {
      print('❌ Error al cerrar sesión: $e');
      throw Exception('Error al cerrar sesión: $e');
    }

    notifyListeners();
  }

  String _parseAuthError(String errorMessage) {
    if (errorMessage.contains('User already registered')) {
      return 'Este correo electrónico ya está registrado.';
    } else if (errorMessage.contains('Invalid login credentials')) {
      return 'Correo o contraseña incorrectos.';
    } else if (errorMessage.contains('Email not confirmed')) {
      return 'Por favor confirma tu correo electrónico.';
    } else if (errorMessage.contains('Password should be at least')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    } else {
      return 'Error de autenticación: $errorMessage';
    }
  }

  User? getInitialUser() {
    return _supabase.auth.currentUser;
  }
}
