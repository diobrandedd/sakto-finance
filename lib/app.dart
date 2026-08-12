import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'appearance/appearance.dart';
import 'database/app_database.dart';
import 'platform/file_support.dart';
import 'services/app_services.dart';
import 'theme/app_theme.dart';
import 'tour/app_tour.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});
final accountsProvider = StreamProvider<List<Account>>(
  (ref) => ref.watch(databaseProvider).watchAccounts(),
);
final recentProvider = StreamProvider<List<MoneyTransaction>>(
  (ref) => ref.watch(databaseProvider).watchRecentTransactions(),
);
final categoriesProvider = StreamProvider.family<List<Category>, String>(
  (ref, type) => ref.watch(databaseProvider).watchCategories(type),
);
final creditsProvider = StreamProvider<List<CreditSummary>>(
  (ref) => ref.watch(databaseProvider).watchCreditSummaries(),
);
final lentProvider = StreamProvider<List<LentMoneyData>>(
  (ref) => ref.watch(databaseProvider).watchLentMoney(),
);
final incomeSourcesProvider = StreamProvider<List<IncomeSource>>(
  (ref) => ref.watch(databaseProvider).watchIncomeSources(),
);

final money = NumberFormat.currency(
  locale: 'en_PH',
  symbol: '₱',
  decimalDigits: 2,
);
final shortDate = DateFormat('MMM d, y');

class SaktoApp extends ConsumerWidget {
  const SaktoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    return MaterialApp(
      title: 'Sakto',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(
        appearance.colors,
        transparentScaffold: appearance.hasImage,
      ),
      builder: (context, child) {
        final page = child ?? const SizedBox.shrink();
        if (!appearance.hasImage || appearance.imagePath == null) {
          return page;
        }
        final image = localFileImage(appearance.imagePath!);
        if (image == null) return page;
        return Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: image,
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: appearance.imageDim),
                BlendMode.darken,
              ),
            ),
          ),
          child: page,
        );
      },
      home: const AppShell(),
    );
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;
  bool _tourVisible = false;
  TourGuide _tourGuide = TourGuide.full;
  final _tourKeys = TourKeys();

  List<TourStep> get _tourSteps => stepsForGuide(_tourGuide);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(tourCompletedProvider)) {
        _startTour(TourGuide.full);
      }
    });
  }

  Future<void> _pickAndStartTour() async {
    final guide = await showTourGuidePicker(context);
    if (guide == null || !mounted) return;
    _startTour(guide);
  }

  void _startTour(TourGuide guide) {
    final steps = stepsForGuide(guide);
    setState(() {
      _tourGuide = guide;
      _index = tabIndexForTourTarget(steps.first.target);
      _tourVisible = true;
    });
  }

  Future<void> _finishTour() async {
    setState(() => _tourVisible = false);
    await ref.read(tourCompletedProvider.notifier).markCompleted();
  }

  void _onTourStepChanged(int stepIndex) {
    final target = _tourSteps[stepIndex].target;
    final nextIndex = tabIndexForTourTarget(target);
    if (_index != nextIndex) {
      setState(() => _index = nextIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TourRequest?>(tourRequestProvider, (previous, next) {
      if (next != null && next.id != previous?.id) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        _startTour(next.guide);
      }
    });
    final pages = [
      HomeScreen(
        helpKey: _tourKeys.help,
        homeKey: _tourKeys.home,
        onChooseGuide: _pickAndStartTour,
      ),
      const AccountsScreen(),
      const SizedBox.shrink(),
      const ReportsScreen(),
      MoreScreen(
        creditsKey: _tourKeys.credits,
        lentKey: _tourKeys.lent,
        incomeKey: _tourKeys.income,
        settingsKey: _tourKeys.settings,
      ),
    ];
    return Stack(
      children: [
        Scaffold(
          body: SafeArea(
            child: IndexedStack(index: _index, children: pages),
          ),
          floatingActionButton: FloatingActionButton(
            key: _tourKeys.add,
            backgroundColor: context.sakto.accent,
            foregroundColor: Colors.white,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
            ),
            child: const Icon(Icons.add_rounded, size: 30),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: NavigationBar(
            height: 70,
            selectedIndex: _index,
            backgroundColor: context.sakto.surface,
            indicatorColor: context.sakto.accentLight,
            onDestinationSelected: (value) {
              if (value == 2) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AddTransactionScreen(),
                  ),
                );
              } else {
                setState(() => _index = value);
              }
            },
            destinations: [
              // Keep keys on `icon` only — `selectedIcon` replaces `icon` when
              // selected, which unmounts the GlobalKey and kills the spotlight.
              const NavigationDestination(
                icon: Icon(Icons.pie_chart_outline_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: KeyedSubtree(
                  key: _tourKeys.accounts,
                  child: const SizedBox(
                    width: 64,
                    height: 40,
                    child: Center(
                      child: Icon(Icons.account_balance_wallet_outlined),
                    ),
                  ),
                ),
                label: 'Accounts',
              ),
              const NavigationDestination(icon: SizedBox(width: 32), label: ''),
              NavigationDestination(
                icon: KeyedSubtree(
                  key: _tourKeys.reports,
                  child: const SizedBox(
                    width: 64,
                    height: 40,
                    child: Center(child: Icon(Icons.calendar_month_outlined)),
                  ),
                ),
                label: 'Reports',
              ),
              NavigationDestination(
                icon: KeyedSubtree(
                  key: _tourKeys.more,
                  child: const SizedBox(
                    width: 64,
                    height: 40,
                    child: Center(child: Icon(Icons.grid_view_outlined)),
                  ),
                ),
                label: 'More',
              ),
            ],
          ),
        ),
        if (_tourVisible)
          Positioned.fill(
            child: AppTourOverlay(
              key: ValueKey(_tourGuide),
              keys: _tourKeys,
              steps: _tourSteps,
              onFinished: _finishTour,
              onStepChanged: _onTourStepChanged,
            ),
          ),
      ],
    );
  }
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader(
    this.title, {
    this.subtitle,
    this.leading,
    this.action,
    super.key,
  });
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
    child: Row(
      children: [
        ?leading,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null)
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(36),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 46, color: context.sakto.muted),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 5),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

