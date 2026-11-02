import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/utils/date_util.dart';
import '../../core/utils/file_saver.dart';
import '../../core/utils/launch_util.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/receipt_image.dart';
import '../../core/widgets/responsive_table.dart';
import '../../data/api/api_errors.dart';
import '../../data/models/models.dart';
import '../../data/models/status_ui.dart';
import '../../data/repositories/admin_repository.dart';

class BookingsScreen extends StatefulWidget {
  final String initialQuery;
  final String initialStatus;
  const BookingsScreen({super.key, this.initialQuery = '', this.initialStatus = ''});
  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final _repo = AdminRepository();
  List<Booking> _all = [];
  List<Map<String, dynamic>> _advances = [];
  bool _loading = true;
  String? _error;
  late String _query = widget.initialQuery;
  late BookingStatus? _filter = _statusFrom(widget.initialStatus);
  final Set<String> _busy = {};

  static final _cur = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  static BookingStatus? _statusFrom(String s) => BookingStatus.values.where((v) => v.name == s).firstOrNull;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BookingsScreen old) {
    super.didUpdateWidget(old);
    if (old.initialQuery != widget.initialQuery || old.initialStatus != widget.initialStatus) {
      setState(() {
        _query = widget.initialQuery;
        _filter = _statusFrom(widget.initialStatus);
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = _all.isEmpty;
      _error = null;
    });
    try {
      final results = await Future.wait<Object?>([
        _repo.bookings(),
        _repo.advanceRequests(status: 'pending').catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _all = results[0] as List<Booking>;
        _advances = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = apiErrorMessage(e, fallback: 'Could not load bookings.');
        });
      }
    }
  }

  List<Booking> get _filtered {
    final q = _query.trim().toLowerCase();
    return _all.where((b) {
      if (_filter != null && b.status != _filter) return false;
      return q.isEmpty || '${b.id} ${b.service} ${b.clientName} ${b.vendorName} ${b.city} ${b.inquiryRef ?? ''}'.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _export() async {
    final m = Toast.of(context);
    final rows = _filtered;
    if (rows.isEmpty) return Toast.info(m, 'No bookings in this view to export.');
    final df = DateFormat('yyyy-MM-dd');
    final csv = toCsv(
      ['ID', 'Inquiry ref', 'Date', 'Service', 'Client', 'Vendor', 'City', 'Status', 'Amount', 'Advance paid', 'Balance due', 'Source'],
      [
        for (final b in rows)
          [b.id, b.inquiryRef ?? '', df.format(b.date), b.service, b.clientName, b.vendorName, b.city, b.status.name, b.amount, b.advancePaid, b.balanceDue, b.source.name],
      ],
    );
    final dl = await saveTextFile('aonego9-bookings-${df.format(DateTime.now())}.csv', csv);
    Toast.ok(m, dl ? 'Exported ${rows.length} bookings' : 'CSV copied to clipboard');
  }

  Future<void> _setStatus(Booking b, BookingStatus s, {required String done}) async {
    final m = Toast.of(context);
    setState(() => _busy.add(b.id));
    try {
      await _repo.setBookingStatus(b.id, s);
      final i = _all.indexWhere((x) => x.id == b.id);
      if (i != -1 && mounted) setState(() => _all[i] = b.copyWith(status: s));
      Toast.ok(m, done);
    } catch (e) {
      Toast.error(m, apiErrorMessage(e, fallback: 'Could not update the booking.'));
    } finally {
      if (mounted) setState(() => _busy.remove(b.id));
    }
  }

  /// Disputes resolve one of two ways — the booking is cancelled (client is
  /// refunded) or completed (payment is released to the vendor).
  Future<void> _resolve(Booking b) async {
    final outcome = await showDialog<BookingStatus>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve dispute'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${b.service} · ${b.clientName} with ${b.vendorName} · ${_cur.format(b.amount)}'),
            const SizedBox(height: 14),
            Text('Refund client — the booking is cancelled and any advance is returned to the client.',
                style: AppType.body(size: 12.5, color: AppColors.textSecondary, height: 1.45)),
            const SizedBox(height: 8),
            Text('Release to vendor — the booking is marked completed and the amount moves to the vendor\'s settlement.',
                style: AppType.body(size: 12.5, color: AppColors.textSecondary, height: 1.45)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, BookingStatus.cancelled),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Refund client'),
          ),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, BookingStatus.completed), child: const Text('Release to vendor')),
        ],
      ),
    );
    if (outcome == null || !mounted) return;
    await _setStatus(
      b,
      outcome,
      done: outcome == BookingStatus.completed ? 'Dispute resolved — payment released to ${b.vendorName}' : 'Dispute resolved — booking cancelled and client refunded',
    );
  }

  Future<void> _approveAdvance(Map<String, dynamic> a) async {
    final m = Toast.of(context);
    try {
      await _repo.approveAdvance('${a['id']}');
      Toast.ok(m, 'Advance approved — booking updated');
      _load();
    } catch (e) {
      Toast.error(m, apiErrorMessage(e, fallback: 'Could not approve the advance.'));
    }
  }

  Future<void> _rejectAdvance(Map<String, dynamic> a) async {
    final c = TextEditingController(text: 'Receipt could not be verified');
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject advance payment'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('The client sees this reason and can upload a new receipt.'),
            const SizedBox(height: 12),
            TextField(controller: c, autofocus: true, maxLines: 3, decoration: const InputDecoration(hintText: 'Reason')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerFill, foregroundColor: AppColors.onAccent(AppColors.dangerFill)),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    c.dispose();
    if (note == null || !mounted) return;
    final m = Toast.of(context);
    try {
      await _repo.rejectAdvance('${a['id']}', adminNote: note.isEmpty ? 'Receipt could not be verified' : note);
      Toast.ok(m, 'Advance rejected');
      _load();
    } catch (e) {
      Toast.error(m, apiErrorMessage(e, fallback: 'Could not reject the advance.'));
    }
  }

  void _viewReceipt(Map<String, dynamic> a) {
    final src = '${a['receipt_image'] ?? ''}';
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(children: [
                Expanded(child: Text('Advance receipt', style: AppType.display(size: 18))),
                if (src.startsWith('http')) IconButton(tooltip: 'Open full size', onPressed: () => openExternal(ctx, Uri.parse(src)), icon: const Icon(Icons.open_in_new)),
                IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
              ]),
            ),
            Flexible(child: InteractiveViewer(child: ReceiptImage(source: src))),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _all.isEmpty) return ErrorView(message: _error!, onRetry: _load);
    final list = _filtered;
    int count(BookingStatus? s) => s == null ? _all.length : _all.where((b) => b.status == s).length;

    return PageBody(
      onRefresh: _load,
      children: [
        PageHeader(
          title: 'Bookings',
          subtitle: 'Every booking across the marketplace — verify advances and resolve disputes',
          actions: [OutlinedButton.icon(onPressed: _export, icon: const Icon(Icons.download_outlined, size: 18), label: const Text('Export CSV'))],
        ),
        if (_advances.isNotEmpty) ...[
          const SizedBox(height: 18),
          _advancesCard(),
        ],
        const SizedBox(height: 18),
        PillBar(children: [
          FilterPill(label: 'All', count: count(null), selected: _filter == null, onTap: () => setState(() => _filter = null)),
          for (final (l, s) in const [
            ('Requested', BookingStatus.requested),
            ('Confirmed', BookingStatus.confirmed),
            ('In progress', BookingStatus.inProgress),
            ('Completed', BookingStatus.completed),
            ('Cancelled', BookingStatus.cancelled),
            ('Disputed', BookingStatus.disputed),
          ])
            FilterPill(
              label: l,
              count: count(s),
              color: s == BookingStatus.disputed ? AppColors.danger : null,
              selected: _filter == s,
              onTap: () => setState(() => _filter = s),
            ),
        ]),
        const SizedBox(height: 14),
        SectionCard(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SearchField(key: ValueKey('bq-${widget.initialQuery}'), initial: _query, hint: 'Search service, client, vendor, city or reference…', onChanged: (v) => setState(() => _query = v)),
            const SizedBox(height: 8),
            if (_loading)
              const LoadingView()
            else if (list.isEmpty)
              EmptyView(icon: Icons.event_note_outlined, message: _all.isEmpty ? 'No bookings yet' : 'No bookings match your filters')
            else
              ResponsiveTable(
                columns: const [
                  TableColumn('Service', flex: 3),
                  TableColumn('Client', flex: 2),
                  TableColumn('Vendor', flex: 2),
                  TableColumn('Date', flex: 2),
                  TableColumn('Amount', flex: 2, numeric: true),
                  TableColumn('Status', flex: 3),
                ],
                rowCount: list.length,
                mobileCardBuilder: (i) => _mobileCard(list[i]),
                cellsBuilder: (i) {
                  final b = list[i];
                  return [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(child: Text(b.service, overflow: TextOverflow.ellipsis, style: AppType.body(size: 13.5, weight: FontWeight.w600))),
                        if (b.source == BookingSource.inquiry) ...[const SizedBox(width: 6), const _InquiryTag()],
                      ]),
                      Text(b.inquiryRef ?? b.id, style: AppType.mono(size: 11)),
                    ]),
                    tcell(b.clientName),
                    tcell(b.vendorName),
                    tcell(DateFormat('d MMM yyyy').format(b.date)),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                      Text(_cur.format(b.amount), style: AppType.mono(size: 13.5, weight: FontWeight.w600, color: AppColors.textPrimary)),
                      if (b.advancePaid > 0) Text('Adv ${_cur.format(b.advancePaid)}', style: AppType.mono(size: 11, color: AppColors.success)),
                    ]),
                    _statusCell(b),
                  ];
                },
              ),
          ]),
        ),
      ],
    );
  }

  Widget _statusCell(Booking b) {
    final (label, color) = StatusUi.booking(b.status);
    return Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
      StatusChip(label: label, color: color),
      if (b.status == BookingStatus.disputed)
        _busy.contains(b.id)
            ? ButtonSpinner(color: AppColors.gold)
            : InkWell(
                onTap: () => _resolve(b),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: Text('Resolve', style: AppType.body(size: 11.5, weight: FontWeight.w700, color: AppColors.gold)),
                ),
              ),
    ]);
  }

  Widget _mobileCard(Booking b) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: b.status == BookingStatus.disputed ? AppColors.danger.withValues(alpha: .45) : AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(b.service, style: AppType.body(size: 14, weight: FontWeight.w700))),
          Text(_cur.format(b.amount), style: AppType.mono(size: 13.5, weight: FontWeight.w700, color: AppColors.gold)),
        ]),
        const SizedBox(height: 4),
        Text('${b.clientName} → ${b.vendorName}', style: AppType.body(size: 12.5, color: AppColors.textSecondary)),
        Text([DateFormat('d MMM yyyy').format(b.date), if (b.city.isNotEmpty) b.city, if (b.inquiryRef != null) b.inquiryRef!].join(' · '),
            style: AppType.mono(size: 11)),
        const SizedBox(height: 10),
        _statusCell(b),
      ]),
    );
  }

  Widget _advancesCard() {
    return SectionCard(
      title: 'Advance payments to verify',
      actions: [StatusChip(label: '${_advances.length} pending', color: AppColors.warning)],
      child: Column(children: [
        for (final a in _advances)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 220, maxWidth: 420),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${a['inquiry_ref'] ?? a['booking_id']} · ${a['client_name'] ?? 'Client'}', style: AppType.body(size: 13.5, weight: FontWeight.w600)),
                  Text(
                    [
                      if ('${a['vendor_name'] ?? ''}'.isNotEmpty) '${a['vendor_name']}',
                      if (a['amount'] != null) _cur.format(num.tryParse('${a['amount']}') ?? 0),
                      formatIstDateTime(parseApiDateTime(a['created_at']?.toString() ?? '')),
                    ].join(' · '),
                    style: AppType.body(size: 12, color: AppColors.textMuted),
                  ),
                ]),
              ),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if ('${a['receipt_image'] ?? ''}'.isNotEmpty)
                  OutlinedButton.icon(onPressed: () => _viewReceipt(a), icon: const Icon(Icons.receipt_long_outlined, size: 16), label: const Text('Receipt')),
                OutlinedButton(onPressed: () => _rejectAdvance(a), style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger), child: const Text('Reject')),
                ElevatedButton(onPressed: () => _approveAdvance(a), child: const Text('Approve')),
              ]),
            ]),
          ),
      ]),
    );
  }
}

class _InquiryTag extends StatelessWidget {
  const _InquiryTag();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.forum_outlined, size: 11, color: AppColors.info),
        const SizedBox(width: 3),
        Text('Inquiry', style: AppType.mono(size: 10.5, weight: FontWeight.w700, color: AppColors.info)),
      ]),
    );
  }
}
