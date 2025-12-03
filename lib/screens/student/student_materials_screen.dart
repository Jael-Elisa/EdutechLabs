import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math'; // ✅ Agregar este import
// Opcional
import '../material_comments_screen.dart';

class StudentMaterialsScreen extends StatefulWidget {
  const StudentMaterialsScreen({super.key});

  @override
  State<StudentMaterialsScreen> createState() => _StudentMaterialsScreenState();
}

class _StudentMaterialsScreenState extends State<StudentMaterialsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _enrolledCourses = [];
  final Map<String, List<Map<String, dynamic>>> _courseMaterials = {};
  bool _isLoading = true;
  String? _selectedCourseId;

  @override
  void initState() {
    super.initState();
    _loadEnrolledCourses();
  }

  Future<void> _loadEnrolledCourses() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Cargar cursos en los que está inscrito el estudiante
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

      setState(() {
        _enrolledCourses = List<Map<String, dynamic>>.from(response);
        if (_enrolledCourses.isNotEmpty) {
          _selectedCourseId = _enrolledCourses.first['course_id'].toString();
          _loadCourseMaterials(_selectedCourseId!);
        } else {
          _isLoading = false;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error al cargar cursos: $e');
    }
  }

  Future<void> _loadCourseMaterials(String courseId) async {
    try {
      setState(() => _isLoading = true);

      // Consulta simplificada sin la relación con uploader_id
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

      setState(() {
        _courseMaterials[courseId] = List<Map<String, dynamic>>.from(materials);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error al cargar materiales: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _downloadMaterial(String fileUrl, String fileName) {
    // Aquí puedes implementar la descarga del archivo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Descargando: $fileName'),
        backgroundColor: Colors.green,
      ),
    );
    print('Descargar: $fileUrl');
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    final i = (log(bytes) / log(1024)).floor(); // ✅ log ahora está disponible
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}'; // ✅ pow ahora está disponible
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
                    // Selector de cursos
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.grey.shade50,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCourseId,
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
                            setState(() => _selectedCourseId = courseId);
                            _loadCourseMaterials(courseId);
                          }
                        },
                      ),
                    ),

                    // Materiales del curso seleccionado
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
