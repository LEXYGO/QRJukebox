import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_jukebox/screens/home_page.dart';

class QRJukeboxApp extends StatefulWidget {
  final SharedPreferences prefs;
  const QRJukeboxApp({super.key, required this.prefs});

  static QRJukeboxAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<QRJukeboxAppState>();

  @override
  State<QRJukeboxApp> createState() => QRJukeboxAppState();
}

class QRJukeboxAppState extends State<QRJukeboxApp> {
  static const _defaultSeedColor = Color(0xFF6750A4);

  void reloadTheme() {
    setState(() {});
  }

  ColorScheme _toFlutterColorScheme(dynamic scheme) {
    return ColorScheme(
      brightness: scheme.brightness == Brightness.dark
          ? Brightness.dark
          : Brightness.light,
      primary: scheme.primary,
      onPrimary: scheme.onPrimary,
      primaryContainer: scheme.primaryContainer,
      onPrimaryContainer: scheme.onPrimaryContainer,
      secondary: scheme.secondary,
      onSecondary: scheme.onSecondary,
      secondaryContainer: scheme.secondaryContainer,
      onSecondaryContainer: scheme.onSecondaryContainer,
      tertiary: scheme.tertiary,
      onTertiary: scheme.onTertiary,
      tertiaryContainer: scheme.tertiaryContainer,
      onTertiaryContainer: scheme.onTertiaryContainer,
      error: scheme.error,
      onError: scheme.onError,
      errorContainer: scheme.errorContainer,
      onErrorContainer: scheme.onErrorContainer,
      surface: scheme.surface,
      onSurface: scheme.onSurface,
      outline: scheme.outline,
      outlineVariant: scheme.outlineVariant,
      shadow: scheme.shadow,
      scrim: scheme.scrim,
      inverseSurface: scheme.inverseSurface,
      onInverseSurface: scheme.onInverseSurface,
      inversePrimary: scheme.inversePrimary,
      surfaceTint: scheme.surfaceTint,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeModeStr = widget.prefs.getString('themeMode') ?? 'system';
    final ThemeMode themeMode;
    switch (themeModeStr) {
      case 'light':
        themeMode = ThemeMode.light;
        break;
      case 'dark':
        themeMode = ThemeMode.dark;
        break;
      case 'system':
      default:
        themeMode = ThemeMode.system;
        break;
    }

    final useDynamicColor = widget.prefs.getBool('useDynamicColor') ?? true;

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;

        if (useDynamicColor && lightDynamic != null && darkDynamic != null) {
          lightColorScheme = _toFlutterColorScheme(lightDynamic.harmonized());
          darkColorScheme = _toFlutterColorScheme(darkDynamic.harmonized());
        } else {
          lightColorScheme = ColorScheme.fromSeed(
            seedColor: _defaultSeedColor,
            brightness: Brightness.light,
          );
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: _defaultSeedColor,
            brightness: Brightness.dark,
          );
        }

        darkColorScheme = darkColorScheme.copyWith(
          surface: Colors.black,
          surfaceContainerLowest: Colors.black,
          surfaceContainerLow: const Color(0xFF0C0C0C),
          surfaceContainer: const Color(0xFF141414),
          surfaceContainerHigh: const Color(0xFF1C1C1C),
          surfaceContainerHighest: const Color(0xFF242424),
        );

        return MaterialApp(
          title: 'QR Jukebox',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: lightColorScheme,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme,
            scaffoldBackgroundColor: Colors.black,
            canvasColor: Colors.black,
            useMaterial3: true,
          ),
          themeMode: themeMode,
          home: HomePage(prefs: widget.prefs),
        );
      },
    );
  }
}
