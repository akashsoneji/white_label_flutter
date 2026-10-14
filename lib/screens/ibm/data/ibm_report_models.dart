/// Typed models for the IB portal report endpoints:
/// `GET ibm/portal/client-funding`, `commission-report` and `payout-report`.
/// Field names follow ibm/IB_Manager_Portal_New_APIs.md §4.
library;

double _toDouble(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

int _toInt(dynamic v) =>
    v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

String _toStr(dynamic v) => v?.toString() ?? '';

List<Map<String, dynamic>> _mapList(dynamic v) => (v is List ? v : const [])
    .whereType<Map>()
    .map((e) => Map<String, dynamic>.from(e))
    .toList();

/// `{page, per_page, total, last_page}`
class IbmReportPagination {
  final int page;
  final int perPage;
  final int total;
  final int lastPage;

  const IbmReportPagination({
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  static const empty =
      IbmReportPagination(page: 1, perPage: 25, total: 0, lastPage: 1);

  bool get hasMore => page < lastPage;

  factory IbmReportPagination.fromJson(dynamic json) {
    final map = json is Map ? json : const {};
    final page = _toInt(map['page'] ?? map['current_page']);
    return IbmReportPagination(
      page: page < 1 ? 1 : page,
      perPage: _toInt(map['per_page']),
      total: _toInt(map['total']),
      lastPage: _toInt(map['last_page']),
    );
  }
}

// ─── Client funding (team deposits / withdrawals) ──────────────────────────

class IbmFundingRow {
  final String type;
  final String movedAt;
  final int clientUserId;
  final String clientName;
  final String clientEmail;
  final double amount;
  final String currency;
  final String status;

  const IbmFundingRow({
    required this.type,
    required this.movedAt,
    required this.clientUserId,
    required this.clientName,
    required this.clientEmail,
    required this.amount,
    required this.currency,
    required this.status,
  });

  bool get isDeposit => type.toLowerCase() == 'deposit';

  factory IbmFundingRow.fromJson(Map<String, dynamic> json) => IbmFundingRow(
        type: _toStr(json['type']),
        movedAt: _toStr(json['moved_at']),
        clientUserId: _toInt(json['client_user_id']),
        clientName: _toStr(json['client_name']),
        clientEmail: _toStr(json['client_email']),
        amount: _toDouble(json['amount']),
        currency: _toStr(json['currency']),
        status: _toStr(json['status']),
      );
}

class IbmFundingTotal {
  final String currency;
  final double deposit;
  final double withdrawal;

  const IbmFundingTotal({
    required this.currency,
    required this.deposit,
    required this.withdrawal,
  });
}

class IbmFundingReport {
  final List<IbmFundingRow> rows;
  final List<IbmFundingTotal> totals;
  final IbmReportPagination pagination;

  const IbmFundingReport({
    required this.rows,
    required this.totals,
    required this.pagination,
  });

  /// `totals` is keyed by currency: `{"USC": {"deposit": .., "withdrawal": ..}}`
  factory IbmFundingReport.fromJson(Map<String, dynamic> data) {
    final rawTotals = data['totals'];
    return IbmFundingReport(
      rows: _mapList(data['rows']).map(IbmFundingRow.fromJson).toList(),
      totals: rawTotals is Map
          ? [
              for (final entry in rawTotals.entries)
                if (entry.value is Map)
                  IbmFundingTotal(
                    currency: '${entry.key}',
                    deposit: _toDouble((entry.value as Map)['deposit']),
                    withdrawal: _toDouble((entry.value as Map)['withdrawal']),
                  ),
            ]
          : const [],
      pagination: IbmReportPagination.fromJson(data['pagination']),
    );
  }
}

// ─── Commission report ─────────────────────────────────────────────────────

class IbmCommissionTradeRow {
  final int id;
  final String mt5Account;
  final String date;
  final String order;
  final String symbol;
  final double price;
  final double profit;
  final double volume;
  final double commission;
  final String currency;
  final String type;

  const IbmCommissionTradeRow({
    required this.id,
    required this.mt5Account,
    required this.date,
    required this.order,
    required this.symbol,
    required this.price,
    required this.profit,
    required this.volume,
    required this.commission,
    required this.currency,
    required this.type,
  });

  bool get isBuy => type.toLowerCase() == 'buy';

  factory IbmCommissionTradeRow.fromJson(Map<String, dynamic> json) =>
      IbmCommissionTradeRow(
        id: _toInt(json['id']),
        mt5Account: _toStr(json['mt5_account']),
        date: _toStr(json['date']),
        order: _toStr(json['order']),
        symbol: _toStr(json['symbol']),
        // price / profit arrive as strings, volume / commission as numbers.
        price: _toDouble(json['price']),
        profit: _toDouble(json['profit']),
        volume: _toDouble(json['volume']),
        commission: _toDouble(json['commission']),
        currency: _toStr(json['currency']),
        type: _toStr(json['type']),
      );
}

class IbmCommissionAccountRow {
  final String mt5Account;
  final String currency;
  final int trades;
  final double lots;
  final double profit;
  final double commission;
  final String lastTrade;

  const IbmCommissionAccountRow({
    required this.mt5Account,
    required this.currency,
    required this.trades,
    required this.lots,
    required this.profit,
    required this.commission,
    required this.lastTrade,
  });

  factory IbmCommissionAccountRow.fromJson(Map<String, dynamic> json) =>
      IbmCommissionAccountRow(
        mt5Account: _toStr(json['mt5_account']),
        currency: _toStr(json['currency']),
        trades: _toInt(json['trades']),
        lots: _toDouble(json['lots']),
        profit: _toDouble(json['profit']),
        commission: _toDouble(json['commission']),
        lastTrade: _toStr(json['last_trade']),
      );
}

class IbmCommissionSummary {
  final String currency;
  final int trades;
  final int accounts;
  final double lots;
  final double commission;

  const IbmCommissionSummary({
    required this.currency,
    required this.trades,
    required this.accounts,
    required this.lots,
    required this.commission,
  });

  factory IbmCommissionSummary.fromJson(Map<String, dynamic> json) =>
      IbmCommissionSummary(
        currency: _toStr(json['currency']),
        trades: _toInt(json['trades']),
        accounts: _toInt(json['accounts']),
        lots: _toDouble(json['lots']),
        commission: _toDouble(json['commission']),
      );
}

class IbmCommissionReport {
  final String view;
  final List<IbmCommissionTradeRow> tradeRows;
  final List<IbmCommissionAccountRow> accountRows;
  final List<IbmCommissionSummary> summary;
  final List<String> accountOptions;
  final List<String> symbolOptions;
  final IbmReportPagination pagination;

  const IbmCommissionReport({
    required this.view,
    required this.tradeRows,
    required this.accountRows,
    required this.summary,
    required this.accountOptions,
    required this.symbolOptions,
    required this.pagination,
  });

  bool get isAccountView => view == 'account';

  factory IbmCommissionReport.fromJson(Map<String, dynamic> data) {
    final view = _toStr(data['view']);
    final rows = _mapList(data['rows']);
    final options = data['options'] is Map ? data['options'] as Map : const {};
    List<String> strings(dynamic v) =>
        (v is List ? v : const []).map((e) => '$e').toList();
    return IbmCommissionReport(
      view: view,
      tradeRows: view == 'account'
          ? const []
          : rows.map(IbmCommissionTradeRow.fromJson).toList(),
      accountRows: view == 'account'
          ? rows.map(IbmCommissionAccountRow.fromJson).toList()
          : const [],
      summary:
          _mapList(data['summary']).map(IbmCommissionSummary.fromJson).toList(),
      accountOptions: strings(options['accounts']),
      symbolOptions: strings(options['symbols']),
      pagination: IbmReportPagination.fromJson(data['pagination']),
    );
  }
}

// ─── Payout report (IB withdraw) ───────────────────────────────────────────

/// The dry run returned no payout rows, so the fields mirror the payout
/// entries already returned by `GET ibm/portal/wallet` (`payouts[]`).
class IbmPayoutRow {
  final int id;
  final double amount;
  final String currency;
  final String status;
  final String requestedAt;
  final String paidAt;
  final String method;

  const IbmPayoutRow({
    required this.id,
    required this.amount,
    required this.currency,
    required this.status,
    required this.requestedAt,
    required this.paidAt,
    required this.method,
  });

  factory IbmPayoutRow.fromJson(Map<String, dynamic> json) => IbmPayoutRow(
        id: _toInt(json['id']),
        amount: _toDouble(json['amount']),
        currency: _toStr(json['currency']),
        status: _toStr(json['status']),
        requestedAt: _toStr(json['requested_at'] ?? json['created_at']),
        paidAt: _toStr(json['paid_at']),
        method: _toStr(
          json['method'] ?? json['payment_method'] ?? json['method_name'],
        ),
      );
}

class IbmPayoutTotal {
  final String currency;
  final double amount;

  const IbmPayoutTotal({required this.currency, required this.amount});

  factory IbmPayoutTotal.fromJson(Map<String, dynamic> json) => IbmPayoutTotal(
        currency: _toStr(json['currency']),
        amount: _toDouble(json['amount'] ?? json['total']),
      );
}

class IbmPayoutReport {
  final List<IbmPayoutRow> rows;
  final List<IbmPayoutTotal> totals;
  final IbmReportPagination pagination;

  const IbmPayoutReport({
    required this.rows,
    required this.totals,
    required this.pagination,
  });

  factory IbmPayoutReport.fromJson(Map<String, dynamic> data) =>
      IbmPayoutReport(
        rows: _mapList(data['rows']).map(IbmPayoutRow.fromJson).toList(),
        totals: _mapList(data['totals']).map(IbmPayoutTotal.fromJson).toList(),
        pagination: IbmReportPagination.fromJson(data['pagination']),
      );
}
