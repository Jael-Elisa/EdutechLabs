import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../teacher/course_comments_screen.dart';

class StudentCoursesScreen extends StatefulWidget {
  const StudentCoursesScreen({super.key});

  @override
  State<StudentCoursesScreen> createState() => _StudentCoursesScreenState();
}

class _StudentCoursesScreenState extends State<StudentCoursesScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _courses = [];
  bool _isLoading = true;
  final Set<String> _enrollingCourses = <String>{};
  final Map<String, bool> _enrolledCourses = {};

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Cargar cursos disponibles
      final response = await _supabase
          .from('courses')
          .select('*, profiles(full_name)')
          .order('created_at', ascending: false);

      // Cargar inscripciones del usuario
      await _loadUserEnrollments(user.id);

      setState(() {
        _courses = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error al cargar cursos: $e');
    }
  }

  Future<void> _loadUserEnrollments(String userId) async {
    try {
      final enrollments = await _supabase
          .from('enrollments')
          .select('course_id')
          .eq('student_id', userId);

      _enrolledCourses.clear();
      for (final enrollment in enrollments) {
        _enrolledCourses[enrollment['course_id'].toString()] = true;
      }
    } catch (e) {
      print('Error cargando inscripciones: $e');
    }
  }

  Future<void> _enrollInCourse(String courseId, String courseTitle) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _showError('Debes iniciar sesión para inscribirte');
        return;
      }

      // Verificar si ya está inscrito (usando cache local)
      if (_enrolledCourses.containsKey(courseId)) {
        _showError('Ya estás inscrito en este curso');
        return;
      }

      setState(() {
        _enrollingCourses.add(courseId);
      });

      // Crear la inscripción
      await _supabase.from('enrollments').insert({
        'student_id': user.id,
        'course_id': courseId,
        'enrolled_at': DateTime.now().toIso8601String(),
        'status': 'active',
      });

      // Actualizar cache local
      _enrolledCourses[courseId] = true;

      _showSuccess('¡Inscripción exitosa en $courseTitle!');

      // Recargar la lista para reflejar cambios
      setState(() {});
    } catch (e) {
      // Manejar error específico de constraint única
      if (e.toString().contains('duplicate key') ||
          e.toString().contains('unique constraint')) {
        _showError('Ya estás inscrito en este curso');
        _enrolledCourses[courseId] = true; // Actualizar cache
      } else {
        _showError('Error al inscribirse: ${e.toString()}');
      }
    } finally {
      setState(() {
        _enrollingCourses.remove(courseId);
      });
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cursos Disponibles'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
              ? const Center(
                  child: Text(
                    'No hay cursos disponibles',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCourses,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _courses.length,
                    itemBuilder: (context, index) {
                      final course = _courses[index];
                      final courseId = course['id'].toString();
                      final isEnrolling = _enrollingCourses.contains(courseId);
                      final isEnrolled = _enrolledCourses.containsKey(courseId);

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          isThreeLine: true,
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isEnrolled
                                  ? Colors.green.shade50
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Icon(
                              isEnrolled ? Icons.check_circle : Icons.school,
                              color: isEnrolled
                                  ? Colors.green
                                  : Colors.blue.shade700,
                              size: 30,
                            ),
                          ),
                          title: Text(
                            course['title'] ?? 'Sin título',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                course['category'] ?? 'Sin categoría',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Profesor: ${_getInstructorName(course)}',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                              if (course['description'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  course['description']!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              if (isEnrolled) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '✅ Ya inscrito',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: isEnrolling
                              ? const SizedBox(
                                  width: 32,
                                  height: 32,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : isEnrolled
                                  ? SizedBox(
                                      width: 220,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          ElevatedButton(
                                            onPressed: null,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.grey.shade800,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              textStyle: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                            child: const Text('Inscrito'),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      CourseCommentsScreen(
                                                          course: course),
                                                ),
                                              );
                                            },
                                            icon: const Icon(
                                                Icons.forum_outlined,
                                                size: 18),
                                            label: const Text(
                                              'Comentarios',
                                              style: TextStyle(fontSize: 13),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFF1A237E),
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              textStyle: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ElevatedButton(
                                      onPressed: () => _enrollInCourse(
                                        courseId,
                                        course['title'] ?? 'el curso',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF1A237E),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                      ),
                                      child: const Text('Inscribirse'),
                                    ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _getInstructorName(Map<String, dynamic> course) {
    try {
      if (course['profiles'] is Map) {
        return course['profiles']['full_name'] ?? 'Instructor';
      }
      return 'Instructor';
    } catch (e) {
      return 'Instructor';
    }
  }
}
