import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../appearance/appearance.dart';
import '../theme/app_theme.dart';

final tourCompletedProvider =
    StateNotifierProvider<TourCompletedController, bool>(
      (ref) => TourCompletedController(ref.watch(sharedPreferencesProvider)),
    );

final tourRequestProvider = StateProvider<int>((ref) => 0);

class TourCompletedController extends StateNotifier<bool> {
  TourCompletedController(this._prefs) : super(_prefs.getBool(_key) ?? false);

  static const _key = 'sakto.tour.completed';
  final SharedPreferences _prefs;

  Future<void> markCompleted() async {
    state = true;
    await _prefs.setBool(_key, true);
  }

  Future<void> reset() async {
    state = false;
    await _prefs.setBool(_key, false);
  }
}

enum TourTarget { welcome, help, home, accounts, add, reports, more, settings }

class TourStep {
  const TourStep({
    required this.target,
    required this.title,
    required this.body,
  });

  final TourTarget target;
  final String title;
  final String body;
}

const saktoTourSteps = [
  TourStep(
    target: TourTarget.welcome,
    title: 'Welcome to Sakto',
    body:
        'This quick tour shows where to tap. You can replay it anytime with the ? button.',
  ),
  TourStep(
    target: TourTarget.home,
    title: 'Home overview',
    body:
        'Your total balance, account chart, forecast, and recent transactions live here.',
  ),
  TourStep(
    target: TourTarget.accounts,
    title: 'Accounts',
    body:
        'Add cash, bank, card, or e-wallet accounts here. Start with at least one account.',
  ),
  TourStep(
    target: TourTarget.add,
    title: 'Add money movement',
    body:
        'Tap + to record an expense or income. Choose the account, category, amount, and date.',
  ),
  TourStep(
    target: TourTarget.reports,
    title: 'Reports',
    body:
        'Review spent, added, and net totals for this week, this month, or a custom date range.',
  ),
  TourStep(
    target: TourTarget.more,
    title: 'More tools',
    body:
        'Open Credits, Lent money, Income sources, and Settings from the More tab.',
  ),
  TourStep(
    target: TourTarget.settings,
    title: 'Settings & look',
    body:
        'Change color themes, pick a background photo, enable reminders, and export a backup.',
  ),
  TourStep(
    target: TourTarget.help,
    title: 'Replay this tour',
    body:
        'Tap the ? anytime to walk through Sakto again. You can skip the tour whenever you want.',
  ),
];

class TourKeys {
  TourKeys();

  final help = GlobalKey();
  final settings = GlobalKey();
  final home = GlobalKey();
  final accounts = GlobalKey();
  final add = GlobalKey();
  final reports = GlobalKey();
  final more = GlobalKey();

  GlobalKey? keyFor(TourTarget target) => switch (target) {
    TourTarget.welcome => null,
    TourTarget.help => help,
    TourTarget.home => home,
    TourTarget.accounts => accounts,
    TourTarget.add => add,
    TourTarget.reports => reports,
    TourTarget.more => more,
    TourTarget.settings => settings,
  };
}

class AppTourOverlay extends StatefulWidget {
  const AppTourOverlay({
    required this.keys,
    required this.onFinished,
    required this.onStepChanged,
    super.key,
  });

  final TourKeys keys;
  final VoidCallback onFinished;
  final ValueChanged<int> onStepChanged;

  @override
  State<AppTourOverlay> createState() => _AppTourOverlayState();
}

class _AppTourOverlayState extends State<AppTourOverlay> {
  int _index = 0;
  Rect? _hole;

  TourStep get _step => saktoTourSteps[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  Future<void> _measure() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    final key = widget.keys.keyFor(_step.target);
    final targetContext = key?.currentContext;
    if (targetContext == null || !targetContext.mounted) {
      setState(() => _hole = null);
      return;
    }
    final box = targetContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      setState(() => _hole = null);
      return;
    }
    final offset = box.localToGlobal(Offset.zero);
    setState(() {
      _hole = Rect.fromLTWH(
        offset.dx - 8,
        offset.dy - 8,
        box.size.width + 16,
        box.size.height + 16,
      );
    });
  }

  Future<void> _goTo(int index) async {
    setState(() {
      _index = index;
      _hole = null;
    });
    widget.onStepChanged(index);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (mounted) await _measure();
    });
  }

  Future<void> _next() async {
    if (_index >= saktoTourSteps.length - 1) {
      widget.onFinished();
      return;
    }
    await _goTo(_index + 1);
  }

  Future<void> _back() async {
    if (_index == 0) return;
    await _goTo(_index - 1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.sakto;
    final size = MediaQuery.sizeOf(context);
    final cardTop = (_hole == null || _hole!.center.dy > size.height * 0.45)
        ? 72.0
        : null;
    final cardBottom = cardTop == null ? 110.0 : null;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: CustomPaint(
                painter: _SpotlightPainter(
                  hole: _hole,
                  dimColor: Colors.black.withValues(alpha: 0.72),
                ),
              ),
            ),
          ),
          if (_hole != null)
            Positioned.fromRect(
              rect: _hole!.inflate(2),
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colors.accent, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: colors.accent.withValues(alpha: 0.35),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            left: 18,
            right: 18,
            top: cardTop,
            bottom: cardBottom,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Card(
                key: ValueKey(_index),
                color: colors.surface,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.accentLight,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'Step ${_index + 1} of ${saktoTourSteps.length}',
                              style: TextStyle(
                                color: colors.accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: widget.onFinished,
                            child: const Text('Skip'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _step.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _step.body,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (_index > 0)
                            TextButton(
                              onPressed: _back,
                              child: const Text('Back'),
                            ),
                          const Spacer(),
                          FilledButton(
                            onPressed: _next,
                            style: FilledButton.styleFrom(
                              // Theme default uses Size.fromHeight (infinite
                              // width), which collapses this button in a Row.
                              minimumSize: const Size(96, 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              backgroundColor: colors.accent,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              _index == saktoTourSteps.length - 1
                                  ? 'Done'
                                  : (_index == 0 ? 'Start' : 'Next'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.hole, required this.dimColor});

  final Rect? hole;
  final Color dimColor;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    if (hole != null) {
      overlay.addRRect(
        RRect.fromRectAndRadius(hole!, const Radius.circular(18)),
      );
    }
    canvas.drawPath(
      overlay,
      Paint()
        ..color = dimColor
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.hole != hole || oldDelegate.dimColor != dimColor;
}
