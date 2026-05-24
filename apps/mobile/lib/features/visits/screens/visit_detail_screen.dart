import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';

class VisitDetailScreen extends StatefulWidget {
  final String visitId;
  const VisitDetailScreen({super.key, required this.visitId});

  @override
  State<VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends State<VisitDetailScreen> {
  Map<String, dynamic>? _visit;
  String? _qrToken;
  bool _loading = true;
  bool _generatingQr = false;

  @override
  void initState() {
    super.initState();
    _fetchVisit();
  }

  Future<void> _fetchVisit() async {
    final client = Supabase.instance.client;
    final data = await client
        .from('visits')
        .select('*, properties(name, address)')
        .eq('id', widget.visitId)
        .single();

    if (mounted) {
      setState(() {
        _visit = data;
        _qrToken = data['qr_token'];
        _loading = false;
      });
    }
  }

  Future<void> _generateQR() async {
    setState(() => _generatingQr = true);

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final response = await Supabase.instance.client.functions.invoke(
        'generate-qr',
        body: {'visit_id': widget.visitId},
      );

      if (response.data != null && response.data['qr_token'] != null) {
        setState(() {
          _qrToken = response.data['qr_token'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating QR: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingQr = false);
    }
  }

  void _shareQR() {
    if (_qrToken == null) return;
    Share.share(
      'You have been invited to visit ${_visit?['properties']?['name'] ?? 'our community'}.\n\nShow this code at the entrance:\n$_qrToken',
      subject: 'Visit invitation - ${_visit?['visitor_name']}',
    );
  }

  Future<void> _cancelVisit() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Visit'),
        content: const Text('Are you sure you want to cancel this visit?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, cancel')),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.from('visits').update({
        'status': 'cancelled',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.visitId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visit cancelled')),
        );
        context.go('/visits');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Visit')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final visit = _visit!;
    final isActive = visit['status'] == 'active';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visit Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/visits'),
        ),
        actions: [
          if (isActive)
            IconButton(icon: const Icon(Icons.share), onPressed: _qrToken != null ? _shareQR : null),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // QR Code
            if (isActive) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      if (_qrToken != null) ...[
                        QrImageView(
                          data: _qrToken!,
                          version: QrVersions.auto,
                          size: 240,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        Text('Show this code at the entrance', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                      ] else ...[
                        Icon(Icons.qr_code_2, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _generatingQr ? null : _generateQR,
                          child: _generatingQr
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Generate QR Code'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Visit info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _InfoRow(label: 'Visitor', value: visit['visitor_name']),
                    if (visit['visitor_document'] != null)
                      _InfoRow(label: 'Document', value: visit['visitor_document']),
                    _InfoRow(label: 'Property', value: visit['properties']?['name'] ?? '—'),
                    _InfoRow(label: 'Type', value: visit['visit_type'] == 'one_time' ? 'One time' : 'Recurring'),
                    _InfoRow(label: 'Status', value: visit['status'].toString().toUpperCase(), valueColor: isActive ? Colors.green : Colors.grey),
                    _InfoRow(label: 'Uses', value: '${visit['times_used']}/${visit['max_uses']}'),
                    if (visit['valid_until'] != null)
                      _InfoRow(label: 'Valid until', value: _formatDateTime(visit['valid_until'])),
                    if (visit['notes'] != null)
                      _InfoRow(label: 'Notes', value: visit['notes']),
                  ],
                ),
              ),
            ),

            if (isActive) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _cancelVisit,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Cancel Visit'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(String date) {
    final d = DateTime.parse(date);
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: valueColor)),
          ),
        ],
      ),
    );
  }
}

