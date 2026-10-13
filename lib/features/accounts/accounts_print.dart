import 'package:flutter/material.dart';

import '../sales/sales_common.dart';
import 'accounts_common.dart';
import 'accounts_models.dart';

String _esc(String v) => salesEscapeHtml(v);

String _logoUrl(SalesCompany c) =>
    c.logo.isNotEmpty ? accCompanyImageUrl('company_images', c.id) : '';

String _stampUrl(SalesCompany c) =>
    c.stamp.isNotEmpty ? accCompanyImageUrl('company_stamps', c.id) : '';

String _headName(List<AccountHead> heads, String id) {
  for (final h in heads) {
    if (h.id == id) return h.masterAccount.isEmpty ? id : h.masterAccount;
  }
  return id;
}

String _headType(List<AccountHead> heads, String id) {
  for (final h in heads) {
    if (h.id == id) return h.accountType;
  }
  return '';
}

String _subHeadName(List<SubHead> subs, String id) {
  for (final s in subs) {
    if (s.id == id) return s.subMasterAccount.isEmpty ? id : s.subMasterAccount;
  }
  return id;
}

String _txnName(List<AccountTxnType> types, String id) {
  for (final t in types) {
    if (t.id == id) return t.paymentChannel.isEmpty ? id : t.paymentChannel;
  }
  return id;
}

const String _accPrintStyle = '''
  @page { size: A4; margin: 15mm; }
  * { box-sizing: border-box; }
  body { margin:0; font-family:'Segoe UI',system-ui,-apple-system,sans-serif; color:#111827; background:#fff; }
  .container { max-width:860px; margin:0 auto; padding:32px; }
  header { display:flex; justify-content:space-between; align-items:flex-start; border-bottom:2px solid #111827; padding-bottom:24px; margin-bottom:28px; }
  .brand { display:flex; gap:16px; align-items:flex-start; }
  .brand img { width:60px; height:60px; object-fit:contain; }
  .brand .name { font-size:22px; font-weight:700; color:#111827; }
  .brand .meta { font-size:13px; color:#4b5563; margin-top:4px; line-height:1.5; }
  .doc { text-align:right; }
  .doc .title { font-size:32px; font-weight:800; letter-spacing:2px; }
  .doc .rid { font-size:13px; color:#6b7280; margin-top:10px; line-height:1.7; }
  .doc .rid span { color:#111827; font-weight:600; }
  table { width:100%; border-collapse:collapse; margin-bottom:12px; }
  th { padding:10px; font-size:11px; font-weight:600; text-transform:uppercase; letter-spacing:0.5px; border:1px solid #d1d5db; color:#fff; text-align:left; }
  td { padding:10px; font-size:13px; border:1px solid #d1d5db; }
  .right { text-align:right; }
  .center { text-align:center; }
  h3.group { font-size:16px; font-weight:700; background:#f3f4f6; padding:8px 12px; border-radius:6px; margin:22px 0 10px; }
  tfoot td { background:#f9fafb; font-weight:700; }
  .grand { margin-top:20px; text-align:right; }
  .grand .lbl { font-size:13px; color:#6b7280; }
  footer { margin-top:40px; border-top:1px solid #d1d5db; padding-top:24px; }
  .sigs { display:flex; justify-content:space-between; align-items:flex-end; margin-bottom:20px; }
  .sig { text-align:center; }
  .sig img { max-height:80px; max-width:180px; object-fit:contain; margin-bottom:5px; }
  .sig .line { border-bottom:1px solid #000; width:200px; margin-bottom:5px; }
  .sig .lbl { font-size:11px; color:#9ca3af; }
  .foot-text { text-align:center; color:#6b7280; margin-top:20px; }
  .foot-text .co { font-size:18px; font-weight:700; color:#111827; }
  .foot-text .sub { font-size:13px; margin-top:4px; }
  .foot-text .thanks { font-size:11px; color:#9ca3af; margin-top:8px; }
  @media print { .container { padding:0; } .no-print { display:none; } }
''';

