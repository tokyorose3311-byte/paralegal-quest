import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/game_provider.dart';
import 'theme/app_theme.dart';
import 'screens/setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ParalegalQuestApp());
}

class ParalegalQuestApp extends StatelessWidget {
  const ParalegalQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.forStyle(GameStyle.classic);
    return ChangeNotifierProvider(
      create: (_) => GameProvider(),
      child: MaterialApp(
        title: 'Paralegal Quest',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: colors.navyDeep,
          colorScheme: ColorScheme.fromSeed(
            seedColor: colors.brass,
            brightness: Brightness.dark,
          ),
          textTheme: GoogleFonts.spectralTextTheme(ThemeData.dark().textTheme),
          fontFamily: GoogleFonts.spectral().fontFamily,
        ),
        home: const SetupScreen(),
      ),
    );
  }
}
