import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _properties = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final results = await Future.wait([
      client.from('profiles').select('*, communities(name)').eq('id', userId).single(),
      client.from('resident_properties').select('properties(name, address)').eq('profile_id', userId),
    ]);

    if (mounted) {
      setState(() {
        _profile = results[0] as Map<String, dynamic>;
        _properties = List<Map<String, dynamic>>.from(
          (results[1] as List).map((r) => r['properties']),
        );
        _loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign Out')),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final name = _profile?['full_name'] ?? '';
    final phone = _profile?['phone'];
    final community = _profile?['communities']?['name'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar & name
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(community, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Info
          Card(
            child: Column(
              children: [
                _ProfileTile(icon: Icons.email_outlined, label: 'Email', value: email),
                const Divider(height: 1),
                _ProfileTile(icon: Icons.phone_outlined, label: 'Phone', value: phone ?? 'Not set'),
                const Divider(height: 1),
                _ProfileTile(icon: Icons.location_city_outlined, label: 'Community', value: community),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Properties
          Text('My Properties', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_properties.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No properties assigned', style: TextStyle(color: Colors.grey[500])),
              ),
            )
          else
            ..._properties.map((p) => Card(
              child: ListTile(
                leading: const Icon(Icons.home_outlined),
                title: Text(p['name'] ?? '—'),
                subtitle: p['address'] != null ? Text(p['address'], style: TextStyle(fontSize: 13, color: Colors.grey[600])) : null,
              ),
            )),

          const SizedBox(height: 32),

          // Sign out
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
    );
  }
}

