import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _grades = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadGrades();
  }

  Future<void> _loadGrades() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'Debes iniciar sesión para ver tus calificaciones.';
          _grades = [];
          _isLoading = false;
        });
        return;
      }

      // Obtener calificaciones del usuario
      final response = await _supabase
          .from('grades')
          .select('id, course_id, course_title, grade, updated_at')
          .eq('student_id', user.id)
          .order('updated_at', ascending: false);

      setState(() {
        _grades = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar calificaciones: $e';
        _grades = [];
        _isLoading = false;
      });
    }
  }

  String _formatGrade(dynamic grade) {
    if (grade == null) return 'Sin calificación';
    return grade.toString();
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Fecha desconocida';
    try {
      final parsedDate = DateTime.parse(date.toString()).toLocal();
      return '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}';
    } catch (e) {
      return 'Fecha inválida';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Calificaciones'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                )
              : _grades.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.grade, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No tienes calificaciones aún',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Tus calificaciones aparecerán aquí una vez que el profesor las registre.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadGrades,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _grades.length,
                        itemBuilder: (context, index) {
                          final grade = _grades[index];
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: const Icon(
                                  Icons.grade,
                                  color: Colors.amber,
                                  size: 30,
                                ),
                              ),
                              title: Text(
                                grade['course_title'] ?? 'Curso desconocido',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    'Calificación: ${_formatGrade(grade['grade'])}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Actualizado: ${_formatDate(grade['updated_at'])}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
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
Validaciones que ahora incluye

Usuario autenticado: No carga calificaciones si el usuario no está logueado.

Manejo de loading: Muestra CircularProgressIndicator mientras se cargan los datos.

Error handling: Muestra mensajes de error si falla la consulta.

Empty state: Muestra mensaje amigable si no hay calificaciones.

Manejo seguro de nulls: course_title, grade y updated_at son validados antes de mostrarse.

Refresh: Permite actualizar la lista tirando hacia abajo (RefreshIndicator).
 */