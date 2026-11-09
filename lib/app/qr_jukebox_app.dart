import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_jukebox/screens/home_page.dart';

class QRJukeboxApp extends StatelessWidget {
  final SharedPreferences prefs;
  const QRJukeboxApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Jukebox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2200FF),
        ),
        useMaterial3: true,
      ),
      home: HomePage(prefs: prefs),
    );
  }
}