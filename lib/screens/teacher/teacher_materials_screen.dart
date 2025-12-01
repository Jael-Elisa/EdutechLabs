import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';

class TeacherMaterialsScreen extends StatefulWidget {
  const TeacherMaterialsScreen({super.key});

  @override
  State<TeacherMaterialsScreen> createState() => _TeacherMaterialsScreenState();
}

class _TeacherMaterialsScreenState extends State<TeacherMaterialsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _myCourses = [];
  List<Map<String, dynamic>> _materials = [];
  String? _selectedCourseId;
  bool _isLoading = true;
  bool _isUploading = false;
  int _currentIndex = 1; // Índice para materiales

  @override
  void initState() {
    super.initState();
    _loadMyCourses();
  }

  Future<void> _loadMyCourses() async {
    try {
      final user = _supabase.auth.currentUser;
      final response = await _supabase
          .from('courses')
          .select('*')
          .eq('teacher_id', user!.id)
          .order('created_at', ascending: false);

      setState(() {
        _myCourses = List<Map<String, dynamic>>.from(response);
        if (_myCourses.isNotEmpty) {
          _selectedCourseId = _myCourses.first['id'];
          _loadMaterials(_myCourses.first['id']);
        } else {
          _isLoading = false;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading courses: $e');
    }
  }

  Future<void> _loadMaterials(String courseId) async {
    try {
      final response = await _supabase
          .from('materials')
          .select('*')
          .eq('course_id', courseId)
          .order('created_at', ascending: false);

      setState(() {
        _materials = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading materials: $e');
    }
  }

  // Navegación del bottom navigation bar
  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    switch (index) {
      case 0: // Cursos
        context.go('/teacher/courses');
        break;
      case 1: // Materiales (ya estamos aquí)
        break;
      case 2: // Perfil
        context.go('/profile');
        break;
    }
  }

  Future<void> _uploadMaterial() async {
    if (_selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un curso primero')),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'txt',
          'rtf',
          'odt',
          'jpg',
          'jpeg',
          'png',
          'gif',
          'mp4',
          'avi',
          'mov',
          'zip',
          'rar',
          'ppt',
          'pptx',
          'xls',
          'xlsx',
        ],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _isUploading = true);

      final file = result.files.first;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final filePath = 'courses/$_selectedCourseId/$fileName';

      print('Starting upload: $fileName - Type: ${file.extension}');

      // Subir el archivo a Supabase Storage
      if (file.bytes != null) {
        // Para web/mobile - usar uploadBytes
        await _supabase.storage
            .from('materials')
            .uploadBinary(filePath, file.bytes!);
      } else if (file.path != null) {
        // Para desktop - usar upload
        final fileData = File(file.path!);
        await _supabase.storage.from('materials').upload(filePath, fileData);
      } else {
        throw Exception('No file data available');
      }

      // Obtener URL pública
      final fileUrl = _supabase.storage
          .from('materials')
          .getPublicUrl(filePath);

      print('File uploaded successfully: $fileUrl');

      // Guardar metadata en la base de datos
      await _supabase.from('materials').insert({
        'course_id': _selectedCourseId,
        'title': file.name,
        'file_url': fileUrl,
        'file_type': _getFileType(file.extension ?? 'unknown'),
        'file_size': file.size,
        'uploader_id': _supabase.auth.currentUser!.id,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Recargar materiales
      await _loadMaterials(_selectedCourseId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${file.name}" subido exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _addLinkMaterial() async {
    if (_selectedCourseId == null) return;

    final titleController = TextEditingController();
    final urlController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Enlace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Título del material',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                border: OutlineInputBorder(),
                hintText: 'https://...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty &&
                  urlController.text.isNotEmpty) {
                try {
                  await _supabase.from('materials').insert({
                    'course_id': _selectedCourseId,
                    'title': titleController.text,
                    'file_url': urlController.text,
                    'file_type': 'link',
                    'uploader_id': _supabase.auth.currentUser!.id,
                    'created_at': DateTime.now().toIso8601String(),
                  });

                  Navigator.pop(context);
                  await _loadMaterials(_selectedCourseId!);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enlace agregado exitosamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al agregar enlace: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMaterial(String materialId, String fileUrl) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Material'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar este material?',
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
      // Eliminar de la base de datos
      await _supabase.from('materials').delete().eq('id', materialId);

      // Si no es un enlace, eliminar también del storage
      if (!fileUrl.contains('http') || fileUrl.contains('supabase.co')) {
        try {
          // Extraer path del file_url y eliminar del storage
          final uri = Uri.parse(fileUrl);
          final pathSegments = uri.pathSegments;
          if (pathSegments.length >= 3) {
            final storagePath = pathSegments.sublist(2).join('/');
            await _supabase.storage.from('materials').remove([storagePath]);
          }
        } catch (e) {
          print('Error deleting from storage: $e');
        }
      }

      await _loadMaterials(_selectedCourseId!);

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

  String _getFileType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'pdf';
      case 'doc':
      case 'docx':
      case 'rtf':
      case 'odt':
        return 'document';
      case 'txt':
        return 'text';
      case 'ppt':
      case 'pptx':
        return 'presentation';
      case 'xls':
      case 'xlsx':
        return 'spreadsheet';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        return 'image';
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
        return 'video';
      case 'mp3':
      case 'wav':
      case 'ogg':
        return 'audio';
      case 'zip':
      case 'rar':
      case '7z':
        return 'archive';
      default:
        return 'other';
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
      case 'presentation':
        return Icons.slideshow;
      case 'spreadsheet':
        return Icons.table_chart;
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.video_library;
      case 'audio':
        return Icons.audiotrack;
      case 'link':
        return Icons.link;
      case 'archive':
        return Icons.archive;
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
      case 'presentation':
        return Colors.orange;
      case 'spreadsheet':
        return Colors.green;
      case 'image':
        return Colors.purple;
      case 'video':
        return Colors.pink;
      case 'audio':
        return Colors.teal;
      case 'link':
        return Colors.amber;
      case 'archive':
        return Colors.brown;
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
      case 'presentation':
        return 'Presentación';
      case 'spreadsheet':
        return 'Hoja de cálculo';
      case 'image':
        return 'Imagen';
      case 'video':
        return 'Video';
      case 'audio':
        return 'Audio';
      case 'link':
        return 'Enlace externo';
      case 'archive':
        return 'Archivo comprimido';
      default:
        return 'Archivo';
    }
  }

  void _openMaterial(Map<String, dynamic> material) {
    final url = material['file_url'];
    if (material['file_type'] == 'link') {
      // Aquí puedes usar url_launcher para abrir el enlace
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Abriendo enlace: $url')));
    } else {
      // Para archivos, mostrar diálogo con opción de descargar/ver
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(material['title'] ?? 'Material'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getFileIcon(material['file_type']),
                size: 64,
                color: _getFileColor(material['file_type']),
              ),
              const SizedBox(height: 16),
              Text(_getFileTypeDescription(material['file_type'])),
              const SizedBox(height: 8),
              if (material['file_size'] != null)
                Text('Tamaño: ${_formatFileSize(material['file_size'])}'),
              const SizedBox(height: 8),
              Text('Formato: ${_getFileExtension(material['title'] ?? '')}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
            ElevatedButton(
              onPressed: () {
                // Aquí puedes implementar la descarga/visualización
                Navigator.pop(context);
                _downloadMaterial(material);
              },
              child: const Text('Descargar'),
            ),
          ],
        ),
      );
    }
  }

  void _downloadMaterial(Map<String, dynamic> material) {
    final url = material['file_url'];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Descargando: ${material['title']}'),
        action: SnackBarAction(
          label: 'Abrir',
          onPressed: () {
            // Aquí puedes usar url_launcher para abrir el enlace
          },
        ),
      ),
    );
  }

  String _getFileExtension(String fileName) {
    try {
      return fileName.split('.').last.toUpperCase();
    } catch (e) {
      return 'DESCONOCIDO';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _myCourses.isNotEmpty
          ? FloatingActionButton(
              onPressed: _isUploading
                  ? null
                  : () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.upload_file),
                                title: const Text('Subir Archivo'),
                                subtitle: const Text(
                                  'Word, PDF, PowerPoint, Excel, etc.',
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  _uploadMaterial();
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.link),
                                title: const Text('Agregar Enlace'),
                                subtitle: const Text(
                                  'Enlace a recursos externos',
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  _addLinkMaterial();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
              child: _isUploading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.add),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Selector de curso
                if (_myCourses.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCourseId,
                      decoration: const InputDecoration(
                        labelText: 'Seleccionar Curso',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: _myCourses.map<DropdownMenuItem<String>>((course) {
                        return DropdownMenuItem<String>(
                          value: course['id'] as String,
                          child: Text(
                            course['title'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? courseId) {
                        if (courseId != null) {
                          setState(() {
                            _selectedCourseId = courseId;
                            _isLoading = true;
                          });
                          _loadMaterials(courseId);
                        }
                      },
                    ),
                  ),
                ],

                // Lista de materiales
                Expanded(
                  child: _myCourses.isEmpty
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
                                'No tienes cursos creados',
                                style: TextStyle(fontSize: 18),
                              ),
                              Text(
                                'Crea un curso primero para agregar materiales',
                              ),
                            ],
                          ),
                        )
                      : _isUploading
                      ? const Center(child: CircularProgressIndicator())
                      : _materials.isEmpty
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
                                'No hay materiales',
                                style: TextStyle(fontSize: 18),
                              ),
                              Text('Agrega el primer material a este curso'),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _loadMaterials(_selectedCourseId!),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _materials.length,
                            itemBuilder: (context, index) {
                              final material = _materials[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: _getFileColor(
                                        material['file_type'],
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _getFileColor(
                                          material['file_type'],
                                        ).withOpacity(0.3),
                                      ),
                                    ),
                                    child: Icon(
                                      _getFileIcon(material['file_type']),
                                      color: _getFileColor(
                                        material['file_type'],
                                      ),
                                      size: 28,
                                    ),
                                  ),
                                  title: Text(
                                    material['title'] ?? 'Sin título',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getFileTypeDescription(
                                          material['file_type'],
                                        ),
                                      ),
                                      if (material['file_size'] != null)
                                        Text(
                                          '${_formatFileSize(material['file_size'])} • ${_getFileExtension(material['title'] ?? '')}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      if (material['created_at'] != null)
                                        Text(
                                          'Subido: ${_formatDate(material['created_at'])}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _deleteMaterial(
                                      material['id'],
                                      material['file_url'],
                                    ),
                                  ),
                                  onTap: () => _openMaterial(material),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
      // Bottom Navigation Bar
      // bottomNavigationBar: BottomNavigationBar(
      //   currentIndex: _currentIndex,
      //   onTap: _onItemTapped,
      //   backgroundColor: Colors.white,
      //   selectedItemColor: const Color(0xFF1A237E),
      //   unselectedItemColor: Colors.grey,
      //   selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
      //   items: const [
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.school),
      //       label: 'Mis Cursos',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.library_books),
      //       label: 'Materiales',
      //     ),
      //     BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
      //   ],
      // ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Fecha desconocida';
    }
  }
}
