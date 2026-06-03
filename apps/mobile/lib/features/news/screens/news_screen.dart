import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<Map<String, dynamic>> _news = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    setState(() => _loading = true);
    final data = await Supabase.instance.client
        .from('news')
        .select('*, profiles!news_author_id_fkey(full_name)')
        .eq('is_published', true)
        .order('published_at', ascending: false);

    if (mounted) {
      setState(() {
        _news = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    }
  }

  String _formatDate(String date) {
    final d = DateTime.parse(date);
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
    final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${d.day} ${months[d.month - 1]}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Noticias')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _news.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.newspaper_outlined, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text('Sin noticias', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                ]))
              : RefreshIndicator(
                  onRefresh: _fetchNews,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _news.length,
                    itemBuilder: (context, index) {
                      final item = _news[index];
                      final authorName = item['profiles']?['full_name'] ?? 'Admin';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => context.go('/news/${item['id']}'), // navigate to detail
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  child: Text(authorName[0].toUpperCase(),
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.primary)),
                                ),
                                const SizedBox(width: 10),
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(authorName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                  Text(_formatDate(item['published_at'] ?? item['created_at']),
                                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                ]),
                                const Spacer(),
                                Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
                              ]),
                              const SizedBox(height: 12),
                              Text(item['title'],
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text(item['body'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5)),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
