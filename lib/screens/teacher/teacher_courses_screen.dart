import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherCoursesScreen extends StatefulWidget {
  const TeacherCoursesScreen({super.key});

  @override
  State<TeacherCoursesScreen> createState() => _TeacherCoursesScreenState();
}

class _TeacherCoursesScreenState extends State<TeacherCoursesScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      final user = _supabase.auth.currentUser;
      final response = await _supabase
          .from('courses')
          .select('*')
          .eq('teacher_id', user!.id)
          .order('created_at', ascending: false);
      
      setState(() {
        _courses = List<Map<String, dynamic>>.from(response);
        _filtered = _courses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _searchCourse(String query) {
    setState(() {
      _filtered = _courses
          .where((course) =>
              (course['title'] ?? '')
                  .toLowerCase()
                  .contains(query.toLowerCase()) ||
              (course['category'] ?? '')
                  .toLowerCase()
                  .contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 🔍 BUSCADOR
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    onChanged: _searchCourse,
                    decoration: InputDecoration(
                      labelText: "Buscar curso...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: _filtered.isEmpty
                      ? const Center(child: Text('No se encontraron cursos'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final course = _filtered[index];
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.school, color: Colors.blue),
                                title: Text(course['title'] ?? 'Sin título'),
                                subtitle:
                                    Text(course['category'] ?? 'Sin categoría'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {},
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
