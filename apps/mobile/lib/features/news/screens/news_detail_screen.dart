import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NewsDetailScreen extends StatefulWidget {
  final String newsId;
  const NewsDetailScreen({super.key, required this.newsId});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  Map<String, dynamic>? _news;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    final data = await Supabase.instance.client
        .from('news')
        .select('*, profiles!news_author_id_fkey(full_name)')
        .eq('id', widget.newsId)
        .single();

    if (mounted) {
      setState(() {
        _news = data;
        _loading = false;
      });
    }
  }

  String _formatDate(String date) {
    final d = DateTime.parse(date);
    final months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return '${d.day} de ${months[d.month - 1]}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Noticia')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _news == null
              ? const Center(child: Text('No encontrada'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_news!['title'],
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.3)),
                    const SizedBox(height: 12),
                    Row(children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        child: Text(
                          (_news!['profiles']?['full_name'] ?? 'A')[0].toUpperCase(),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_news!['profiles']?['full_name'] ?? 'Admin',
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                      const SizedBox(width: 8),
                      Text('·', style: TextStyle(color: Colors.grey[400])),
                      const SizedBox(width: 8),
                      Text(_formatDate(_news!['published_at'] ?? _news!['created_at']),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ]),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 20),
                    Text(_news!['body'],
                      style: const TextStyle(fontSize: 16, height: 1.7, color: Color(0xFF333333))),
                  ]),
                ),
    );
  }
}
