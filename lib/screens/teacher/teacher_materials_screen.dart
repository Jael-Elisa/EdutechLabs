import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import '../video_player_screen.dart';

// Helper para descargas (necesitas crearlo)
import 'download_helper.dart';
import '../material_comments_screen.dart';

class TeacherMaterialsScreen extends StatefulWidget {
  const TeacherMaterialsScreen({super.key});

  @override
  State<TeacherMaterialsScreen> createState() => _TeacherMaterialsScreenState();
}

class _TeacherMaterialsScreenState extends State<TeacherMaterialsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _myCourses = [];
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _filteredMaterials = [];
  String? _selectedCourseId;
  bool _isLoading = true;
  bool _isUploading = false;
  int _currentIndex = 1;
  final TextEditingController _searchController = TextEditingController();
  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _loadMyCourses();
  }

  Future<void> _createNotificationsForNewMaterial({
    required String courseId,
    required String materialId,
    required String materialTitle,
  }) async {
    try {
      String courseTitle = 'Curso';
      try {
        final course = _myCourses.firstWhere(
          (c) => c['id'] == courseId,
          orElse: () => {},
        );
        if (course['title'] != null) {
          courseTitle = course['title'] as String;
        }
      } catch (_) {}
      final enrollmentsResp = await _supabase
          .from('enrollments')
          .select('student_id')
          .eq('course_id', courseId)
          .eq('status', 'active');

      final enrollments =
          List<Map<String, dynamic>>.from(enrollmentsResp as List);

      if (enrollments.isEmpty) return;

      final rows = enrollments.map((e) {
        final studentId = e['student_id'];
        return {
          'user_id': studentId,
          'material_id': materialId,
          'message':
              'Nuevo material "$materialTitle" en el curso "$courseTitle".',
        };
      }).toList();
      await _supabase.from('notifications').insert(rows);
    } catch (e) {
      debugPrint('Error creando notificaciones: $e');
    }
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
        _filteredMaterials = _materials;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading materials: $e');
    }
  }

  void _searchMaterial(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMaterials = _materials;
      } else {
        _filteredMaterials = _materials.where((m) {
          final title = m['title']?.toString().toLowerCase() ?? '';
          final type = m['file_type']?.toString().toLowerCase() ?? '';
          final description =
              _getFileTypeDescription(m['file_type']).toLowerCase();

          return title.contains(query.toLowerCase()) ||
              type.contains(query.toLowerCase()) ||
              description.contains(query.toLowerCase());
        }).toList();
      }
    });
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

      if (file.bytes != null) {
        await _supabase.storage
            .from('materials')
            .uploadBinary(filePath, file.bytes!);
      } else if (file.path != null) {
        final fileData = File(file.path!);
        await _supabase.storage.from('materials').upload(filePath, fileData);
      } else {
        throw Exception('No file data available');
      }

      final fileUrl =
          _supabase.storage.from('materials').getPublicUrl(filePath);

      print('File uploaded successfully: $fileUrl');

      final inserted = await _supabase
          .from('materials')
          .insert({
            'course_id': _selectedCourseId,
            'title': file.name,
            'file_url': fileUrl,
            'file_type': _getFileType(file.extension ?? 'unknown'),
            'file_size': file.size,
            'uploader_id': _supabase.auth.currentUser!.id,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id, title, course_id')
          .single();

      final material = Map<String, dynamic>.from(inserted as Map);

      await _createNotificationsForNewMaterial(
        courseId: material['course_id'] as String,
        materialId: material['id'] as String,
        materialTitle: material['title'] as String? ?? 'Nuevo material',
      );

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
                  final inserted = await _supabase
                      .from('materials')
                      .insert({
                        'course_id': _selectedCourseId,
                        'title': titleController.text.trim(),
                        'file_url': urlController.text.trim(),
                        'file_type': 'link',
                        'uploader_id': _supabase.auth.currentUser!.id,
                        'created_at': DateTime.now().toIso8601String(),
                      })
                      .select('id, title, course_id')
                      .single();

                  final material = Map<String, dynamic>.from(inserted as Map);

                  await _createNotificationsForNewMaterial(
                    courseId: material['course_id'] as String,
                    materialId: material['id'] as String,
                    materialTitle:
                        material['title'] as String? ?? 'Nuevo material',
                  );

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

  // MÉTODOS PARA VER MATERIALES

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
      await _downloadAndOpenFile(fileUrl, title, fileType);
    }
  }

  // Método específico para descargar (similar al primer código)
  Future<void> _downloadAndSave(String url, String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cleanFileName = _cleanFileName(fileName);
      final filePath = '${dir.path}/$cleanFileName';

      final response = await _dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      final file = await File(filePath).writeAsBytes(response.data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Archivo guardado en: ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar el archivo: $e')),
        );
      }
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

  Future<void> _downloadAndOpenFile(
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

      print('🔗 Iniciando descarga desde: $url');

      // 1. Descargar los bytes usando Dio
      Uint8List bytes;
      try {
        final response = await _dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        bytes = Uint8List.fromList(response.data!);
        print('✅ Bytes descargados: ${bytes.length}');
      } catch (e) {
        print('❌ Error descargando bytes: $e');
        throw Exception('No se pudieron descargar los bytes: $e');
      }

      // 2. Usar DownloadHelper para manejar la descarga
      await DownloadHelper.downloadFile(
        bytes: bytes,
        fileName: fileName,
        mimeType: _getMimeType(fileType),
      );
    } catch (e) {
      print('Error descargando archivo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Método tradicional para descargar en móvil/desktop
  Future<void> _traditionalDownload(
    Uint8List bytes,
    String fileName,
    String fileType,
  ) async {
    try {
      // Solicitar permisos de almacenamiento (solo Android/iOS)
      if (Platform.isAndroid || Platform.isIOS) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          if (await Permission.storage.isPermanentlyDenied) {
            if (mounted) {
              await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Permiso necesario'),
                  content: const Text(
                    'Se necesita permiso de almacenamiento para guardar archivos. '
                    'Por favor, habilítalo en la configuración de la app.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => openAppSettings(),
                      child: const Text('Abrir configuración'),
                    ),
                  ],
                ),
              );
            }
          }
          throw Exception('Permiso de almacenamiento denegado');
        }
      }

      // Obtener directorio de descargas
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        directory = await getDownloadsDirectory();
      }

      if (directory == null) {
        throw Exception('No se pudo obtener directorio de descargas');
      }

      // Crear carpeta de descargas si no existe
      final downloadDir = Directory('${directory.path}/EdutechLabs/Materiales');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      // Limpiar nombre del archivo
      final cleanFileName = _cleanFileName(fileName);
      final filePath = '${downloadDir.path}/$cleanFileName';

      // Guardar archivo
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      print('💾 Archivo guardado en: $filePath');

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
              content:
                  Text('Descargado pero no se pudo abrir: ${result.message}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Error en descarga tradicional: $e');
      rethrow;
    }
  }

  /// Método auxiliar para limpiar nombres de archivo
  String _cleanFileName(String fileName) {
    final cleaned = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

    if (cleaned.length > 100) {
      final extension = cleaned.split('.').last;
      final name = cleaned.substring(0, 100 - extension.length - 1);
      return '$name.$extension';
    }

    return cleaned;
  }

  /// Obtener MIME type basado en el tipo de archivo
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

  // MÉTODOS AUXILIARES

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
      case 'mkv':
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

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Fecha desconocida';
    }
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
                            _searchController.clear();
                          });
                          _loadMaterials(courseId);
                        }
                      },
                    ),
                  ),
                ],

                // Buscador
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _searchMaterial,
                    decoration: InputDecoration(
                      labelText: 'Buscar material...',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _searchMaterial('');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

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
                          : _filteredMaterials.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _searchController.text.isNotEmpty
                                            ? Icons.search_off
                                            : Icons.library_books,
                                        size: 64,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _searchController.text.isNotEmpty
                                            ? 'No se encontraron materiales'
                                            : 'No hay materiales',
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                      Text(
                                        _searchController.text.isNotEmpty
                                            ? 'Intenta con otra búsqueda'
                                            : 'Agrega el primer material a este curso',
                                      ),
                                    ],
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: () =>
                                      _loadMaterials(_selectedCourseId!),
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _filteredMaterials.length,
                                    itemBuilder: (context, index) {
                                      final material =
                                          _filteredMaterials[index];
                                      return Card(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        child: ListTile(
                                          leading: Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: _getFileColor(
                                                material['file_type'],
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: _getFileColor(
                                                  material['file_type'],
                                                ).withOpacity(0.3),
                                              ),
                                            ),
                                            child: Icon(
                                              _getFileIcon(
                                                  material['file_type']),
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
                                              if (material['created_at'] !=
                                                  null)
                                                Text(
                                                  'Subido: ${_formatDate(material['created_at'])}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                ),
                                            ],
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
                                                      : Icons.open_in_new,
                                                  color: Colors.blue,
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
                                                  ),
                                                  onPressed: () =>
                                                      _downloadAndSave(
                                                    material['file_url'],
                                                    material['title'] ??
                                                        'archivo',
                                                  ),
                                                ),
                                              // Botón para eliminar
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                ),
                                                onPressed: () =>
                                                    _deleteMaterial(
                                                  material['id'],
                                                  material['file_url'],
                                                ),
                                              ),
                                            ],
                                          ),
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    MaterialCommentsScreen(
                                                        material: material),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                ),
              ],
            ),
    );
  }
}

enum MaterialAction {
  view,
  download,
  cancel,
}
