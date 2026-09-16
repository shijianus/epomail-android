import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/account_provider.dart';
import '../../theme/app_theme.dart';
import 'login_screen.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();

  late final _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
  late final _scale = Tween(begin: 0.88, end: 1.0).animate(
    CurvedAnimation(parent: _ac, curve: Curves.easeOutBack),
  );

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    await auth.init();
    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    Widget target;
    if (auth.isAuthenticated) {
      await context.read<AccountProvider>().load();
      if (mounted) await context.read<AccountProvider>().refreshStats();
      target = const HomeScreen();
    } else {
      target = const LoginScreen();
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => target,
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBgBase,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppTheme.blue.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                        color: AppTheme.blue.withOpacity(0.35), width: 1.5),
                  ),
                  child: const Icon(Icons.mark_email_unread_outlined,
                      size: 46, color: AppTheme.blue),
                ),
                const SizedBox(height: 28),
                const Text(
                  'EpoCanvas Mail',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your private email, everywhere.',
                  style: TextStyle(
                      fontSize: 14, color: Colors.white.withOpacity(0.42)),
                ),
                const SizedBox(height: 52),
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.blue.withOpacity(0.65)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
