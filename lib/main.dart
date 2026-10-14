import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.light);
final ValueNotifier<Color> appSeedColor = ValueNotifier(const Color(0xFF075E54));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  appThemeMode.value = (prefs.getString('themeMode') == 'dark') ? ThemeMode.dark : ThemeMode.light;
  appSeedColor.value = Color(prefs.getInt('seedColor') ?? 0xFF075E54);
  runApp(const BluetoothWhatsAppApp());
}

class BluetoothWhatsAppApp extends StatelessWidget {
  const BluetoothWhatsAppApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) => ValueListenableBuilder<Color>(
        valueListenable: appSeedColor,
        builder: (context, seed, __) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'واتساب بلوتوث',
          themeMode: mode,
          theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: seed), scaffoldBackgroundColor: const Color(0xFFECE5DD)),
          darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark, colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark)),
          home: const StartupScreen(),
        ),
      ),
    );
  }
}

class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<SharedPreferences>(
    future: SharedPreferences.getInstance(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      final prefs = snapshot.data!;
      final name = prefs.getString('profileName') ?? '';
      return name.isEmpty ? const LoginScreen() : const HomeScreen();
    },
  );
}