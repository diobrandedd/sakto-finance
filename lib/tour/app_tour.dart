import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../appearance/appearance.dart';
import '../theme/app_theme.dart';

final tourCompletedProvider =
    StateNotifierProvider<TourCompletedController, bool>(
      (ref) => TourCompletedController(ref.watch(sharedPreferencesProvider)),
    );

final tourRequestProvider = StateProvider<TourRequest?>((ref) => null);

class TourRequest {
  TourRequest(this.guide) : id = DateTime.now().microsecondsSinceEpoch;

  final TourGuide guide;
  final int id;
}

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

enum TourGuide { full, lentMoney, incomeSources }

enum TourTarget {
  welcome,
  help,
  home,
  accounts,
  add,
  reports,
  more,
  credits,
  lent,
  income,
  settings,
}

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

const fullTourSteps = [
  TourStep(
    target: TourTarget.welcome,
    title: 'Welcome to Sakto',
    body:
        'This quick tour shows where to tap. Tap ? anytime to replay everything, or jump to Lent money or Income sources only.',
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
        'Credits, lent money, income sources, and Settings are all under the More tab.',
  ),
  TourStep(
    target: TourTarget.credits,
    title: 'Credits',
    body:
        'Track loans and installment purchases you owe — principal, schedule, and payment progress.',
  ),
  TourStep(
    target: TourTarget.lent,
    title: 'Lent money',
    body:
        'When you lend money, Sakto deducts the amount from the account you choose. When they pay you back, you pick which account receives it.',
  ),
  TourStep(
    target: TourTarget.income,
    title: 'Income sources',
    body:
        'Add recurring pay here so Home can estimate month-end balance from expected income.',
  ),
  TourStep(
    target: TourTarget.settings,
    title: 'Settings & look',
    body:
        'Change color themes, pick a background photo, enable reminders, and export a backup.',
  ),
  TourStep(
    target: TourTarget.help,
    title: 'Pick a guide anytime',
    body:
        'Tap ? to choose Replay everything, Lent money, or Income sources. You can skip a guide whenever you want.',
  ),
];

const lentMoneyTourSteps = [
  TourStep(
    target: TourTarget.more,
    title: 'Find Lent money',
    body: 'Open the More tab to track money others owe you.',
  ),
  TourStep(
    target: TourTarget.lent,
    title: 'Lent money',
    body:
        'When you lend money, Sakto deducts the amount from the account you choose. When they pay you back, you pick which account receives it.',
  ),
];

const incomeSourcesTourSteps = [
  TourStep(
    target: TourTarget.more,
    title: 'Find Income sources',
    body: 'Open the More tab to set up recurring pay for forecasting.',
  ),
  TourStep(
    target: TourTarget.income,
    title: 'Income sources',
    body:
        'Add recurring pay here so Home can estimate month-end balance from expected income.',
  ),
];

List<TourStep> stepsForGuide(TourGuide guide) => switch (guide) {
  TourGuide.full => fullTourSteps,
  TourGuide.lentMoney => lentMoneyTourSteps,
  TourGuide.incomeSources => incomeSourcesTourSteps,
};

int tabIndexForTourTarget(TourTarget target) => switch (target) {
  TourTarget.accounts => 1,
  TourTarget.reports => 3,
  TourTarget.more ||
  TourTarget.credits ||
  TourTarget.lent ||
  TourTarget.income ||
  TourTarget.settings =>
    4,
  _ => 0,
};

Future<TourGuide?> showTourGuidePicker(BuildContext context) {
  return showModalBottomSheet<TourGuide>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final colors = context.sakto;
      Widget option({
        required IconData icon,
        required String title,
        required String subtitle,
        required TourGuide guide,
      }) {
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: colors.accentLight,
            foregroundColor: colors.accent,
            child: Icon(icon),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pop(context, guide),
        );
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'Choose a guide',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              option(
                icon: Icons.all_inclusive_rounded,
                title: 'Replay everything',
                subtitle: 'Full walkthrough of Home, tabs, and More tools',
                guide: TourGuide.full,
              ),
              option(
                icon: Icons.handshake_outlined,
                title: 'Lent money',
                subtitle: 'How lending deducts from an account',
                guide: TourGuide.lentMoney,
              ),
              option(
                icon: Icons.event_repeat,
                title: 'Income sources',
                subtitle: 'Recurring pay and month-end forecasts',
                guide: TourGuide.incomeSources,
              ),
            ],
          ),
        ),
      );
    },
  );
}

class TourKeys {
  TourKeys();

  final help = GlobalKey();
  final settings = GlobalKey();
  final home = GlobalKey();
  final accounts = GlobalKey();
  final add = GlobalKey();
  final reports = GlobalKey();
  final more = GlobalKey();
  final credits = GlobalKey();
  final lent = GlobalKey();
  final income = GlobalKey();

  GlobalKey? keyFor(TourTarget target) => switch (target) {
    TourTarget.welcome => null,
    TourTarget.help => help,
    TourTarget.home => home,
    TourTarget.accounts => accounts,
    TourTarget.add => add,
    TourTarget.reports => reports,
    TourTarget.more => more,
    TourTarget.credits => credits,
    TourTarget.lent => lent,
    TourTarget.income => income,
    TourTarget.settings => settings,
  };
}

class AppTourOverlay extends StatefulWidget {
  const AppTourOverlay({
    required this.keys,
    required this.steps,
    required this.onFinished,
    required this.onStepChanged,
    super.key,
  });

  final TourKeys keys;
  final List<TourStep> steps;
  final VoidCallback onFinished;
  final ValueChanged<int> onStepChanged;

  @override
  State<AppTourOverlay> createState() => _AppTourOverlayState();
}

class _AppTourOverlayState extends State<AppTourOverlay> {
  int _index = 0;
  Rect? _hole;
  int _measureToken = 0;

  List<TourStep> get _steps => widget.steps;
  TourStep get _step => _steps[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onStepChanged(_index);
      _measure();
    });
  }

  Future<void> _measure({int attempt = 0}) async {
    final token = ++_measureToken;
    await Future<void>.delayed(Duration(milliseconds: attempt == 0 ? 50 : 120));
    if (!mounted || token != _measureToken) return;

    final key = widget.keys.keyFor(_step.target);
    final targetContext = key?.currentContext;
    if (targetContext == null || !targetContext.mounted) {
      if (attempt < 8) {
        await _measure(attempt: attempt + 1);
        return;
      }
      setState(() => _hole = null);
      return;
    }
    final box = targetContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      if (attempt < 8) {
        await _measure(attempt: attempt + 1);
        return;
      }
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
  }

  Future<void> _next() async {
    if (_index >= _steps.length - 1) {
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
    final isLast = _index == _steps.length - 1;

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
                              'Step ${_index + 1} of ${_steps.length}',
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
                              minimumSize: const Size(96, 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              backgroundColor: colors.accent,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              isLast
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
