import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'home.dart';
import 'setup.dart';
import 'store.dart';
import 'ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  store.load();
  runApp(TurnistaApp(store: store));
}

class TurnistaApp extends StatelessWidget {
  final AppStore store;
  const TurnistaApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: MaterialApp(
        title: 'Turnista',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: const Locale('it', 'IT'),
        supportedLocales: const [Locale('it', 'IT')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (!store.loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Palette.primary)),
      );
    }
    if (!store.data.settings.setupDone) return const SetupFlow();
    return const HomeShell();
  }
}
