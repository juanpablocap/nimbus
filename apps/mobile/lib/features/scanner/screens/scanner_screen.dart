import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  MobileScannerController? _controller;
  bool _isProcessing = false;
  Map<String, dynamic>? _result;
  bool _showResult = false;
  String? _scannedToken; // keep raw token to send to confirm-access

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _showResult) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    setState(() {
      _isProcessing = true;
      _scannedToken = raw;
    });
    _controller?.stop();

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'validate-qr',
        body: {'qr_token': raw},
      );
      if (mounted) {
        setState(() {
          _result = response.data;
          _showResult = true;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = {'valid': false, 'reason': 'error', 'message': e.toString()};
          _showResult = true;
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _confirmAccess() async {
    if (_result == null || _result!['visit'] == null || _scannedToken == null) return;
    setState(() => _isProcessing = true);

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'confirm-access',
        body: {'qr_token': _scannedToken, 'action': 'entry'}, // FIX: send token not visit_id
      );
      if (mounted) {
        final success = response.data?['success'] == true;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'Acceso registrado' : 'Error al registrar acceso'),
          backgroundColor: success ? Colors.green : Colors.red,
        ));
        _resetScanner();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  void _resetScanner() {
    setState(() {
      _result = null;
      _showResult = false;
      _isProcessing = false;
      _scannedToken = null;
    });
    _controller?.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear QR')),
      body: _showResult ? _buildResult() : _buildScanner(),
    );
  }

  Widget _buildScanner() {
    return Stack(children: [
      MobileScanner(controller: _controller!, onDetect: _onDetect),
      Center(
        child: Container(
          width: 260, height: 260,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      if (_isProcessing)
        Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
      Positioned(
        bottom: 80, left: 0, right: 0,
        child: Text(
          'Apuntá la cámara al QR del visitante',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 14, shadows: [Shadow(blurRadius: 8, color: Colors.black)]),
        ),
      ),
    ]);
  }

  Widget _buildResult() {
    final isValid = _result?['valid'] == true;
    final visit = _result?['visit'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        const SizedBox(height: 24),
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (isValid ? Colors.green : Colors.red).withOpacity(0.1),
          ),
          child: Icon(isValid ? Icons.check_circle : Icons.cancel, size: 48, color: isValid ? Colors.green : Colors.red),
        ),
        const SizedBox(height: 16),
        Text(
          isValid ? 'QR Válido' : 'QR Inválido',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isValid ? Colors.green : Colors.red),
        ),
        if (!isValid) ...[
          const SizedBox(height: 8),
          Text(_result?['message'] ?? 'Error desconocido',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
        ],
        if (isValid && visit != null) ...[
          const SizedBox(height: 24),
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _DetailRow(icon: Icons.person, label: 'Visitante', value: visit['visitor_name']),
              if (visit['visitor_document'] != null)
                _DetailRow(icon: Icons.badge, label: 'Documento', value: visit['visitor_document']),
              _DetailRow(icon: Icons.home, label: 'Propiedad', value: visit['property']?['name'] ?? '—'),
              if (visit['property']?['address'] != null)
                _DetailRow(icon: Icons.location_on, label: 'Dirección', value: visit['property']['address']),
              _DetailRow(icon: Icons.person_outline, label: 'Residente', value: visit['resident']?['name'] ?? '—'),
              if (visit['resident']?['phone'] != null)
                _DetailRow(icon: Icons.phone, label: 'Teléfono', value: visit['resident']['phone']),
              _DetailRow(icon: Icons.repeat, label: 'Usos', value: '${visit['times_used']}/${visit['max_uses']}'),
              if (visit['notes'] != null)
                _DetailRow(icon: Icons.notes, label: 'Notas', value: visit['notes']),
            ]),
          )),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _confirmAccess,
              icon: const Icon(Icons.check),
              label: _isProcessing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Aprobar ingreso'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(onPressed: _resetScanner, child: const Text('Escanear otro')),
        ),
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.grey[500]),
        const SizedBox(width: 12),
        SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}
