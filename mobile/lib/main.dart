import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'audio.dart';
import 'api.dart';
import 'screens/auth.dart';
import 'screens/home.dart';
import 'design_tokens.dart';
import 'theme.dart';
import 'theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.load();
  await AppAudio.load();
  final themeProvider = ThemeProvider();
  await themeProvider.load();
  runApp(AdviserLinkApp(themeProvider: themeProvider));
}

class AdviserLinkApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  const AdviserLinkApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: themeProvider,
      child: _AdviserLinkAppCore(),
    );
  }
}

class _AdviserLinkAppCore extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'AdviserLink',
          debugShowCheckedModeBanner: false,
          theme: buildLight(),
          darkTheme: buildDark(),
          themeMode: switch (themeProvider.mode) {
            AppThemeMode.light => ThemeMode.light,
            AppThemeMode.dark => ThemeMode.dark,
            AppThemeMode.system => ThemeMode.system,
          },
          home: const Root(),
        );
      },
    );
  }
}

/// App root: checks for saved token and loads user
class Root extends StatefulWidget {
  const Root({super.key});
  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  Widget? _screen;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final path = Uri.base.path;
    final token = Uri.base.queryParameters['token'];
    if (path.endsWith('/verify-email')) {
      setState(() => _screen = EmailVerificationScreen(token: token));
      return;
    }
    if (Api.token == null) {
      setState(() => _screen = const LandingScreen());
      return;
    }
    try {
      await Api.me();
      setState(() => _screen = const HomeShell());
    } catch (_) {
      await Api.logout();
      setState(() => _screen = const LandingScreen());
    }
  }

  @override
  Widget build(BuildContext context) =>
      _screen ??
      const Scaffold(
          body: Center(
              child:
                  CircularProgressIndicator(color: DesignTokens.brandPrimary)));
}
