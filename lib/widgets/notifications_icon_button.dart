import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsIconButton extends StatefulWidget {
  const NotificationsIconButton({super.key});

  @override
  State<NotificationsIconButton> createState() =>
      _NotificationsIconButtonState();
}

class _NotificationsIconButtonState extends State<NotificationsIconButton> {
  final SupabaseClient _supabase = Supabase.instance.client;

  int _unreadCount = 0;
  RealtimeChannel? _notificationsChannel;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _subscribeToRealtimeNotifications();
  }

  @override
  void dispose() {
    _notificationsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final resp = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);

      setState(() {
        _unreadCount = (resp as List).length;
      });
    } catch (_) {
      //
    }
  }

  void _subscribeToRealtimeNotifications() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _notificationsChannel =
        _supabase.channel('public:notifications:badge_${user.id}');

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

            final isRead = newRow['is_read'] == true;
            if (isRead) return;

            if (!mounted) return;
            setState(() {
              _unreadCount += 1;
            });
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () async {
        await context.push('/notifications');
        await _loadUnreadCount();
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications),
          if (_unreadCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  _unreadCount > 9 ? '9+' : '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
