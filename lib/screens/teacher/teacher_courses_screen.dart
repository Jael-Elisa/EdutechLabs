import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import '../video_player_screen.dart';
import '../teacher/course_comments_screen.dart';
import 'dart:typed_data';
import '../teacher/download_helper.dart';

class TeacherCoursesScreen extends StatefulWidget {
  const TeacherCoursesScreen({super.key});

  @override
  State<TeacherCoursesScreen> createState() => _TeacherCoursesScreenState();
}

class _TeacherCoursesScreenState extends State<TeacherCoursesScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Dio _dio = Dio();

  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _filteredCourses = [];
  final Map<String, List<Map<String, dynamic>>> _courseMaterials = {};
  final Map<String, bool> _expandedCourses = {};
  bool _isLoading = true;
  int _currentIndex = 0;
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
      
      // Validar usuario autenticado
      if (user == null) {
        if (!mounted) return;
        _showErrorSnackBar('Usuario no autenticado. Por favor inicie sesión.');
        context.go('/login');
        return;
      }

      final response = await _supabase
          .from('courses')
          .select('*')
          .eq('teacher_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;
      
      // Validar respuesta
      if (response == null) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Error al cargar cursos: respuesta nula');
        return;
      }

      final courses = List<Map<String, dynamic>>.from(response);

      setState(() {
        _courses = courses;
        _filteredCourses = courses;
        _isLoading = false;
      });

      // Cargar materiales para cada curso
      for (var course in courses) {
        if (!mounted) return;
        if (course['id'] != null) {
          await _loadCourseMaterials(course['id'].toString());
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showErrorSnackBar('Error al cargar cursos: $e');
    }
  }

  Future<void> _loadCourseMaterials(String courseId) async {
    // Validar courseId
    if (courseId.isEmpty) {
      print('Error: courseId vacío');
      return;
    }

    try {
      final response = await _supabase
          .from('materials')
          .select('*')
          .eq('course_id', courseId)
          .order('created_at', ascending: false);

      if (!mounted) return;

      if (response == null) return;

      setState(() {
        _courseMaterials[courseId] = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (!mounted) return;
      print('Error loading materials for course $courseId: $e');
    }
  }

  void _searchCourse(String query) {
    if (!mounted) return;
    setState(() {
      if (query.isEmpty) {
        _filteredCourses = _courses;
      } else {
        _filteredCourses = _courses.where((course) {
          final title = course['title']?.toString().toLowerCase() ?? '';
          final category = course['category']?.toString().toLowerCase() ?? '';
          final description =
              course['description']?.toString().toLowerCase() ?? '';

          return title.contains(query.toLowerCase()) ||
              category.contains(query.toLowerCase()) ||
              description.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _deleteCourse(String courseId) async {
    // Validar courseId
    if (courseId.isEmpty) {
      _showErrorSnackBar('ID de curso inválido');
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Curso'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar este curso? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      // Verificar si el curso existe antes de eliminar
      final existingCourse = await _supabase
          .from('courses')
          .select('id')
          .eq('id', courseId)
          .single()
          .catchError((_) => null);

      if (existingCourse == null) {
        if (!mounted) return;
        _showErrorSnackBar('El curso no existe o ya fue eliminado');
        return;
      }

      await _supabase.from('courses').delete().eq('id', courseId);
      await _loadCourses();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Curso eliminado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _showErrorSnackBar('Error al eliminar curso: $e');
    }
  }

  Future<void> _openMaterial(Map<String, dynamic> material) async {
    // Validar material
    if (material.isEmpty) {
      _showErrorSnackBar('Material inválido');
      return;
    }

    final String? fileUrl = material['file_url'];
    final String title = material['title']?.toString() ?? 'Material';
    final String? fileType = material['file_type'];

    // Validar URL y tipo de archivo
    if (fileUrl == null || fileUrl.isEmpty) {
      _showErrorSnackBar('URL del material no disponible');
      return;
    }

    if (fileType == null || fileType.isEmpty) {
      _showErrorSnackBar('Tipo de archivo no especificado');
      return;
    }

    if (fileType == 'link') {
      await _openLink(fileUrl);
      return;
    }

    if (fileType == 'video') {
      if (!mounted) return;
      
      // Validar URL de video
      if (!_isValidUrl(fileUrl)) {
        _showErrorSnackBar('URL de video inválida');
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
      await _downloadAndSave(fileUrl, title, fileType);
    }
  }

  Future<void> _openLink(String url) async {
    // Validar URL
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
    // Validar URL
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
    // Validaciones de entrada
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

      Uint8List bytes;
      try {
        final response = await _dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        
        // Validar respuesta de descarga
        if (response.data == null || response.data!.isEmpty) {
          throw Exception('Archivo vacío o no disponible');
        }
        
        bytes = Uint8List.fromList(response.data!);
      } catch (e) {
        throw Exception('No se pudieron descargar los bytes: $e');
      }

      await DownloadHelper.downloadFile(
        bytes: bytes,
        fileName: _cleanFileName(fileName),
        mimeType: _getMimeType(fileType),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error al descargar: $e');
    }
  }

  Future<void> _deleteMaterial(
      String materialId, String courseId, String fileUrl) async {
    // Validar IDs
    if (materialId.isEmpty || courseId.isEmpty) {
      _showErrorSnackBar('ID de material o curso inválido');
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Material'),
        content:
            const Text('¿Estás seguro de que quieres eliminar este material?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      // Verificar si el material existe antes de eliminar
      final existingMaterial = await _supabase
          .from('materials')
          .select('id')
          .eq('id', materialId)
          .single()
          .catchError((_) => null);

      if (existingMaterial == null) {
        if (!mounted) return;
        _showErrorSnackBar('El material no existe o ya fue eliminado');
        return;
      }

      await _supabase.from('materials').delete().eq('id', materialId);
      await _loadCourseMaterials(courseId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Material eliminado'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _showErrorSnackBar('Error al eliminar: $e');
    }
  }

  void _navigateToCourseMaterials(Map<String, dynamic> course) {
    // Validar curso
    if (course.isEmpty || course['id'] == null) {
      _showErrorSnackBar('Curso inválido para navegar a materiales');
      return;
    }
    
    context.go(
      '/teacher/materials',
      extra: {
        'courseId': course['id'] as String,
        'courseTitle': course['title'] ?? 'Sin título',
      },
    );
  }

  void _navigateToCourseComments(Map<String, dynamic> course) {
    // Validar curso
    if (course.isEmpty) {
      _showErrorSnackBar('Curso inválido para navegar a comentarios');
      return;
    }
    
    context.push('/teacher/comments', extra: course);
  }

  void _onItemTapped(int index) {
    if (!mounted) return;

    setState(() {
      _currentIndex = index;
    });

    switch (index) {
      case 0:
        break;
      case 1:
        context.go('/teacher/materials');
        break;
      case 2:
        context.go('/profile');
        break;
      default:
        break;
    }
  }

  String _cleanFileName(String fileName) {
    if (fileName.isEmpty) return 'archivo';
    
    final cleaned = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    if (cleaned.length > 100) {
      final extension = cleaned.split('.').last;
      final name = cleaned.substring(0, 100 - extension.length - 1);
      return '$name.$extension';
    }
    return cleaned;
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
      case 'url':
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
      case 'url':
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
      case 'url':
        return 'Enlace externo';
      default:
        return 'Archivo';
    }
  }

  String _formatFileSize(dynamic bytes) {
    try {
      final size = bytes is int ? bytes : int.tryParse(bytes.toString()) ?? 0;
      
      if (size < 1024) return '$bytes B';
      if (size < 1048576) return '${(size / 1024).toStringAsFixed(1)} KB';
      return '${(size / 1048576).toStringAsFixed(1)} MB';
    } catch (e) {
      return 'Tamaño desconocido';
    }
  }

  String _formatDate(dynamic dateString) {
    try {
      if (dateString == null) return 'Fecha desconocida';
      
      final date = DateTime.parse(dateString.toString());
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Fecha desconocida';
    }
  }

  // Método auxiliar para validar URLs
  bool _isValidUrl(String url) {
    if (url.isEmpty) return false;
    
    try {
      final uri = Uri.parse(url);
      return uri.isAbsolute;
    } catch (e) {
      return false;
    }
  }

  // Método auxiliar para mostrar errores
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
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
        title: const Text('Mis Cursos'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/teacher/create-course'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                  child: _courses.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.school, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No tienes cursos creados',
                                style:
                                    TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                              Text(
                                'Crea tu primer curso para comenzar',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : _filteredCourses.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _searchController.text.isNotEmpty
                                        ? Icons.search_off
                                        : Icons.school,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchController.text.isNotEmpty
                                        ? 'No se encontraron cursos'
                                        : 'No hay cursos',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    _searchController.text.isNotEmpty
                                        ? 'Intenta con otra búsqueda'
                                        : 'Crea tu primer curso para comenzar',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredCourses.length,
                              itemBuilder: (context, index) {
                                final course = _filteredCourses[index];
                                final courseId = course['id']?.toString() ?? '';
                                final materials =
                                    _courseMaterials[courseId] ?? [];
                                final isExpanded =
                                    _expandedCourses[courseId] ?? false;

                                return Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ExpansionTile(
                                    leading: Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      child: const Icon(Icons.school,
                                          color: Colors.blue),
                                    ),
                                    title: Text(
                                      course['title']?.toString() ?? 'Sin título',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          course['category']?.toString() ?? 'Sin categoría',
                                          style: TextStyle(
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          course['description']?.toString() ??
                                              'Sin descripción',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
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
                                          () => _navigateToCourseMaterials(
                                              course),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            isExpanded
                                                ? Icons.expand_less
                                                : Icons.expand_more,
                                          ),
                                          onPressed: () {
                                            if (!mounted) return;
                                            setState(() {
                                              _expandedCourses[courseId] =
                                                  !isExpanded;
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
                                              style:
                                                  TextStyle(color: Colors.grey),
                                            ),
                                          ),
                                        )
                                      else
                                        ...materials.map((material) {
                                          final materialId = material['id']?.toString() ?? '';
                                          final fileType = material['file_type']?.toString() ?? '';
                                          final fileUrl = material['file_url']?.toString() ?? '';
                                          final title = material['title']?.toString() ?? 'Sin título';
                                          
                                          return Material(
                                            color: Colors.transparent,
                                            child: ListTile(
                                              leading: Icon(
                                                _getFileIcon(fileType),
                                                color: _getFileColor(fileType),
                                              ),
                                              title: Text(
                                                title,
                                                style: const TextStyle(
                                                    fontSize: 14),
                                              ),
                                              subtitle: Text(
                                                '${_getFileTypeDescription(fileType)} • ${_formatDate(material['created_at'])}',
                                                style: const TextStyle(
                                                    fontSize: 12),
                                              ),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(
                                                      fileType == 'video'
                                                          ? Icons.play_arrow
                                                          : fileType == 'link'
                                                              ? Icons
                                                                  .open_in_new
                                                              : Icons
                                                                  .remove_red_eye,
                                                      color: Colors.blue,
                                                      size: 20,
                                                    ),
                                                    onPressed: () =>
                                                        _openMaterial(material),
                                                  ),
                                                  if (fileType != 'link' && fileUrl.isNotEmpty)
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.download,
                                                        color: Colors.green,
                                                        size: 20,
                                                      ),
                                                      onPressed: () =>
                                                          _downloadAndSave(
                                                        fileUrl,
                                                        title,
                                                        fileType,
                                                      ),
                                                    ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.delete,
                                                      color: Colors.red,
                                                      size: 20,
                                                    ),
                                                    onPressed: () =>
                                                        _deleteMaterial(
                                                      materialId,
                                                      courseId,
                                                      fileUrl,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              onTap: () =>
                                                  _openMaterial(material),
                                            ),
                                          );
                                        }),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _navigateToCourseMaterials(
                                                      course),
                                              icon: const Icon(Icons.add),
                                              label: const Text(
                                                  'Agregar Material'),
                                            ),
                                            OutlinedButton.icon(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        CourseCommentsScreen(
                                                      course: course,
                                                    ),
                                                  ),
                                                );
                                              },
                                              icon: const Icon(Icons.comment),
                                              label: const Text('Comentarios'),
                                            ),
                                            PopupMenuButton<String>(
                                              icon: const Icon(Icons.more_vert),
                                              onSelected: (value) {
                                                if (value == 'delete') {
                                                  _deleteCourse(courseId);
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.delete,
                                                          color: Colors.red,
                                                          size: 20),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Eliminar Curso',
                                                        style: TextStyle(
                                                            color: Colors.red),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
    );
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
}

enum MaterialAction {
  view,
  download,
  cancel,
}