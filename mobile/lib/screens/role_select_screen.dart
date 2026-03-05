import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart';

enum UserRole { patient, doctor }

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  Future<void> _showRolePicker(BuildContext context) async {
    final role = await showDialog<UserRole>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Register as",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),

                _RoleTile(
                  icon: Icons.badge_outlined,
                  title: "Patient",
                  onTap: () => Navigator.pop(ctx, UserRole.patient),
                ),

                const SizedBox(height: 10),

                _RoleTile(
                  icon: Icons.medical_services_outlined,
                  title: "Doctor",
                  onTap: () => Navigator.pop(ctx, UserRole.doctor),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (role == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterScreen(role: role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF3F6FB);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  const Spacer(flex: 2),
                  /// LOGO
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF0F172A),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      "AI",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// TITLE
                  const Text(
                    "AI-DPMMS",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// SUBTITLE
                  const Text(
                    "Helping You Stay on\nTrack, Every Day",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),

                  const SizedBox(height: 48),
                  const Spacer(flex: 3),
                  /// REGISTER BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _showRolePicker(context),
                      child: const _MainButton(
                        icon: Icons.person_add_alt_1_outlined,
                        text: "Register as",
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// LOGIN BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const _MainButton(
                        icon: Icons.login,
                        text: "Login",
                      ),
                    ),
                  ),
                const Spacer(flex: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// BUTTON STYLE
class _MainButton extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MainButton({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 6),
            color: Color(0x14000000),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF0F172A)),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

/// ROLE TILE
class _RoleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _RoleTile({
    required this.icon,
    required this.title,
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
            Icon(icon, color: const Color(0xFF0F172A)),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }
}