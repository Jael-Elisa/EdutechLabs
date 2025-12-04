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

  bool _isLoading = true;
  bool _isSending = false;
  List<Map<String, dynamic>> _comments = [];
  RealtimeChannel? _commentsChannel;

  String get _courseId => widget.course['id'] as String;
  String get _courseTitle =>
      widget.course['title']?.toString() ?? 'Curso sin título';

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
              'id, content, created_at, user_id, profiles(full_name, avatar_url)')
          .eq('course_id', _courseId)
          .isFilter('material_id', null)
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
    final courseId = _courseId;

    _commentsChannel =
        _supabase.channel('public:course_comments:course_$courseId');

    _commentsChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'course_id',
            value: courseId,
          ),
          callback: (payload) async {
            final newRow = payload.newRecord;
            if (newRow == null) return;

            if (newRow['material_id'] != null) return;

            final newId = newRow['id'] as String?;
            if (newId == null) return;

            try {
              final resp = await _supabase
                  .from('comments')
                  .select(
                    'id, content, created_at, user_id, '
                    'profiles(full_name, avatar_url)',
                  )
                  .eq('id', newId)
                  .single();

              if (!mounted) return;
              setState(() {
                _comments.add(Map<String, dynamic>.from(resp as Map));
              });
            } catch (_) {
              //
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
      await _supabase.from('comments').insert({
        'course_id': _courseId,
        'user_id': user.id,
        'content': text,
      });

      if (!mounted) return;
      setState(() {
        _commentController.clear();
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

  String _formatDate(dynamic date) {
    try {
      final d = DateTime.parse(date.toString()).toLocal();
      final hh = d.hour.toString().padLeft(2, '0');
      final mm = d.minute.toString().padLeft(2, '0');
      return '${d.day}/${d.month}/${d.year} $hh:$mm';
    } catch (_) {
      return '';
    }
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final profile = comment['profiles'] as Map<String, dynamic>?;

    final name = profile?['full_name']?.toString() ?? 'Usuario';
    final avatarUrl = profile?['avatar_url']?.toString();
    final content = comment['content']?.toString() ?? '';
    final createdAt = comment['created_at'];

    final initials = name.trim().isNotEmpty
        ? name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
            .join()
        : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4),
      child: ListTile(
        leading: CircleAvatar(
          radius: 22,
          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
              ? NetworkImage(avatarUrl)
              : null,
          child: (avatarUrl == null || avatarUrl.isEmpty)
              ? Text(
                  initials,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                )
              : null,
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Comentarios - $_courseTitle'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(
                        child: Text('Aún no hay comentarios en este curso.'),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadComments,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) =>
                              _buildCommentItem(_comments[index]),
                        ),
                      ),
          ),
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Escribe un comentario...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    color: Theme.of(context).primaryColor,
                    onPressed: _isSending ? null : _sendComment,
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
