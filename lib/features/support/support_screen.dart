import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/responsive_table.dart';
import '../../data/models/models.dart';
import '../../data/models/status_ui.dart';
import '../../data/repositories/admin_repository.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _repo = AdminRepository();
  List<SupportTicket> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo.tickets().then((t) {
      if (mounted) setState(() { _all = t; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final open = _all.where((t) => t.status == 'open').length;
    final pending = _all.where((t) => t.status == 'pending').length;
    final resolved = _all.where((t) => t.status == 'resolved').length;
    final cols = responsiveValue(context, mobile: 3, desktop: 3);

    return ListView(
      padding: EdgeInsets.all(responsiveValue(context, mobile: 16, desktop: 28)),
      children: [
        PageHeader(title: 'Support', subtitle: 'Vendor and user support tickets'),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: responsiveValue(context, mobile: 1.1, desktop: 2.2),
          children: [
            StatCard(label: 'Open', value: '$open', icon: Icons.mark_email_unread_outlined, color: AppColors.danger),
            StatCard(label: 'Pending', value: '$pending', icon: Icons.hourglass_empty, color: AppColors.warning),
            StatCard(label: 'Resolved', value: '$resolved', icon: Icons.check_circle_outline, color: AppColors.success),
          ],
        ),
        const SizedBox(height: 24),
        SectionCard(
          padding: const EdgeInsets.all(16),
          child: _loading
              ? const LoadingView()
              : ResponsiveTable(
                  columns: const [
                    TableColumn('Ticket', flex: 1),
                    TableColumn('Subject', flex: 4),
                    TableColumn('Requester', flex: 3),
                    TableColumn('Priority', flex: 2),
                    TableColumn('Date', flex: 2),
                    TableColumn('Status', flex: 2),
                  ],
                  rowCount: _all.length,
                  cellsBuilder: (i) {
                    final t = _all[i];
                    return [
                      tcell(t.id, color: AppColors.textMuted),
                      tcell(t.subject, weight: FontWeight.w600),
                      tcell(t.requester),
                      StatusChip(label: t.priority[0].toUpperCase() + t.priority.substring(1), color: StatusUi.priority(t.priority)),
                      tcell(DateFormat('d MMM').format(t.date)),
                      StatusChip(
                        label: t.status[0].toUpperCase() + t.status.substring(1),
                        color: t.status == 'open' ? AppColors.danger : t.status == 'pending' ? AppColors.warning : AppColors.success,
                      ),
                    ];
                  },
                ),
        ),
      ],
    );
  }
}
