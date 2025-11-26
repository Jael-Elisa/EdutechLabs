import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

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
    }
  }

  Future<void> _uploadMaterial() async {
  if (_selectedCourseId == null) return;

  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'png', 'mp4'],
  );

  if (result == null || result.files.isEmpty) return;

  setState(() => _isUploading = true);

  try {
    final file = result.files.first;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    
    // ✅ CORRECCIÓN: Usar uploadBytes en lugar de upload
    await _supabase.storage
        .from('materials')
        .uploadBinary(
          'courses/$_selectedCourseId/$fileName', 
          file.bytes!, // ✅ Esto es Uint8List
        );

    // Obtener URL pública
    final fileUrl = _supabase.storage
        .from('materials')
        .getPublicUrl('courses/$_selectedCourseId/$fileName');

    // Guardar en la base de datos
    await _supabase.from('materials').insert({
      'course_id': _selectedCourseId,
      'title': file.name,
      'file_url': fileUrl,
      'file_type': _getFileType(file.extension!),
      'file_size': file.size,
    });

    // Recargar materiales
    await _loadMaterials(_selectedCourseId!);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Material subido exitosamente')),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir material: $e')),
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
              decoration: const InputDecoration(labelText: 'Título del material'),
            ),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(labelText: 'URL'),
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
              if (titleController.text.isNotEmpty && urlController.text.isNotEmpty) {
                await _supabase.from('materials').insert({
                  'course_id': _selectedCourseId,
                  'title': titleController.text,
                  'file_url': urlController.text,
                  'file_type': 'link',
                });
                Navigator.pop(context);
                await _loadMaterials(_selectedCourseId!);
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMaterial(String materialId) async {
    try {
      await _supabase.from('materials').delete().eq('id', materialId);
      await _loadMaterials(_selectedCourseId!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Material eliminado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
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
        return 'document';
      case 'jpg':
      case 'png':
      case 'jpeg':
        return 'image';
      case 'mp4':
      case 'avi':
        return 'video';
      default:
        return 'other';
    }
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'document':
        return Icons.description;
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.video_library;
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
        return Colors.blue;
      case 'image':
        return Colors.green;
      case 'video':
        return Colors.purple;
      case 'link':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _myCourses.isNotEmpty
          ? FloatingActionButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.upload_file),
                        title: const Text('Subir Archivo'),
                        onTap: () {
                          Navigator.pop(context);
                          _uploadMaterial();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.link),
                        title: const Text('Agregar Enlace'),
                        onTap: () {
                          Navigator.pop(context);
                          _addLinkMaterial();
                        },
                      ),
                    ],
                  ),
                );
              },
              child: const Icon(Icons.add),
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
                    child:// En la parte del DropdownButtonFormField, cambia esto:
                      DropdownButtonFormField<String>(
                        value: _selectedCourseId,
                        decoration: const InputDecoration(
                          labelText: 'Seleccionar Curso',
                          border: OutlineInputBorder(),
                        ),
                        // ✅ CORRECCIÓN: Especificar el tipo explícitamente
                        items: _myCourses.map<DropdownMenuItem<String>>((course) {
                          return DropdownMenuItem<String>(
                            value: course['id'] as String, // ✅ Cast explícito
                            child: Text(course['title'] as String),
                          );
                        }).toList(),
                        onChanged: (String? courseId) { // ✅ Tipo nullable String
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
                              Icon(Icons.library_books, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No tienes cursos creados',
                                style: TextStyle(fontSize: 18),
                              ),
                              Text('Crea un curso primero para agregar materiales'),
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
                                      Icon(Icons.library_books, size: 64, color: Colors.grey),
                                      SizedBox(height: 16),
                                      Text(
                                        'No hay materiales',
                                        style: TextStyle(fontSize: 18),
                                      ),
                                      Text('Agrega el primer material a este curso'),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _materials.length,
                                  itemBuilder: (context, index) {
                                    final material = _materials[index];
                                    return Card(
                                      child: ListTile(
                                        leading: Icon(
                                          _getFileIcon(material['file_type']),
                                          color: _getFileColor(material['file_type']),
                                          size: 32,
                                        ),
                                        title: Text(material['title'] ?? 'Sin título'),
                                        subtitle: Text(
                                          material['file_type'] == 'link'
                                              ? 'Enlace externo'
                                              : 'Tipo: ${material['file_type']}',
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _deleteMaterial(material['id']),
                                        ),
                                        onTap: () {
                                          // Abrir material
                                          if (material['file_type'] == 'link') {
                                            // Abrir enlace web
                                          } else {
                                            // Ver archivo
                                          }
                                        },
                                      ),
                                    );
                                  },
                                ),
                ),
              ],
            ),
    );
  }
}