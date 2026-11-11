import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/store.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(GuessTheNumberApp(store: AppStore(prefs)));
}

class GuessTheNumberApp extends StatelessWidget {
  final AppStore store;
  const GuessTheNumberApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) => StoreScope(
    store: store,
    child: MaterialApp(
      title: 'Gimit',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeScreen(),
    ),
  );
}
