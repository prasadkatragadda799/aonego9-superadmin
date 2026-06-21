import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../data/models/status_ui.dart';
import '../../data/repositories/admin_repository.dart';

/// Events & Live Poster — the super admin owns the full event lifecycle
/// and curates the scrolling poster feed shown to users in the user app.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _repo = AdminRepository();
  List<PlatformEvent> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await _repo.events();
    if (!mounted) return;
    setState(() { _events = e; _loading = false; });
  }

  Future<void> _togglePoster(PlatformEvent e, bool v) async {
    await _repo.toggleEventPoster(e.id, v);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(v ? '“${e.title}” added to live poster' : '“${e.title}” removed from poster')),
    );
  }

  Future<void> _setStatus(PlatformEvent e, EventStatus s) async {
    await _repo.setEventStatus(e.id, s);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    return ListView(
      padding: EdgeInsets.all(responsiveValue(context, mobile: 16, desktop: 28)),
      children: [
        PageHeader(
          title: 'Events & Poster',
          subtitle: 'Curate platform events and the live scroll poster',
          actions: [ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.add, size: 18), label: const Text('New Event'))],
        ),
        const SizedBox(height: 24),
        ResponsiveLayout(
          mobile: (_) => Column(children: [_posterCard(), const SizedBox(height: 16), _eventsCard()]),
          desktop: (_) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3, child: _eventsCard()),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: _posterCard()),
          ]),
        ),
      ],
    );
  }

  Widget _eventsCard() {
    final df = DateFormat('d MMM yyyy');
    final fmt = NumberFormat.decimalPattern('en_IN');
    return SectionCard(
      title: 'All Events',
      child: Column(
        children: [
          for (final e in _events)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.goldDark, AppColors.gold]), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.celebration_outlined, color: Color(0xFF1A1407), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text('${e.category} · ${e.city} · ${df.format(e.date)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ]),
                      ),
                      StatusChip(label: StatusUi.event(e.status).$1, color: StatusUi.event(e.status).$2),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.people_outline, size: 15, color: AppColors.textMuted),
                      const SizedBox(width: 5),
                      Text('${fmt.format(e.registrations)} registered', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                      const Spacer(),
                      _statusMenu(e),
                      const SizedBox(width: 8),
                      // Poster toggle
                      Tooltip(
                        message: e.onPoster ? 'On live poster' : 'Add to live poster',
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.bolt, size: 15, color: AppColors.textMuted),
                          Switch(value: e.onPoster, activeColor: AppColors.gold, onChanged: (v) => _togglePoster(e, v)),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusMenu(PlatformEvent e) {
    return PopupMenuButton<EventStatus>(
      tooltip: 'Set status',
      color: AppColors.surfaceAlt,
      onSelected: (s) => _setStatus(e, s),
      itemBuilder: (_) => [
        for (final s in EventStatus.values)
          PopupMenuItem(value: s, child: Text(StatusUi.event(s).$1, style: const TextStyle(color: AppColors.textPrimary))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Status', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
        ]),
      ),
    );
  }

  Widget _posterCard() {
    final live = _events.where((e) => e.onPoster).toList();
    return SectionCard(
      title: 'Live Scroll Poster',
      actions: [StatusChip(label: '${live.length} live', color: AppColors.success)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Preview of the scrolling poster users see in the app.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 14),
          // Poster preview strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2A2410), Color(0xFF1C1F27)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: live.isEmpty
                ? const Text('No events on the poster yet — toggle ⚡ on an event.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final e in live)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(children: [
                            Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(child: Text('${e.title}  ·  ${e.city}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                            if (e.status == EventStatus.live)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
                                child: const Text('● LIVE', style: TextStyle(color: AppColors.success, fontSize: 9.5, fontWeight: FontWeight.w700)),
                              ),
                          ]),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          Text('Tip: keep 3–5 events on the poster for the best scroll cadence.', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.8), fontSize: 11.5, height: 1.4)),
        ],
      ),
    );
  }
}
