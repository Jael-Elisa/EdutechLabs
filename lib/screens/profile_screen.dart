// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../app/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', user!.id)
          .single();
      
      setState(() {
        _profile = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      _profile?['full_name'] ?? 'Sin nombre',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Chip(
                      label: Text(
                        authProvider.userRole == 'teacher' ? 'Docente' : 'Estudiante',
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: authProvider.userRole == 'teacher' 
                          ? Colors.blue 
                          : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.email),
                      title: const Text('Email'),
                      subtitle: Text(_profile?['email'] ?? 'Sin email'),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Miembro desde'),
                      subtitle: Text(
                        _profile?['created_at'] != null 
                            ? '${_profile!['created_at'].toString().substring(0, 10)}'
                            : 'Fecha no disponible'
                      ),
                    ),
                  ),
                  if (_profile?['bio'] != null) ...[
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.info),
                        title: const Text('Biografía'),
                        subtitle: Text(_profile!['bio']),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}