import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateVisitScreen extends StatefulWidget {
  const CreateVisitScreen({super.key});

  @override
  State<CreateVisitScreen> createState() => _CreateVisitScreenState();
}

class _CreateVisitScreenState extends State<CreateVisitScreen> {
  final _nameController = TextEditingController();
  final _documentController = TextEditingController();
  final _notesController = TextEditingController();
  String _visitType = 'one_time';
  int _maxUses = 1;
  DateTime _validUntil = DateTime.now().add(const Duration(hours: 24));
  String? _selectedPropertyId;
  List<Map<String, dynamic>> _properties = [];
  bool _loading = false;
  bool _fetchingProperties = true;

  @override
  void initState() {
    super.initState();
    _fetchProperties();
  }

  Future<void> _fetchProperties() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    // Get properties assigned to this resident
    final assignments = await client
        .from('resident_properties')
        .select('property_id, properties(id, name)')
        .eq('profile_id', userId!);

    if (mounted) {
      setState(() {
        _properties = List<Map<String, dynamic>>.from(
          (assignments as List).map((a) => a['properties']),
        );
        if (_properties.isNotEmpty) {
          _selectedPropertyId = _properties.first['id'];
        }
        _fetchingProperties = false;
      });
    }
  }

  Future<void> _createVisit() async {
    if (_nameController.text.trim().isEmpty || _selectedPropertyId == null) return;

    setState(() => _loading = true);

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      final profile = await client.from('profiles').select('community_id').eq('id', userId!).single();

      await client.from('visits').insert({
        'community_id': profile['community_id'],
        'property_id': _selectedPropertyId,
        'created_by': userId,
        'visitor_name': _nameController.text.trim(),
        'visitor_document': _documentController.text.trim().isEmpty ? null : _documentController.text.trim(),
        'visit_type': _visitType,
        'status': 'active',
        'valid_until': _validUntil.toIso8601String(),
        'max_uses': _maxUses,
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visit created successfully')),
        );
        context.go('/visits');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _validUntil,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_validUntil),
    );
    if (time == null || !mounted) return;

    setState(() {
      _validUntil = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _documentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Visit'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/visits'),
        ),
      ),
      body: _fetchingProperties
          ? const Center(child: CircularProgressIndicator())
          : _properties.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.home_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'No property assigned',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Contact your community administrator to assign you a property.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Visitor name
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Visitor name *', hintText: 'Full name of the visitor'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),

                      // Document
                      TextField(
                        controller: _documentController,
                        decoration: const InputDecoration(labelText: 'Document / ID', hintText: 'Optional'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),

                      // Property selector
                      DropdownButtonFormField<String>(
                        value: _selectedPropertyId,
                        decoration: const InputDecoration(labelText: 'Property'),
                        items: _properties.map((p) => DropdownMenuItem(
                          value: p['id'] as String,
                          child: Text(p['name'] as String),
                        )).toList(),
                        onChanged: (v) => setState(() => _selectedPropertyId = v),
                      ),
                      const SizedBox(height: 16),

                      // Visit type
                      DropdownButtonFormField<String>(
                        value: _visitType,
                        decoration: const InputDecoration(labelText: 'Visit type'),
                        items: const [
                          DropdownMenuItem(value: 'one_time', child: Text('One time')),
                          DropdownMenuItem(value: 'recurring', child: Text('Recurring')),
                        ],
                        onChanged: (v) => setState(() {
                          _visitType = v!;
                          if (v == 'recurring') _maxUses = 10;
                          else _maxUses = 1;
                        }),
                      ),
                      const SizedBox(height: 16),

                      // Max uses
                      Row(
                        children: [
                          Text('Max uses: ', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _maxUses > 1 ? () => setState(() => _maxUses--) : null,
                            icon: const Icon(Icons.remove_circle_outline),
                            iconSize: 28,
                          ),
                          Text('$_maxUses', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          IconButton(
                            onPressed: () => setState(() => _maxUses++),
                            icon: const Icon(Icons.add_circle_outline),
                            iconSize: 28,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Valid until
                      GestureDetector(
                        onTap: _pickDateTime,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Valid until'),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_validUntil.day}/${_validUntil.month}/${_validUntil.year} ${_validUntil.hour.toString().padLeft(2, '0')}:${_validUntil.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const Icon(Icons.calendar_today, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Notes
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(labelText: 'Notes', hintText: 'Optional instructions for the guard'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 32),

                      // Submit
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _createVisit,
                          child: _loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Create Visit'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

