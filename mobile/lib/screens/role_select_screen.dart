import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';
import 'register_screen.dart';

enum UserRole { patient, doctor }

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _chevronCtrl;
  late final AnimationController _sheetCtrl;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoSlide;
  late final Animation<double> _titleFade;
  late final Animation<double> _titleSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<double> _subtitleSlide;
  late final Animation<double> _hintFade;
  late final Animation<double> _pulse;
  late final Animation<double> _sheetSlide;
  late final Animation<double> _backdropFade;

  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();

    // Entry animation (one-shot)
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    _logoFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    _logoSlide = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );
    _titleFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.25, 0.65, curve: Curves.easeOut),
    );
    _titleSlide = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.25, 0.65, curve: Curves.easeOutCubic),
      ),
    );
    _subtitleFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.45, 0.82, curve: Curves.easeOut),
    );
    _subtitleSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.45, 0.82, curve: Curves.easeOutCubic),
      ),
    );
    _hintFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.72, 1.0, curve: Curves.easeOut),
    );

    // Pulse glow (repeating)
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.14).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Chevrons (repeating)
    _chevronCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    // Sheet
    _sheetCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _sheetSlide = CurvedAnimation(
      parent: _sheetCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _backdropFade = CurvedAnimation(
      parent: _sheetCtrl,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _chevronCtrl.dispose();
    _sheetCtrl.dispose();
    super.dispose();
  }

  void _openSheet() {
    if (_sheetOpen) return;
    setState(() => _sheetOpen = true);
    _sheetCtrl.forward();
  }

  void _closeSheet() {
    _sheetCtrl.reverse().then((_) {
      if (mounted) setState(() => _sheetOpen = false);
    });
  }

  void _goLogin() {
    _closeSheet();
    Future.delayed(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  Future<void> _goRegister() async {
    _closeSheet();
    await Future.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    final role = await _showRolePicker();
    if (role == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RegisterScreen(role: role)),
    );
  }

  Future<UserRole?> _showRolePicker() {
    return showDialog<UserRole>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Register as',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _RoleTile(
                icon: Icons.person_outline_rounded,
                title: 'Patient',
                subtitle: 'Track medications & stay on schedule',
                onTap: () => Navigator.pop(ctx, UserRole.patient),
              ),
              const SizedBox(height: 10),
              _RoleTile(
                icon: Icons.medical_services_outlined,
                title: 'Doctor',
                subtitle: 'Monitor patients & manage care',
                onTap: () => Navigator.pop(ctx, UserRole.doctor),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Animation<double> _chevronOpacity(int index) {
    final start = index * 0.22;
    final end = (start + 0.54).clamp(0.0, 1.0);
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
    ]).animate(CurvedAnimation(parent: _chevronCtrl, curve: Interval(start, end)));
  }

  Animation<double> _chevronOffset(int index) {
    final start = index * 0.22;
    final end = (start + 0.54).clamp(0.0, 1.0);
    return Tween<double>(begin: 8.0, end: -8.0).animate(
      CurvedAnimation(
        parent: _chevronCtrl,
        curve: Interval(start, end, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return PopScope(
      canPop: !_sheetOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeSheet();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1D3A),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragEnd: (details) {
            if (details.velocity.pixelsPerSecond.dy < -300) _openSheet();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Dark gradient background
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0B1D3A),
                        Color(0xFF0F2554),
                        Color(0xFF163466),
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // Decorative orbs
              Positioned(
                top: -90, right: -90,
                child: Container(
                  width: 300, height: 300,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x1A3B82F6),
                  ),
                ),
              ),
              Positioned(
                top: -40, right: -40,
                child: Container(
                  width: 160, height: 160,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x142563EB),
                  ),
                ),
              ),
              Positioned(
                bottom: -80, left: -80,
                child: Container(
                  width: 280, height: 280,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x151E40AF),
                  ),
                ),
              ),
              Positioned(
                top: size.height * 0.42, left: -50,
                child: Container(
                  width: 130, height: 130,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x0D60A5FA),
                  ),
                ),
              ),

              // Main content
              SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // Logo with entry animation
                    AnimatedBuilder(
                      animation: _entryCtrl,
                      builder: (_, child) => Opacity(
                        opacity: _logoFade.value,
                        child: Transform.translate(
                          offset: Offset(0, _logoSlide.value),
                          child: child,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Pulsing glow ring
                          AnimatedBuilder(
                            animation: _pulseCtrl,
                            builder: (_, _) => Transform.scale(
                              scale: _pulse.value,
                              child: Container(
                                width: 148, height: 148,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0x203B82F6),
                                  border: Border.all(
                                    color: const Color(0x403B82F6),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // White logo circle
                          Container(
                            width: 112, height: 112,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x503B82F6),
                                  blurRadius: 28,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Center(
                                  child: Text(
                                    'AI',
                                    style: TextStyle(
                                      color: Color(0xFF0D1B4C),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 28,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Title
                    AnimatedBuilder(
                      animation: _entryCtrl,
                      builder: (_, child) => Opacity(
                        opacity: _titleFade.value,
                        child: Transform.translate(
                          offset: Offset(0, _titleSlide.value),
                          child: child,
                        ),
                      ),
                      child: Text(
                        'AI-DPMMS',
                        style: GoogleFonts.poppins(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Subtitle
                    AnimatedBuilder(
                      animation: _entryCtrl,
                      builder: (_, child) => Opacity(
                        opacity: _subtitleFade.value,
                        child: Transform.translate(
                          offset: Offset(0, _subtitleSlide.value),
                          child: child,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Your smart companion for\npersonalized care',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            height: 1.6,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF93C5FD),
                          ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Swipe hint
                    AnimatedBuilder(
                      animation: _hintFade,
                      builder: (_, child) => Opacity(
                        opacity: _hintFade.value,
                        child: child,
                      ),
                      child: _SwipeHint(
                        chevronOpacity: _chevronOpacity,
                        chevronOffset: _chevronOffset,
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),

              // Backdrop
              if (_sheetOpen)
                FadeTransition(
                  opacity: _backdropFade,
                  child: GestureDetector(
                    onTap: _closeSheet,
                    child: Container(color: Colors.black54),
                  ),
                ),

              // Bottom sheet
              if (_sheetOpen)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).animate(_sheetSlide),
                    child: _GetStartedSheet(
                      onLogin: _goLogin,
                      onRegister: _goRegister,
                      onClose: _closeSheet,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Swipe hint ────────────────────────────────────────────────────────────────

class _SwipeHint extends StatelessWidget {
  final Animation<double> Function(int) chevronOpacity;
  final Animation<double> Function(int) chevronOffset;

  const _SwipeHint({required this.chevronOpacity, required this.chevronOffset});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(3, (i) {
          final idx = 2 - i;
          final opacity = chevronOpacity(idx);
          final offset = chevronOffset(idx);
          return AnimatedBuilder(
            animation: opacity,
            builder: (_, _) => Transform.translate(
              offset: Offset(0, offset.value),
              child: Opacity(
                opacity: opacity.value.clamp(0.0, 1.0),
                child: const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: Color(0xFF60A5FA),
                  size: 30,
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        Text(
          'Swipe up to get started',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ── Bottom sheet ─────────────────────────────────────────────────────────────

class _GetStartedSheet extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback onClose;

  const _GetStartedSheet({
    required this.onLogin,
    required this.onRegister,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.velocity.pixelsPerSecond.dy > 300) onClose();
      },
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              blurRadius: 40,
              offset: Offset(0, -10),
              color: Color(0x33000000),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Get Started',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0D1B4C),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose an option to continue',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D1B4C),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: onLogin,
                      icon: const Icon(Icons.login_rounded, size: 20),
                      label: Text('Login',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                    ),
                  ),

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0D1B4C),
                        side: const BorderSide(
                            color: Color(0xFF0D1B4C), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: onRegister,
                      icon: const Icon(Icons.person_add_outlined, size: 20),
                      label: Text('Create Account',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                    ),
                  ),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Role tile ─────────────────────────────────────────────────────────────────

class _RoleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF1E3A8A), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: const Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: const Color(0xFF64748B))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
