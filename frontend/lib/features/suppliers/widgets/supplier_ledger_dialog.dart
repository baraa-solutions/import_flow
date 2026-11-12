// Vendor Statement of Account, 30/60/90 Aging & Credit Limit (Trello GzFff0Pc).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_format.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../models/supplier_ledger_model.dart';
import '../providers/supplier_ledger_provider.dart';

void showSupplierLedgerDialog(BuildContext context, {required int supplierId, required String supplierName}) {
  showDialog(
    context: context,
    builder: (_) => SupplierLedgerDialog(supplierId: supplierId, supplierName: supplierName),
  );
}

class SupplierLedgerDialog extends ConsumerStatefulWidget {
  final int supplierId;
  final String supplierName;

  const SupplierLedgerDialog({super.key, required this.supplierId, required this.supplierName});

  @override
  ConsumerState<SupplierLedgerDialog> createState() => _SupplierLedgerDialogState();
}

class _SupplierLedgerDialogState extends ConsumerState<SupplierLedgerDialog> {
  @override
  void initState() {
    super.initState();
    // Live load on open: never show a cached statement.
    ref.read(supplierLedgerActionsProvider).invalidateSupplier(widget.supplierId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final size = MediaQuery.of(context).size;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: size.width * 0.9 > 1200 ? 1200 : size.width * 0.9,
        height: size.height * 0.85,
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.cobalt),
                title: Text(l10n.supplierLedgerTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(widget.supplierName),
                trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ),
              TabBar(
                labelColor: AppTheme.cobalt,
                unselectedLabelColor: AppTheme.charcoal,
                tabs: [
                  Tab(text: l10n.supplierLedgerTabStatement),
                  Tab(text: l10n.supplierLedgerTabAging),
                  Tab(text: l10n.supplierLedgerTabCredit),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _StatementTab(supplierId: widget.supplierId),
                    _AgingTab(supplierId: widget.supplierId),
                    _CreditTab(supplierId: widget.supplierId),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _errorView(BuildContext context, Object error, VoidCallback onRetry) {
  final l10n = context.l10n;
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: AppTheme.crimson, size: 40),
        const SizedBox(height: 8),
        Text(ApiErrorText.of(l10n, error), style: const TextStyle(color: AppTheme.crimson)),
        const SizedBox(height: 8),
        ElevatedButton(onPressed: onRetry, child: Text(l10n.retryConnectionBtn)),
      ],
    ),
  );
}

String _money(num? v, String ccy) => AppFormat.money(v, currency: ccy);

// ── Statement ───────────────────────────────────────────────────────────────────

class _StatementTab extends ConsumerStatefulWidget {
  final int supplierId;

  const _StatementTab({required this.supplierId});

  @override
  ConsumerState<_StatementTab> createState() => _StatementTabState();
}

class _StatementTabState extends ConsumerState<_StatementTab> {
  String _currency = '';
  final Set<String> _knownCurrencies = {};
  bool _syncing = false;

  Future<void> _sync() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _syncing = true);
    try {
      await ref.read(supplierLedgerActionsProvider).syncLedger(widget.supplierId);
      messenger.showSnackBar(SnackBar(content: Text(l10n.supplierLedgerSynced), backgroundColor: AppTheme.emerald));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ApiErrorText.of(l10n, e)), backgroundColor: AppTheme.crimson));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = (supplierId: widget.supplierId, currency: _currency.isEmpty ? null : _currency);
    final async = ref.watch(supplierStatementProvider(query));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _errorView(context, e, () => ref.invalidate(supplierStatementProvider(query))),
      data: (st) {
        if (_currency.isEmpty) _knownCurrencies.addAll(st.currencies);
        final items = <SearchableDropdownItem<String>>[
          SearchableDropdownItem(value: '', label: l10n.supplierLedgerAllCurrencies),
          ...(_knownCurrencies.toList()..sort()).map((c) => SearchableDropdownItem(value: c, label: c)),
        ];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                SizedBox(
                  width: 220,
                  child: SearchableDropdownField<String>(
                    value: _currency,
                    items: items,
                    labelText: l10n.supplierLedgerCurrencyFilter,
                    onChanged: (v) => setState(() => _currency = v ?? ''),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _syncing ? null : _sync,
                  icon: _syncing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync),
                  label: Text(l10n.supplierLedgerRefresh),
                ),
              ],
            ),
            for (final w in st.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l10n.supplierLedgerWarningNotValued(w.importFileCode ?? '${w.importFileId ?? ''}'),
                    style: const TextStyle(color: AppTheme.orange)),
              ),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: st.balances.map((b) => _BalanceCard(balance: b)).toList()),
            const SizedBox(height: 16),
            if (st.statements.isEmpty) Center(child: Text(l10n.supplierLedgerEmpty)),
            for (final s in st.statements) _StatementTable(statement: s),
          ],
        );
      },
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final SupplierCurrencyBalance balance;

  const _BalanceCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final b = balance;
    final color = b.isAdvance ? AppTheme.emerald : (b.balanceFx > 0 ? AppTheme.crimson : AppTheme.charcoal);
    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
        color: color.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${l10n.supplierLedgerColBalance} (${b.currency})', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(_money(b.balanceFx, b.currency),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text('${l10n.supplierLedgerColBalanceEgp}: ${_money(b.bookBalanceEgp, 'EGP')}'),
          Text('${l10n.supplierLedgerBalanceEgpNow}: '
              '${b.currentBalanceEgp == null ? l10n.supplierLedgerRateMissing : _money(b.currentBalanceEgp, 'EGP')}'),
          if (b.openCommitmentsFx > 0)
            Text('${l10n.supplierLedgerOpenCommitments}: ${_money(b.openCommitmentsFx, b.currency)}'),
          if (b.unappliedFx > 0) Text('${l10n.supplierLedgerAdvance}: ${_money(b.unappliedFx, b.currency)}'),
        ],
      ),
    );
  }
}

