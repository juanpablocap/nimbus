import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _loading = true);
    final data = await Supabase.instance.client
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(50);

    if (mounted) {
      setState(() {
        _notifications = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    }
    // Mark all as read
    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true})
        .eq('is_read', false);
  }

  String _formatDate(String date) {
    final d = DateTime.parse(date);
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
    final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${d.day} ${months[d.month - 1]}';
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'news': return Icons.newspaper_outlined;
      case 'visit': return Icons.person_add_outlined;
      case 'access': return Icons.door_front_door_outlined;
      default: return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text('Sin notificaciones', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _fetchNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final isUnread = n['is_read'] == false;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(isUnread ? 0.15 : 0.06),
                          child: Icon(_iconForType(n['type']),
                            color: Theme.of(context).colorScheme.primary.withOpacity(isUnread ? 1 : 0.5),
                            size: 20),
                        ),
                        title: Text(n['title'],
                          style: TextStyle(
                            fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                            fontSize: 14,
                          )),
                        subtitle: Text(n['body'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                        trailing: Text(_formatDate(n['created_at']),
                          style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                        tileColor: isUnread ? Theme.of(context).colorScheme.primary.withOpacity(0.04) : null,
                      );
                    },
                  ),
                ),
    );
  }
}
