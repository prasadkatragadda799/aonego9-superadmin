import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/responsive_table.dart';
import '../../data/models/models.dart';
import '../../data/models/status_ui.dart';
import '../../data/repositories/admin_repository.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});
  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final _repo = AdminRepository();
  List<Booking> _all = [];
  bool _loading = true;
  String _query = '';
  BookingStatus? _filter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await _repo.bookings();
    if (!mounted) return;
    setState(() {
      _all = b;
      _loading = false;
    });
  }

  List<Booking> get _filtered => _all.where((b) {
        final q = _query.isEmpty || b.service.toLowerCase().contains(_query.toLowerCase()) || b.clientName.toLowerCase().contains(_query.toLowerCase()) || b.vendorName.toLowerCase().contains(_query.toLowerCase());
        final f = _filter == null || b.status == _filter;
        return q && f;
      }).toList();

  @override
  Widget build(BuildContext context) {
    final cur = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return ListView(
      padding: EdgeInsets.all(responsiveValue(context, mobile: 16, desktop: 28)),
      children: [
        PageHeader(
          title: 'Bookings',
          subtitle: 'Monitor every booking and resolve disputes across the marketplace',
          actions: [OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.download, size: 18), label: const Text('Export'))],
        ),
        const SizedBox(height: 20),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _tab('All', null),
          _tab('Requested', BookingStatus.requested),
          _tab('Confirmed', BookingStatus.confirmed),
          _tab('In Progress', BookingStatus.inProgress),
          _tab('Completed', BookingStatus.completed),
          _tab('Disputed', BookingStatus.disputed),
        ]),
        const SizedBox(height: 16),
        SectionCard(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Padding(padding: const EdgeInsets.only(bottom: 8), child: SearchField(hint: 'Search bookings…', onChanged: (v) => setState(() => _query = v))),
            if (_loading)
              const LoadingView()
            else if (_filtered.isEmpty)
              const EmptyView(message: 'No bookings match your filters')
            else
              ResponsiveTable(
                columns: const [
                  TableColumn('ID', flex: 2),
                  TableColumn('Service', flex: 3),
                  TableColumn('Client', flex: 2),
                  TableColumn('Vendor', flex: 2),
                  TableColumn('Date', flex: 2),
                  TableColumn('Amount', flex: 2, numeric: true),
                  TableColumn('Status', flex: 2),
                ],
                rowCount: _filtered.length,
                cellsBuilder: (i) {
                  final b = _filtered[i];
                  final (label, color) = StatusUi.booking(b.status);
                  return [
                    tcell(b.id, color: AppColors.textMuted),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(child: Text(b.service, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
                      if (b.source == BookingSource.inquiry) ...[
                        const SizedBox(width: 6),
                        const _InquiryTag(),
                      ],
                    ]),
                    tcell(b.clientName),
                    tcell(b.vendorName),
                    tcell(DateFormat('d MMM').format(b.date)),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                      Text(cur.format(b.amount), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      if (b.advancePaid > 0)
                        Text('Adv ${cur.format(b.advancePaid)}', style: const TextStyle(fontSize: 11, color: AppColors.success)),
                    ]),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      StatusChip(label: label, color: color),
                      if (b.status == BookingStatus.disputed) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _resolve(b),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.gold.withValues(alpha: 0.4))),
                            child: const Text('Resolve', style: TextStyle(color: AppColors.gold, fontSize: 11.5, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ]),
                  ];
                },
              ),
          ]),
        ),
      ],
    );
  }

  void _resolve(Booking b) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Resolve Dispute'),
        content: Text('Choose how to resolve the dispute on ${b.id} (${b.service}).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Refund client')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Release to vendor')),
        ],
      ),
    );
  }

  Widget _tab(String label, BookingStatus? status) {
    final selected = _filter == status;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _filter = status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold.withValues(alpha: 0.14) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.gold : AppColors.border),
        ),
        child: Text(label, style: TextStyle(color: selected ? AppColors.gold : AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12.5)),
      ),
    );
  }
}

/// Small badge marking a booking that originated from a user inquiry.
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
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.forum_outlined, size: 11, color: AppColors.info),
        SizedBox(width: 3),
        Text('Inquiry', style: TextStyle(color: AppColors.info, fontSize: 10.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
