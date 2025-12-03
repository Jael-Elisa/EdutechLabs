import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../video_player_screen.dart';
import 'dart:io';

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
  Map<String, List<Map<String, dynamic>>> _courseMaterials = {};
  Map<String, bool> _expandedCourses = {};
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
      final response = await _supabase
          .from('courses')
          .select('*')
          .eq('teacher_id', user!.id)
          .order('created_at', ascending: false);

      setState(() {
        _courses = List<Map<String, dynamic>>.from(response);
        _filteredCourses = _courses;
        _isLoading = false;
      });

      // Cargar materiales para cada curso
      for (var course in _courses) {
        _loadCourseMaterials(course['id']);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading courses: $e');
    }
  }

  Future<void> _loadCourseMaterials(String courseId) async {
    try {
      final response = await _supabase
          .from('materials')
          .select('*')
          .eq('course_id', courseId)
          .order('created_at', ascending: false);

      setState(() {
        _courseMaterials[courseId] = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error loading materials for course $courseId: $e');
    }
  }

  void _searchCourse(String query) {
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
      await _supabase.from('courses').delete().eq('id', courseId);
      await _loadCourses(); // Recargar la lista

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Curso eliminado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar curso: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // FUNCIONALIDAD DE VISUALIZAR Y DESCARGAR MATERIALES
  Future<void> _openMaterial(Map<String, dynamic> material) async {
    final String fileUrl = material['file_url'];
    final String title = material['title'] ?? 'Material';
    final String fileType = material['file_type'];

    // Si es un enlace externo
    if (fileType == 'link') {
      await _openLink(fileUrl);
      return;
    }

    // Si es un video, abrir en el reproductor
    if (fileType == 'video') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(url: fileUrl),
        ),
      );
      return;
    }

    // Mostrar diálogo de opciones para otros archivos
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
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir: $url')),
        );
      }
    }
  }

  Future<void> _viewInBrowser(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir en el navegador')),
        );
      }
    }
  }

  Future<void> _downloadAndSave(
      String url, String fileName, String fileType) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Descargando $fileName...'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final dir = await getApplicationDocumentsDirectory();
      final cleanFileName = _cleanFileName(fileName);
      final filePath = '${dir.path}/$cleanFileName';

      final response = await _dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      final file = await File(filePath).writeAsBytes(response.data);

      // Intentar abrir el archivo
      final result = await OpenFile.open(filePath);

      if (mounted) {
        if (result.type == ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"$cleanFileName" descargado y abierto'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Archivo guardado en: ${file.path}'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteMaterial(
      String materialId, String courseId, String fileUrl) async {
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
      await _supabase.from('materials').delete().eq('id', materialId);
      await _loadCourseMaterials(courseId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Material eliminado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToCourseMaterials(Map<String, dynamic> course) {
    context.push('/teacher/courses/${course['id']}/materials', extra: course);
  }

  void _navigateToCourseComments(Map<String, dynamic> course) {
    context.push('/teacher/comments', extra: course);
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    switch (index) {
      case 0: // Cursos (ya estamos aquí)
        break;
      case 1: // Materiales
        context.go('/teacher/materials');
        break;
      case 2: // Perfil
        context.go('/profile');
        break;
    }
  }

  // MÉTODOS AUXILIARES PARA ARCHIVOS
  String _cleanFileName(String fileName) {
    final cleaned = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    if (cleaned.length > 100) {
      final extension = cleaned.split('.').last;
      final name = cleaned.substring(0, 100 - extension.length - 1);
      return '$name.$extension';
    }
    return cleaned;
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
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                // 🔍 BUSCADOR
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _searchCourse,
                    decoration: InputDecoration(
                      labelText: "Buscar curso...",
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _searchCourse('');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
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
                                final courseId = course['id'];
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
                                      course['title'] ?? 'Sin título',
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
                                          course['category'] ?? 'Sin categoría',
                                          style: TextStyle(
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          course['description'] ??
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
                                          return Material(
                                            color: Colors.transparent,
                                            child: ListTile(
                                              leading: Icon(
                                                _getFileIcon(
                                                    material['file_type']),
                                                color: _getFileColor(
                                                    material['file_type']),
                                              ),
                                              title: Text(
                                                material['title'] ??
                                                    'Sin título',
                                                style: const TextStyle(
                                                    fontSize: 14),
                                              ),
                                              subtitle: Text(
                                                '${_getFileTypeDescription(material['file_type'])} • ${_formatDate(material['created_at'] ?? '')}',
                                                style: const TextStyle(
                                                    fontSize: 12),
                                              ),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // Botón para abrir/ver
                                                  IconButton(
                                                    icon: Icon(
                                                      material['file_type'] ==
                                                              'video'
                                                          ? Icons.play_arrow
                                                          : material['file_type'] ==
                                                                  'link'
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
                                                  // Botón para descargar (si no es enlace)
                                                  if (material['file_type'] !=
                                                      'link')
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.download,
                                                        color: Colors.green,
                                                        size: 20,
                                                      ),
                                                      onPressed: () =>
                                                          _downloadAndSave(
                                                        material['file_url'],
                                                        material['title'] ??
                                                            'archivo',
                                                        material['file_type'],
                                                      ),
                                                    ),
                                                  // Botón para eliminar
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.delete,
                                                      color: Colors.red,
                                                      size: 20,
                                                    ),
                                                    onPressed: () =>
                                                        _deleteMaterial(
                                                      material['id'],
                                                      courseId,
                                                      material['file_url'],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              onTap: () =>
                                                  _openMaterial(material),
                                            ),
                                          );
                                        }).toList(),
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
                                              onPressed: () =>
                                                  _navigateToCourseComments(
                                                      course),
                                              icon: const Icon(Icons.comment),
                                              label: const Text('Comentarios'),
                                            ),
                                            PopupMenuButton<String>(
                                              icon: const Icon(Icons.more_vert),
                                              onSelected: (value) {
                                                if (value == 'delete') {
                                                  _deleteCourse(course['id']);
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
