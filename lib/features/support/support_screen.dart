import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/launch_util.dart';
import '../../core/widgets/common.dart';
import '../../data/api/api_errors.dart';
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
  String? _error;
  String _status = 'open';
  final Set<String> _busy = {};

  static const _statuses = ['open', 'pending', 'resolved'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _all.isEmpty;
      _error = null;
    });
    try {
      final t = await _repo.tickets();
      if (!mounted) return;
      setState(() {
        _all = t;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = apiErrorMessage(e, fallback: 'Could not load support tickets.');
        });
      }
    }
  }

  Color _statusColor(String s) => switch (s) {
        'open' => AppColors.danger,
        'pending' => AppColors.warning,
        _ => AppColors.success,
      };

  Future<void> _setStatus(SupportTicket t, String s) async {
    final m = Toast.of(context);
    setState(() => _busy.add(t.id));
    try {
      await _repo.updateTicket(t.id, s);
      final i = _all.indexWhere((x) => x.id == t.id);
      if (i != -1 && mounted) setState(() => _all[i] = t.copyWith(status: s));
      Toast.ok(m, 'Ticket ${t.id} → $s');
    } catch (e) {
      Toast.error(m, apiErrorMessage(e, fallback: 'Could not update the ticket.'));
    } finally {
      if (mounted) setState(() => _busy.remove(t.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _all.isEmpty) return ErrorView(message: _error!, onRetry: _load);
    if (_loading) return const LoadingView();
    int count(String s) => _all.where((t) => t.status == s).length;
    final list = _status == 'all' ? _all : _all.where((t) => t.status == _status).toList();

    return PageBody(
      onRefresh: _load,
      children: [
        const PageHeader(title: 'Support', subtitle: 'Vendor and user support tickets'),
        const SizedBox(height: 18),
        ResponsiveGrid(minTileWidth: 160, maxColumns: 3, children: [
          StatCard(label: 'Open', value: '${count('open')}', icon: Icons.mark_email_unread_outlined, color: AppColors.danger, onTap: () => setState(() => _status = 'open')),
          StatCard(label: 'Pending', value: '${count('pending')}', icon: Icons.hourglass_empty, color: AppColors.warning, onTap: () => setState(() => _status = 'pending')),
          StatCard(label: 'Resolved', value: '${count('resolved')}', icon: Icons.check_circle_outline, color: AppColors.success, onTap: () => setState(() => _status = 'resolved')),
        ]),
        const SizedBox(height: 16),
        PillBar(children: [
          for (final s in [..._statuses, 'all'])
            FilterPill(
              label: s[0].toUpperCase() + s.substring(1),
              count: s == 'all' ? _all.length : count(s),
              selected: _status == s,
              onTap: () => setState(() => _status = s),
            ),
        ]),
        const SizedBox(height: 14),
        if (list.isEmpty)
          EmptyView(icon: Icons.support_agent_outlined, message: _status == 'open' ? 'No open tickets' : 'Nothing here', detail: _status == 'open' ? 'Every ticket has been handled.' : null)
        else
          for (final t in list) Padding(padding: const EdgeInsets.only(bottom: 12), child: _card(t)),
      ],
    );
  }

  Widget _card(SupportTicket t) {
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          StatusChip(label: t.status[0].toUpperCase() + t.status.substring(1), color: _statusColor(t.status)),
          if (t.priority.isNotEmpty) StatusChip(label: '${t.priority[0].toUpperCase()}${t.priority.substring(1)} priority', color: StatusUi.priority(t.priority)),
          Text('#${t.id} · ${DateFormat('d MMM yyyy, h:mm a').format(t.date)}', style: AppType.mono(size: 11)),
        ]),
        const SizedBox(height: 10),
        Text(t.subject, style: AppType.body(size: 14.5, weight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text([if (t.requester.isNotEmpty) t.requester, if (t.requesterEmail.isNotEmpty) t.requesterEmail].join(' · '),
            style: AppType.body(size: 12.5, color: AppColors.textMuted)),
        if (t.message.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(t.message, style: AppType.body(size: 13, color: AppColors.textSecondary, height: 1.5)),
        ],
        const SizedBox(height: 12),
        if (_busy.contains(t.id))
          ButtonSpinner(color: AppColors.gold)
        else
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (t.requesterEmail.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () => openExternal(context, mailUri(t.requesterEmail, subject: 'Re: ${t.subject} [#${t.id}]')),
                icon: const Icon(Icons.reply, size: 16),
                label: const Text('Reply'),
              ),
            for (final s in _statuses)
              if (s != t.status)
                OutlinedButton(
                  onPressed: () => _setStatus(t, s),
                  child: Text(switch (s) { 'open' => 'Reopen', 'pending' => 'Mark pending', _ => 'Resolve' }),
                ),
          ]),
      ]),
    );
  }
}
