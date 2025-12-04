import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';

import '../material_comments_screen.dart';
import '../teacher/download_helper.dart';

class StudentMaterialsScreen extends StatefulWidget {
  const StudentMaterialsScreen({super.key});

  @override
  State<StudentMaterialsScreen> createState() => _StudentMaterialsScreenState();
}

class _StudentMaterialsScreenState extends State<StudentMaterialsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Dio _dio = Dio();

  List<Map<String, dynamic>> _enrolledCourses = [];
  final Map<String, List<Map<String, dynamic>>> _courseMaterials = {};
  bool _isLoading = true;
  String? _selectedCourseId;

  @override
  void initState() {
    super.initState();
    _loadEnrolledCourses();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadEnrolledCourses() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase.from('enrollments').select('''
            course_id,
            courses!inner (
              id,
              title,
              description,
              category,
              teacher_id,
              created_at
            )
          ''').eq('student_id', user.id).eq('status', 'active');

      if (!mounted) return;

      final list = List<Map<String, dynamic>>.from(response);

      setState(() {
        _enrolledCourses = list;
        _isLoading = false;
      });

      if (list.isNotEmpty) {
        final firstCourseId = list.first['course_id'].toString();

        if (!mounted) return;
        setState(() {
          _selectedCourseId = firstCourseId;
        });

        await _loadCourseMaterials(firstCourseId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Error al cargar cursos: $e');
    }
  }

  Future<void> _loadCourseMaterials(String courseId) async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);

      final materials = await _supabase.from('materials').select('''
            id,
            course_id,
            title,
            description,
            file_url,
            file_type,
            file_size,
            created_at,
            uploader_id
          ''').eq('course_id', courseId).order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _courseMaterials[courseId] = List<Map<String, dynamic>>.from(materials);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Error al cargar materiales: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _downloadMaterial(String fileUrl, String fileName) async {
    if (fileUrl.isEmpty) {
      _showError('No hay archivo asociado a este material');
      return;
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
        fileUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = Uint8List.fromList(response.data!);
      final mimeType = DownloadHelper.getMimeType(fileName);

      await DownloadHelper.downloadFile(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Error al descargar: $e');
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
      return '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}';
    } catch (e) {
      return 'Fecha inválida';
    }
  }

  Widget _buildMaterialItem(Map<String, dynamic> material) {
    final fileType = material['file_type']?.toString().toLowerCase() ?? 'file';
    final fileSize = material['file_size'] ?? 0;

    IconData icon;
    Color color;

    switch (fileType) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      case 'doc':
      case 'docx':
        icon = Icons.description;
        color = Colors.blue;
        break;
      case 'ppt':
      case 'pptx':
        icon = Icons.slideshow;
        color = Colors.orange;
        break;
      case 'video':
      case 'mp4':
      case 'avi':
      case 'mov':
        icon = Icons.video_library;
        color = Colors.purple;
        break;
      case 'image':
      case 'jpg':
      case 'png':
      case 'jpeg':
      case 'gif':
        icon = Icons.image;
        color = Colors.green;
        break;
      case 'zip':
      case 'rar':
      case '7z':
        icon = Icons.folder_zip;
        color = Colors.amber;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          material['title'] ?? 'Sin título',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (material['description'] != null) ...[
              Text(
                material['description']!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    fileType.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatFileSize(fileSize),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Subido: ${_formatDate(material['created_at'])}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.download, color: Colors.green),
          ),
          onPressed: () => _downloadMaterial(
            material['file_url'] ?? '',
            material['title'] ?? 'archivo',
          ),
        ),
        onTap: () {
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MaterialCommentsScreen(material: material),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Materiales de Cursos'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _enrolledCourses.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.school, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No estás inscrito en ningún curso',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Inscríbete en cursos para ver los materiales',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.grey.shade50,
                      child: DropdownButtonFormField<String>(
                        value: _selectedCourseId,
                        decoration: const InputDecoration(
                          labelText: 'Seleccionar Curso',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _enrolledCourses.map((enrollment) {
                          final course = enrollment['courses'];
                          return DropdownMenuItem<String>(
                            value: enrollment['course_id'].toString(),
                            child: Text(
                              course['title'] ?? 'Curso sin título',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          );
                        }).toList(),
                        onChanged: (courseId) {
                          if (courseId != null) {
                            if (!mounted) return;
                            setState(() => _selectedCourseId = courseId);
                            _loadCourseMaterials(courseId);
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: _selectedCourseId == null ||
                              _courseMaterials[_selectedCourseId] == null ||
                              _courseMaterials[_selectedCourseId]!.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.library_books,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No hay materiales disponibles',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'El profesor aún no ha subido materiales para este curso',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () =>
                                  _loadCourseMaterials(_selectedCourseId!),
                              child: ListView.builder(
                                itemCount:
                                    _courseMaterials[_selectedCourseId]!.length,
                                itemBuilder: (context, index) {
                                  final material = _courseMaterials[
                                      _selectedCourseId]![index];
                                  return _buildMaterialItem(material);
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}