String _header(SalesCompany c, String title, String accent, String metaHtml) {
  final logo = _logoUrl(c);
  return '''
  <header>
    <div class="brand">
      ${logo.isNotEmpty ? '<img src="${_esc(logo)}" alt="Logo" onerror="this.style.display=\'none\'" />' : ''}
      <div>
        <div class="name">${_esc(c.name.isEmpty ? 'Company Name' : c.name)}</div>
        ${c.address.isNotEmpty ? '<div class="meta">${_esc(c.address)}</div>' : ''}
        ${c.contact1.isNotEmpty ? '<div class="meta">Phone: ${_esc(c.contact1)}</div>' : ''}
      </div>
    </div>
    <div class="doc">
      <div class="title" style="color:$accent">$title</div>
      <div class="rid">$metaHtml</div>
    </div>
  </header>''';
}

String _footer(SalesCompany c) {
  final stamp = _stampUrl(c);
  return '''
  <footer>
    <div class="sigs">
      <div class="sig">${stamp.isNotEmpty ? '<img src="${_esc(stamp)}" alt="Company Stamp" onerror="this.style.display=\'none\'" />' : '<div class="line"></div>'}<div class="lbl">Company Stamp</div></div>
      <div class="sig"><div class="line"></div><div class="lbl">Authorized Signature</div></div>
    </div>
    <div class="foot-text">
      <div class="co">${_esc(c.name)}</div>
      ${c.contact1.isNotEmpty ? '<div class="sub">Phone: ${_esc(c.contact1)}</div>' : ''}
      <div class="thanks">This is a computer-generated document and does not require a signature</div>
    </div>
  </footer>''';
}

String _printButton() => '''
<div class="no-print" style="text-align:center;margin:16px 0">
  <button onclick="window.print()" style="padding:10px 22px;background:#111827;color:#fff;border:none;border-radius:8px;cursor:pointer;font-size:14px">Print</button>
</div>''';

String _page(String title, String body) =>
    '''<!DOCTYPE html>
<html><head><meta charset="utf-8"/><title>${_esc(title)}</title>
<style>$_accPrintStyle</style></head>
<body><div class="container">$body</div>${_printButton()}</body></html>''';

/// HTML for a grouped-by-head table set (shared by the report + one-day prints).
({String html, double total}) _groupedSections({
  required List<AccountEntry> entries,
  required List<AccountHead> heads,
  required List<SubHead> subs,
  required List<AccountTxnType> types,
  required String accent,
}) {
  final order = <String>[];
  final groups = <String, List<AccountEntry>>{};
  for (final e in entries) {
    groups.putIfAbsent(e.head, () {
      order.add(e.head);
      return [];
    }).add(e);
  }

  var total = 0.0;
  final parts = StringBuffer();
  for (final head in order) {
    final group = groups[head]!;
    final headName = _headName(heads, head);
    var subtotal = 0.0;
    var i = 0;
    final rows = StringBuffer();
    for (final e in group) {
      i++;
      subtotal += e.amount;
      rows.write('''
        <tr>
          <td class="center" style="color:#6b7280">$i</td>
          <td>${_esc(e.date)}</td>
          <td>${_esc(_subHeadName(subs, e.subHead))}</td>
          <td>${_esc(e.description.isEmpty ? '-' : e.description)}</td>
          <td>${_esc(_txnName(types, e.transactionType))}</td>
          <td class="right" style="font-weight:600">${accNumber(e.amount)}</td>
        </tr>''');
    }
    total += subtotal;
    parts.write('''
    <section>
      <h3 class="group">${_esc(headName)}</h3>
      <table>
        <thead><tr style="background:$accent">
          <th class="center">#</th><th>Date</th><th>Sub Head</th><th>Description</th><th>Type</th><th class="right">Amount (PKR)</th>
        </tr></thead>
        <tbody>$rows</tbody>
        <tfoot><tr><td colspan="5">${_esc(headName)} Subtotal</td><td class="right" style="font-size:15px">PKR ${accNumber(subtotal)}</td></tr></tfoot>
      </table>
    </section>''');
  }
  return (html: parts.toString(), total: total);
}

