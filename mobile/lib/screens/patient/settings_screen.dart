import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../services/settings_service.dart';
import '../reset_password_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService.instance;

  static const Color _primary = Color(0xFF1E3A8A);

  // ── helpers ─────────────────────────────────────────────────────────────

  bool get _isDark {
    final mode = _settings.themeMode;
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  // ── section / tile builders ─────────────────────────────────────────────

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: _primary.withValues(alpha: 0.75),
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    final cardColor = _isDark ? const Color(0xFF1E1E2E) : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.25 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: _divided(children)),
    );
  }

  List<Widget> _divided(List<Widget> tiles) {
    final result = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      result.add(tiles[i]);
      if (i < tiles.length - 1) {
        result.add(Divider(
          height: 1,
          indent: 56,
          endIndent: 16,
          color: _isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.grey.shade200,
        ));
      }
    }
    return result;
  }

  Widget _tile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final iconBg = iconColor.withValues(alpha: 0.12);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration:
            BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
          : null,
      trailing: trailing ??
          (onTap != null
              ? Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20)
              : null),
    );
  }

  // ── pickers ──────────────────────────────────────────────────────────────

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ThemePickerSheet(settings: _settings),
    ).then((_) => setState(() {}));
  }

  void _showFontSizePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FontSizePickerSheet(settings: _settings),
    ).then((_) => setState(() {}));
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LanguagePickerSheet(settings: _settings),
    ).then((_) => setState(() {}));
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isRtl = _settings.isRtl;
    final bgColor = _isDark ? const Color(0xFF12121F) : const Color(0xFFF3F6FB);

    final themeLabel = switch (_settings.themeMode) {
      ThemeMode.light => s.themeLight,
      ThemeMode.dark => s.themeDark,
      ThemeMode.system => s.themeSystem,
    };

    final fontLabel = switch (_settings.fontSize) {
      AppFontSize.small => s.fontSmall,
      AppFontSize.medium => s.fontMedium,
      AppFontSize.large => s.fontLarge,
    };

    final langLabel = switch (_settings.locale.languageCode) {
      'ar' => 'العربية',
      'he' => 'עברית',
      _ => 'English',
    };

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              isRtl ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
              size: 18,
              color: _isDark ? Colors.white : Colors.black87,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            s.settingsTitle,
            style: TextStyle(
              color: _isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            // ── Appearance ──────────────────────────────────────
            _section(s.appearanceSection),
            _card(children: [
              _tile(
                icon: Icons.brightness_6_outlined,
                iconColor: const Color(0xFF7C3AED),
                title: s.themeTitle,
                subtitle: themeLabel,
                onTap: _showThemePicker,
                trailing: _PillBadge(label: themeLabel, isDark: _isDark),
              ),
              _tile(
                icon: Icons.text_fields_rounded,
                iconColor: const Color(0xFF0369A1),
                title: s.fontSizeTitle,
                subtitle: fontLabel,
                onTap: _showFontSizePicker,
                trailing: _PillBadge(label: fontLabel, isDark: _isDark),
              ),
            ]),

            // ── Language ─────────────────────────────────────────
            _section(s.languageSection),
            _card(children: [
              _tile(
                icon: Icons.language_rounded,
                iconColor: const Color(0xFF059669),
                title: s.appLanguageTitle,
                subtitle: langLabel,
                onTap: _showLanguagePicker,
                trailing: _PillBadge(label: langLabel, isDark: _isDark),
              ),
            ]),

            // ── Privacy & Security ────────────────────────────────
            _section(s.securitySection),
            _card(children: [
              _tile(
                icon: Icons.lock_outline_rounded,
                iconColor: const Color(0xFFDC2626),
                title: s.changePasswordTitle,
                subtitle: s.changePasswordSub,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ResetPasswordScreen()),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Shared bottom-sheet base ───────────────────────────────────────────────

class _SheetBase extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final SettingsService settings;

  const _SheetBase({
    required this.title,
    required this.children,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final isRtl = settings.isRtl;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        decoration: BoxDecoration(
          color: sheetColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Align(
              alignment:
                  isRtl ? Alignment.centerRight : Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1E3A8A);
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? primary : null,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: primary, size: 22)
          : Icon(Icons.radio_button_unchecked,
              color: Colors.grey.shade400, size: 22),
    );
  }
}

// ── Theme picker ──────────────────────────────────────────────────────────

class _ThemePickerSheet extends StatefulWidget {
  final SettingsService settings;
  const _ThemePickerSheet({required this.settings});

  @override
  State<_ThemePickerSheet> createState() => _ThemePickerSheetState();
}

class _ThemePickerSheetState extends State<_ThemePickerSheet> {
  late ThemeMode _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.settings.themeMode;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return _SheetBase(
      title: s.themeTitle,
      settings: widget.settings,
      children: [
        _OptionTile(
          label: s.themeLight,
          selected: _selected == ThemeMode.light,
          onTap: () {
            setState(() => _selected = ThemeMode.light);
            widget.settings.setThemeMode(ThemeMode.light);
            Navigator.pop(context);
          },
        ),
        _OptionTile(
          label: s.themeDark,
          selected: _selected == ThemeMode.dark,
          onTap: () {
            setState(() => _selected = ThemeMode.dark);
            widget.settings.setThemeMode(ThemeMode.dark);
            Navigator.pop(context);
          },
        ),
        _OptionTile(
          label: s.themeSystem,
          selected: _selected == ThemeMode.system,
          onTap: () {
            setState(() => _selected = ThemeMode.system);
            widget.settings.setThemeMode(ThemeMode.system);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

// ── Font size picker ──────────────────────────────────────────────────────

class _FontSizePickerSheet extends StatefulWidget {
  final SettingsService settings;
  const _FontSizePickerSheet({required this.settings});

  @override
  State<_FontSizePickerSheet> createState() => _FontSizePickerSheetState();
}

class _FontSizePickerSheetState extends State<_FontSizePickerSheet> {
  late AppFontSize _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.settings.fontSize;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return _SheetBase(
      title: s.fontSizeTitle,
      settings: widget.settings,
      children: [
        _OptionTile(
          label: s.fontSmall,
          selected: _selected == AppFontSize.small,
          onTap: () {
            setState(() => _selected = AppFontSize.small);
            widget.settings.setFontSize(AppFontSize.small);
            Navigator.pop(context);
          },
        ),
        _OptionTile(
          label: s.fontMedium,
          selected: _selected == AppFontSize.medium,
          onTap: () {
            setState(() => _selected = AppFontSize.medium);
            widget.settings.setFontSize(AppFontSize.medium);
            Navigator.pop(context);
          },
        ),
        _OptionTile(
          label: s.fontLarge,
          selected: _selected == AppFontSize.large,
          onTap: () {
            setState(() => _selected = AppFontSize.large);
            widget.settings.setFontSize(AppFontSize.large);
            Navigator.pop(context);
          },
        ),
        const SizedBox(height: 8),
        _FontPreviewRow(fontSize: _selected, s: s),
      ],
    );
  }
}

class _FontPreviewRow extends StatelessWidget {
  final AppFontSize fontSize;
  final S s;

  const _FontPreviewRow({required this.fontSize, required this.s});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = switch (fontSize) {
      AppFontSize.small => 0.85,
      AppFontSize.medium => 1.0,
      AppFontSize.large => 1.15,
    };

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : const Color(0xFFBFDBFE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.textPreviewLabel,
            style: TextStyle(fontSize: 11 * scale, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          Text(
            s.textPreviewContent,
            style: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ── Language picker ───────────────────────────────────────────────────────

class _LanguagePickerSheet extends StatefulWidget {
  final SettingsService settings;
  const _LanguagePickerSheet({required this.settings});

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  late String _selectedCode;

  // Native name • English name  (intentionally NOT translated)
  static const _langs = [
    (code: 'en', display: 'English  •  English'),
    (code: 'ar', display: 'العربية  •  Arabic'),
    (code: 'he', display: 'עברית  •  Hebrew'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedCode = widget.settings.locale.languageCode;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return _SheetBase(
      title: s.appLanguageTitle,
      settings: widget.settings,
      children: _langs.map((lang) {
        return _OptionTile(
          label: lang.display,
          selected: _selectedCode == lang.code,
          onTap: () {
            setState(() => _selectedCode = lang.code);
            widget.settings.setLocale(Locale(lang.code));
            Navigator.pop(context);
          },
        );
      }).toList(),
    );
  }
}

// ── Pill badge ─────────────────────────────────────────────────────────────

class _PillBadge extends StatelessWidget {
  final String label;
  final bool isDark;

  const _PillBadge({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
            : const Color(0xFFE8EEF9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
        ),
      ),
    );
  }
}
