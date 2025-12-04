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

  bool _isLoading = true;
  bool _isSending = false;
  List<Map<String, dynamic>> _comments = [];
  RealtimeChannel? _commentsChannel;

  String get _materialId => widget.material['id'] as String;
  String? get _courseId => widget.material['course_id'] as String?;
  String get _fileUrl => widget.material['file_url'] as String? ?? '';
  String get _fileType => widget.material['file_type'] as String? ?? 'file';

  @override
  void initState() {
    super.initState();
    _loadComments();
    _subscribeToRealtimeComments();
  }

  @override
  void dispose() {
    _commentsChannel?.unsubscribe();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final resp = await _supabase
          .from('comments')
          .select(
            'id, content, created_at, user_id, profiles(full_name, avatar_url)',
          )
          .eq('material_id', _materialId)
          .order('created_at', ascending: true);

      setState(() {
        _comments = List<Map<String, dynamic>>.from(resp as List);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar comentarios: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
                _comments.add(Map<String, dynamic>.from(resp as Map));
              });
            } catch (e) {
              print(e);
            }
          },
        )
        .subscribe();
  }

  Future<void> _sendComment() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para comentar.'),
          backgroundColor: Colors.orange,
        ),
      );
      context.go('/login');
      return;
    }

    final text = _commentController.text.trim();
    if (text.isEmpty) return;

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
        _comments.add(Map<String, dynamic>.from(inserted as Map));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar comentario: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _formatDate(dynamic value) {
    try {
      final dt = DateTime.parse(value.toString()).toLocal();
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '${dt.day}/${dt.month}/${dt.year} $hh:$mm';
    } catch (_) {
      return value?.toString() ?? '';
    }
  }

  Future<void> _openMaterial() async {
    if (_fileUrl.isEmpty) return;

    final uri = Uri.parse(_fileUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el material'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Tipo: ${_fileType.toUpperCase()}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    if (material['created_at'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Subido: ${_formatDate(material['created_at'])}',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _openMaterial,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Abrir material'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Comentarios',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(
                        child: Text('No hay comentarios aún.'),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadComments,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: _comments.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final c = _comments[index];
                            final profile =
                                c['profiles'] as Map<String, dynamic>?;
                            final name =
                                profile?['full_name'] as String? ?? 'Usuario';
                            final avatarUrl = profile?['avatar_url'] as String?;
                            final content = c['content'] as String? ?? '';
                            final createdAt = c['created_at'];

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                    avatarUrl != null && avatarUrl.isNotEmpty
                                        ? NetworkImage(avatarUrl)
                                        : null,
                                child: (avatarUrl == null || avatarUrl.isEmpty)
                                    ? Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : '?',
                                      )
                                    : null,
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(content),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDate(createdAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
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
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Escribe tu comentario...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _isSending ? null : _sendComment,
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      color: Theme.of(context).primaryColor,
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
