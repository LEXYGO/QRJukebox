import 'package:flutter/services.dart'; //for HapticFeedback
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  bool _hasScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: ReaderWidget(
        onScan: (result) {
          if (_hasScanned) return;
          if (result.text != null && result.text!.isNotEmpty) {
            _hasScanned = true;
            HapticFeedback.mediumImpact();
            Navigator.pop(context, result.text);
          }
        },
        scanDelay: const Duration(milliseconds: 100),
        showScannerOverlay: false,
        tryHarder: true,
        tryInverted: true,
        cropPercent: 0.8,
      ),
    );
  }
}