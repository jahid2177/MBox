import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A pure-Flutter cinematic MBOX intro. No network, demo content or assets.
class MBoxSplashScreen extends StatefulWidget {
  final Widget next;
  const MBoxSplashScreen({super.key, required this.next});

  @override
  State<MBoxSplashScreen> createState() => _MBoxSplashScreenState();
}

class _MBoxSplashScreenState extends State<MBoxSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  late final Animation<double> _scale = Tween<double>(begin: .63, end: 1.0)
      .animate(CurvedAnimation(parent: _controller,
          curve: const Interval(.08, .82, curve: Curves.easeOutCubic)));
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(.05, .45, curve: Curves.easeIn),
  );
  late final Animation<double> _glow = CurvedAnimation(
    parent: _controller,
    curve: const Interval(.38, .94, curve: Curves.easeInOut),
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder<void>(
            pageBuilder: (_, animation, secondaryAnimation) => widget.next,
            transitionDuration: const Duration(milliseconds: 380),
            transitionsBuilder: (_, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.scale(
              scale: _scale.value,
              child: Opacity(
                opacity: _fade.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(alignment: Alignment.center, children: [
                      Container(
                        width: 132,
                        height: 132,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                            color: AppColors.red.withValues(alpha: .4 * _glow.value),
                            blurRadius: 75 * _glow.value,
                            spreadRadius: 10 * _glow.value,
                          )],
                        ),
                      ),
                      const Icon(Icons.play_arrow_rounded,
                          size: 90, color: AppColors.red),
                    ]),
                    const SizedBox(height: 12),
                    const Text('MBOX',
                      style: TextStyle(color: Colors.white,
                        fontSize: 55, letterSpacing: 9,
                        fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    const Text('YOUR CINEMA. ANYWHERE.',
                      style: TextStyle(color: Colors.white54,
                        fontSize: 10, letterSpacing: 3)),
                    const SizedBox(height: 30),
                    SizedBox(width: 150, child: LinearProgressIndicator(
                      value: _controller.value, minHeight: 2,
                      color: AppColors.red,
                      backgroundColor: Colors.white12,
                    )),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