String _grandTotalHtml(int count, double total, String accent) => '''
<div class="grand">
  <div class="lbl">Total Entries: <span style="font-weight:700;color:#111827">$count</span></div>
  <div class="lbl">Grand Total: <span style="font-size:18px;font-weight:800;color:$accent">PKR ${accNumber(total)}</span></div>
</div>''';

// ---------------------------------------------------------------------------
// Single account entry (violet) — Account Reports row action.
// ---------------------------------------------------------------------------

String buildAccountEntryPrintHtml(
  SalesCompany company,
  AccountEntry entry,
  List<AccountHead> heads,
  List<SubHead> subs,
  List<AccountTxnType> types,
) {
  const accent = '#7c3aed';
  final meta =
      'Entry ID: <span>${_esc(entry.id)}</span><br/>Date: <span>${_esc(entry.date)}</span>';
  final body = '''
  ${_header(company, 'ACCOUNT ENTRY', accent, meta)}
  <table>
    <thead><tr style="background:$accent">
      <th style="width:33%">Field</th><th>Value</th>
    </tr></thead>
    <tbody>
      <tr><td><b>Account Head</b></td><td>${_esc(_headName(heads, entry.head))}</td></tr>
      <tr><td><b>Account Type</b></td><td>${_esc(_headType(heads, entry.head))}</td></tr>
      <tr><td><b>Sub Head</b></td><td>${_esc(_subHeadName(subs, entry.subHead))}</td></tr>
      <tr><td><b>Description</b></td><td>${_esc(entry.description.isEmpty ? '-' : entry.description)}</td></tr>
      <tr><td><b>Transaction Type</b></td><td>${_esc(_txnName(types, entry.transactionType))}</td></tr>
      <tr><td><b>Amount (PKR)</b></td><td style="font-size:16px;font-weight:700;color:#059669">${accNumber(entry.amount)}</td></tr>
      <tr><td><b>Created By</b></td><td>${_esc(entry.addBy)}</td></tr>
      <tr><td><b>Last Edited By</b></td><td>${_esc(entry.editBy)}</td></tr>
    </tbody>
  </table>
  ${_footer(company)}''';
  return _page('Account Entry ${entry.id}', body);
}

// ---------------------------------------------------------------------------
// Account report (all filtered entries, grouped — violet).
// ---------------------------------------------------------------------------

String buildAccountReportPrintHtml(
  SalesCompany company,
  List<AccountEntry> entries,
  List<AccountHead> heads,
  List<SubHead> subs,
  List<AccountTxnType> types, {
  required String from,
  required String to,
  required String headFilter,
  required String userFilter,
}) {
  const accent = '#7c3aed';
  final meta = [
    'Date: <span>${accDdMmmYyyy(DateTime.now())}</span>',
    'Period: <span>${from.isEmpty ? 'Start' : _esc(from)} to ${to.isEmpty ? 'End' : _esc(to)}</span>',
    if (headFilter.isNotEmpty)
      'Head: <span>${_esc(_headName(heads, headFilter))}</span>',
    if (userFilter.isNotEmpty) 'User: <span>${_esc(userFilter)}</span>',
  ].join('<br/>');

  final grouped = _groupedSections(
    entries: entries,
    heads: heads,
    subs: subs,
    types: types,
    accent: accent,
  );
  final body = '''
  ${_header(company, 'ACCOUNT REPORT', accent, meta)}
  ${grouped.html}
  ${_grandTotalHtml(entries.length, grouped.total, accent)}
  ${_footer(company)}''';
  return _page('Account Report', body);
}

