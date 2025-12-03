import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
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

  Future<void> _openMaterialFromNotification(Map<String, dynamic> notif) async {
    final notifId = notif['id'] as String;
    final materialId = notif['material_id'] as String?;

    if (materialId == null) return;

    try {
      if (notif['is_read'] == false) {
        await _supabase
            .from('notifications')
            .update({'is_read': true}).eq('id', notifId);
      }

      final materialResp = await _supabase
          .from('materials')
          .select('file_url, file_type, title')
          .eq('id', materialId)
          .single();

      final material = Map<String, dynamic>.from(materialResp as Map);
      final url = material['file_url'] as String?;
      if (url == null || url.isEmpty) return;

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el material')),
        );
      }

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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(
                  child: Text('No tienes notificaciones por ahora.'),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];
                      final bool isRead = notif['is_read'] == true;
                      final createdAt =
                          notif['created_at']?.toString().substring(0, 16) ??
                              '';

                      return Card(
                        color: isRead ? Colors.white : Colors.blue.shade50,
                        child: ListTile(
                          leading: Icon(
                            isRead
                                ? Icons.notifications_none
                                : Icons.notifications_active,
                            color: isRead ? Colors.grey : Colors.blue,
                          ),
                          title: Text(
                            notif['message'] ?? 'Nueva notificación',
                          ),
                          subtitle: Text(createdAt),
                          onTap: () => _openMaterialFromNotification(notif),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
