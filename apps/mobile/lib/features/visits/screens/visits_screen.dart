import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VisitsScreen extends StatefulWidget {
  const VisitsScreen({super.key});

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  List<Map<String, dynamic>> _visits = [];
  bool _loading = true;
  String _filter = 'active';

  @override
  void initState() {
    super.initState();
    _fetchVisits();
  }

  Future<void> _fetchVisits() async {
    setState(() => _loading = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    var query = client
        .from('visits')
        .select('*, properties(name)')
        .eq('created_by', userId!)
        .order('created_at', ascending: false);

    if (_filter != 'all') {
      query = query.eq('status', _filter);
    }

    final data = await query;
    if (mounted) {
      setState(() {
        _visits = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Visits'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/visits/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Visit'),
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(label: 'Active', value: 'active', selected: _filter, onTap: (v) { setState(() => _filter = v); _fetchVisits(); }),
                const SizedBox(width: 8),
                _FilterChip(label: 'Used', value: 'used', selected: _filter, onTap: (v) { setState(() => _filter = v); _fetchVisits(); }),
                const SizedBox(width: 8),
                _FilterChip(label: 'Expired', value: 'expired', selected: _filter, onTap: (v) { setState(() => _filter = v); _fetchVisits(); }),
                const SizedBox(width: 8),
                _FilterChip(label: 'All', value: 'all', selected: _filter, onTap: (v) { setState(() => _filter = v); _fetchVisits(); }),
              ],
            ),
          ),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _visits.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text('No visits found', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchVisits,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _visits.length,
                          itemBuilder: (context, index) {
                            final visit = _visits[index];
                            return _VisitCard(visit: visit, onTap: () => context.go('/visits/${visit['id']}'));
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final Function(String) onTap;

  const _FilterChip({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  final Map<String, dynamic> visit;
  final VoidCallback onTap;

  const _VisitCard({required this.visit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColors = {
      'active': Colors.green,
      'used': Colors.blue,
      'expired': Colors.red,
      'cancelled': Colors.grey,
    };
    final color = statusColors[visit['status']] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(visit['visitor_name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      visit['properties']?['name'] ?? '—',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${visit['times_used']}/${visit['max_uses']} uses',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  visit['status'].toString().toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

