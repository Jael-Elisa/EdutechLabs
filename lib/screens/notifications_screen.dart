import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/material_comments_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  RealtimeChannel? _notificationsChannel;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _subscribeToRealtimeNotifications();
  }

  @override
  void dispose() {
    _notificationsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _notifications = [];
        _isLoading = false;
      });
      return;
    }

    try {
      final resp = await _supabase
          .from('notifications')
          .select('id, material_id, message, is_read, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _notifications = List<Map<String, dynamic>>.from(resp as List);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando notificaciones: $e')),
        );
      }
    }
  }

  void _subscribeToRealtimeNotifications() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _notificationsChannel =
        _supabase.channel('public:notifications:user_${user.id}');

    _notificationsChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            final newRow = payload.newRecord;

            final alreadyExists =
                _notifications.any((n) => n['id'] == newRow['id']);
            if (alreadyExists) return;

            if (!mounted) return;

            setState(() {
              _notifications.insert(0, {
                'id': newRow['id'],
                'material_id': newRow['material_id'],
                'message': newRow['message'],
                'is_read': newRow['is_read'],
                'created_at': newRow['created_at'],
              });
            });
          },
        )
        .subscribe();
  }

  Future<void> _openMaterialFromNotification(
    Map<String, dynamic> notif,
  ) async {
    final notifId = notif['id'] as String;
    final materialId = notif['material_id'] as String?;

    if (materialId == null) return;

    try {
      if (notif['is_read'] == false) {
        await _supabase
            .from('notifications')
            .update({'is_read': true}).eq('id', notifId);
      }
      final materialResp = await _supabase.from('materials').select('''
          id,
          course_id,
          title,
          description,
          file_url,
          file_type,
          file_size,
          created_at
        ''').eq('id', materialId).single();

      final material = Map<String, dynamic>.from(materialResp as Map);

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MaterialCommentsScreen(material: material),
        ),
      );

      if (mounted) _loadNotifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir material: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFF0A0F1C),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'No tienes notificaciones por ahora.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF0A0F1C),
                          Color(0xFF1A1F2C),
                        ],
                      ),
                    ),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notif = _notifications[index];
                        final bool isRead = notif['is_read'] == true;

                        final rawDate = notif['created_at']?.toString() ?? '';
                        final createdAt = rawDate.length >= 16
                            ? rawDate.substring(0, 16)
                            : rawDate;

                        final Color bgColor = isRead
                            ? const Color(0xFF111827)
                            : const Color(0xFF1E293B);

                        final Color borderColor = isRead
                            ? Colors.blueGrey.shade800.withOpacity(0.7)
                            : const Color(0xFF3D5AFE).withOpacity(0.7);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _openMaterialFromNotification(notif),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: borderColor,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isRead
                                            ? Colors.blueGrey.shade800
                                                .withOpacity(0.3)
                                            : const Color(0xFF3D5AFE)
                                                .withOpacity(0.2),
                                      ),
                                      child: Icon(
                                        isRead
                                            ? Icons.notifications_none
                                            : Icons.notifications_active,
                                        size: 20,
                                        color: isRead
                                            ? Colors.blueGrey.shade200
                                            : const Color(0xFF3D5AFE),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            notif['message'] ??
                                                'Nueva notificación',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isRead
                                                  ? FontWeight.w500
                                                  : FontWeight.w600,
                                              color: isRead
                                                  ? Colors.blueGrey.shade100
                                                  : Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.schedule,
                                                size: 14,
                                                color: Colors.blueGrey.shade400,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                createdAt,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      Colors.blueGrey.shade400,
                                                ),
                                              ),
                                              if (!isRead) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF3D5AFE)
                                                            .withOpacity(0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            999),
                                                  ),
                                                  child: const Text(
                                                    'Nuevo',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Color(0xFF3D5AFE),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
    );
  }
}
