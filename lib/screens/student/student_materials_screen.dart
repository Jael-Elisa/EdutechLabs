import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
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
  final CancelToken _dioCancelToken = CancelToken();

  List<Map<String, dynamic>> _enrolledCourses = [];
  final Map<String, List<Map<String, dynamic>>> _courseMaterials = {};
  List<Map<String, dynamic>> _currentMaterials = [];
  List<Map<String, dynamic>> _filteredMaterials = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String? _selectedCourseId;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEnrolledCourses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dioCancelToken.cancel('Widget disposed');
    super.dispose();
  }

  Future<void> _loadEnrolledCourses() async {
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
          .from('enrollments')
          .select('''
            course_id,
            courses!inner (
              id,
              title,
              description,
              category,
              teacher_id,
              created_at
            )
          ''')
          .eq('student_id', user.id)
          .eq('status', 'active')
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response == null) {
        throw Exception('No se recibieron datos del servidor');
      }

      final list = List<Map<String, dynamic>>.from(response);

      setState(() {
        _enrolledCourses = list;
        _isLoading = false;
        _hasError = false;
      });

      if (list.isNotEmpty) {
        final firstCourseId = list.first['course_id']?.toString();
        
        if (firstCourseId == null || firstCourseId.isEmpty) {
          throw Exception('ID de curso inválido');
        }

        setState(() {
          _selectedCourseId = firstCourseId;
        });

        await _loadCourseMaterials(firstCourseId);
      } else {
        setState(() => _isLoading = false);
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

  Future<void> _loadCourseMaterials(String courseId) async {
    // Validar courseId
    if (courseId.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'ID de curso inválido';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

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
            created_at,
            uploader_id
          ''')
          .eq('course_id', courseId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (materials == null) {
        throw Exception('No se recibieron datos de materiales');
      }

      final list = List<Map<String, dynamic>>.from(materials);

      setState(() {
        _courseMaterials[courseId] = list;

        if (_selectedCourseId == courseId) {
          _currentMaterials = list;
          _filteredMaterials = list;
        }

        _isLoading = false;
        _hasError = false;
      });
    } on TimeoutException catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Tiempo de espera agotado al cargar materiales';
      });
      _showErrorSnackBar('No se pudo cargar los materiales. Verifica tu conexión.');
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
        _errorMessage = 'Error al cargar materiales: ${e.toString()}';
      });
      _showErrorSnackBar('Error al cargar materiales: $e');
    }
  }

  void _searchMaterial(String query) {
    if (!mounted) return;

    setState(() {
      if (query.isEmpty) {
        _filteredMaterials = _currentMaterials;
      } else {
        final q = query.toLowerCase();
        _filteredMaterials = _currentMaterials.where((m) {
          final title = m['title']?.toString().toLowerCase() ?? '';
          final type = m['file_type']?.toString().toLowerCase() ?? '';
          final description = (m['description']?.toString().toLowerCase() ?? '');
          final typeDesc = _getFileTypeDescription(m['file_type']).toLowerCase();

          return title.contains(q) ||
              type.contains(q) ||
              description.contains(q) ||
              typeDesc.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _downloadMaterial(Map<String, dynamic> material) async {
    final String? fileUrl = material['file_url']?.toString();
    final String fileName = material['title']?.toString() ?? 'archivo_desconocido';
    final String fileType = material['file_type']?.toString() ?? '';

    // Validaciones
    if (fileUrl == null || fileUrl.isEmpty) {
      _showErrorSnackBar('No hay archivo asociado a este material');
      return;
    }

    if (!_isValidUrl(fileUrl)) {
      _showErrorSnackBar('URL de archivo inválida');
      return;
    }

    // Validar tamaño máximo de archivo (50MB)
    final fileSize = material['file_size'] as int? ?? 0;
    const maxSize = 50 * 1024 * 1024; // 50MB
    if (fileSize > maxSize) {
      final shouldContinue = await _showSizeWarningDialog(fileSize, maxSize);
      if (!shouldContinue) return;
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

      // Usar cancel token para poder cancelar si es necesario
      final response = await _dio.get<List<int>>(
        fileUrl,
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

  Future<bool> _showSizeWarningDialog(int fileSize, int maxSize) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archivo muy grande'),
        content: Text(
          'El archivo es de ${_formatFileSize(fileSize)} '
          '(límite recomendado: ${_formatFileSize(maxSize)}).\n'
          '¿Deseas continuar con la descarga?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descargar de todos modos'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.isAbsolute;
    } catch (_) {
      return false;
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
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
      return 'Fecha inválida';
    }
  }

  String _getFileTypeDescription(dynamic fileTypeRaw) {
    final fileType = (fileTypeRaw ?? '').toString().toLowerCase();
    switch (fileType) {
      case 'pdf':
        return 'Documento PDF';
      case 'doc':
      case 'docx':
        return 'Documento Word';
      case 'ppt':
      case 'pptx':
        return 'Presentación';
      case 'video':
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
        return 'Video';
      case 'image':
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return 'Imagen';
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return 'Archivo comprimido';
      case 'audio':
      case 'mp3':
      case 'wav':
      case 'ogg':
        return 'Audio';
      case 'txt':
      case 'text':
        return 'Archivo de texto';
      case 'xls':
      case 'xlsx':
      case 'csv':
        return 'Hoja de cálculo';
      default:
        return 'Archivo';
    }
  }

  Widget _buildMaterialItem(Map<String, dynamic> material) {
    final fileType = material['file_type']?.toString().toLowerCase() ?? 'file';
    final fileSize = material['file_size'] as int? ?? 0;
    final title = material['title']?.toString() ?? 'Sin título';
    final description = material['description']?.toString();
    final uploadDate = material['created_at'];

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
      case 'wmv':
        icon = Icons.video_library;
        color = Colors.purple;
        break;
      case 'image':
      case 'jpg':
      case 'png':
      case 'jpeg':
      case 'gif':
      case 'webp':
        icon = Icons.image;
        color = Colors.green;
        break;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
        icon = Icons.folder_zip;
        color = Colors.amber;
        break;
      case 'audio':
      case 'mp3':
      case 'wav':
        icon = Icons.audiotrack;
        color = Colors.teal;
        break;
      case 'txt':
      case 'text':
        icon = Icons.text_fields;
        color = Colors.blueGrey;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      child: InkWell(
        onTap: () {
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MaterialCommentsScreen(material: material),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icono del tipo de archivo
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              
              // Información del archivo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                    
                    const SizedBox(height: 8),
                    
                    // Etiquetas y metadatos
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
                            _getFileTypeDescription(fileType).toUpperCase(),
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
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(uploadDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Botón de descarga
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.download, color: Colors.green),
                ),
                onPressed: () => _downloadMaterial(material),
                tooltip: 'Descargar archivo',
              ),
            ],
          ),
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
            'Error al cargar datos',
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
            onPressed: _loadEnrolledCourses,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCoursesState() {
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
            'No estás inscrito en ningún curso',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Inscríbete en cursos para ver los materiales disponibles',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => context.go('/student/courses'),
            icon: const Icon(Icons.search),
            label: const Text('Explorar cursos'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMaterialsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay materiales disponibles',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'El profesor aún no ha subido materiales para este curso',
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
        title: const Text('Materiales de Cursos'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading ? null : () => context.go('/student/courses'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? _buildErrorState()
              : _enrolledCourses.isEmpty
                  ? _buildEmptyCoursesState()
                  : Column(
                      children: [
                        // Selector de curso
                        Container(
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
                              items: _enrolledCourses.map((enrollment) {
                                final course = enrollment['courses'];
                                final courseTitle = course?['title']?.toString() ?? 'Curso sin título';
                                final courseId = enrollment['course_id']?.toString();
                                
                                return DropdownMenuItem<String>(
                                  value: courseId,
                                  enabled: courseId != null && courseId.isNotEmpty,
                                  child: Text(
                                    courseTitle,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (courseId) {
                                if (courseId != null && courseId.isNotEmpty) {
                                  if (!mounted) return;
                                  setState(() {
                                    _selectedCourseId = courseId;
                                    _isLoading = true;
                                    _searchController.clear();
                                    _currentMaterials = [];
                                    _filteredMaterials = [];
                                  });
                                  _loadCourseMaterials(courseId);
                                }
                              },
                            ),
                          ),
                        ),
                        
                        // Barra de búsqueda
                        if (_selectedCourseId != null && 
                            _courseMaterials[_selectedCourseId] != null &&
                            _courseMaterials[_selectedCourseId]!.isNotEmpty)
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
                                onChanged: _searchMaterial,
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
                        
                        // Contador de materiales
                        if (_selectedCourseId != null && 
                            _courseMaterials[_selectedCourseId] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_filteredMaterials.length} ${_filteredMaterials.length == 1 ? 'material' : 'materiales'}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (_currentMaterials.isNotEmpty)
                                  ElevatedButton.icon(
                                    onPressed: () => _loadCourseMaterials(_selectedCourseId!),
                                    icon: const Icon(Icons.refresh, size: 16),
                                    label: const Text('Actualizar'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      textStyle: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        
                        // Lista de materiales
                        Expanded(
                          child: _selectedCourseId == null || 
                                _courseMaterials[_selectedCourseId] == null
                              ? const Center(child: CircularProgressIndicator())
                              : _currentMaterials.isEmpty
                                  ? _buildEmptyMaterialsState()
                                  : _filteredMaterials.isEmpty
                                      ? Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.search_off,
                                                size: 64,
                                                color: Colors.grey.shade400,
                                              ),
                                              const SizedBox(height: 16),
                                              const Text(
                                                'No se encontraron materiales',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              const Text(
                                                'Intenta con otros términos de búsqueda',
                                                style: TextStyle(color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        )
                                      : RefreshIndicator(
                                          onRefresh: () => _loadCourseMaterials(_selectedCourseId!),
                                          child: ListView.builder(
                                            itemCount: _filteredMaterials.length,
                                            itemBuilder: (context, index) {
                                              final material = _filteredMaterials[index];
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