Future<bool> confirmDelete(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this record?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    required this.helpKey,
    required this.homeKey,
    required this.onChooseGuide,
    super.key,
  });

  final GlobalKey helpKey;
  final GlobalKey homeKey;
  final VoidCallback onChooseGuide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final transactions = ref.watch(recentProvider);
    final sources = ref.watch(incomeSourcesProvider);
    final lent = ref.watch(lentProvider);
    final credits = ref.watch(creditsProvider);

    ref.listen(lentProvider, (_, next) {
      next.whenData(NotificationService.instance.remindDueLentMoney);
    });

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: ScreenHeader(
            'Sakto',
            subtitle: 'Your money, exactly where it stands',
            leading: IconButton(
              key: helpKey,
              tooltip: 'Choose a guide',
              onPressed: onChooseGuide,
              icon: const Icon(Icons.help_outline_rounded),
            ),
            action: IconButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
              icon: const Icon(Icons.settings_outlined),
            ),
          ),
        ),
        accounts.when(
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) =>
              SliverFillRemaining(child: Center(child: Text('$error'))),
          data: (items) {
            if (items.isEmpty) {
              return SliverFillRemaining(
                child: KeyedSubtree(
                  key: homeKey,
                  child: const EmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Start with an account',
                    message: 'Add your cash, e-wallet, or bank account first.',
                  ),
                ),
              );
            }
            final total = items.fold<double>(0, (sum, a) => sum + a.balance);
            final forecast = _forecast(
              total,
              sources.valueOrNull ?? [],
              lent.valueOrNull ?? [],
              credits.valueOrNull ?? [],
            );
            return SliverList.list(
              children: [
                KeyedSubtree(
                  key: homeKey,
                  child: Column(
                    children: [
                      _BalanceDonut(accounts: items, total: total),
                      _ForecastCard(data: forecast),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: Text(
                    'Recent transactions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                transactions.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Text('$error'),
                  data: (rows) => rows.isEmpty
                      ? const EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No transactions yet',
                          message:
                              'Tap + to record your first expense or income.',
                        )
                      : _TransactionList(rows: rows.take(8).toList()),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _BalanceDonut extends StatefulWidget {
  const _BalanceDonut({required this.accounts, required this.total});
  final List<Account> accounts;
  final double total;

  @override
  State<_BalanceDonut> createState() => _BalanceDonutState();
}

class _BalanceDonutState extends State<_BalanceDonut> {
  int? selected;

  @override
  Widget build(BuildContext context) {
    final positiveTotal = widget.accounts.fold<double>(
      0,
      (sum, a) => sum + max(0, a.balance),
    );
    final focused = selected == null ? null : widget.accounts[selected!];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          SizedBox(
            width: 210,
            height: 210,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    centerSpaceRadius: 68,
                    sectionsSpace: 2,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        final index =
                            response?.touchedSection?.touchedSectionIndex;
                        if (index != null && index >= 0) {
                          setState(() => selected = index);
                        }
                      },
                    ),
                    sections: widget.accounts.map((account) {
                      final value = max<double>(0, account.balance);
                      return PieChartSectionData(
                        value: positiveTotal == 0 ? 1 : value,
                        color: hexColor(account.color),
                        radius: 25,
                        showTitle: false,
                      );
                    }).toList(),
                  ),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      focused?.name ?? 'Total balance',
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      money.format(focused?.balance ?? widget.total),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...widget.accounts.indexed.map((pair) {
            final (index, account) = pair;
            final percent = widget.total == 0
                ? 0
                : account.balance / widget.total * 100;
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => selected = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: selected == index
                      ? context.sakto.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected == index
                        ? context.sakto.border
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hexColor(account.color),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(account.name)),
                    Text(
                      money.format(account.balance),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 38,
                      child: Text(
                        '${percent.toStringAsFixed(0)}%',
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class ForecastData {
  const ForecastData(this.current, this.income, this.bills, this.end);
  final double current;
  final double income;
  final double bills;
  final double end;
}

ForecastData _forecast(
  double current,
  List<IncomeSource> sources,
  List<LentMoneyData> lent,
  List<CreditSummary> credits,
) {
  final now = DateTime.now();
  final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  var expected = 0.0;
  for (final source in sources.where((s) => s.active)) {
    if (source.frequency == 'monthly' && source.payDayOfMonth != null) {
      final day = min(source.payDayOfMonth!, monthEnd.day);
      if (DateTime(now.year, now.month, day).isAfter(now)) {
        expected += source.amount;
      }
    } else {
      var cursor = DateTime(now.year, now.month, now.day + 1);
      while (!cursor.isAfter(monthEnd)) {
        if (cursor.weekday % 7 == (source.payWeekday ?? 0)) {
          expected += source.amount;
          if (source.frequency == 'biweekly') {
            cursor = cursor.add(const Duration(days: 7));
          }
        }
        cursor = cursor.add(const Duration(days: 1));
      }
    }
  }
  expected += lent
      .where(
        (l) =>
            l.status == 'unpaid' &&
            l.expectedReturnDate.isAfter(now) &&
            !l.expectedReturnDate.isAfter(monthEnd),
      )
      .fold<double>(0, (sum, l) => sum + l.amount);
  final inSevenDays = now.add(const Duration(days: 7));
  final bills = credits
      .where((c) {
        if (c.credit.status != 'active') return false;
        final due = DateTime(now.year, now.month, c.credit.dueDay);
        return !due.isBefore(now) && !due.isAfter(inSevenDays);
      })
      .fold<double>(0, (sum, c) => sum + c.credit.monthlyPayment);
  return ForecastData(current, expected, bills, current + expected - bills);
}

class _ForecastCard extends StatefulWidget {
  const _ForecastCard({required this.data});
  final ForecastData data;

  @override
  State<_ForecastCard> createState() => _ForecastCardState();
}

class _ForecastCardState extends State<_ForecastCard> {
  bool includeBills = true;

  @override
  Widget build(BuildContext context) {
    final projected =
        widget.data.current +
        widget.data.income -
        (includeBills ? widget.data.bills : 0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${DateFormat.MMMM().format(DateTime.now())} forecast',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Switch(
                    value: includeBills,
                    onChanged: (value) => setState(() => includeBills = value),
                  ),
                ],
              ),
              Text(
                includeBills
                    ? 'Known bills due in the next 7 days are included'
                    : 'Upcoming bills are excluded',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _ForecastMetric('Current', widget.data.current),
                  _ForecastMetric(
                    'Income est.',
                    widget.data.income,
                    color: AppColors.green,
                  ),
                  _ForecastMetric(
                    'Month end',
                    projected,
                    color: context.sakto.accent,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForecastMetric extends StatelessWidget {
  const _ForecastMetric(this.label, this.value, {this.color});
  final String label;
  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        FittedBox(
          child: Text(
            money.format(value),
            style: TextStyle(
              color: color ?? context.sakto.text,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
      ],
    ),
  );
}

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    return Column(
      children: [
        ScreenHeader(
          'Accounts',
          subtitle: 'Cash, banks, cards, and e-wallets',
          action: TextButton.icon(
            onPressed: () => _showAccountEditor(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ),
        Expanded(
          child: accounts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('$error')),
            data: (rows) {
              final total = rows.fold<double>(
                0,
                (sum, account) => sum + account.balance,
              );
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.sakto.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Net worth',
                          style: TextStyle(color: Colors.white70),
                        ),
                        Text(
                          money.format(total),
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (rows.isEmpty)
                    const EmptyState(
                      icon: Icons.wallet_outlined,
                      title: 'No accounts',
                      message: 'Add an account to start tracking money.',
                    ),
                  ...rows.map(
                    (account) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            backgroundColor: hexColor(
                              account.color,
                            ).withValues(alpha: .14),
                            foregroundColor: hexColor(account.color),
                            child: const Icon(Icons.account_balance_wallet),
                          ),
                          title: Text(
                            account.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(account.type),
                          trailing: Text(
                            money.format(account.balance),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          onTap: () => _showAccountEditor(
                            context,
                            ref,
                            account: account,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

Future<void> _showAccountEditor(
  BuildContext context,
  WidgetRef ref, {
  Account? account,
}) async {
  final name = TextEditingController(text: account?.name);
  final balance = TextEditingController(
    text: account?.balance.toStringAsFixed(2) ?? '',
  );
  var type = account?.type ?? 'cash';
  var color = account?.color ?? '#3B82F6';
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              account == null ? 'Add account' : 'Edit account',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Account name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Account type'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'ewallet', child: Text('E-wallet')),
                DropdownMenuItem(value: 'bank', child: Text('Bank')),
                DropdownMenuItem(value: 'card', child: Text('Card')),
              ],
              onChanged: (value) => type = value!,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: balance,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Current balance'),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              children: AppColors.accountPalette.map((item) {
                final hex = colorHex(item);
                return GestureDetector(
                  onTap: () => setSheetState(() => color = hex),
                  child: CircleAvatar(
                    radius: color == hex ? 17 : 14,
                    backgroundColor: item,
                    child: color == hex
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                final value = double.tryParse(balance.text) ?? 0;
                final database = ref.read(databaseProvider);
                if (account == null) {
                  await database.addAccount(
                    AccountsCompanion.insert(
                      name: name.text.trim(),
                      type: type,
                      balance: Value(value),
                      color: color,
                    ),
                  );
                } else {
                  await database.updateAccount(
                    account.copyWith(
                      name: name.text.trim(),
                      type: type,
                      balance: value,
                      color: color,
                    ),
                  );
                }
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
              child: const Text('Save account'),
            ),
            if (account != null)
              TextButton(
                onPressed: () async {
                  try {
                    await ref.read(databaseProvider).deleteAccount(account.id);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(
                        sheetContext,
                      ).showSnackBar(SnackBar(content: Text('$error')));
                    }
                  }
                },
                child: const Text(
                  'Delete account',
                  style: TextStyle(color: AppColors.red),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({this.existing, super.key});
  final MoneyTransaction? existing;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final amount = TextEditingController();
  final note = TextEditingController();
  String type = 'expense';
  int? accountId;
  int? categoryId;
  int? creditId;
  DateTime date = DateTime.now();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      amount.text = existing.amount.toStringAsFixed(2);
      note.text = existing.note;
      type = existing.type;
      accountId = existing.accountId;
      categoryId = existing.categoryId;
      creditId = existing.source == 'credit_payment' ? existing.linkedId : null;
      date = existing.date;
    }
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).valueOrNull ?? [];
    final categories = ref.watch(categoriesProvider(type)).valueOrNull ?? [];
    final credits = ref.watch(creditsProvider).valueOrNull ?? [];
    final selectedCategory = categories
        .where((category) => category.id == categoryId)
        .firstOrNull;
    final payingCredit = selectedCategory?.name == 'Pay credit';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Add transaction' : 'Edit transaction',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'expense',
                icon: Icon(Icons.remove),
                label: Text('Expense'),
              ),
              ButtonSegment(
                value: 'income',
                icon: Icon(Icons.add),
                label: Text('Income'),
              ),
            ],
            selected: {type},
            onSelectionChanged: (value) => setState(() {
              type = value.first;
              categoryId = null;
              creditId = null;
            }),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium,
            decoration: const InputDecoration(
              prefixText: '₱ ',
              hintText: '0.00',
              border: InputBorder.none,
              filled: false,
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<int>(
            initialValue: accountId,
            decoration: const InputDecoration(labelText: 'Account'),
            items: accounts
                .map(
                  (a) => DropdownMenuItem(
                    value: a.id,
                    child: Text('${a.name}  •  ${money.format(a.balance)}'),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => accountId = value),
          ),
          const SizedBox(height: 18),
          Text('Category', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories
                .map(
                  (category) => ChoiceChip(
                    selected: category.id == categoryId,
                    avatar: Icon(
                      _categoryIcon(category.icon),
                      size: 18,
                      color: hexColor(category.color),
                    ),
                    label: Text(category.name),
                    onSelected: (_) => setState(() => categoryId = category.id),
                  ),
                )
                .toList(),
          ),
          if (payingCredit) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: creditId,
              decoration: const InputDecoration(labelText: 'Credit to pay'),
              items: credits
                  .where((c) => c.credit.status == 'active')
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.credit.id,
                      child: Text(
                        '${c.credit.name} • ${money.format(c.remaining)} left',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  creditId = value;
                  final selected = credits.firstWhere(
                    (c) => c.credit.id == value,
                  );
                  amount.text = selected.credit.monthlyPayment.toStringAsFixed(
                    2,
                  );
                });
              },
            ),
          ],
          const SizedBox(height: 16),
          ListTile(
            shape: RoundedRectangleBorder(
              side: BorderSide(color: context.sakto.border),
              borderRadius: BorderRadius.circular(12),
            ),
            tileColor: context.sakto.surface,
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('Date'),
            trailing: Text(shortDate.format(date)),
            onTap: () async {
              final value = await showDatePicker(
                context: context,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                initialDate: date,
              );
              if (value != null) setState(() => date = value);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: note,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: saving || accounts.isEmpty ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: type == 'expense'
                  ? AppColors.red
                  : AppColors.green,
            ),
            child: Text(saving ? 'Saving…' : 'Save transaction'),
          ),
          if (widget.existing != null)
            TextButton(
              onPressed: saving ? null : _delete,
              child: const Text(
                'Delete transaction',
                style: TextStyle(color: AppColors.red),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await confirmDelete(
      context,
      'This reverses the amount on the account and removes the record.',
    );
    if (!confirmed) return;
    await ref.read(databaseProvider).deleteTransaction(existing.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    final value = double.tryParse(amount.text);
    if (value == null ||
        value <= 0 ||
        accountId == null ||
        categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter an amount, account, and category.'),
        ),
      );
      return;
    }
    setState(() => saving = true);
    final database = ref.read(databaseProvider);
    final payingCredit = creditId != null && type == 'expense';
    final existing = widget.existing;
    try {
      if (existing == null) {
        if (payingCredit) {
          await database.payCredit(
            creditId: creditId!,
            accountId: accountId!,
            amount: value,
            date: date,
            categoryId: categoryId,
          );
        } else {
          await database.addTransaction(
            accountId: accountId!,
            categoryId: categoryId,
            type: type,
            amount: value,
            date: date,
            note: note.text.trim(),
          );
        }
      } else {
        await database.updateTransaction(
          original: existing,
          accountId: accountId!,
          categoryId: categoryId,
          type: type,
          amount: value,
          date: date,
          note: note.text.trim(),
          source: payingCredit ? 'credit_payment' : 'manual',
          linkedId: payingCredit ? creditId : null,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}

IconData _categoryIcon(String key) => switch (key) {
  'restaurant' => Icons.restaurant,
  'directions_car' => Icons.directions_car,
  'shopping_cart' => Icons.shopping_cart,
  'medical_services' => Icons.medical_services,
  'receipt_long' => Icons.receipt_long,
  'movie' => Icons.movie,
  'credit_card' => Icons.credit_card,
  'payments' => Icons.payments,
  'storefront' => Icons.storefront,
  'redeem' => Icons.redeem,
  'add_circle' => Icons.add_circle,
  _ => Icons.more_horiz,
};

class _TransactionList extends StatelessWidget {
  const _TransactionList({required this.rows});
  final List<MoneyTransaction> rows;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      children: rows.indexed.map((pair) {
        final (index, row) = pair;
        return Column(
          children: [
            ListTile(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddTransactionScreen(existing: row),
                ),
              ),
              leading: CircleAvatar(
                backgroundColor: row.type == 'income'
                    ? AppColors.greenLight
                    : AppColors.redLight,
                foregroundColor: row.type == 'income'
                    ? AppColors.green
                    : AppColors.red,
                child: Icon(
                  row.type == 'income'
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                ),
              ),
              title: Text(row.note.isEmpty ? row.type : row.note),
              subtitle: Text('${shortDate.format(row.date)}  •  tap to edit'),
              trailing: Text(
                '${row.type == 'income' ? '+' : '−'}${money.format(row.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: row.type == 'income'
                      ? AppColors.green
                      : context.sakto.text,
                ),
              ),
            ),
            if (index != rows.length - 1) const Divider(height: 1, indent: 72),
          ],
        );
      }).toList(),
    ),
  );
}

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String range = 'month';
  DateTime from = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime to = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final stream = ref
        .watch(databaseProvider)
        .watchTransactionsBetween(
          from,
          DateTime(to.year, to.month, to.day, 23, 59),
        );
    return Column(
      children: [
        const ScreenHeader('Reports', subtitle: 'Understand where money moved'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'week', label: Text('Week')),
              ButtonSegment(value: 'month', label: Text('Month')),
              ButtonSegment(value: 'custom', label: Text('Custom')),
            ],
            selected: {range},
            onSelectionChanged: (value) => _setRange(value.first),
          ),
        ),
        const SizedBox(height: 10),
        if (range == 'custom')
          TextButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range),
            label: Text('${shortDate.format(from)} – ${shortDate.format(to)}'),
          ),
        Expanded(
          child: StreamBuilder<List<MoneyTransaction>>(
            stream: stream,
            builder: (context, snapshot) {
              final rows = snapshot.data ?? [];
              final spent = rows
                  .where((r) => r.type == 'expense')
                  .fold<double>(0, (sum, r) => sum + r.amount);
              final added = rows
                  .where((r) => r.type == 'income')
                  .fold<double>(0, (sum, r) => sum + r.amount);
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  Row(
                    children: [
                      _ReportMetric('Spent', spent, AppColors.red),
                      const SizedBox(width: 8),
                      _ReportMetric('Added', added, AppColors.green),
                      const SizedBox(width: 8),
                      _ReportMetric('Net', added - spent, context.sakto.accent),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (rows.isEmpty)
                    const EmptyState(
                      icon: Icons.query_stats,
                      title: 'Nothing in this range',
                      message:
                          'Transactions in the selected dates appear here.',
                    )
                  else
                    _TransactionList(rows: rows),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _setRange(String value) {
    final now = DateTime.now();
    setState(() {
      range = value;
      if (value == 'week') {
        from = now.subtract(Duration(days: now.weekday - 1));
        to = now;
      } else if (value == 'month') {
        from = DateTime(now.year, now.month);
        to = now;
      }
    });
  }

  Future<void> _pickRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: from, end: to),
    );
    if (result != null) {
      setState(() {
        from = result.start;
        to = result.end;
      });
    }
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                money.format(value),
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({
    this.creditsKey,
    this.lentKey,
    this.incomeKey,
    this.settingsKey,
    super.key,
  });

  final GlobalKey? creditsKey;
  final GlobalKey? lentKey;
  final GlobalKey? incomeKey;
  final GlobalKey? settingsKey;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        creditsKey,
        'Credits',
        'Loans and installment purchases',
        Icons.credit_card,
        const CreditsScreen(),
      ),
      (
        lentKey,
        'Lent money',
        'Money others owe you',
        Icons.handshake_outlined,
        const LentMoneyScreen(),
      ),
      (
        incomeKey,
        'Income sources',
        'Recurring pay and forecasting',
        Icons.event_repeat,
        const IncomeSourcesScreen(),
      ),
      (
        settingsKey,
        'Settings',
        'Theme, background, notifications, and backup',
        Icons.settings_outlined,
        const SettingsScreen(),
      ),
    ];
    return Column(
      children: [
        const ScreenHeader('More', subtitle: 'Plan and manage the details'),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                key: item.$1,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: CircleAvatar(
                    backgroundColor: context.sakto.accentLight,
                    foregroundColor: context.sakto.accent,
                    child: Icon(item.$4),
                  ),
                  title: Text(
                    item.$2,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(item.$3),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => item.$5),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class CreditsScreen extends ConsumerWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credits = ref.watch(creditsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Credits'),
        actions: [
          IconButton(
            onPressed: () => _showCreditEditor(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: credits.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (rows) => rows.isEmpty
            ? const EmptyState(
                icon: Icons.credit_card_off_outlined,
                title: 'No credits',
                message: 'Add a loan or installment purchase to track it.',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final summary = rows[index];
                  final hasInterest = summary.interest > 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CreditDetailScreen(summary.credit.id),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      summary.credit.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                  _StatusBadge(
                                    hasInterest ? 'Interest' : 'No interest',
                                    hasInterest
                                        ? AppColors.red
                                        : AppColors.green,
                                  ),
                                  IconButton(
                                    tooltip: 'Edit credit',
                                    onPressed: () => _showCreditEditor(
                                      context,
                                      ref,
                                      credit: summary.credit,
                                    ),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              LinearProgressIndicator(
                                value: summary.progress,
                                minHeight: 7,
                                borderRadius: BorderRadius.circular(8),
                                backgroundColor: context.sakto.border,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${money.format(summary.remaining)} left',
                                  ),
                                  Text(
                                    summary.credit.status == 'completed'
                                        ? 'Completed'
                                        : 'Due day ${summary.credit.dueDay}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class CreditDetailScreen extends ConsumerWidget {
  const CreditDetailScreen(this.creditId, {super.key});
  final int creditId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref
        .watch(creditsProvider)
        .valueOrNull
        ?.where((item) => item.credit.id == creditId)
        .firstOrNull;
    if (summary == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Credit')),
        body: const Center(child: Text('This credit was deleted.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(summary.credit.name),
        actions: [
          IconButton(
            tooltip: 'Edit credit',
            onPressed: () =>
                _showCreditEditor(context, ref, credit: summary.credit),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete credit',
            onPressed: () async {
              final confirmed = await confirmDelete(
                context,
                'This removes the credit, reverses its cash-loan amount if any, and deletes linked payments.',
              );
              if (!confirmed) return;
              await ref.read(databaseProvider).deleteCredit(creditId);
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: StreamBuilder<List<CreditPayment>>(
        stream: ref.watch(databaseProvider).watchCreditPayments(creditId),
        builder: (context, snapshot) {
          final payments = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Text(
                        money.format(summary.remaining),
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const Text('remaining'),
                      const SizedBox(height: 14),
                      LinearProgressIndicator(
                        value: summary.progress,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Principal ${money.format(summary.credit.principalAmount)} • '
                        'Interest ${money.format(summary.interest)}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Payment history',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (payments.isEmpty)
                const Text(
                  'No payments recorded yet. Tap a payment later to edit it.',
                )
              else
                ...payments.map(
                  (payment) => ListTile(
                    onTap: () async {
                      final txn = await ref
                          .read(databaseProvider)
                          .getTransaction(payment.transactionId);
                      if (txn == null || !context.mounted) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AddTransactionScreen(existing: txn),
                        ),
                      );
                    },
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.greenLight,
                      foregroundColor: AppColors.green,
                      child: Icon(Icons.check),
                    ),
                    title: Text(money.format(payment.amount)),
                    subtitle: Text(
                      '${shortDate.format(payment.date)}  •  tap to edit',
                    ),
                    trailing: const Icon(Icons.edit_outlined, size: 18),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _showCreditEditor(
  BuildContext context,
  WidgetRef ref, {
  Credit? credit,
}) async {
  final name = TextEditingController(text: credit?.name);
  final principal = TextEditingController(
    text: credit?.principalAmount.toStringAsFixed(2),
  );
  final payment = TextEditingController(
    text: credit?.monthlyPayment.toStringAsFixed(2),
  );
  final months = TextEditingController(text: '${credit?.totalMonths ?? 12}');
  final dueDay = TextEditingController(text: '${credit?.dueDay ?? 15}');
  var type = credit?.creditType ?? 'item_purchase';
  int? accountId = credit?.accountId;
  final accounts = ref.read(accountsProvider).valueOrNull ?? [];
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              credit == null ? 'Add credit' : 'Edit credit',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'item_purchase',
                  label: Text('Item purchase'),
                ),
                ButtonSegment(value: 'cash_loan', label: Text('Cash loan')),
              ],
              selected: {type},
              onSelectionChanged: (value) =>
                  setSheetState(() => type = value.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: principal,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Principal amount'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: payment,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Monthly payment'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: months,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Months'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: dueDay,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Due day'),
                  ),
                ),
              ],
            ),
            if (type == 'cash_loan') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: accountId,
                decoration: const InputDecoration(labelText: 'Receive into'),
                items: accounts
                    .map(
                      (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                    )
                    .toList(),
                onChanged: (value) => accountId = value,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                final principalValue = double.tryParse(principal.text);
                final paymentValue = double.tryParse(payment.text);
                final monthValue = int.tryParse(months.text);
                final dayValue = int.tryParse(dueDay.text);
                if (name.text.trim().isEmpty ||
                    principalValue == null ||
                    paymentValue == null ||
                    monthValue == null ||
                    dayValue == null ||
                    (type == 'cash_loan' && accountId == null)) {
                  return;
                }
                final companion = credit == null
                    ? CreditsCompanion.insert(
                        name: name.text.trim(),
                        creditType: type,
                        principalAmount: principalValue,
                        accountId: Value(accountId),
                        monthlyPayment: paymentValue,
                        totalMonths: monthValue,
                        startDate: DateTime.now(),
                        dueDay: dayValue.clamp(1, 31),
                      )
                    : CreditsCompanion(
                        name: Value(name.text.trim()),
                        creditType: Value(type),
                        principalAmount: Value(principalValue),
                        accountId: Value(accountId),
                        monthlyPayment: Value(paymentValue),
                        totalMonths: Value(monthValue),
                        dueDay: Value(dayValue.clamp(1, 31)),
                      );
                if (credit == null) {
                  await ref.read(databaseProvider).addCredit(companion);
                } else {
                  await ref
                      .read(databaseProvider)
                      .updateCredit(credit, companion);
                }
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
              child: Text(credit == null ? 'Save credit' : 'Save changes'),
            ),
            if (credit != null)
              TextButton(
                onPressed: () async {
                  final confirmed = await confirmDelete(
                    sheetContext,
                    'This removes the credit and reverses related balances and payments.',
                  );
                  if (!confirmed) return;
                  await ref.read(databaseProvider).deleteCredit(credit.id);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                child: const Text(
                  'Delete credit',
                  style: TextStyle(color: AppColors.red),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class LentMoneyScreen extends ConsumerWidget {
  const LentMoneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lent = ref.watch(lentProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lent money'),
        actions: [
          IconButton(
            onPressed: () => _showLentEditor(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: lent.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (rows) {
          final unpaid = rows
              .where((r) => r.status == 'unpaid')
              .fold<double>(0, (sum, row) => sum + row.amount);
          final overdue = rows
              .where(
                (r) =>
                    r.status == 'unpaid' &&
                    r.expectedReturnDate.isBefore(DateTime.now()),
              )
              .fold<double>(0, (sum, row) => sum + row.amount);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  _ReportMetric('Owed to you', unpaid, context.sakto.accent),
                  const SizedBox(width: 10),
                  _ReportMetric('Overdue', overdue, AppColors.red),
                ],
              ),
              const SizedBox(height: 16),
              if (rows.isEmpty)
                const EmptyState(
                  icon: Icons.handshake_outlined,
                  title: 'No lent money',
                  message:
                      'Record money you lend and its expected return date.',
                ),
              ...rows.map((item) {
                final status = _lentStatus(item);
                final statusColor = switch (status) {
                  'Overdue' => AppColors.red,
                  'Due today' => AppColors.amber,
                  'Paid' => AppColors.green,
                  _ => AppColors.blue,
                };
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _showLentEditor(context, ref, item: item),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              child: Text(
                                item.borrowerName
                                    .split(' ')
                                    .take(2)
                                    .map((part) => part[0])
                                    .join(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.borrowerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Due ${shortDate.format(item.expectedReturnDate)}  •  tap to edit',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 5),
                                  _StatusBadge(status, statusColor),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  money.format(item.amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (item.status == 'unpaid')
                                  TextButton(
                                    onPressed: () =>
                                        _markPaid(context, ref, item),
                                    child: const Text('Mark paid'),
                                  )
                                else
                                  TextButton(
                                    onPressed: () => ref
                                        .read(databaseProvider)
                                        .unmarkLentPaid(item.id),
                                    child: const Text('Mark unpaid'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

String _lentStatus(LentMoneyData item) {
  if (item.status == 'paid') return 'Paid';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final due = DateTime(
    item.expectedReturnDate.year,
    item.expectedReturnDate.month,
    item.expectedReturnDate.day,
  );
  if (due.isBefore(today)) return 'Overdue';
  if (due == today) return 'Due today';
  return 'Upcoming';
}

Future<void> _markPaid(
  BuildContext context,
  WidgetRef ref,
  LentMoneyData item,
) async {
  final accounts = ref.read(accountsProvider).valueOrNull ?? [];
  var destination = item.accountId;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Mark as paid'),
        content: DropdownButtonFormField<int>(
          initialValue: destination,
          decoration: const InputDecoration(labelText: 'Paid into account'),
          items: accounts
              .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
              .toList(),
          onChanged: (value) => setState(() => destination = value!),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ),
  );
  if (confirmed == true) {
    await ref.read(databaseProvider).markLentPaid(item.id, destination);
    await NotificationService.instance.cancelLentReminder(item.id);
  }
}

Future<void> _showLentEditor(
  BuildContext context,
  WidgetRef ref, {
  LentMoneyData? item,
}) async {
  final borrower = TextEditingController(text: item?.borrowerName);
  final amount = TextEditingController(text: item?.amount.toStringAsFixed(2));
  final note = TextEditingController(text: item?.note);
  var accountId =
      item?.accountId ??
      ref.read(accountsProvider).valueOrNull?.firstOrNull?.id;
  var lentDate = item?.lentDate ?? DateTime.now();
  var returnDate =
      item?.expectedReturnDate ?? DateTime.now().add(const Duration(days: 7));
  final accounts = ref.read(accountsProvider).valueOrNull ?? [];
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: borrower,
              decoration: const InputDecoration(labelText: 'Borrower name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: accountId,
              decoration: const InputDecoration(labelText: 'Money leaves from'),
              items: accounts
                  .map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                  )
                  .toList(),
              onChanged: (value) => accountId = value,
            ),
            ListTile(
              title: const Text('Date lent'),
              trailing: Text(shortDate.format(lentDate)),
              onTap: () async {
                final value = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  initialDate: lentDate,
                );
                if (value != null) {
                  setSheetState(() => lentDate = value);
                }
              },
            ),
            ListTile(
              title: const Text('Expected return'),
              trailing: Text(shortDate.format(returnDate)),
              onTap: () async {
                final value = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  initialDate: returnDate,
                );
                if (value != null) {
                  setSheetState(() => returnDate = value);
                }
              },
            ),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                final value = double.tryParse(amount.text);
                if (borrower.text.trim().isEmpty ||
                    value == null ||
                    accountId == null) {
                  return;
                }
                final database = ref.read(databaseProvider);
                if (item == null) {
                  await database.addLentMoney(
                    LentMoneyCompanion.insert(
                      borrowerName: borrower.text.trim(),
                      amount: value,
                      accountId: accountId!,
                      lentDate: lentDate,
                      expectedReturnDate: returnDate,
                      note: Value(note.text.trim()),
                    ),
                  );
                } else {
                  await database.updateLentMoney(
                    item,
                    LentMoneyCompanion(
                      borrowerName: Value(borrower.text.trim()),
                      amount: Value(value),
                      accountId: Value(accountId!),
                      lentDate: Value(lentDate),
                      expectedReturnDate: Value(returnDate),
                      note: Value(note.text.trim()),
                    ),
                  );
                }
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
              child: Text(item == null ? 'Save lent money' : 'Save changes'),
            ),
            if (item != null)
              TextButton(
                onPressed: () async {
                  final confirmed = await confirmDelete(
                    sheetContext,
                    'This reverses the amount on the related account(s).',
                  );
                  if (!confirmed) return;
                  await ref.read(databaseProvider).deleteLentMoney(item.id);
                  await NotificationService.instance.cancelLentReminder(
                    item.id,
                  );
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                child: const Text(
                  'Delete lent money',
                  style: TextStyle(color: AppColors.red),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
    ),
  );
}

class IncomeSourcesScreen extends ConsumerWidget {
  const IncomeSourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(incomeSourcesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Income sources'),
        actions: [
          IconButton(
            onPressed: () => _showIncomeEditor(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: sources.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (rows) => rows.isEmpty
            ? const EmptyState(
                icon: Icons.event_repeat,
                title: 'No recurring income',
                message: 'Add salary or other recurring pay for forecasting.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final source = rows[index];
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      onTap: () =>
                          _showIncomeEditor(context, ref, source: source),
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.greenLight,
                        foregroundColor: AppColors.green,
                        child: Icon(Icons.payments_outlined),
                      ),
                      title: Text(
                        source.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('${source.frequency}  •  tap to edit'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            money.format(source.amount),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          GestureDetector(
                            onTap: () async {
                              final confirmed = await confirmDelete(
                                context,
                                'This removes the recurring income from forecasts.',
                              );
                              if (!confirmed) return;
                              await ref
                                  .read(databaseProvider)
                                  .deleteIncomeSource(source.id);
                            },
                            child: const Text(
                              'Remove',
                              style: TextStyle(
                                color: AppColors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

Future<void> _showIncomeEditor(
  BuildContext context,
  WidgetRef ref, {
  IncomeSource? source,
}) async {
  final name = TextEditingController(text: source?.name);
  final amount = TextEditingController(text: source?.amount.toStringAsFixed(2));
  var frequency = source?.frequency ?? 'monthly';
  var payDay = source?.payDayOfMonth ?? 15;
  var weekday = source?.payWeekday ?? DateTime.friday % 7;
  var accountId =
      source?.accountId ??
      ref.read(accountsProvider).valueOrNull?.firstOrNull?.id;
  final accounts = ref.read(accountsProvider).valueOrNull ?? [];
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Source name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount per pay'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: frequency,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: const [
                DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                DropdownMenuItem(value: 'biweekly', child: Text('Biweekly')),
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
              ],
              onChanged: (value) => setSheetState(() => frequency = value!),
            ),
            const SizedBox(height: 12),
            if (frequency == 'monthly')
              DropdownButtonFormField<int>(
                initialValue: payDay,
                decoration: const InputDecoration(labelText: 'Pay day'),
                items: List.generate(
                  31,
                  (i) =>
                      DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
                ),
                onChanged: (value) => payDay = value!,
              )
            else
              DropdownButtonFormField<int>(
                initialValue: weekday,
                decoration: const InputDecoration(labelText: 'Pay weekday'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Monday')),
                  DropdownMenuItem(value: 2, child: Text('Tuesday')),
                  DropdownMenuItem(value: 3, child: Text('Wednesday')),
                  DropdownMenuItem(value: 4, child: Text('Thursday')),
                  DropdownMenuItem(value: 5, child: Text('Friday')),
                  DropdownMenuItem(value: 6, child: Text('Saturday')),
                  DropdownMenuItem(value: 0, child: Text('Sunday')),
                ],
                onChanged: (value) => weekday = value!,
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: accountId,
              decoration: const InputDecoration(
                labelText: 'Destination account',
              ),
              items: accounts
                  .map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                  )
                  .toList(),
              onChanged: (value) => accountId = value,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                final value = double.tryParse(amount.text);
                if (name.text.trim().isEmpty ||
                    value == null ||
                    accountId == null) {
                  return;
                }
                final database = ref.read(databaseProvider);
                if (source == null) {
                  await database.addIncomeSource(
                    IncomeSourcesCompanion.insert(
                      name: name.text.trim(),
                      amount: value,
                      frequency: frequency,
                      payWeekday: Value(
                        frequency == 'monthly' ? null : weekday,
                      ),
                      payDayOfMonth: Value(
                        frequency == 'monthly' ? payDay : null,
                      ),
                      accountId: accountId!,
                      startDate: DateTime.now(),
                    ),
                  );
                } else {
                  await database.updateIncomeSource(
                    source.copyWith(
                      name: name.text.trim(),
                      amount: value,
                      frequency: frequency,
                      payWeekday: Value(
                        frequency == 'monthly' ? null : weekday,
                      ),
                      payDayOfMonth: Value(
                        frequency == 'monthly' ? payDay : null,
                      ),
                      accountId: accountId!,
                    ),
                  );
                }
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
              child: Text(
                source == null ? 'Save income source' : 'Save changes',
              ),
            ),
            if (source != null)
              TextButton(
                onPressed: () async {
                  final confirmed = await confirmDelete(
                    sheetContext,
                    'This removes the recurring income from forecasts.',
                  );
                  if (!confirmed) return;
                  await ref
                      .read(databaseProvider)
                      .deleteIncomeSource(source.id);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                child: const Text(
                  'Delete income source',
                  style: TextStyle(color: AppColors.red),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final colors = appearance.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Look and feel', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Color theme'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: themePresets.map((preset) {
                      final selected =
                          appearance.presetId == preset.id &&
                          appearance.backgroundHex == null &&
                          appearance.accentHex == null;
                      return ChoiceChip(
                        selected: selected,
                        label: Text(preset.name),
                        avatar: CircleAvatar(
                          backgroundColor: preset.colors.accent,
                        ),
                        onSelected: (_) => ref
                            .read(appearanceProvider.notifier)
                            .setPreset(preset.id),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  _ColorRow(
                    label: 'Background',
                    color: colors.background,
                    onPick: (color) => ref
                        .read(appearanceProvider.notifier)
                        .setColor(backgroundHex: colorHex(color)),
                  ),
                  _ColorRow(
                    label: 'Cards',
                    color: colors.surface,
                    onPick: (color) => ref
                        .read(appearanceProvider.notifier)
                        .setColor(surfaceHex: colorHex(color)),
                  ),
                  _ColorRow(
                    label: 'Accent',
                    color: colors.accent,
                    onPick: (color) => ref
                        .read(appearanceProvider.notifier)
                        .setColor(accentHex: colorHex(color)),
                  ),
                  _ColorRow(
                    label: 'Text',
                    color: colors.text,
                    onPick: (color) => ref
                        .read(appearanceProvider.notifier)
                        .setColor(textHex: colorHex(color)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('Background picture'),
                  subtitle: Text(
                    appearance.hasImage
                        ? 'Custom photo is in use'
                        : 'Choose any photo from your gallery',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => ref
                      .read(appearanceProvider.notifier)
                      .pickBackgroundImage(),
                ),
                if (appearance.hasImage) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Photo dim',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Slider(
                          value: appearance.imageDim,
                          min: 0,
                          max: 0.8,
                          onChanged: (value) => ref
                              .read(appearanceProvider.notifier)
                              .setImageDim(value),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.hide_image_outlined),
                    title: const Text('Remove background picture'),
                    onTap: () => ref
                        .read(appearanceProvider.notifier)
                        .clearBackgroundImage(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded),
                  title: const Text('App guides'),
                  subtitle: const Text(
                    'Replay everything, Lent money, or Income sources',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final guide = await showTourGuidePicker(context);
                    if (guide == null) return;
                    ref.read(tourRequestProvider.notifier).state =
                        TourRequest(guide);
                  },
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.currency_exchange),
                  title: Text('Currency'),
                  subtitle: Text('Philippine peso (₱ PHP)'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Lent money reminders'),
                  subtitle: const Text('Daily reminders when due or overdue'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final result = await NotificationService.instance
                        .requestPermission();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result == false
                                ? 'Notification permission was not granted.'
                                : 'Notifications are enabled.',
                          ),
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: const Text('Export backup'),
                  subtitle: const Text('Save all data as a JSON file'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final path = await BackupService.exportJson(
                      ref.read(databaseProvider),
                    );
                    if (context.mounted) {
                      showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Backup created'),
                          content: SelectableText(path),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Done'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'All Sakto data stays in the local database on this device. '
            'Keep exports somewhere safe before uninstalling the app.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.label,
    required this.color,
    required this.onPick,
  });

  final String label;
  final Color color;
  final ValueChanged<Color> onPick;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: GestureDetector(
      onTap: () async {
        var next = color;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Choose $label color'),
            content: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: color,
                onColorChanged: (value) => next = value,
                enableAlpha: false,
                labelTypes: const [],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Apply'),
              ),
            ],
          ),
        );
        if (confirmed == true) onPick(next);
      },
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: context.sakto.border),
        ),
      ),
    ),
  );
}