// ---------------------------------------------------------------------------
// One-day balance sheet (teal) — single entry or grouped bulk.
// ---------------------------------------------------------------------------

String buildOneDayBalancePrintHtml(
  SalesCompany company,
  List<AccountEntry> entries,
  List<AccountHead> heads,
  List<SubHead> subs,
  List<AccountTxnType> types, {
  required String dateLabel,
}) {
  const accent = '#0d9488';
  final isSingle = entries.length == 1;
  final title = isSingle ? 'ACCOUNT ENTRY' : 'OD BALANCE SHEET';
  final metaParts = [
    if (isSingle) 'Entry ID: <span>${_esc(entries.first.id)}</span>',
    'Date: <span>${_esc(dateLabel)}</span>',
    'Entries: <span>${entries.length}</span>',
  ];
  final meta = metaParts.join('<br/>');

  final body = StringBuffer()
    ..write(_header(company, title, accent, meta));

  if (isSingle) {
    final e = entries.first;
    body.write('''
    <table>
      <thead><tr style="background:$accent">
        <th style="width:33%">Field</th><th>Value</th>
      </tr></thead>
      <tbody>
        <tr><td><b>Account Head</b></td><td>${_esc(_headName(heads, e.head))}</td></tr>
        <tr><td><b>Account Type</b></td><td>${_esc(_headType(heads, e.head))}</td></tr>
        <tr><td><b>Sub Head</b></td><td>${_esc(_subHeadName(subs, e.subHead))}</td></tr>
        <tr><td><b>Description</b></td><td>${_esc(e.description.isEmpty ? '-' : e.description)}</td></tr>
        <tr><td><b>Transaction Type</b></td><td>${_esc(_txnName(types, e.transactionType))}</td></tr>
        <tr><td><b>Amount (PKR)</b></td><td style="font-size:16px;font-weight:700;color:$accent">${accNumber(e.amount)}</td></tr>
        <tr><td><b>Created By</b></td><td>${_esc(e.addBy)}</td></tr>
      </tbody>
    </table>''');
  } else {
    final grouped = _groupedSections(
      entries: entries,
      heads: heads,
      subs: subs,
      types: types,
      accent: accent,
    );
    body.write(grouped.html);
    body.write(_grandTotalHtml(entries.length, grouped.total, accent));
  }
  body.write(_footer(company));
  return _page(title, body.toString());
}

// ---------------------------------------------------------------------------
// Openers (write the HTML to a temp file and open it in the browser).
// ---------------------------------------------------------------------------

Future<void> printAccountEntry(
  BuildContext context,
  SalesCompany company,
  AccountEntry entry,
  List<AccountHead> heads,
  List<SubHead> subs,
  List<AccountTxnType> types,
) async {
  await salesOpenHtml(
    context,
    'account_entry_${entry.id}.html',
    buildAccountEntryPrintHtml(company, entry, heads, subs, types),
  );
}

Future<void> printAccountReport(
  BuildContext context,
  SalesCompany company,
  List<AccountEntry> entries,
  List<AccountHead> heads,
  List<SubHead> subs,
  List<AccountTxnType> types, {
  required String from,
  required String to,
  required String headFilter,
  required String userFilter,
}) async {
  await salesOpenHtml(
    context,
    'account_report.html',
    buildAccountReportPrintHtml(
      company,
      entries,
      heads,
      subs,
      types,
      from: from,
      to: to,
      headFilter: headFilter,
      userFilter: userFilter,
    ),
  );
}

Future<void> printOneDayBalance(
  BuildContext context,
  SalesCompany company,
  List<AccountEntry> entries,
  List<AccountHead> heads,
  List<SubHead> subs,
  List<AccountTxnType> types, {
  required String dateLabel,
}) async {
  await salesOpenHtml(
    context,
    'od_balance_sheet.html',
    buildOneDayBalancePrintHtml(
      company,
      entries,
      heads,
      subs,
      types,
      dateLabel: dateLabel,
    ),
  );
}
