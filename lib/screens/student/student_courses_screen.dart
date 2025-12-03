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
  final Set<String> _enrollingCourses = <String>{};
  final Map<String, bool> _enrolledCourses = {}; // Cache de inscripciones

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _showError('Debes iniciar sesión para ver los cursos.');
        setState(() => _isLoading = false);
        return;
      }

      // Cargar cursos disponibles
      final response = await _supabase
          .from('courses')
          .select('*, profiles(full_name)')
          .order('created_at', ascending: false);

      // Validación de tipo seguro
      if (response == null || response is! List) {
        _showError('No se pudieron cargar los cursos.');
        setState(() => _isLoading = false);
        return;
      }

      // Cargar inscripciones del usuario
      await _loadUserEnrollments(user.id);

      setState(() {
        _courses = List<Map<String, dynamic>>.from(response
            .where((c) => c is Map)
            .map((c) => Map<String, dynamic>.from(c)));
        _isLoading = false;
      });
    } catch (e) {
      _showError('Error al cargar cursos: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserEnrollments(String userId) async {
    try {
      final enrollments = await _supabase
          .from('enrollments')
          .select('course_id, status')
          .eq('student_id', userId);

      if (enrollments != null && enrollments is List) {
        _enrolledCourses.clear();
        for (final enrollment in enrollments) {
          if (enrollment is Map &&
              enrollment['course_id'] != null &&
              enrollment['status'] == 'active') {
            _enrolledCourses[enrollment['course_id'].toString()] = true;
          }
        }
      }
    } catch (e) {
      _showError('Error cargando inscripciones: $e');
    }
  }

  Future<void> _enrollInCourse(String courseId, String courseTitle) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _showError('Debes iniciar sesión para inscribirte.');
      return;
    }

    if (_enrolledCourses.containsKey(courseId)) {
      _showError('Ya estás inscrito en este curso.');
      return;
    }

    if (_enrollingCourses.contains(courseId)) return;

    setState(() => _enrollingCourses.add(courseId));

    try {
      await _supabase.from('enrollments').insert({
        'student_id': user.id,
        'course_id': courseId,
        'enrolled_at': DateTime.now().toIso8601String(),
        'status': 'active',
      });

      _enrolledCourses[courseId] = true;
      _showSuccess('¡Inscripción exitosa en $courseTitle!');
      setState(() {});
    } catch (e) {
      if (e.toString().contains('duplicate key') ||
          e.toString().contains('unique constraint')) {
        _showError('Ya estás inscrito en este curso');
        _enrolledCourses[courseId] = true;
      } else {
        _showError('Error al inscribirse: $e');
      }
    } finally {
      setState(() => _enrollingCourses.remove(courseId));
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

  String _getInstructorName(Map<String, dynamic> course) {
    try {
      if (course['profiles'] is Map) {
        return course['profiles']['full_name'] ?? 'Instructor';
      }
      return 'Instructor';
    } catch (_) {
      return 'Instructor';
    }
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
                      final courseId = course['id']?.toString() ?? '';
                      final isEnrolling = _enrollingCourses.contains(courseId);
                      final isEnrolled = _enrolledCourses.containsKey(courseId);

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
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
                            course['title']?.toString() ?? 'Sin título',
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
                                course['category']?.toString() ?? 'Sin categoría',
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
                                  course['description']?.toString() ?? '',
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
                              ? const CircularProgressIndicator()
                              : isEnrolled
                                  ? ElevatedButton(
                                      onPressed: null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                      ),
                                      child: const Text('Inscrito'),
                                    )
                                  : ElevatedButton(
                                      onPressed: () => _enrollInCourse(
                                        courseId,
                                        course['title']?.toString() ??
                                            'el curso',
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
}

/*
Mejoras aplicadas

Autenticación: Mensaje claro si no hay usuario al cargar cursos o inscribirse.

Validación de tipos y nulls: Todos los accesos a campos del curso y profiles están protegidos.

Errores de red: _loadUserEnrollments ahora muestra feedback en caso de error.

Prevención de duplicados: Se revisa status == 'active' en cache local y se captura constraint de Supabase.

UI defensiva: Todos los campos muestran valores por defecto si son nulos.

Protección contra doble click: _enrollingCourses evita que se inscriba varias veces.

Refresh seguro: RefreshIndicator mantiene feedback de carga y errores. */