import 'dart:async'; // Añade esta importación
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CourseCommentsScreen extends StatefulWidget {
  final Map<String, dynamic> course;

  const CourseCommentsScreen({super.key, required this.course});

  @override
  State<CourseCommentsScreen> createState() => _CourseCommentsScreenState();
}

class _CourseCommentsScreenState extends State<CourseCommentsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  bool _isLoading = true;
  bool _isSending = false;
  bool _hasError = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _comments = [];
  RealtimeChannel? _commentsChannel;
  final ScrollController _scrollController = ScrollController();

  String get _courseId => widget.course['id']?.toString() ?? '';
  String get _courseTitle =>
      widget.course['title']?.toString() ?? 'Curso sin título';

  @override
  void initState() {
    super.initState();
    
    // Validar que tenemos un curso con ID
    if (_courseId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Curso no válido';
        });
      }
      return;
    }
    
    _loadComments();
    _subscribeToRealtimeComments();
  }

  @override
  void dispose() {
    _unsubscribeFromRealtime();
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    if (_courseId.isEmpty) return;

    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // Validar conexión
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final resp = await _supabase
          .from('comments')
          .select(
            'id, content, created_at, user_id, profiles(full_name, avatar_url)',
          )
          .eq('course_id', _courseId)
          .isFilter('material_id', null)
          .order('created_at', ascending: true)
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (resp == null) {
        throw Exception('No se recibieron datos del servidor');
      }

      setState(() {
        _comments = List<Map<String, dynamic>>.from(resp as List);
        _isLoading = false;
        _hasError = false;
      });

      // Desplazar al final si hay comentarios
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && _comments.isNotEmpty) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } on TimeoutException catch (_) { // Ahora TimeoutException está disponible
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Tiempo de espera agotado';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cargar los comentarios. Verifica tu conexión.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
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
        _errorMessage = 'Error al cargar comentarios: ${e.toString()}';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar comentarios: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _subscribeToRealtimeComments() {
    if (_courseId.isEmpty) return;

    try {
      final channelName = 'course_comments_${_courseId}_${DateTime.now().millisecondsSinceEpoch}';
      
      _commentsChannel = _supabase.channel(channelName);

      _commentsChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'comments',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'course_id',
              value: _courseId,
            ),
            callback: (payload) async {
              try {
                final newRow = payload.newRecord;
                if (newRow == null) return;

                // Validar que sea un comentario de curso (no de material)
                if (newRow['material_id'] != null) return;

                final newId = newRow['id']?.toString();
                if (newId == null || newId.isEmpty) return;

                // Validar que no sea nuestro propio comentario (evitar duplicados)
                final currentUser = _supabase.auth.currentUser;
                if (currentUser != null && newRow['user_id'] == currentUser.id) {
                  // Podría ser nuestro comentario, pero lo verificamos de todos modos
                  final existing = _comments.firstWhere(
                    (c) => c['id']?.toString() == newId,
                    orElse: () => {},
                  );
                  
                  if (existing.isNotEmpty) return;
                }

                // Obtener datos completos del comentario
                final resp = await _supabase
                    .from('comments')
                    .select(
                      'id, content, created_at, user_id, profiles(full_name, avatar_url)',
                    )
                    .eq('id', newId)
                    .single()
                    .timeout(const Duration(seconds: 10));

                if (!mounted) return;

                final newComment = Map<String, dynamic>.from(resp as Map);
                
                // Evitar duplicados
                final alreadyExists = _comments.any(
                  (c) => c['id']?.toString() == newComment['id']?.toString(),
                );
                
                if (!alreadyExists) {
                  setState(() {
                    _comments.add(newComment);
                  });

                  // Desplazar al final
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                }
              } on TimeoutException catch (_) {
                print('Timeout al cargar comentario en tiempo real');
              } catch (e) {
                print('Error procesando comentario en tiempo real: $e');
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: 'comments',
            callback: (payload) {
              try {
                final oldRow = payload.oldRecord;
                if (oldRow == null) return;

                final deletedId = oldRow['id']?.toString();
                if (deletedId == null) return;

                setState(() {
                  _comments.removeWhere((c) => c['id']?.toString() == deletedId);
                });
              } catch (e) {
                print('Error eliminando comentario en tiempo real: $e');
              }
            },
          )
          .subscribe((status, [error]) {
            if (status == RealtimeSubscribeStatus.subscribed) {
              print('✅ Suscrito a comentarios en tiempo real');
            } else if (status == RealtimeSubscribeStatus.timedOut) {
              print('⚠️ Timeout en suscripción a comentarios');
            } else if (error != null) {
              print('❌ Error en suscripción: $error');
            }
          });
    } catch (e) {
      print('❌ Error al suscribirse a comentarios: $e');
    }
  }

  void _unsubscribeFromRealtime() {
    try {
      if (_commentsChannel != null) {
        _commentsChannel!.unsubscribe();
        _commentsChannel = null;
        print('🔴 Desuscrito de comentarios en tiempo real');
      }
    } catch (e) {
      print('Error al desuscribirse: $e');
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    
    // Validar entrada
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe un comentario primero'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (text.length > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El comentario no puede exceder 2000 caracteres'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para comentar.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      
      // Opcional: redirigir al login
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) context.go('/login');
      });
      return;
    }

    if (_courseId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: curso no válido'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      await _supabase.from('comments').insert({
        'course_id': _courseId,
        'user_id': user.id,
        'content': text,
        'created_at': DateTime.now().toIso8601String(),
      }).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      
      // Limpiar el campo
      setState(() {
        _commentController.clear();
      });
      
      // Enfocar de nuevo para facilitar otro comentario
      _commentFocusNode.requestFocus();
      
    } on TimeoutException catch (_) { // Corregido aquí también
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tiempo de espera agotado. Intenta de nuevo.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      
      String errorMessage = 'Error al enviar comentario';
      if (e.code == '42501') {
        errorMessage = 'No tienes permiso para comentar';
      } else if (e.message != null) {
        errorMessage = 'Error: ${e.message}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error inesperado: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _formatDate(dynamic date) {
    try {
      if (date == null) return 'Fecha desconocida';
      
      final d = DateTime.parse(date.toString()).toLocal();
      final now = DateTime.now().toLocal();
      final difference = now.difference(d);
      
      // Mostrar tiempo relativo para fechas recientes
      if (difference.inMinutes < 1) {
        return 'Ahora mismo';
      } else if (difference.inHours < 1) {
        return 'Hace ${difference.inMinutes} min';
      } else if (difference.inDays < 1) {
        return 'Hace ${difference.inHours} h';
      } else if (difference.inDays < 7) {
        return 'Hace ${difference.inDays} d';
      }
      
      final hh = d.hour.toString().padLeft(2, '0');
      final mm = d.minute.toString().padLeft(2, '0');
      return '${d.day}/${d.month}/${d.year} $hh:$mm';
    } catch (_) {
      return 'Fecha desconocida';
    }
  }

  Widget _buildCommentItem(Map<String, dynamic> comment, int index) {
    final profile = comment['profiles'] as Map<String, dynamic>?;

    final name = profile?['full_name']?.toString() ?? 'Usuario';
    final avatarUrl = profile?['avatar_url']?.toString();
    final content = comment['content']?.toString() ?? '';
    final createdAt = comment['created_at'];
    final userId = comment['user_id']?.toString();
    final currentUserId = _supabase.auth.currentUser?.id;

    final initials = name.trim().isNotEmpty
        ? name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
            .join()
        : '?';

    final bool isOwnComment = userId == currentUserId;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isOwnComment 
            ? Colors.blue.shade50 
            : Theme.of(context).colorScheme.surface,
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: isOwnComment 
              ? Colors.blue.shade100 
              : Colors.grey.shade200,
          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
              ? NetworkImage(avatarUrl)
              : null,
          child: (avatarUrl == null || avatarUrl.isEmpty)
              ? Text(
                  initials,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isOwnComment ? Colors.blue.shade800 : Colors.grey.shade800,
                  ),
                )
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isOwnComment ? Colors.blue.shade800 : null,
                ),
              ),
            ),
            if (isOwnComment)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Tú',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              content,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 6),
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
            'Error al cargar comentarios',
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
            onPressed: _loadComments,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'Aún no hay comentarios',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sé el primero en comentar',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Validar que tenemos un curso
    if (_courseId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: _buildErrorState(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Comentarios',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadComments,
            tooltip: 'Actualizar comentarios',
          ),
        ],
      ),
      body: Column(
        children: [
          // Encabezado del curso
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Icon(
                  Icons.school,
                  color: Colors.blue.shade700,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _courseTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          
          // Contador de comentarios
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                Icon(
                  Icons.comment,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_comments.length} ${_comments.length == 1 ? 'comentario' : 'comentarios'}',
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
                : _hasError
                    ? _buildErrorState()
                    : _comments.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadComments,
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.only(top: 8, bottom: 8),
                              itemCount: _comments.length,
                              itemBuilder: (context, index) =>
                                  _buildCommentItem(_comments[index], index),
                            ),
                          ),
          ),
          
          // Campo para nuevo comentario
          const Divider(height: 1),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      decoration: InputDecoration(
                        hintText: 'Escribe un comentario...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        suffixIcon: _commentController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _commentController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() {}); // Para actualizar el botón clear
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSending || _commentController.text.trim().isEmpty
                          ? null
                          : _sendComment,
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                        backgroundColor: Theme.of(context).primaryColor,
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
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