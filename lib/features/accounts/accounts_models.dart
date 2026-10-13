/// Accounts data models — Flutter counterparts of the `AccountHead`, `SubHead`,
/// `TransactionType` and `AccountEntry` interfaces used by the web client's
/// `accounts/*` pages.
library;

double _toDouble(Object? v) => double.tryParse(v?.toString() ?? '') ?? 0;
String _toStr(Object? v) => v?.toString() ?? '';

/// Account types accepted by the Account Head form (`accountTypes` in
/// `accounts/account-head/page.tsx`).
const List<String> accountTypes = [
  'Assets Account',
  'Expense Account',
  'Revenue/Income Account',
  'Liabilities Account',
  'Equity Account',
];

/// Options offered by the Account Entry "Filter By" select.
const List<String> accountFilterByOptions = ['All', 'Add By', 'Edit By'];

/// `accounts/heads`.
class AccountHead {
  AccountHead({
    required this.id,
    required this.masterAccount,
    required this.accountType,
    this.description = '',
  });

  final String id;
  final String masterAccount;
  final String accountType;
  final String description;

  factory AccountHead.fromJson(Map<String, dynamic> j) => AccountHead(
    id: _toStr(j['id']),
    masterAccount: _toStr(j['masterAccount']),
    accountType: _toStr(j['accountType']),
    description: _toStr(j['description']),
  );
}

/// `accounts/sub-heads`.
class SubHead {
  SubHead({
    required this.id,
    required this.subMasterAccount,
    this.masterAccountId = '',
    this.masterAccount = '',
    this.accountType = '',
    this.budget = '',
    this.description = '',
  });

  final String id;
  final String subMasterAccount;
  final String masterAccountId;
  final String masterAccount;
  final String accountType;
  final String budget;
  final String description;

  factory SubHead.fromJson(Map<String, dynamic> j) => SubHead(
    id: _toStr(j['id']),
    subMasterAccount: _toStr(j['subMasterAccount']),
    masterAccountId: _toStr(j['masterAccountId']),
    masterAccount: _toStr(j['masterAccount']),
    accountType: _toStr(j['accountType']),
    budget: _toStr(j['budget']),
    description: _toStr(j['description']),
  );
}

/// `billing/transaction-types` (the subset the Accounts pages read).
class AccountTxnType {
  AccountTxnType({
    required this.id,
    required this.paymentChannel,
    this.transaction = '',
    this.openingBalance = 0,
  });

  final String id;
  final String paymentChannel;
  final String transaction;
  final double openingBalance;

  factory AccountTxnType.fromJson(Map<String, dynamic> j) => AccountTxnType(
    id: _toStr(j['id']),
    paymentChannel: _toStr(j['paymentChannel']),
    transaction: _toStr(j['transaction']),
    openingBalance: _toDouble(j['openingBalance']),
  );
}

/// `accounts/entries`.
class AccountEntry {
  AccountEntry({
    required this.id,
    this.head = '',
    this.subHead = '',
    this.description = '',
    this.date = '',
    this.addBy = '',
    this.editBy = '',
    this.amount = 0,
    this.transactionType = '',
    this.companyId = '',
  });

  final String id;
  final String head;
  final String subHead;
  final String description;
  final String date;
  final String addBy;
  final String editBy;
  final double amount;
  final String transactionType;
  final String companyId;

  factory AccountEntry.fromJson(Map<String, dynamic> j) => AccountEntry(
    id: _toStr(j['id']),
    head: _toStr(j['head']),
    subHead: _toStr(j['subHead']),
    description: _toStr(j['description']),
    date: _toStr(j['date']),
    addBy: _toStr(j['addBy']),
    editBy: _toStr(j['editBy']),
    amount: _toDouble(j['amount']),
    transactionType: _toStr(j['transactionType']),
    companyId: _toStr(j['companyId']),
  );
}
