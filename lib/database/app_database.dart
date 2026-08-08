import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  RealColumn get balance => real().withDefault(const Constant(0))();
  TextColumn get color => text()();
  TextColumn get icon => text().withDefault(const Constant('wallet'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get icon => text()();
  TextColumn get color => text()();
}

@TableIndex(name: 'transactions_date', columns: {#date})
class MoneyTransactions extends Table {
  @override
  String get tableName => 'transactions';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  TextColumn get type => text()();
  RealColumn get amount => real()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get date => dateTime()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  IntColumn get linkedId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Transfers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get fromAccountId => integer().references(Accounts, #id)();
  IntColumn get toAccountId => integer().references(Accounts, #id)();
  RealColumn get amount => real()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get date => dateTime()();
}

class Credits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get creditType => text()();
  RealColumn get principalAmount => real()();
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();
  RealColumn get monthlyPayment => real()();
  IntColumn get totalMonths => integer()();
  DateTimeColumn get startDate => dateTime()();
  IntColumn get dueDay => integer()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class CreditPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get creditId => integer().references(Credits, #id)();
  IntColumn get transactionId => integer().references(MoneyTransactions, #id)();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
}

class LentMoney extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get borrowerName => text()();
  RealColumn get amount => real()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  DateTimeColumn get lentDate => dateTime()();
  DateTimeColumn get expectedReturnDate => dateTime()();
  TextColumn get status => text().withDefault(const Constant('unpaid'))();
  DateTimeColumn get paidDate => dateTime().nullable()();
  IntColumn get paidToAccountId =>
      integer().nullable().references(Accounts, #id)();
  TextColumn get note => text().withDefault(const Constant(''))();
}

class IncomeSources extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get amount => real()();
  TextColumn get frequency => text()();
  IntColumn get payWeekday => integer().nullable()();
  IntColumn get payDayOfMonth => integer().nullable()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  DateTimeColumn get startDate => dateTime()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

class CreditSummary {
  const CreditSummary(this.credit, this.paid);
  final Credit credit;
  final double paid;

  double get totalPayable => credit.monthlyPayment * credit.totalMonths;
  double get remaining => max(0, totalPayable - paid);
  double get progress =>
      totalPayable == 0 ? 1 : (paid / totalPayable).clamp(0, 1);
  double get interest => max(0, totalPayable - credit.principalAmount);
}

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    MoneyTransactions,
    Transfers,
    Credits,
    CreditPayments,
    LentMoney,
    IncomeSources,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'sakto'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedCategories();
    },
  );

  Future<void> _seedCategories() async {
    const defaults = [
      ('Food', 'expense', 'restaurant', '#F97316'),
      ('Transport', 'expense', 'directions_car', '#3B82F6'),
      ('Grocery', 'expense', 'shopping_cart', '#0E9E94'),
      ('Health', 'expense', 'medical_services', '#DC2626'),
      ('Bills', 'expense', 'receipt_long', '#D97706'),
      ('Leisure', 'expense', 'movie', '#9333EA'),
      ('Pay credit', 'expense', 'credit_card', '#DC2626'),
      ('Other', 'expense', 'more_horiz', '#8C8C96'),
      ('Salary', 'income', 'payments', '#16A34A'),
      ('Business', 'income', 'storefront', '#0E9E94'),
      ('Gift', 'income', 'redeem', '#EC4899'),
      ('Other income', 'income', 'add_circle', '#3B82F6'),
    ];
    await batch((b) {
      b.insertAll(
        categories,
        defaults
            .map(
              (c) => CategoriesCompanion.insert(
                name: c.$1,
                type: c.$2,
                icon: c.$3,
                color: c.$4,
              ),
            )
            .toList(),
      );
    });
  }

  Stream<List<Account>> watchAccounts() => (select(
    accounts,
  )..orderBy([(a) => OrderingTerm.asc(a.createdAt)])).watch();

  Stream<List<Category>> watchCategories(String kind) =>
      (select(categories)..where((c) => c.type.equals(kind))).watch();

  Stream<List<MoneyTransaction>> watchRecentTransactions([int limit = 20]) =>
      (select(moneyTransactions)
            ..orderBy([(t) => OrderingTerm.desc(t.date)])
            ..limit(limit))
          .watch();

  Stream<List<MoneyTransaction>> watchTransactionsBetween(
    DateTime from,
    DateTime to,
  ) =>
      (select(moneyTransactions)
            ..where((t) => t.date.isBetweenValues(from, to))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .watch();

  Future<int> addAccount(AccountsCompanion account) =>
      into(accounts).insert(account);

  Future<void> updateAccount(Account account) =>
      update(accounts).replace(account);

  Future<void> deleteAccount(int id) => transaction(() async {
    final count = await (select(
      moneyTransactions,
    )..where((t) => t.accountId.equals(id))).get().then((rows) => rows.length);
    if (count > 0) {
      throw StateError('This account has transactions and cannot be deleted.');
    }
    await (delete(accounts)..where((a) => a.id.equals(id))).go();
  });

  Future<int> addTransaction({
    required int accountId,
    required int? categoryId,
    required String type,
    required double amount,
    required DateTime date,
    String note = '',
    String source = 'manual',
    int? linkedId,
  }) => transaction(() async {
    final account = await (select(
      accounts,
    )..where((a) => a.id.equals(accountId))).getSingle();
    final delta = type == 'expense' ? -amount : amount;
    await (update(accounts)..where((a) => a.id.equals(account.id))).write(
      AccountsCompanion(balance: Value(account.balance + delta)),
    );
    return into(moneyTransactions).insert(
      MoneyTransactionsCompanion.insert(
        accountId: accountId,
        categoryId: Value(categoryId),
        type: type,
        amount: amount,
        note: Value(note),
        date: date,
        source: Value(source),
        linkedId: Value(linkedId),
      ),
    );
  });

  Future<int> addCredit(CreditsCompanion credit) => transaction(() async {
    final id = await into(credits).insert(credit);
    if (credit.creditType.value == 'cash_loan' && credit.accountId.present) {
      final account = await (select(
        accounts,
      )..where((a) => a.id.equals(credit.accountId.value!))).getSingle();
      await (update(accounts)..where((a) => a.id.equals(account.id))).write(
        AccountsCompanion(
          balance: Value(account.balance + credit.principalAmount.value),
        ),
      );
    }
    return id;
  });

  Stream<List<CreditSummary>> watchCreditSummaries() {
    final paid = creditPayments.amount.sum();
    final query =
        select(credits).join([
            leftOuterJoin(
              creditPayments,
              creditPayments.creditId.equalsExp(credits.id),
              useColumns: false,
            ),
          ])
          ..addColumns([paid])
          ..groupBy([credits.id])
          ..orderBy([OrderingTerm.asc(credits.status)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => CreditSummary(row.readTable(credits), row.read(paid) ?? 0),
          )
          .toList(),
    );
  }

  Stream<List<CreditPayment>> watchCreditPayments(int creditId) =>
      (select(creditPayments)
            ..where((p) => p.creditId.equals(creditId))
            ..orderBy([(p) => OrderingTerm.desc(p.date)]))
          .watch();

  Future<void> payCredit({
    required int creditId,
    required int accountId,
    required double amount,
    required DateTime date,
    required int? categoryId,
  }) => transaction(() async {
    final transactionId = await addTransaction(
      accountId: accountId,
      categoryId: categoryId,
      type: 'expense',
      amount: amount,
      date: date,
      source: 'credit_payment',
      linkedId: creditId,
    );
    await into(creditPayments).insert(
      CreditPaymentsCompanion.insert(
        creditId: creditId,
        transactionId: transactionId,
        amount: amount,
        date: date,
      ),
    );
    final credit = await (select(
      credits,
    )..where((c) => c.id.equals(creditId))).getSingle();
    final totalPaid =
        await (selectOnly(creditPayments)
              ..addColumns([creditPayments.amount.sum()])
              ..where(creditPayments.creditId.equals(creditId)))
            .map((r) => r.read(creditPayments.amount.sum()) ?? 0)
            .getSingle();
    if (totalPaid >= credit.monthlyPayment * credit.totalMonths) {
      await (update(credits)..where((c) => c.id.equals(creditId))).write(
        const CreditsCompanion(status: Value('completed')),
      );
    }
  });

  Stream<List<LentMoneyData>> watchLentMoney() => (select(
    lentMoney,
  )..orderBy([(l) => OrderingTerm.asc(l.expectedReturnDate)])).watch();

  Future<int> addLentMoney(LentMoneyCompanion entry) => transaction(() async {
    final account = await (select(
      accounts,
    )..where((a) => a.id.equals(entry.accountId.value))).getSingle();
    await (update(accounts)..where((a) => a.id.equals(account.id))).write(
      AccountsCompanion(balance: Value(account.balance - entry.amount.value)),
    );
    return into(lentMoney).insert(entry);
  });

  Future<void> markLentPaid(int id, int destinationAccountId) =>
      transaction(() async {
        final item = await (select(
          lentMoney,
        )..where((l) => l.id.equals(id))).getSingle();
        if (item.status == 'paid') return;
        final account = await (select(
          accounts,
        )..where((a) => a.id.equals(destinationAccountId))).getSingle();
        await (update(accounts)..where((a) => a.id.equals(account.id))).write(
          AccountsCompanion(balance: Value(account.balance + item.amount)),
        );
        await (update(lentMoney)..where((l) => l.id.equals(id))).write(
          LentMoneyCompanion(
            status: const Value('paid'),
            paidDate: Value(DateTime.now()),
            paidToAccountId: Value(destinationAccountId),
          ),
        );
      });

  Stream<List<IncomeSource>> watchIncomeSources() =>
      select(incomeSources).watch();

  Future<int> addIncomeSource(IncomeSourcesCompanion source) =>
      into(incomeSources).insert(source);

  Future<void> deleteIncomeSource(int id) =>
      (delete(incomeSources)..where((s) => s.id.equals(id))).go();

  Future<void> deleteCredit(int id) => transaction(() async {
    final payments = await (select(
      creditPayments,
    )..where((p) => p.creditId.equals(id))).get();
    if (payments.isNotEmpty) {
      throw StateError('Credits with payments cannot be deleted.');
    }
    await (delete(credits)..where((c) => c.id.equals(id))).go();
  });

  Future<Map<String, Object?>> exportSnapshot() async => {
    'exportedAt': DateTime.now().toIso8601String(),
    'accounts': (await select(accounts).get()).map((e) => e.toJson()).toList(),
    'categories': (await select(
      categories,
    ).get()).map((e) => e.toJson()).toList(),
    'transactions': (await select(
      moneyTransactions,
    ).get()).map((e) => e.toJson()).toList(),
    'transfers': (await select(
      transfers,
    ).get()).map((e) => e.toJson()).toList(),
    'credits': (await select(credits).get()).map((e) => e.toJson()).toList(),
    'creditPayments': (await select(
      creditPayments,
    ).get()).map((e) => e.toJson()).toList(),
    'lentMoney': (await select(
      lentMoney,
    ).get()).map((e) => e.toJson()).toList(),
    'incomeSources': (await select(
      incomeSources,
    ).get()).map((e) => e.toJson()).toList(),
  };
}
