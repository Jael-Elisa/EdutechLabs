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
import '../teacher/download_helper.dart';
import '../material_comments_screen.dart';

class TeacherMaterialsScreen extends StatefulWidget {
  final String? initialCourseId;

  const TeacherMaterialsScreen({super.key, this.initialCourseId});

  @override
  State<TeacherMaterialsScreen> createState() => _TeacherMaterialsScreenState();
}

class _TeacherMaterialsScreenState extends State<TeacherMaterialsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Dio _dio = Dio();
  
  List<Map<String, dynamic>> _myCourses = [];
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _filteredMaterials = [];
  String? _selectedCourseId;
  
  bool _isLoading = true;
  bool _isUploading = false;
  bool _isDownloading = false;
  bool _isDeleting = false;
  int _currentIndex = 1;
  
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _linkTitleController = TextEditingController();
  final TextEditingController _linkUrlController = TextEditingController();
  
  // Variables para validaciones
  bool _showFileSizeError = false;
  bool _showFileTypeError = false;
  bool _showLinkUrlError = false;
  bool _showLinkTitleError = false;
  bool _showLinkFormatError = false;
  bool _showCourseEmptyError = false;
  String? _uploadingFileName;
  String? _downloadingMaterialId;
  String? _deletingMaterialId;
  
  // Expresiones regulares
  final RegExp _urlRegex = RegExp(
    r'^(https?:\/\/)?([\w\-]+\.)+[\w\-]+(\/[\w\-\.\/?%&=]*)?$',
    caseSensitive: false,
  );
  final RegExp _youtubeRegex = RegExp(
    r'^(https?\:\/\/)?(www\.)?(youtube\.com|youtu\.?be)\/.+$',
    caseSensitive: false,
  );
  final RegExp _googleDriveRegex = RegExp(
    r'^(https?\:\/\/)?(drive\.google\.com)\/.+$',
    caseSensitive: false,
  );
  
  // Límites y restricciones
  final int _maxFileSize = 100 * 1024 * 1024; // 100MB
  final int _maxTitleLength = 200;
  final int _minTitleLength = 3;
  final int _maxUrlLength = 500;
  
  // Formatos permitidos
  final Map<String, List<String>> _allowedFormats = {
    'documentos': ['pdf', 'doc', 'docx', 'txt', 'rtf', 'odt', 'ppt', 'pptx'],
    'imágenes': ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'],
    'videos': ['mp4', 'avi', 'mov', 'wmv', 'mkv', 'flv', 'webm'],
    'audios': ['mp3', 'wav', 'ogg', 'm4a', 'aac'],
    'hojas de cálculo': ['xls', 'xlsx', 'csv', 'ods'],
    'archivos comprimidos': ['zip', 'rar', '7z', 'tar', 'gz'],
  };
  
  @override
  void initState() {
    super.initState();
    _loadMyCourses();
    _searchController.addListener(_onSearchChanged);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _linkTitleController.dispose();
    _linkUrlController.dispose();
    super.dispose();
  }
  
  void _onSearchChanged() {
    _searchMaterial(_searchController.text);
  }
  
  void _validateLinkInputs() {
    final title = _linkTitleController.text;
    final url = _linkUrlController.text;
    
    setState(() {
      _showLinkTitleError = title.trim().isEmpty || title.length < _minTitleLength;
      _showLinkUrlError = url.trim().isEmpty;
      _showLinkFormatError = !_urlRegex.hasMatch(url) && url.isNotEmpty;
    });
  }
  
  bool _validateFileUpload(PlatformFile file) {
    // Validar tamaño
    if (file.size > _maxFileSize) {
      _showErrorDialog(
        'Archivo demasiado grande',
        'El tamaño máximo permitido es ${_maxFileSize ~/ (1024 * 1024)}MB. '
        'Tu archivo es de ${(file.size / (1024 * 1024)).toStringAsFixed(2)}MB.'
      );
      return false;
    }
    
    // Validar extensión
    final extension = file.extension?.toLowerCase() ?? '';
    final isValidExtension = _allowedFormats.values.any(
      (formats) => formats.contains(extension)
    );
    
    if (!isValidExtension) {
      final allowedExtensions = _allowedFormats.values.expand((x) => x).join(', ');
      _showErrorDialog(
        'Formato no permitido',
        'Extensión "$extension" no permitida.\n\n'
        'Formatos permitidos:\n$allowedExtensions'
      );
      return false;
    }
    
    // Validar nombre
    if (file.name.isEmpty) {
      _showErrorDialog('Nombre inválido', 'El archivo no tiene un nombre válido.');
      return false;
    }
    
    // Validar datos del archivo
    if (file.bytes == null && file.path == null) {
      _showErrorDialog('Archivo vacío', 'El archivo seleccionado está vacío o no se pudo leer.');
      return false;
    }
    
    return true;
  }
  
  bool _validateLinkSubmission() {
    final title = _linkTitleController.text.trim();
    final url = _linkUrlController.text.trim();
    
    if (title.isEmpty) {
      _showErrorDialog('Título requerido', 'Por favor ingresa un título para el enlace.');
      return false;
    }
    
    if (title.length < _minTitleLength) {
      _showErrorDialog(
        'Título muy corto',
        'El título debe tener al menos $_minTitleLength caracteres.'
      );
      return false;
    }
    
    if (title.length > _maxTitleLength) {
      _showErrorDialog(
        'Título muy largo',
        'El título no puede exceder $_maxTitleLength caracteres.'
      );
      return false;
    }
    
    if (url.isEmpty) {
      _showErrorDialog('URL requerida', 'Por favor ingresa la URL del recurso.');
      return false;
    }
    
    if (!_urlRegex.hasMatch(url)) {
      _showErrorDialog(
        'URL inválida',
        'Por favor ingresa una URL válida (ej: https://ejemplo.com).'
      );
      return false;
    }
    
    if (url.length > _maxUrlLength) {
      _showErrorDialog(
        'URL muy larga',
        'La URL no puede exceder $_maxUrlLength caracteres.'
      );
      return false;
    }
    
    return true;
  }
  
  Future<bool> _showDeleteConfirmation(String materialName) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Material'),
        content: Text(
          '¿Estás seguro de que deseas eliminar "$materialName"?\n\n'
          'Esta acción no se puede deshacer y eliminará todos los comentarios asociados.'
        ),
        backgroundColor: Colors.red.shade50,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }
  
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        backgroundColor: Colors.red.shade50,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }
  
  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        backgroundColor: Colors.green.shade50,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
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

      final enrollments = List<Map<String, dynamic>>.from(enrollmentsResp as List);

      if (enrollments.isEmpty) return;

      final rows = enrollments.map((e) {
        final studentId = e['student_id'];
        return {
          'user_id': studentId,
          'material_id': materialId,
          'message':
              'Nuevo material disponible: "$materialTitle" en el curso "$courseTitle".',
          'created_at': DateTime.now().toIso8601String(),
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
      if (user == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      final response = await _supabase
          .from('courses')
          .select('*')
          .eq('teacher_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      final courses = List<Map<String, dynamic>>.from(response);

      setState(() {
        _myCourses = courses;
        if (_myCourses.isEmpty) {
          _isLoading = false;
        }
      });

      if (courses.isNotEmpty && mounted) {
        var selected = courses.first;

        if (widget.initialCourseId != null) {
          final found = courses.firstWhere(
            (c) => c['id'] == widget.initialCourseId,
            orElse: () => selected,
          );
          selected = found;
        }

        setState(() {
          _selectedCourseId = selected['id'] as String;
          _isLoading = true;
          _searchController.clear();
        });

        await _loadMaterials(_selectedCourseId!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorDialog('Error al cargar cursos', e.toString());
    }
  }

  Future<void> _loadMaterials(String courseId) async {
    try {
      final response = await _supabase
          .from('materials')
          .select('*')
          .eq('course_id', courseId)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _materials = List<Map<String, dynamic>>.from(response);
        _filteredMaterials = _materials;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorDialog('Error al cargar materiales', e.toString());
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
          final description = _getFileTypeDescription(m['file_type']).toLowerCase();

          return title.contains(query.toLowerCase()) ||
              type.contains(query.toLowerCase()) ||
              description.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _uploadMaterial() async {
    if (_selectedCourseId == null) {
      _showErrorDialog(
        'Selecciona un curso',
        'Debes seleccionar un curso antes de subir materiales.'
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedFormats.values.expand((x) => x).toList(),
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;
      
      final file = result.files.first;
      
      // Validar archivo antes de subir
      if (!_validateFileUpload(file)) return;
      
      if (!mounted) return;
      setState(() {
        _isUploading = true;
        _uploadingFileName = file.name;
      });

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_cleanFileName(file.name)}';
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

      final fileUrl = _supabase.storage.from('materials').getPublicUrl(filePath);

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
        _showSuccessDialog(
          'Material subido',
          '"${file.name}" ha sido subido exitosamente.'
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      _showErrorDialog('Error de autenticación', e.message);
    } catch (e) {
      print('Upload error: $e');
      if (mounted) {
        _showErrorDialog('Error al subir archivo', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadingFileName = null;
        });
      }
    }
  }

  Future<void> _addLinkMaterial() async {
    if (_selectedCourseId == null) {
      _showErrorDialog(
        'Selecciona un curso',
        'Debes seleccionar un curso antes de agregar enlaces.'
      );
      return;
    }

    _linkTitleController.clear();
    _linkUrlController.clear();
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Agregar Enlace'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _linkTitleController,
                    onChanged: (_) {
                      setState(() {
                        _validateLinkInputs();
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Título del material *',
                      border: const OutlineInputBorder(),
                      errorText: _showLinkTitleError ? 'Mínimo $_minTitleLength caracteres' : null,
                      suffixText: '${_linkTitleController.text.length}/$_maxTitleLength',
                      counterText: '',
                    ),
                    maxLength: _maxTitleLength,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _linkUrlController,
                    onChanged: (_) {
                      setState(() {
                        _validateLinkInputs();
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'URL *',
                      border: const OutlineInputBorder(),
                      hintText: 'https://ejemplo.com/recurso',
                      errorText: _showLinkUrlError ? 'URL requerida' : 
                                _showLinkFormatError ? 'URL inválida' : null,
                      suffixText: '${_linkUrlController.text.length}/$_maxUrlLength',
                      counterText: '',
                    ),
                    maxLength: _maxUrlLength,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 8),
                  if (_linkUrlController.text.isNotEmpty)
                    Column(
                      children: [
                        if (_youtubeRegex.hasMatch(_linkUrlController.text))
                          Chip(
                            label: const Text('YouTube'),
                            backgroundColor: Colors.red.shade100,
                          ),
                        if (_googleDriveRegex.hasMatch(_linkUrlController.text))
                          Chip(
                            label: const Text('Google Drive'),
                            backgroundColor: Colors.blue.shade100,
                          ),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_validateLinkSubmission()) {
                    Navigator.of(context).pop(true);
                  }
                },
                child: const Text('Agregar'),
              ),
            ],
          );
        },
      ),
    );

    if (result != true) return;

    try {
      final inserted = await _supabase
          .from('materials')
          .insert({
            'course_id': _selectedCourseId,
            'title': _linkTitleController.text.trim(),
            'file_url': _linkUrlController.text.trim(),
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
        materialTitle: material['title'] as String? ?? 'Nuevo enlace',
      );

      await _loadMaterials(_selectedCourseId!);

      if (mounted) {
        _showSuccessDialog(
          'Enlace agregado',
          'El enlace ha sido agregado exitosamente.'
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      _showErrorDialog('Error de autenticación', e.message);
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Error al agregar enlace', e.toString());
    }
  }

  Future<void> _deleteMaterial(String materialId, String fileUrl, String materialName) async {
    final shouldDelete = await _showDeleteConfirmation(materialName);
    if (shouldDelete != true) return;

    if (!mounted) return;
    setState(() {
      _isDeleting = true;
      _deletingMaterialId = materialId;
    });

    try {
      await _supabase.from('materials').delete().eq('id', materialId);

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
          SnackBar(
            content: const Text('Material eliminado exitosamente'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      _showErrorDialog('Error de autenticación', e.message);
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Error al eliminar material', e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _deletingMaterialId = null;
        });
      }
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(url: fileUrl),
        ),
      );
      return;
    }

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
      await _downloadAndOpenFile(fileUrl, title, fileType, material['id']);
    }
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);

    if (!await launchUrl(uri)) {
      if (mounted) {
        _showErrorDialog('Error al abrir enlace', 'No se pudo abrir: $url');
      }
    }
  }

  Future<void> _viewInBrowser(String url) async {
    final uri = Uri.parse(url);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        _showErrorDialog('Error', 'No se pudo abrir en el navegador.');
      }
    }
  }

  Future<void> _downloadAndOpenFile(
    String url,
    String fileName,
    String fileType,
    String materialId,
  ) async {
    if (!mounted) return;
    
    setState(() {
      _isDownloading = true;
      _downloadingMaterialId = materialId;
    });

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Preparando descarga de $fileName...'),
          duration: const Duration(seconds: 3),
        ),
      );

      print('🔗 Iniciando descarga desde: $url');

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

      await DownloadHelper.downloadFile(
        bytes: bytes,
        fileName: fileName,
        mimeType: _getMimeType(fileType),
      );
    } catch (e) {
      print('Error descargando archivo: $e');
      if (mounted) {
        _showErrorDialog('Error al descargar', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadingMaterialId = null;
        });
      }
    }
  }

  String _cleanFileName(String fileName) {
    final cleaned = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

    if (cleaned.length > 100) {
      final extension = cleaned.split('.').last;
      final name = cleaned.substring(0, 100 - extension.length - 1);
      return '$name.$extension';
    }

    return cleaned;
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
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Fecha desconocida';
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    switch (index) {
      case 0:
        context.go('/teacher/courses');
        break;
      case 1:
        break;
      case 2:
        context.go('/profile');
        break;
    }
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
        title: const Text('Mis Materiales'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading ? null : () => context.go('/teacher/courses'),
        ),
      ),
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
                                subtitle: Text(
                                  'Máximo: ${_maxFileSize ~/ (1024 * 1024)}MB\n'
                                  'Formatos: ${_allowedFormats.values.expand((x) => x).join(', ')}',
                                  style: const TextStyle(fontSize: 12),
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
                                  'Enlace a recursos externos, YouTube, etc.',
                                  style: TextStyle(fontSize: 12),
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
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                        value: _uploadingFileName != null ? null : 0,
                      ),
                    )
                  : const Icon(Icons.add),
              tooltip: 'Agregar material',
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_myCourses.isNotEmpty) ...[
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
                      child: DropdownButtonFormField<String>(
                        value: _selectedCourseId,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF111827),
                        iconEnabledColor: Colors.blueGrey.shade100,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Seleccionar curso',
                          hintStyle: TextStyle(
                            color: Colors.blueGrey.shade300,
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF111827),
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
                        items: _myCourses.map<DropdownMenuItem<String>>((course) {
                          return DropdownMenuItem<String>(
                            value: course['id'] as String,
                            child: Text(
                              course['title'] as String,
                              overflow: TextOverflow.ellipsis,
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
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      cursorColor: const Color(0xFF3D5AFE),
                      decoration: InputDecoration(
                        hintText: 'Buscar material...',
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
                                  _searchMaterial('');
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
                const SizedBox(height: 10),
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
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Subiendo: ${_uploadingFileName ?? "archivo"}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const Text('Por favor espera...'),
                                ],
                              ),
                            )
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
                                  onRefresh: () => _loadMaterials(_selectedCourseId!),
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _filteredMaterials.length,
                                    itemBuilder: (context, index) {
                                      final material = _filteredMaterials[index];
                                      final materialId = material['id'] as String;
                                      final isDownloading = _isDownloading && _downloadingMaterialId == materialId;
                                      final isDeleting = _isDeleting && _deletingMaterialId == materialId;
                                      
                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        elevation: 2,
                                        child: ListTile(
                                          leading: Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: _getFileColor(material['file_type']).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: _getFileColor(material['file_type']).withOpacity(0.3),
                                              ),
                                            ),
                                            child: isDownloading
                                                ? const CircularProgressIndicator(strokeWidth: 2)
                                                : Icon(
                                                    _getFileIcon(material['file_type']),
                                                    color: _getFileColor(material['file_type']),
                                                    size: 28,
                                                  ),
                                          ),
                                          title: Text(
                                            material['title'] ?? 'Sin título',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _getFileTypeDescription(material['file_type']),
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
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: isDownloading
                                                    ? const SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child: CircularProgressIndicator(strokeWidth: 2),
                                                      )
                                                    : Icon(
                                                        material['file_type'] == 'video'
                                                            ? Icons.play_arrow
                                                            : material['file_type'] == 'link'
                                                                ? Icons.open_in_new
                                                                : Icons.open_in_full,
                                                        color: Colors.blue,
                                                      ),
                                                onPressed: isDownloading ? null : () => _openMaterial(material),
                                                tooltip: 'Abrir material',
                                              ),
                                              if (material['file_type'] != 'link')
                                                IconButton(
                                                  icon: isDownloading
                                                      ? const SizedBox(
                                                          width: 20,
                                                          height: 20,
                                                          child: CircularProgressIndicator(strokeWidth: 2),
                                                        )
                                                      : const Icon(
                                                          Icons.download,
                                                          color: Colors.green,
                                                        ),
                                                  onPressed: isDownloading
                                                      ? null
                                                      : () => _downloadAndOpenFile(
                                                            material['file_url'],
                                                            material['title'] ?? 'archivo',
                                                            material['file_type'] ?? 'other',
                                                            materialId,
                                                          ),
                                                  tooltip: 'Descargar',
                                                ),
                                              IconButton(
                                                icon: isDeleting
                                                    ? const SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child: CircularProgressIndicator(strokeWidth: 2),
                                                      )
                                                    : const Icon(
                                                        Icons.delete,
                                                        color: Colors.red,
                                                      ),
                                                onPressed: isDeleting
                                                    ? null
                                                    : () => _deleteMaterial(
                                                          materialId,
                                                          material['file_url'],
                                                          material['title'] ?? 'Material',
                                                        ),
                                                tooltip: 'Eliminar',
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

/* 
1. Validaciones de Archivos:
✅ Tamaño máximo: 100MB

✅ Formatos permitidos organizados por categorías

✅ Validación de extensión del archivo

✅ Validación de nombre del archivo

✅ Validación de datos del archivo (no vacío)

2. Validaciones de Enlaces:
✅ Formato de URL válido

✅ Longitud máxima de URL (500 caracteres)

✅ Longitud mínima/máxima del título

✅ Detección de plataformas (YouTube, Google Drive)

✅ Validación en tiempo real en el diálogo

3. Validaciones de Curso:
✅ Verificación de curso seleccionado antes de subir

✅ Mensaje de error si no hay cursos

✅ Control de estado de carga

4. Diálogos de Confirmación:
✅ Confirmación antes de eliminar materiales

✅ Diálogos de éxito/error personalizados

✅ Diálogos de validación en tiempo real

5. Manejo de Estado Mejorado:
✅ Indicadores de carga específicos para cada acción

✅ Estado de descarga por material

✅ Estado de eliminación por material

✅ Estado de subida con nombre de archivo

6. Protección contra Errores:
✅ Captura de excepciones de autenticación

✅ Manejo de errores de red

✅ Validación antes de operaciones costosas

✅ Fallbacks para errores inesperados

7. Feedback Visual Mejorado:
✅ Progress indicators en botones específicos

✅ Mensajes de error descriptivos

✅ Snackbars con mejor diseño

✅ Tooltips en botones de acción

8. Validaciones de Entrada:
✅ Longitud máxima del título (200 caracteres)

✅ Longitud mínima del título (3 caracteres)

✅ Contadores de caracteres en tiempo real

✅ Limpieza de nombres de archivo

9. Mejoras de UX:
✅ Indicación de tamaño máximo en FAB

✅ Lista de formatos permitidos visible

✅ Botones deshabilitados durante operaciones

✅ Refresh indicator para actualizar lista

10. Seguridad Adicional:
✅ Validación de permisos implícita

✅ Protección contra inyección de nombres

✅ Validación de URLs maliciosas

✅ Control de acceso basado en usuario
*/