class _StatementTable extends StatelessWidget {
  final SupplierCurrencyStatement statement;

  const _StatementTable({required this.statement});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ccy = statement.currency;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppTheme.cloudWhite),
          columns: [
            DataColumn(label: Text(l10n.supplierLedgerColDate)),
            DataColumn(label: Text(l10n.supplierLedgerColType)),
            DataColumn(label: Text(l10n.supplierLedgerColReference)),
            DataColumn(label: Text(l10n.supplierLedgerColDue)),
            DataColumn(label: Text('${l10n.supplierLedgerColCredit} $ccy'), numeric: true),
            DataColumn(label: Text('${l10n.supplierLedgerColDebit} $ccy'), numeric: true),
            DataColumn(label: Text('${l10n.supplierLedgerColBalance} $ccy'), numeric: true),
            DataColumn(label: Text(l10n.supplierLedgerColBalanceEgp), numeric: true),
            DataColumn(label: Text(l10n.supplierLedgerColStatus)),
          ],
          rows: statement.lines.map((ln) {
            final memoStyle = ln.isMemo ? const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic) : null;
            return DataRow(cells: [
              DataCell(Text(AppFormat.date(ln.entryDate))),
              DataCell(Text(l10n.supplierLedgerEntryTypeLabel(ln.entryType), style: memoStyle)),
              DataCell(SelectableText(ln.reference ?? ln.entryCode ?? '')),
              DataCell(Text(AppFormat.date(ln.dueDate))),
              DataCell(Text(ln.isMemo ? '(${AppFormat.number(ln.amountFx)})' : AppFormat.number(ln.creditFx), style: memoStyle)),
              DataCell(Text(AppFormat.number(ln.debitFx))),
              DataCell(Text(AppFormat.number(ln.balanceFx), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(AppFormat.number(ln.balanceEgp))),
              DataCell(Text(l10n.supplierLedgerStatusLabel(ln.status))),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

// ── Aging ───────────────────────────────────────────────────────────────────────

const _bucketOrder = ['CURRENT', '1_30', '31_60', '61_90', 'OVER_90'];

Color _bucketColor(String bucket) => switch (bucket) {
      'CURRENT' => AppTheme.emerald,
      '1_30' => AppTheme.cobalt,
      '31_60' => AppTheme.orange,
      _ => AppTheme.crimson,
    };

class _AgingTab extends ConsumerWidget {
  final int supplierId;

  const _AgingTab({required this.supplierId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ref.watch(supplierAgingProvider(supplierId)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _errorView(context, e, () => ref.invalidate(supplierAgingProvider(supplierId))),
          data: (aging) {
            if (aging.currencies.isEmpty) return Center(child: Text(l10n.supplierAgingNone));
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l10n.supplierAgingAsOf(AppFormat.date(aging.asOf)),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AppTheme.cloudWhite),
                    columns: [
                      DataColumn(label: Text(l10n.supplierLedgerCurrencyFilter)),
                      for (final b in _bucketOrder)
                        DataColumn(
                          label: Text(l10n.supplierAgingBucketLabel(b), style: TextStyle(color: _bucketColor(b))),
                          numeric: true,
                        ),
                      DataColumn(label: Text(l10n.supplierAgingTotalOpen), numeric: true),
                      DataColumn(label: Text(l10n.supplierLedgerBalanceEgpNow), numeric: true),
                    ],
                    rows: aging.currencies
                        .map((c) => DataRow(cells: [
                              DataCell(Text(c.currency, style: const TextStyle(fontWeight: FontWeight.bold))),
                              for (final b in _bucketOrder) DataCell(Text(AppFormat.number(c.buckets[b]))),
                              DataCell(Text(AppFormat.number(c.totalOpenFx),
                                  style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(c.totalOpenEgp == null
                                  ? l10n.supplierLedgerRateMissing
                                  : AppFormat.number(c.totalOpenEgp))),
                            ]))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                for (final c in aging.currencies)
                  for (final it in c.items)
                    ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 6,
                        backgroundColor: _bucketColor(it.bucket),
                      ),
                      title: Text('${it.reference ?? it.entryCode ?? ''} • ${_money(it.openAmountFx, c.currency)}'),
                      subtitle: Text('${l10n.supplierLedgerColDue}: ${AppFormat.date(it.dueDate)} • '
                          '${l10n.supplierAgingDaysPastDue}: ${it.daysPastDue}'),
                      trailing: Text(l10n.supplierAgingBucketLabel(it.bucket),
                          style: TextStyle(color: _bucketColor(it.bucket))),
                    ),
              ],
            );
          },
        );
  }
}

// ── Credit limit ────────────────────────────────────────────────────────────────

class _CreditTab extends ConsumerStatefulWidget {
  final int supplierId;

  const _CreditTab({required this.supplierId});

  @override
  ConsumerState<_CreditTab> createState() => _CreditTabState();
}

class _CreditTabState extends ConsumerState<_CreditTab> {
  final _formKey = GlobalKey<FormState>();
  final _limitCtrl = TextEditingController();
  String? _currency;
  String _policy = 'BLOCK';
  bool _initialized = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(currenciesProvider.notifier).fetchCurrencies(includeInactive: false);
    });
  }

  @override
  void dispose() {
    _limitCtrl.dispose();
    super.dispose();
  }

  void _initFrom(SupplierCreditStatus status) {
    if (_initialized) return;
    _initialized = true;
    _limitCtrl.text = status.credit.hasLimit ? status.credit.limitAmount.toStringAsFixed(2) : '0';
    _currency = status.credit.currency.isEmpty ? null : status.credit.currency;
    _policy = status.credit.policy;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(supplierLedgerActionsProvider).updateCreditLimit(
            widget.supplierId,
            creditLimit: double.parse(_limitCtrl.text.trim()),
            currency: _currency,
            policy: _policy,
          );
      _initialized = false;
      messenger.showSnackBar(SnackBar(content: Text(l10n.supplierCreditSaved), backgroundColor: AppTheme.emerald));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ApiErrorText.of(l10n, e)), backgroundColor: AppTheme.crimson));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currencies = ref.watch(currenciesProvider).valueOrNull ?? const [];
    return ref.watch(supplierCreditStatusProvider(widget.supplierId)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              _errorView(context, e, () => ref.invalidate(supplierCreditStatusProvider(widget.supplierId))),
          data: (status) {
            _initFrom(status);
            final c = status.credit;
            final ratio = c.utilizationRatio;
            final barColor = c.exceeded || (ratio ?? 0) >= 1 ? AppTheme.crimson : ((ratio ?? 0) >= 0.8 ? AppTheme.orange : AppTheme.emerald);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!c.hasLimit)
                  Text(l10n.supplierCreditNoLimit, style: const TextStyle(fontWeight: FontWeight.bold))
                else ...[
                  Text('${l10n.supplierCreditUtilization}: ${_money(c.utilizationAmount, c.currency)} / '
                      '${_money(c.limitAmount, c.currency)} (${AppFormat.percent(c.utilizationPct)})',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: ratio, minHeight: 10, color: barColor, backgroundColor: AppTheme.cloudWhite),
                  const SizedBox(height: 4),
                  Text('${l10n.supplierCreditAvailable}: ${_money(c.availableAmount, c.currency)}',
                      style: TextStyle(color: barColor)),
                ],
                const Divider(height: 32),
                Form(
                  key: _formKey,
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 220,
                        child: TextFormField(
                          controller: _limitCtrl,
                          decoration: InputDecoration(labelText: '${l10n.supplierCreditLimitLabel} *', isDense: true),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          validator: (v) {
                            final parsed = double.tryParse((v ?? '').trim());
                            return parsed == null || parsed < 0 ? l10n.supplierCreditLimitInvalid : null;
                          },
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: SearchableDropdownField<String>(
                          value: _currency,
                          labelText: l10n.supplierCreditLimitCurrency,
                          items: currencies
                              .map((cur) => SearchableDropdownItem(value: cur.currencyCode, label: cur.currencyCode))
                              .toList(),
                          onChanged: (v) => setState(() => _currency = v),
                        ),
                      ),
                      SizedBox(
                        width: 420,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.supplierCreditPolicyLabel),
                            const SizedBox(height: 6),
                            SegmentedButton<String>(
                              segments: [
                                ButtonSegment(value: 'BLOCK', label: Text(l10n.supplierCreditPolicyBlock)),
                                ButtonSegment(value: 'WARN', label: Text(l10n.supplierCreditPolicyWarn)),
                              ],
                              selected: {_policy},
                              onSelectionChanged: (s) => setState(() => _policy = s.first),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_outlined),
                        label: Text(l10n.supplierCreditSave),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 32),
                Text(l10n.supplierCreditOverridesTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (status.overrides.isEmpty) Text(l10n.supplierCreditNoOverrides),
                for (final o in status.overrides)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.admin_panel_settings_outlined, color: AppTheme.orange),
                    title: Text('${o.reference ?? o.context} • ${_money(o.requestedAmount, o.currency)}'),
                    subtitle: Text('${o.reason} — ${o.createdBy} • ${AppFormat.dateTime(o.createdAt)}'),
                    trailing: Text('${_money(o.projectedAmount, o.currency)} / ${_money(o.limitAmount, o.currency)}'),
                  ),
              ],
            );
          },
        );
  }
}
