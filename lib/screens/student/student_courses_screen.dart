import 'dart:async';
import 'dart:math';
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
  final CancelToken _dioCancelToken = CancelToken();

  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _filteredCourses = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
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
    _dioCancelToken.cancel('Widget disposed');
    super.dispose();
  }

  Future<void> _loadCourses() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final response = await _supabase
          .from('courses')
          .select('*, profiles(full_name)')
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 30));

      await _loadUserEnrollments(user.id);

      if (response == null) {
        throw Exception('No se recibieron datos del servidor');
      }

      final courses = List<Map<String, dynamic>>.from(response);

      if (!mounted) return;
      
      setState(() {
        _courses = courses;
        _filteredCourses = courses;
        _isLoading = false;
        _hasError = false;
      });

      // Cargar materiales solo para cursos inscritos
      for (final course in courses) {
        final courseId = course['id']?.toString();
        if (courseId != null && _enrolledCourses[courseId] == true) {
          await _loadCourseMaterials(courseId);
        }
      }
    } on TimeoutException catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Tiempo de espera agotado al cargar cursos';
      });
      _showErrorSnackBar('No se pudo cargar los cursos. Verifica tu conexión.');
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Error del servidor: ${e.message}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Error al cargar cursos: ${e.toString()}';
      });
      _showErrorSnackBar('Error al cargar cursos: $e');
    }
  }

  void _searchCourse(String query) {
    if (!mounted) return;
    
    setState(() {
      if (query.isEmpty) {
        _filteredCourses = _courses;
      } else {
        final q = query.toLowerCase();
        _filteredCourses = _courses.where((course) {
          final title = (course['title'] ?? '').toString().toLowerCase();
          final category = (course['category'] ?? '').toString().toLowerCase();
          final description = (course['description'] ?? '').toString().toLowerCase();
          final instructor = _getInstructorName(course).toLowerCase();

          return title.contains(q) ||
              category.contains(q) ||
              description.contains(q) ||
              instructor.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _loadUserEnrollments(String userId) async {
    try {
      final enrollments = await _supabase
          .from('enrollments')
          .select('course_id, status')
          .eq('student_id', userId)
          .timeout(const Duration(seconds: 10));

      _enrolledCourses.clear();
      for (final enrollment in enrollments) {
        final courseId = enrollment['course_id']?.toString();
        final status = enrollment['status']?.toString();
        
        if (courseId != null && status == 'active') {
          _enrolledCourses[courseId] = true;
        }
      }
    } catch (e) {
      print('Error cargando inscripciones: $e');
    }
  }

  Future<void> _loadCourseMaterials(String courseId) async {
    // Validar courseId
    if (courseId.isEmpty) {
      print('Error: courseId vacío al cargar materiales');
      return;
    }

    try {
      final materials = await _supabase
          .from('materials')
          .select('''
            id,
            course_id,
            title,
            description,
            file_url,
            file_type,
            file_size,
            created_at
          ''')
          .eq('course_id', courseId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;
      
      if (materials == null) {
        throw Exception('No se recibieron datos de materiales');
      }

      setState(() {
        _courseMaterials[courseId] = List<Map<String, dynamic>>.from(materials);
      });
    } on TimeoutException catch (_) {
      print('Timeout al cargar materiales para curso $courseId');
    } catch (e) {
      print('Error al cargar materiales para curso $courseId: $e');
    }
  }

  Future<void> _enrollInCourse(Map<String, dynamic> course) async {
    final courseId = course['id']?.toString();
    final courseTitle = course['title']?.toString() ?? 'el curso';
    
    // Validaciones
    if (courseId == null || courseId.isEmpty) {
      _showErrorSnackBar('ID de curso inválido');
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) {
      _showErrorSnackBar('Debes iniciar sesión para inscribirte');
      return;
    }

    if (_enrolledCourses[courseId] == true) {
      _showErrorSnackBar('Ya estás inscrito en este curso');
      return;
    }

    setState(() {
      _enrollingCourses.add(courseId);
    });

    try {
      await _supabase.from('enrollments').insert({
        'student_id': user.id,
        'course_id': courseId,
        'enrolled_at': DateTime.now().toIso8601String(),
        'status': 'active',
      }).timeout(const Duration(seconds: 15));

      // Actualizar estado local
      _enrolledCourses[courseId] = true;
      _showSuccessSnackBar('¡Inscripción exitosa en $courseTitle!');

      // Cargar materiales del curso
      await _loadCourseMaterials(courseId);

      if (mounted) {
        setState(() {});
      }
    } on TimeoutException catch (_) {
      _showErrorSnackBar('Tiempo de espera agotado. Intenta de nuevo.');
    } on PostgrestException catch (e) {
      String errorMessage = 'Error al inscribirse';
      
      if (e.code == '23505') { // Violación de unicidad
        errorMessage = 'Ya estás inscrito en este curso';
        _enrolledCourses[courseId] = true;
      } else if (e.code == '42501') { // Permiso denegado
        errorMessage = 'No tienes permiso para inscribirte en este curso';
      } else if (e.message != null) {
        errorMessage = 'Error: ${e.message}';
      }
      
      _showErrorSnackBar(errorMessage);
    } catch (e) {
      _showErrorSnackBar('Error al inscribirse: ${e.toString()}');
    } finally {
      if (!mounted) return;
      setState(() {
        _enrollingCourses.remove(courseId);
      });
    }
  }

  Future<void> _openMaterial(Map<String, dynamic> material) async {
    final String? fileUrl = material['file_url']?.toString();
    final String title = material['title']?.toString() ?? 'Material';
    final String? fileType = material['file_type']?.toString();

    // Validaciones
    if (fileUrl == null || fileUrl.isEmpty) {
      _showErrorSnackBar('No hay archivo asociado a este material');
      return;
    }

    if (fileType == null || fileType.isEmpty) {
      _showErrorSnackBar('Tipo de archivo no especificado');
      return;
    }

    if (!_isValidUrl(fileUrl)) {
      _showErrorSnackBar('URL de archivo inválida');
      return;
    }

    if (fileType.toLowerCase() == 'link') {
      await _openLink(fileUrl);
      return;
    }

    if (fileType.toLowerCase() == 'video') {
      if (!mounted) return;
      
      // Validar que sea una URL de video soportada
      if (!_isVideoUrl(fileUrl)) {
        _showErrorSnackBar('URL de video no soportada');
        return;
      }
      
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
              Text('Tamaño: ${_formatFileSize(material['file_size'] as int)}'),
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
    if (!_isValidUrl(url)) {
      _showErrorSnackBar('URL inválida');
      return;
    }

    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      _showErrorSnackBar('No se pudo abrir: $url');
    }
  }

  Future<void> _viewInBrowser(String url) async {
    if (!_isValidUrl(url)) {
      _showErrorSnackBar('URL inválida');
      return;
    }

    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      _showErrorSnackBar('No se pudo abrir en el navegador');
    }
  }

  Future<void> _downloadAndSave(
    String url,
    String fileName,
    String fileType,
  ) async {
    // Validaciones
    if (!_isValidUrl(url)) {
      _showErrorSnackBar('URL de descarga inválida');
      return;
    }

    if (fileName.isEmpty) {
      fileName = 'archivo_desconocido';
    }

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Preparando descarga de $fileName...'),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
        cancelToken: _dioCancelToken,
      );

      // Validar respuesta
      if (response.data == null || response.data!.isEmpty) {
        throw Exception('Archivo vacío o no disponible');
      }

      final bytes = Uint8List.fromList(response.data!);
      final mimeType = DownloadHelper.getMimeType(fileName);

      // Validar archivo antes de descargar
      const maxSize = 50 * 1024 * 1024; // 50MB
      if (!DownloadHelper.validateFileForDownload(
        bytes: bytes,
        fileName: fileName,
        maxSizeInBytes: maxSize,
      )) {
        throw Exception('Archivo no válido para descarga');
      }

      await DownloadHelper.downloadFile(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        print('Descarga cancelada');
        return;
      }
      
      if (!mounted) return;
      
      String errorMessage = 'Error al descargar el archivo';
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Tiempo de espera agotado. Verifica tu conexión.';
      } else if (e.type == DioExceptionType.badResponse) {
        errorMessage = 'Error del servidor (${e.response?.statusCode})';
      }
      
      _showErrorSnackBar('$errorMessage: $fileName');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error al descargar $fileName: $e');
    }
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.isAbsolute;
    } catch (_) {
      return false;
    }
  }

  bool _isVideoUrl(String url) {
    final uri = Uri.parse(url);
    final path = uri.path.toLowerCase();
    return path.endsWith('.mp4') || 
           path.endsWith('.avi') || 
           path.endsWith('.mov') ||
           path.endsWith('.wmv') ||
           path.endsWith('.webm');
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _getInstructorName(Map<String, dynamic> course) {
    try {
      final profiles = course['profiles'];
      if (profiles is Map) {
        return profiles['full_name']?.toString() ?? 'Instructor';
      }
      return 'Instructor';
    } catch (_) {
      return 'Instructor';
    }
  }

  String _getMimeType(String fileType) {
    if (fileType.isEmpty) return 'application/octet-stream';
    
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'image':
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'image/jpeg';
      case 'document':
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'text':
      case 'txt':
        return 'text/plain';
      case 'video':
      case 'mp4':
      case 'avi':
      case 'mov':
        return 'video/mp4';
      case 'audio':
      case 'mp3':
      case 'wav':
        return 'audio/mpeg';
      case 'spreadsheet':
      case 'xls':
      case 'xlsx':
        return 'application/vnd.ms-excel';
      case 'presentation':
      case 'ppt':
      case 'pptx':
        return 'application/vnd.ms-powerpoint';
      default:
        return 'application/octet-stream';
    }
  }

  IconData _getFileIcon(String fileType) {
    if (fileType.isEmpty) return Icons.insert_drive_file;
    
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'document':
      case 'doc':
      case 'docx':
        return Icons.article;
      case 'text':
      case 'txt':
        return Icons.text_fields;
      case 'image':
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'video':
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_library;
      case 'audio':
      case 'mp3':
      case 'wav':
        return Icons.audiotrack;
      case 'link':
        return Icons.link;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String fileType) {
    if (fileType.isEmpty) return Colors.grey;
    
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'document':
      case 'doc':
      case 'docx':
        return Colors.blue.shade700;
      case 'text':
      case 'txt':
        return Colors.blue.shade500;
      case 'image':
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Colors.purple;
      case 'video':
      case 'mp4':
      case 'avi':
      case 'mov':
        return Colors.pink;
      case 'audio':
      case 'mp3':
      case 'wav':
        return Colors.teal;
      case 'link':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _getFileTypeDescription(String fileType) {
    if (fileType.isEmpty) return 'Archivo';
    
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return 'Documento PDF';
      case 'document':
      case 'doc':
      case 'docx':
        return 'Documento Word';
      case 'text':
      case 'txt':
        return 'Archivo de texto';
      case 'image':
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'Imagen';
      case 'video':
      case 'mp4':
      case 'avi':
      case 'mov':
        return 'Video';
      case 'audio':
      case 'mp3':
      case 'wav':
        return 'Audio';
      case 'link':
        return 'Enlace externo';
      default:
        return 'Archivo';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Fecha desconocida';
    try {
      final parsedDate = DateTime.parse(date.toString()).toLocal();
      final now = DateTime.now().toLocal();
      final difference = now.difference(parsedDate);
      
      // Tiempo relativo para fechas recientes
      if (difference.inMinutes < 1) {
        return 'Hace un momento';
      } else if (difference.inHours < 1) {
        return 'Hace ${difference.inMinutes} min';
      } else if (difference.inDays < 1) {
        return 'Hace ${difference.inHours} h';
      } else if (difference.inDays < 7) {
        return 'Hace ${difference.inDays} d';
      }
      
      return '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}';
    } catch (_) {
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

  Widget _buildMaterialTile(Map<String, dynamic> material, String courseId) {
    final fileType = material['file_type'] as String? ?? 'other';
    final fileUrl = material['file_url']?.toString();
    final hasValidFile = fileUrl != null && fileUrl.isNotEmpty && _isValidUrl(fileUrl);

    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(
          _getFileIcon(fileType),
          color: _getFileColor(fileType),
        ),
        title: Text(
          material['title']?.toString() ?? 'Sin título',
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getFileTypeDescription(fileType),
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              _formatDate(material['created_at']),
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
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
                color: hasValidFile ? Colors.blue : Colors.grey,
                size: 20,
              ),
              onPressed: hasValidFile ? () => _openMaterial(material) : null,
              tooltip: 'Abrir material',
            ),
            if (fileType != 'link' && hasValidFile)
              IconButton(
                icon: const Icon(
                  Icons.download,
                  color: Colors.green,
                  size: 20,
                ),
                onPressed: () => _downloadAndSave(
                  fileUrl!,
                  material['title']?.toString() ?? 'archivo',
                  fileType,
                ),
                tooltip: 'Descargar',
              ),
          ],
        ),
        onTap: () {
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MaterialCommentsScreen(material: material),
              ),
            );
          }
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
          course['title']?.toString() ?? 'Sin título',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            ...materials.map((material) => _buildMaterialTile(material, courseId)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () {
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourseCommentsScreen(course: course),
                      ),
                    );
                  }
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
                onPressed: () => _enrollInCourse(course),
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

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Error al cargar cursos',
            style: TextStyle(
              fontSize: 18,
              color: Colors.red.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadCourses,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay cursos disponibles',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Vuelve más tarde para ver nuevos cursos',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadCourses,
            tooltip: 'Actualizar cursos',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? _buildErrorState()
              : _courses.isEmpty
                  ? _buildEmptyState()
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
                                final courseId = course['id']?.toString() ?? '';
                                final isEnrolling = _enrollingCourses.contains(courseId);
                                final isEnrolled = _enrolledCourses[courseId] == true;
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