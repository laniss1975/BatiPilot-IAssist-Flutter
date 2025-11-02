import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart'; // Import pour l'initialisation
import 'ui/pages/home_page.dart';
import 'ui/theme/app_theme.dart';

// La fonction main est maintenant 'async' pour permettre l'initialisation
void main() async {
  // Assure que le binding Flutter est prêt avant toute chose
  WidgetsFlutterBinding.ensureInitialized();
  // Initialise les données de formatage pour la locale française
  await initializeDateFormatting('fr_FR', null);
  
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BâtiPilot IAssist',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}
