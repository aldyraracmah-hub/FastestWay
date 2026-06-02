import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'services/tile_cache_service.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await TileCacheService.init();

  runApp(const FastestWayApp());
}

class FastestWayApp extends StatelessWidget {

  const FastestWayApp({super.key});

  @override
  Widget build(BuildContext context) {

    return MaterialApp(

      title: 'FastestWay',

      debugShowCheckedModeBanner: false,

      theme: ThemeData(

        useMaterial3: true,

        scaffoldBackgroundColor:
        const Color(0xFFF7F1E8),

        colorScheme: ColorScheme.fromSeed(

          seedColor:
          const Color(0xFFD6BFA7),

          brightness: Brightness.light,
        ),

        cardColor:
        const Color(0xFFFFFBF7),

        textTheme: const TextTheme(

          bodyLarge: TextStyle(
            color: Color(0xFF5C4632),
          ),

          bodyMedium: TextStyle(
            color: Color(0xFF5C4632),
          ),

          titleLarge: TextStyle(
            color: Color(0xFF5C4632),
            fontWeight: FontWeight.bold,
          ),
        ),

        appBarTheme: const AppBarTheme(

          backgroundColor:
          Color(0xFFF7F1E8),

          elevation: 0,

          iconTheme: IconThemeData(
            color: Color(0xFF5C4632),
          ),

          titleTextStyle: TextStyle(
            color: Color(0xFF5C4632),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      home: const SplashScreen(),
    );
  }
}