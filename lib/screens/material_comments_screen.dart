import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class MaterialCommentsScreen extends StatefulWidget {
  final Map<String, dynamic> material;

  const MaterialCommentsScreen({
    super.key,
    required this.material,
  });

  @override
  State<MaterialCommentsScreen> createState() => _MaterialCommentsScreenState();
}

class _MaterialCommentsScreenState extends State<MaterialCommentsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  bool _isLoading = true;
  bool _isSending = false;
  bool _isDeleting = false;
  bool _showCommentError = false;
  bool _showCommentLengthError = false;
  bool _showCommentEmptyError = false;
  bool _showCommentSpamError = false;
  List<Map<String, dynamic>> _comments = [];
  RealtimeChannel? _commentsChannel;
  String? _deletingCommentId;

  // Variables para detección de spam
  DateTime? _lastCommentTime;
  int _rapidCommentCount = 0;
  final List<String> _spamPatterns = [
    'http://', 'https://', 'www.', '.com', '.net', '.org',
    'promoción', 'oferta', 'gratis', 'descarga', 'clic aquí',
    'seguro', 'gana dinero', 'trabajo desde casa'
  ];

  // Expresiones regulares
  final RegExp _urlRegex = RegExp(r'https?://[^\s]+|www\.[^\s]+');
  final RegExp _emailRegex = RegExp(r'[\w\.-]+@[\w-]+\.[\w-]+');
  final RegExp _phoneRegex = RegExp(r'[\+\d\s\-\(\)]{10,}');

  // Límites
  final int _maxCommentLength = 500;
  final int _minCommentLength = 3;
  final int _maxCommentsPerMinute = 3;
  final Duration _spamTimeWindow = const Duration(minutes: 1);

  String get _materialId => widget.material['id'] as String;
  String? get _courseId => widget.material['course_id'] as String?;
  String get _fileUrl => widget.material['file_url'] as String? ?? '';
  String get _fileType => widget.material['file_type'] as String? ?? 'file';

  @override
  void initState() {
    super.initState();
    _loadComments();
    _subscribeToRealtimeComments();
    _commentController.addListener(_validateCommentOnType);
  }

  @override
  void dispose() {
    _commentsChannel?.unsubscribe();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _validateCommentOnType() {
    final text = _commentController.text;
    
    if (text.isEmpty) {
      setState(() {
        _showCommentError = false;
        _showCommentLengthError = false;
        _showCommentEmptyError = false;
        _showCommentSpamError = false;
      });
      return;
    }

    setState(() {
      _showCommentEmptyError = text.trim().isEmpty;
      _showCommentLengthError = text.length < _minCommentLength || 
                               text.length > _maxCommentLength;
      _showCommentSpamError = _containsSpamPatterns(text);
    });
  }

  bool _containsSpamPatterns(String text) {
    final lowerText = text.toLowerCase();
    
    // Detectar URLs
    if (_urlRegex.hasMatch(lowerText)) return true;
    
    // Detectar emails
    if (_emailRegex.hasMatch(lowerText)) return true;
    
    // Detectar teléfonos
    if (_phoneRegex.hasMatch(lowerText)) return true;
    
    // Detectar palabras spam
    for (final pattern in _spamPatterns) {
      if (lowerText.contains(pattern)) return true;
    }
    
    // Detectar repeticiones excesivas
    if (_containsExcessiveRepetition(text)) return true;
    
    return false;
  }

  bool _containsExcessiveRepetition(String text) {
    // Verificar caracteres repetidos
    if (RegExp(r'(.)\1{10,}').hasMatch(text)) return true;
    
    // Verificar palabras repetidas
    final words = text.split(' ');
    final uniqueWords = words.toSet();
    if (words.length > 5 && uniqueWords.length < 3) return true;
    
    return false;
  }

  bool _isSpamAttack() {
    final now = DateTime.now();
    
    if (_lastCommentTime == null) {
      _lastCommentTime = now;
      _rapidCommentCount = 1;
      return false;
    }
    
    final timeDifference = now.difference(_lastCommentTime!);
    
    if (timeDifference < _spamTimeWindow) {
      _rapidCommentCount++;
      if (_rapidCommentCount >= _maxCommentsPerMinute) {
        return true;
      }
    } else {
      // Reiniciar contador si ha pasado el tiempo de ventana
      _rapidCommentCount = 1;
      _lastCommentTime = now;
    }
    
    return false;
  }

  Widget _buildCommentRequirements() {
    final hasText = _commentController.text.isNotEmpty;
    if (!hasText) return const SizedBox.shrink();

    final currentLength = _commentController.text.length;
    final bool isNearLimit = currentLength > _maxCommentLength * 0.8;
    final bool isOverLimit = currentLength > _maxCommentLength;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Caracteres: $currentLength/$_maxCommentLength',
          style: TextStyle(
            fontSize: 12,
            color: isOverLimit 
                ? Colors.red 
                : isNearLimit 
                    ? Colors.orange 
                    : Colors.grey,
            fontWeight: isOverLimit ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 4),
        if (_showCommentEmptyError)
          _buildRequirementError('El comentario no puede estar vacío'),
        if (_showCommentLengthError && currentLength < _minCommentLength)
          _buildRequirementError('Mínimo $_minCommentLength caracteres'),
        if (_showCommentLengthError && currentLength > _maxCommentLength)
          _buildRequirementError('Máximo $_maxCommentLength caracteres'),
        if (_showCommentSpamError)
          _buildRequirementError(
            'Contenido no permitido (URLs, spam, etc.)',
            isWarning: true,
          ),
      ],
    );
  }

  Widget _buildRequirementError(String text, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning ? Icons.warning_amber : Icons.error_outline,
            size: 12,
            color: isWarning ? Colors.orange : Colors.red.shade600,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: isWarning ? Colors.orange : Colors.red.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadComments() async {
    try {
      final resp = await _supabase
          .from('comments')
          .select(
            'id, content, created_at, user_id, profiles(full_name, avatar_url)',
          )
          .eq('material_id', _materialId)
          .order('created_at', ascending: false);

      setState(() {
        _comments = List<Map<String, dynamic>>.from(resp as List);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      _showErrorDialog('Error al cargar comentarios', e.toString());
    }
  }

  void _subscribeToRealtimeComments() {
    final materialId = _materialId;

    _commentsChannel =
        _supabase.channel('public:comments:material_$materialId');

    _commentsChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'material_id',
            value: materialId,
          ),
          callback: (payload) async {
            final newId = payload.newRecord['id'] as String?;
            if (newId == null) return;

            final alreadyExists = _comments.any((c) => c['id'] == newId);
            if (alreadyExists) return;

            try {
              final resp = await _supabase
                  .from('comments')
                  .select(
                    'id, content, created_at, user_id, profiles(full_name, avatar_url)',
                  )
                  .eq('id', newId)
                  .single();

              if (!mounted) return;
              setState(() {
                _comments.insert(0, Map<String, dynamic>.from(resp as Map));
              });
            } catch (e) {
              print('Error al cargar comentario en tiempo real: $e');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'material_id',
            value: materialId,
          ),
          callback: (payload) {
            final deletedId = payload.oldRecord['id'] as String?;
            if (deletedId == null) return;

            if (!mounted) return;
            setState(() {
              _comments.removeWhere((c) => c['id'] == deletedId);
            });
          },
        )
        .subscribe();
  }

  Future<bool> _validateCommentSubmission() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return false;
      _showValidationDialog(
        'Debes iniciar sesión',
        'Para comentar, primero debes iniciar sesión en tu cuenta.'
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        context.go('/login');
      });
      return false;
    }

    final text = _commentController.text.trim();
    
    // Validaciones básicas
    if (text.isEmpty) {
      _showValidationDialog(
        'Comentario vacío',
        'Por favor escribe algo antes de enviar.'
      );
      return false;
    }

    if (text.length < _minCommentLength) {
      _showValidationDialog(
        'Comentario muy corto',
        'El comentario debe tener al menos $_minCommentLength caracteres.'
      );
      return false;
    }

    if (text.length > _maxCommentLength) {
      _showValidationDialog(
        'Comentario muy largo',
        'El comentario no puede exceder $_maxCommentLength caracteres.'
      );
      return false;
    }

    // Validar spam patterns
    if (_containsSpamPatterns(text)) {
      _showValidationDialog(
        'Contenido no permitido',
        'Tu comentario contiene elementos no permitidos (URLs, spam, etc.).'
      );
      return false;
    }

    // Validar ataque de spam
    if (_isSpamAttack()) {
      _showValidationDialog(
        'Demasiados comentarios',
        'Por favor espera un momento antes de enviar otro comentario.'
      );
      return false;
    }

    return true;
  }

  Future<void> _sendComment() async {
    // Validar antes de enviar
    final isValid = await _validateCommentSubmission();
    if (!isValid) return;

    final text = _commentController.text.trim();
    final user = _supabase.auth.currentUser!;

    setState(() => _isSending = true);

    try {
      final inserted = await _supabase
          .from('comments')
          .insert({
            'course_id': _courseId,
            'material_id': _materialId,
            'user_id': user.id,
            'content': text,
          })
          .select(
              'id, content, created_at, user_id, profiles(full_name, avatar_url)')
          .single();

      setState(() {
        _commentController.clear();
        _comments.insert(0, Map<String, dynamic>.from(inserted as Map));
        _commentFocusNode.unfocus();
        
        // Actualizar tiempo del último comentario
        _lastCommentTime = DateTime.now();
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      _showErrorDialog('Error de autenticación', e.message);
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Error al enviar comentario', e.toString());
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<bool> _showDeleteConfirmation(String commentId) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar comentario'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este comentario?\n'
          'Esta acción no se puede deshacer.'
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

  Future<void> _deleteComment(String commentId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Mostrar confirmación
    final confirmed = await _showDeleteConfirmation(commentId);
    if (!confirmed) return;

    if (!mounted) return;
    setState(() {
      _isDeleting = true;
      _deletingCommentId = commentId;
    });

    try {
      await _supabase
          .from('comments')
          .delete()
          .eq('id', commentId)
          .eq('user_id', user.id);

      if (!mounted) return;
      
      // Eliminar de la lista local
      setState(() {
        _comments.removeWhere((c) => c['id'] == commentId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Comentario eliminado'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      _showErrorDialog('Error de autenticación', e.message);
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Error al eliminar comentario', e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _deletingCommentId = null;
        });
      }
    }
  }

  String _formatDate(dynamic value) {
    try {
      final dt = DateTime.parse(value.toString()).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dt);
      
      // Si es hoy, mostrar hora
      if (difference.inDays == 0) {
        if (difference.inHours < 1) {
          return 'Hace ${difference.inMinutes} min';
        }
        return 'Hoy ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      
      // Si es ayer
      if (difference.inDays == 1) {
        return 'Ayer ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      
      // Si es esta semana
      if (difference.inDays < 7) {
        final days = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
        return '${days[dt.weekday % 7]} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      
      // Si es más antiguo
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return value?.toString() ?? '';
    }
  }

  Future<void> _openMaterial() async {
    if (_fileUrl.isEmpty) {
      _showValidationDialog('Sin material', 'Este material no tiene archivo disponible.');
      return;
    }

    final uri = Uri.parse(_fileUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      _showErrorDialog('Error', 'No se pudo abrir el material. Verifica tu conexión.');
    }
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

  void _showValidationDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final material = widget.material;
    final String title = material['title'] ?? 'Material';
    final String? description = material['description'];

    final user = _supabase.auth.currentUser;
    final bool canComment = user != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadComments,
            tooltip: 'Actualizar comentarios',
          ),
        ],
      ),
      body: Column(
        children: [
          // Información del material
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            _fileType.toUpperCase(),
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.blue.shade50,
                        ),
                        if (material['created_at'] != null)
                          Chip(
                            label: Text(
                              _formatDate(material['created_at']),
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: Colors.grey.shade100,
                          ),
                        Chip(
                          label: Text(
                            '${_comments.length} comentario${_comments.length != 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: Colors.green.shade50,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _openMaterial,
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Abrir material'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Título de comentarios
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Comentarios',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '(${_comments.length})',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          
          // Lista de comentarios
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay comentarios aún',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sé el primero en comentar',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadComments,
                        color: Colors.blueAccent,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: _comments.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 16),
                          itemBuilder: (context, index) {
                            final c = _comments[index];
                            final profile =
                                c['profiles'] as Map<String, dynamic>?;
                            final name =
                                profile?['full_name'] as String? ?? 'Usuario';
                            final avatarUrl = profile?['avatar_url'] as String?;
                            final content = c['content'] as String? ?? '';
                            final createdAt = c['created_at'];
                            final userId = c['user_id'] as String?;
                            final isOwnComment = userId == user?.id;
                            final commentId = c['id'] as String?;
                            final isDeleting = commentId == _deletingCommentId && _isDeleting;

                            return AnimatedOpacity(
                              opacity: isDeleting ? 0.5 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Card(
                                elevation: 1,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundImage:
                                                avatarUrl != null && avatarUrl.isNotEmpty
                                                    ? NetworkImage(avatarUrl)
                                                    : null,
                                            child: (avatarUrl == null || avatarUrl.isEmpty)
                                                ? Text(
                                                    name.isNotEmpty
                                                        ? name[0].toUpperCase()
                                                        : '?',
                                                    style: const TextStyle(fontSize: 12),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  _formatDate(createdAt),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isOwnComment && commentId != null)
                                            IconButton(
                                              icon: isDeleting
                                                  ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                    )
                                                  : const Icon(Icons.delete_outline, size: 18),
                                              onPressed: isDeleting ? null : () => _deleteComment(commentId),
                                              color: Colors.grey.shade600,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                minWidth: 36,
                                                minHeight: 36,
                                              ),
                                              tooltip: 'Eliminar comentario',
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        content,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
          
          // Sección para escribir comentario
          if (!canComment)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Card(
                color: Colors.amber.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.lock, color: Colors.amber),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Debes iniciar sesión para comentar este material.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Iniciar sesión'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Column(
                  children: [
                    _buildCommentRequirements(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            focusNode: _commentFocusNode,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: _maxCommentLength,
                            decoration: InputDecoration(
                              hintText: 'Escribe tu comentario...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.all(12),
                            ),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendComment(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueAccent.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: _isSending ? null : _sendComment,
                            icon: _isSending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send, color: Colors.white),
                            color: Theme.of(context).primaryColor,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              disabledBackgroundColor: Colors.grey.shade400,
                            ),
                            tooltip: 'Enviar comentario',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/*
1. Validaciones de Contenido:
✅ Longitud mínima (3 caracteres)

✅ Longitud máxima (500 caracteres)

✅ No vacío (solo espacios)

✅ Contador de caracteres en tiempo real

✅ Cambio de color al acercarse al límite

2. Detección de Spam:
✅ URLs (http://, https://, www.)

✅ Emails

✅ Teléfonos

✅ Palabras clave de spam

✅ Caracteres repetidos excesivamente

✅ Palabras repetidas

3. Protección contra Ataques:
✅ Límite de comentarios por minuto (3 por minuto)

✅ Ventana de tiempo para spam

✅ Control de frecuencia de envío

4. Funcionalidad de Eliminación:
✅ Botón para eliminar comentarios propios

✅ Diálogo de confirmación

✅ Indicador de carga durante eliminación

✅ Actualización en tiempo real

5. Formato de Fechas Mejorado:
✅ "Hace X minutos" para comentarios recientes

✅ "Hoy HH:MM" para hoy

✅ "Ayer HH:MM" para ayer

✅ "Día HH:MM" para esta semana

✅ Fecha completa para más antiguos

6. Mejoras de UX:
✅ Refresh indicator para actualizar

✅ Botón de actualización en AppBar

✅ Indicador de cantidad de comentarios

✅ Card para cada comentario con sombra

✅ Avatar con fallback de iniciales

✅ Animaciones de opacidad

7. Validaciones de Usuario:
✅ Verificación de autenticación

✅ Mensaje amigable para usuarios no logueados

✅ Control de permisos (solo eliminar propios)

✅ Redirección al login si no autenticado

8. Manejo de Errores:
✅ Diálogos de error específicos

✅ Snackbars con mejor diseño

✅ Captura de excepciones de Auth

✅ Mensajes informativos al usuario

9. Validaciones de Archivo:
✅ Verificación de URL de material

✅ Mensaje si no hay archivo disponible

✅ Manejo de errores de lanzamiento de URL

10. Visual Improvements:
✅ Chips para información del material

✅ Iconos para mejor identificación

✅ Espaciado y separadores mejorados

✅ Colores consistentes con el tema
 */