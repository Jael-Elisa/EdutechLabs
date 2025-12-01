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
  List<Map<String, dynamic>> _filteredCourses = [];
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
        _filteredCourses = _courses; // Inicialmente igual
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _searchCourse(String query) {
    setState(() {
      _filteredCourses = _courses.where((course) {
        final title = course['title']?.toLowerCase() ?? '';
        final category = course['category']?.toLowerCase() ?? '';
        return title.contains(query.toLowerCase()) ||
               category.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cursos disponibles')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Buscador
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    onChanged: _searchCourse,
                    decoration: const InputDecoration(
                      labelText: 'Buscar curso...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),

                // Lista de cursos
                Expanded(
                  child: _filteredCourses.isEmpty
                      ? const Center(child: Text('No hay cursos disponibles'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredCourses.length,
                          itemBuilder: (context, index) {
                            final course = _filteredCourses[index];
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
                ),
              ],
            ),
    );
  }
}
