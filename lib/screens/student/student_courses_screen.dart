import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentCoursesScreen extends StatefulWidget {
  const StudentCoursesScreen({super.key});

  @override
  State<StudentCoursesScreen> createState() => _StudentCoursesScreenState();
}

class _StudentCoursesScreenState extends State<StudentCoursesScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _courses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      final response = await _supabase
          .from('courses')
          .select('*, profiles(full_name)')
          .order('created_at', ascending: false);
      
      setState(() {
        _courses = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
              ? const Center(child: Text('No hay cursos disponibles'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _courses.length,
                  itemBuilder: (context, index) {
                    final course = _courses[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.school, color: Colors.green),
                        title: Text(course['title'] ?? 'Sin título'),
                        subtitle: Text(course['category'] ?? 'Sin categoría'),
                        trailing: ElevatedButton(
                          onPressed: () {
                            // Inscribirse en curso
                          },
                          child: const Text('Inscribirse'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}