import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Map<String, dynamic>? _profile;
  int _activeVisits = 0;
  List<Map<String, dynamic>> _recentNews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final results = await Future.wait([
      client.from('profiles').select().eq('id', userId).single(),
      client.from('visits').select('id').eq('created_by', userId).eq('status', 'active'),
      client.from('news').select('id, title, created_at').eq('is_published', true).order('created_at', ascending: false).limit(5),
    ]);

    if (mounted) {
      setState(() {
        _profile = results[0] as Map<String, dynamic>;
        _activeVisits = (results[1] as List).length;
        _recentNews = List<Map<String, dynamic>>.from(results[2] as List);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final name = _profile?['full_name'] ?? 'Resident';
    final firstName = name.split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, $firstName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Quick actions
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.add_circle_outline,
                    label: 'New Visit',
                    onTap: () => context.go('/visits/create'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.qr_code,
                    label: 'My QR Codes',
                    onTap: () => context.go('/visits'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Stats
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text('$_activeVisits', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Active Visits', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Recent news
            Text('Latest News', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (_recentNews.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('No announcements yet.', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                ),
              )
            else
              ..._recentNews.map((n) => Card(
                child: ListTile(
                  title: Text(n['title'], style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(_formatDate(n['created_at']), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => context.go('/news'),
                ),
              )),
          ],
        ),
      ),
    );
  }

  String _formatDate(String date) {
    final d = DateTime.parse(date);
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            children: [
              Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

