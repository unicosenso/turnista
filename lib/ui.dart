import 'package:flutter/material.dart';

import 'models.dart';
import 'store.dart';

/// Colori nello stile di MF Life.
class Palette {
  static const bg = Color(0xFFF2F4F0);
  static const card = Colors.white;
  static const primary = Color(0xFF0F6E63);
  static const primarySoft = Color(0xFFCDE9E3);
  static const text = Color(0xFF1B1C1A);
  static const muted = Color(0xFF5E6360);
  static const line = Color(0xFFE3E6E1);
  static const errorBg = Color(0xFFFBEAEA);
  static const warmBg = Color(0xFFFFF8EC);
  static const warmBorder = Color(0xFFF0DDB0);

  /// Colori proposti per i tipi di turno.
  static const shiftColors = <int>[
    0xFF7C3AED, // viola
    0xFFF59E0B, // arancio
    0xFF1E88E5, // blu
    0xFF0F6E63, // verde petrolio
    0xFFE11D48, // rosso
    0xFF16A34A, // verde
    0xFFDB2777, // rosa
    0xFF0891B2, // azzurro
    0xFF92400E, // marrone
    0xFF475569, // ardesia
    0xFF9AA19D, // grigio
    0xFFCA8A04, // ocra
  ];
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.primary,
    primary: Palette.primary,
    surface: Palette.bg,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Palette.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Palette.text),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Palette.primarySoft,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 13,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? Palette.text : Palette.muted,
          )),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? Palette.primary : Palette.muted,
          )),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Palette.primary,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Palette.primary : null),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.bg,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
  );
}

/// Accesso allo store da qualunque widget.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

class AppCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color? border;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  const AppCard({
    super.key,
    required this.child,
    this.color = Palette.card,
    this.border,
    this.padding = const EdgeInsets.fromLTRB(22, 20, 22, 20),
    this.onTap,
    this.radius = 28,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: border == null ? BorderSide.none : BorderSide(color: border!, width: 1.5),
    );
    return Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Badge colorato con la sigla del turno (come "CM" e "Mfe" in MF Life).
class ShiftBadge extends StatelessWidget {
  final ShiftType? type;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const ShiftBadge(this.type,
      {super.key,
      this.fontSize = 17,
      this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5)});

  @override
  Widget build(BuildContext context) {
    final t = type;
    if (t == null) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Palette.line, width: 1.5),
        ),
        child: Text('—',
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: Palette.muted)),
      );
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Color(t.color),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        t.code.isEmpty ? '?' : t.code,
        style: TextStyle(
            fontSize: fontSize, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15),
      ),
    );
  }
}

class CardHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const CardHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Palette.text)),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600, color: Palette.primary)),
          ),
      ],
    );
  }
}

class MutedText extends StatelessWidget {
  final String text;
  final double size;
  const MutedText(this.text, {super.key, this.size = 16});
  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(fontSize: size, color: Palette.muted, height: 1.35));
}

/// Riquadro rosa per avvisi (stesso stile del messaggio di errore di MF Life).
class WarningCard extends StatelessWidget {
  final String text;
  final String action;
  final VoidCallback onAction;
  const WarningCard({super.key, required this.text, required this.action, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Palette.errorBg,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(fontSize: 16, color: Palette.text, height: 1.4)),
          const SizedBox(height: 4),
          TextButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    );
  }
}

/// Selettore orario "HH:MM" con il time picker di sistema.
Future<String?> pickHm(BuildContext context, String current, {String? help}) async {
  final m = parseHm(current);
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    helpText: help,
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  if (t == null) return null;
  return '${two(t.hour)}:${two(t.minute)}';
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}

/// Pulsante "+ / −" per regolare l'anticipo della sveglia a mano.
class OffsetStepper extends StatelessWidget {
  final int minutes;
  final ValueChanged<int> onChanged;
  const OffsetStepper({super.key, required this.minutes, required this.onChanged});

  Widget _btn(IconData icon, VoidCallback? onTap) => Material(
        color: Palette.primarySoft,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Palette.primary),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _btn(Icons.remove, minutes > 0 ? () => onChanged((minutes - 5).clamp(0, 600).toInt()) : null),
            Expanded(
              child: Text(
                '${formatDuration(minutes)} prima',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
            ),
            _btn(Icons.add, minutes < 600 ? () => onChanged((minutes + 5).clamp(0, 600).toInt()) : null),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [15, 30, 45, 60, 75, 90, 120]
              .map((v) => ChoiceChip(
                    label: Text(formatDuration(v)),
                    selected: minutes == v,
                    onSelected: (_) => onChanged(v),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
