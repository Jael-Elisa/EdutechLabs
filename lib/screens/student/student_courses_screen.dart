import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../video_player_screen.dart';
import '../teacher/course_comments_screen.dart';
import '../teacher/download_helper.dart';
import '../material_comments_screen.dart';

class StudentCoursesScreen extends StatefulWidget {
  const StudentCoursesScreen({super.key});

  @override
  State<StudentCoursesScreen> createState() => _StudentCoursesScreenState();
}

class _StudentCoursesScreenState extends State<StudentCoursesScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Dio _dio = Dio();

  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _filteredCourses = [];
  bool _isLoading = true;
  final Set<String> _enrollingCourses = <String>{};
  final Map<String, bool> _enrolledCourses = {};
  final Map<String, List<Map<String, dynamic>>> _courseMaterials = {};
  final Map<String, bool> _expandedCourses = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('courses')
          .select('*, profiles(full_name)')
          .order('created_at', ascending: false);

      await _loadUserEnrollments(user.id);

      final courses = List<Map<String, dynamic>>.from(response);

      if (!mounted) return;
      setState(() {
        _courses = courses;
        _filteredCourses = courses;
        _isLoading = false;
      });

      for (final course in courses) {
        final courseId = course['id'].toString();
        if (_enrolledCourses[courseId] == true) {
          _loadCourseMaterials(courseId);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Error al cargar cursos: $e');
    }
  }

  void _searchCourse(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCourses = _courses;
      } else {
        final q = query.toLowerCase();
        _filteredCourses = _courses.where((course) {
          final title = (course['title'] ?? '').toString().toLowerCase();
          final category = (course['category'] ?? '').toString().toLowerCase();
          final description =
              (course['description'] ?? '').toString().toLowerCase();

          return title.contains(q) ||
              category.contains(q) ||
              description.contains(q);
        }).toList();
      }
    });
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

  Future<void> _loadCourseMaterials(String courseId) async {
    try {
      final materials = await _supabase.from('materials').select('''
            id,
            course_id,
            title,
            description,
            file_url,
            file_type,
            file_size,
            created_at
          ''').eq('course_id', courseId).order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _courseMaterials[courseId] = List<Map<String, dynamic>>.from(materials);
      });
    } catch (e) {
      if (!mounted) return;
      _showError('Error al cargar materiales: $e');
    }
  }

  Future<void> _enrollInCourse(String courseId, String courseTitle) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _showError('Debes iniciar sesión para inscribirte');
        return;
      }

      if (_enrolledCourses[courseId] == true) {
        _showError('Ya estás inscrito en este curso');
        return;
      }

      setState(() {
        _enrollingCourses.add(courseId);
      });

      await _supabase.from('enrollments').insert({
        'student_id': user.id,
        'course_id': courseId,
        'enrolled_at': DateTime.now().toIso8601String(),
        'status': 'active',
      });

      _enrolledCourses[courseId] = true;
      _showSuccess('¡Inscripción exitosa en $courseTitle!');

      await _loadCourseMaterials(courseId);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (e.toString().contains('duplicate key') ||
          e.toString().contains('unique constraint')) {
        _showError('Ya estás inscrito en este curso');
        _enrolledCourses[courseId] = true;
      } else {
        _showError('Error al inscribirse: ${e.toString()}');
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _enrollingCourses.remove(courseId);
      });
    }
  }

  Future<void> _openMaterial(Map<String, dynamic> material) async {
    final String fileUrl = material['file_url'];
    final String title = material['title'] ?? 'Material';
    final String fileType = material['file_type'];

    if (fileType == 'link') {
      await _openLink(fileUrl);
      return;
    }

    if (fileType == 'video') {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(url: fileUrl),
        ),
      );
      return;
    }

    if (!mounted) return;
    final action = await showDialog<MaterialAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getFileIcon(fileType),
              size: 64,
              color: _getFileColor(fileType),
            ),
            const SizedBox(height: 16),
            Text(_getFileTypeDescription(fileType)),
            const SizedBox(height: 8),
            if (material['file_size'] != null)
              Text('Tamaño: ${_formatFileSize(material['file_size'])}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, MaterialAction.view),
            child: const Text('Ver en Navegador'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, MaterialAction.download),
            child: const Text('Descargar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, MaterialAction.cancel),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (action == MaterialAction.view) {
      await _viewInBrowser(fileUrl);
    } else if (action == MaterialAction.download) {
      await _downloadAndSave(
        fileUrl,
        title,
        fileType,
      );
    }
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      _showError('No se pudo abrir: $url');
    }
  }

  Future<void> _viewInBrowser(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      _showError('No se pudo abrir en el navegador');
    }
  }

  Future<void> _downloadAndSave(
    String url,
    String fileName,
    String fileType,
  ) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Preparando descarga de $fileName...'),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      Uint8List bytes;
      try {
        final response = await _dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        bytes = Uint8List.fromList(response.data!);
      } catch (e) {
        throw Exception('No se pudieron descargar los bytes: $e');
      }

      await DownloadHelper.downloadFile(
        bytes: bytes,
        fileName: fileName,
        mimeType: _getMimeType(fileType),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Error al descargar: $e');
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

  String _getMimeType(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'image':
        return 'image/jpeg';
      case 'document':
        return 'application/msword';
      case 'text':
        return 'text/plain';
      case 'video':
        return 'video/mp4';
      case 'audio':
        return 'audio/mpeg';
      case 'spreadsheet':
        return 'application/vnd.ms-excel';
      case 'presentation':
        return 'application/vnd.ms-powerpoint';
      default:
        return 'application/octet-stream';
    }
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'document':
        return Icons.article;
      case 'text':
        return Icons.text_fields;
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.video_library;
      case 'audio':
        return Icons.audiotrack;
      case 'link':
        return Icons.link;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String fileType) {
    switch (fileType) {
      case 'pdf':
        return Colors.red;
      case 'document':
        return Colors.blue.shade700;
      case 'text':
        return Colors.blue.shade500;
      case 'image':
        return Colors.purple;
      case 'video':
        return Colors.pink;
      case 'audio':
        return Colors.teal;
      case 'link':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _getFileTypeDescription(String fileType) {
    switch (fileType) {
      case 'pdf':
        return 'Documento PDF';
      case 'document':
        return 'Documento Word';
      case 'text':
        return 'Archivo de texto';
      case 'image':
        return 'Imagen';
      case 'video':
        return 'Video';
      case 'audio':
        return 'Audio';
      case 'link':
        return 'Enlace externo';
      default:
        return 'Archivo';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Fecha desconocida';
    }
  }

  Widget _buildInfoChip(
    IconData icon,
    String text,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialTile(Map<String, dynamic> material) {
    final fileType = material['file_type'] as String? ?? 'other';

    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(
          _getFileIcon(fileType),
          color: _getFileColor(fileType),
        ),
        title: Text(
          material['title'] ?? 'Sin título',
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          '${_getFileTypeDescription(fileType)} • ${_formatDate(material['created_at'] ?? '')}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                fileType == 'video'
                    ? Icons.play_arrow
                    : fileType == 'link'
                        ? Icons.open_in_new
                        : Icons.remove_red_eye,
                color: Colors.blue,
                size: 20,
              ),
              onPressed: () => _openMaterial(material),
            ),
            if (fileType != 'link')
              IconButton(
                icon: const Icon(
                  Icons.download,
                  color: Colors.green,
                  size: 20,
                ),
                onPressed: () => _downloadAndSave(
                  material['file_url'],
                  material['title'] ?? 'archivo',
                  fileType,
                ),
              ),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MaterialCommentsScreen(material: material),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnrolledCourseCard(
    Map<String, dynamic> course,
    String courseId,
    List<Map<String, dynamic>> materials,
  ) {
    final isExpanded = _expandedCourses[courseId] ?? false;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(25),
          ),
          child: const Icon(Icons.check_circle, color: Colors.green),
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
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInfoChip(
              Icons.library_books,
              '${materials.length}',
              Colors.blue,
              () {
                setState(() {
                  _expandedCourses[courseId] = true;
                });
              },
            ),
            IconButton(
              icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () {
                setState(() {
                  _expandedCourses[courseId] = !isExpanded;
                });
              },
            ),
          ],
        ),
        children: [
          if (materials.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'No hay materiales en este curso',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...materials.map(_buildMaterialTile),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CourseCommentsScreen(course: course),
                    ),
                  );
                },
                icon: const Icon(Icons.comment),
                label: const Text('Comentarios'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableCourseCard(
    Map<String, dynamic> course,
    String courseId,
    bool isEnrolling,
  ) {
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
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Icon(
            Icons.school,
            color: Colors.blue.shade700,
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
          ],
        ),
        trailing: isEnrolling
            ? const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : ElevatedButton(
                onPressed: () => _enrollInCourse(
                  courseId,
                  course['title'] ?? 'el curso',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Inscribirse'),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(
        color: Colors.blueGrey.shade700.withOpacity(0.5),
        width: 1,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cursos Disponibles'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFF0A0F1C),
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
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _searchCourse,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            cursorColor: const Color(0xFF3D5AFE),
                            decoration: InputDecoration(
                              hintText: "Buscar curso...",
                              hintStyle: TextStyle(
                                color: Colors.blueGrey.shade300,
                                fontSize: 14,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF111827),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.blueGrey.shade200,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      color: Colors.blueGrey.shade200,
                                      onPressed: () {
                                        _searchController.clear();
                                        _searchCourse('');
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              enabledBorder: baseBorder,
                              focusedBorder: baseBorder.copyWith(
                                borderSide: const BorderSide(
                                  color: Color(0xFF3D5AFE),
                                  width: 1.6,
                                ),
                              ),
                              border: baseBorder,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredCourses.length,
                          itemBuilder: (context, index) {
                            final course = _filteredCourses[index];
                            final courseId = course['id'].toString();
                            final isEnrolling =
                                _enrollingCourses.contains(courseId);
                            final isEnrolled =
                                _enrolledCourses[courseId] == true;
                            final materials = _courseMaterials[courseId] ?? [];

                            if (isEnrolled) {
                              return _buildEnrolledCourseCard(
                                course,
                                courseId,
                                materials,
                              );
                            } else {
                              return _buildAvailableCourseCard(
                                course,
                                courseId,
                                isEnrolling,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

enum MaterialAction {
  view,
  download,
  cancel,
}
