import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';


import 'app/qr_jukebox_app.dart';
import 'package:qr_jukebox/services/app_version.dart';


// ─── Entry Point ───────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final prefs = await SharedPreferences.getInstance();

  final keepAwake = prefs.getBool('keepAwake') ?? true;
  WakelockPlus.toggle(enable: keepAwake);

  await AppVersion.init();

  runApp(QRJukeboxApp(prefs: prefs));
}
