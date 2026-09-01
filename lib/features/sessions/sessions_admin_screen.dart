import 'package:flutter/material.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/admin_form.dart';
import '../../core/widgets/common.dart';
import '../../data/models/directory_models.dart';
import '../../data/repositories/admin_repository.dart';

/// Workshops & Webinars — the sessions programme the user app lists and takes
/// seat requests against.
class SessionsAdminScreen extends StatefulWidget {
  const SessionsAdminScreen({super.key});
  @override
  State<SessionsAdminScreen> createState() => _SessionsAdminScreenState();
}

class _SessionsAdminScreenState extends State<SessionsAdminScreen> {
  final _repo = AdminRepository();
  List<Session> _sessions = [];
  bool _loading = true;
  String _mode = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _repo.sessions();
    if (!mounted) return;
    setState(() {
      _sessions = s;
      _loading = false;
    });
  }

  List<Session> get _visible {
    var list = _sessions;
    if (_mode == 'workshop') list = list.where((s) => !s.isWebinar).toList();
    if (_mode == 'webinar') list = list.where((s) => s.isWebinar).toList();
    final sorted = [...list]..sort((a, b) => a.date.compareTo(b.date));
    return sorted;
  }

  Future<void> _togglePublished(Session s, bool v) async {
    final i = _sessions.indexWhere((x) => x.id == s.id);
    if (i != -1) setState(() => _sessions[i] = _sessions[i].copyWith(published: v));
    try {
      await _repo.setSessionPublished(s.id, v);
    } catch (err) {
      if (i != -1 && mounted) setState(() => _sessions[i] = s);
      if (mounted) showAdminError(context, err);
    }
  }

  void _edit([Session? existing]) {
    showDialog<void>(
      context: context,
      builder: (_) => _SessionEditor(
        existing: existing,
        onSaved: () {
          _load();
          if (mounted) showAdminOk(context, existing == null ? 'Session created' : 'Session updated');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    final published = _sessions.where((s) => s.published).length;
    final registrations = _sessions.fold<int>(0, (sum, s) => sum + s.registrations);

    return ListView(
      padding: EdgeInsets.all(responsiveValue(context, mobile: 16, desktop: 28)),
      children: [
        PageHeader(
          eyebrow: 'Learning programme',
          title: 'Workshops & Webinars',
          subtitle: 'Sessions listed in the marketplace, with seats and registrations',
          actions: [
            ElevatedButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New session'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(spacing: 14, runSpacing: 14, children: [
          StatCard(label: 'Sessions', value: '${_sessions.length}', icon: Icons.school_outlined, color: AppColors.gold),
          StatCard(label: 'Published', value: '$published', icon: Icons.visibility_outlined, color: AppColors.success),
          StatCard(
            label: 'Webinars',
            value: '${_sessions.where((s) => s.isWebinar).length}',
            icon: Icons.laptop_outlined,
            color: AppColors.info,
          ),
          StatCard(label: 'Registrations', value: '$registrations', icon: Icons.how_to_reg_outlined, color: AppColors.warning),
        ]),
        const SizedBox(height: 20),
        SectionCard(
          title: 'Schedule',
          actions: [
            _ModeSeg(value: _mode, onChanged: (v) => setState(() => _mode = v)),
          ],
          child: _visible.isEmpty
              ? const EmptyView(message: 'No sessions scheduled yet', icon: Icons.school_outlined)
              : Column(children: [for (final s in _visible) _row(s)]),
        ),
      ],
    );
  }

  Widget _row(Session s) {
    final accent = s.isWebinar ? AppColors.info : AppColors.gold;
    final narrow = Responsive.isMobile(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(s.emoji, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  StatusChip(label: s.isWebinar ? 'WEBINAR' : 'WORKSHOP', color: accent),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(divisionName(s.division),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body(size: 11, color: AppColors.textMuted)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(s.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body(size: 14, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  [
                    if (s.host.isNotEmpty) s.host,
                    if (s.date.isNotEmpty) s.date,
                    if (s.placeLabel.isNotEmpty) s.placeLabel,
                    s.fee,
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body(size: 12, color: AppColors.textSecondary),
                ),
              ]),
            ),
            if (!narrow) ...[
              const SizedBox(width: 14),
              SizedBox(width: 120, child: _seats(s, accent)),
              const SizedBox(width: 14),
            ],
            AdminToggle(value: s.published, onChanged: (v) => _togglePublished(s, v)),
            IconButton(
              onPressed: () => _edit(s),
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Edit',
              color: AppColors.textSecondary,
            ),
          ]),
          if (narrow) ...[
            const SizedBox(height: 10),
            _seats(s, accent),
          ],
        ],
      ),
    );
  }

  Widget _seats(Session s, Color accent) {
    if (s.seats == 0) {
      return Text('No seat cap', style: AppType.body(size: 11, color: AppColors.textMuted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: s.fillRatio,
            minHeight: 4,
            backgroundColor: AppColors.border,
            color: s.soldOut ? AppColors.danger : accent,
          ),
        ),
        const SizedBox(height: 5),
        Text(s.soldOut ? 'Fully booked' : '${s.seatsLeft} of ${s.seats} left',
            style: AppType.body(size: 10.5, color: s.soldOut ? AppColors.danger : AppColors.textMuted)),
      ],
    );
  }
}

class _ModeSeg extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _ModeSeg({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final o in const [('all', 'All'), ('workshop', 'Workshops'), ('webinar', 'Webinars')])
            InkWell(
              onTap: () => onChanged(o.$1),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: value == o.$1 ? AppColors.gold.withValues(alpha: .16) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(o.$2,
                    style: AppType.body(
                        size: 12,
                        weight: FontWeight.w700,
                        color: value == o.$1 ? AppColors.gold : AppColors.textMuted)),
              ),
            ),
        ]),
      );
}

class _SessionEditor extends StatefulWidget {
  final Session? existing;
  final VoidCallback onSaved;
  const _SessionEditor({this.existing, required this.onSaved});

  @override
  State<_SessionEditor> createState() => _SessionEditorState();
}

class _SessionEditorState extends State<_SessionEditor> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _host = TextEditingController(text: widget.existing?.host ?? '');
  late final _city = TextEditingController(text: widget.existing?.city ?? '');
  late final _state = TextEditingController(text: widget.existing?.state ?? '');
  late final _date = TextEditingController(text: widget.existing?.date ?? '');
  late final _time = TextEditingController(text: widget.existing?.time ?? '');
  late final _duration = TextEditingController(text: widget.existing?.duration ?? '');
  late final _fee = TextEditingController(text: widget.existing?.fee ?? 'Free');
  late final _seats = TextEditingController(text: '${widget.existing?.seats ?? 0}');
  late final _seatsLeft = TextEditingController(text: '${widget.existing?.seatsLeft ?? 0}');
  late final _blurb = TextEditingController(text: widget.existing?.blurb ?? '');
  late final _emoji = TextEditingController(text: widget.existing?.emoji ?? '🎓');
  late String _mode = widget.existing?.mode ?? 'workshop';
  late String _division = widget.existing?.division ?? 'talent';

  @override
  void dispose() {
    for (final c in [_title, _host, _city, _state, _date, _time, _duration, _fee, _seats, _seatsLeft, _blurb, _emoji]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminEditor(
      title: widget.existing == null ? 'New session' : 'Edit session',
      subtitle: 'Appears under Workshops & Webinars in the marketplace',
      saveLabel: widget.existing == null ? 'Create' : 'Save',
      fields: (c) => [
        AdminRow(
          left: AdminField(
            label: 'Format',
            child: AdminSelect<String>(
              options: const [(value: 'workshop', label: 'Workshop (in person)'), (value: 'webinar', label: 'Webinar (online)')],
              value: _mode,
              onChanged: (v) => setState(() {
                _mode = v;
                // An online session has no city to travel to; prefilling it
                // keeps the marketplace card honest instead of blank.
                if (v == 'webinar' && _city.text.trim().isEmpty) _city.text = 'Online';
              }),
            ),
          ),
          right: AdminField(
            label: 'Division',
            child: AdminSelect<String>(
              options: [for (final d in adminDivisions) (value: d.id, label: '${d.icon}  ${d.name}')],
              value: _division,
              onChanged: (v) => setState(() => _division = v),
            ),
          ),
        ),
        AdminField(label: 'Title', child: AdminInput(controller: _title, placeholder: 'Comp card clinic — what casting actually reads')),
        AdminField(label: 'Host', child: AdminInput(controller: _host, placeholder: 'Name · role, or the partner institution')),
        AdminField(label: 'Description', child: AdminInput(controller: _blurb, placeholder: 'What attendees leave with', minLines: 3)),
        AdminRow(
          left: AdminField(label: 'Date', hint: 'YYYY-MM-DD', child: AdminInput(controller: _date, placeholder: '2026-09-14')),
          right: AdminField(label: 'Time', child: AdminInput(controller: _time, placeholder: '11:00 IST')),
        ),
        AdminRow(
          left: AdminField(label: 'Duration', child: AdminInput(controller: _duration, placeholder: '3 hrs')),
          right: AdminField(label: 'Fee', hint: 'Type “Free” for a free session', child: AdminInput(controller: _fee, placeholder: '₹1,500')),
        ),
        AdminRow(
          left: AdminField(label: 'City', child: AdminInput(controller: _city, placeholder: 'Mumbai')),
          right: AdminField(label: 'State', child: AdminInput(controller: _state, placeholder: 'Maharashtra')),
        ),
        AdminRow(
          left: AdminField(
            label: 'Total seats',
            hint: '0 for no cap',
            child: AdminInput(controller: _seats, placeholder: '40', keyboardType: TextInputType.number),
          ),
          right: AdminField(
            label: 'Seats left',
            child: AdminInput(controller: _seatsLeft, placeholder: '40', keyboardType: TextInputType.number),
          ),
        ),
        AdminField(label: 'Emoji', child: AdminInput(controller: _emoji, placeholder: '🎓')),
      ],
      onSave: () async {
        final messenger = ScaffoldMessenger.of(context);
        if (_title.text.trim().isEmpty || _date.text.trim().isEmpty) {
          showAdminErrorOn(messenger, 'A title and a date are required');
          return false;
        }
        final seats = int.tryParse(_seats.text.trim()) ?? 0;
        final left = int.tryParse(_seatsLeft.text.trim()) ?? 0;
        if (seats > 0 && left > seats) {
          // Otherwise the marketplace's fill bar renders backwards.
          showAdminErrorOn(messenger, 'Seats left cannot exceed total seats');
          return false;
        }
        try {
          await AdminRepository().saveSession(Session(
            id: widget.existing?.id ?? '',
            mode: _mode,
            title: _title.text.trim(),
            host: _host.text.trim(),
            division: _division,
            city: _city.text.trim(),
            state: _state.text.trim(),
            date: _date.text.trim(),
            time: _time.text.trim(),
            duration: _duration.text.trim(),
            fee: _fee.text.trim().isEmpty ? 'Free' : _fee.text.trim(),
            seats: seats,
            seatsLeft: left,
            blurb: _blurb.text.trim(),
            emoji: _emoji.text.trim().isEmpty ? '🎓' : _emoji.text.trim(),
            published: widget.existing?.published ?? false,
          ));
          widget.onSaved();
          return true;
        } catch (err) {
          showAdminErrorOn(messenger, err);
          return false;
        }
      },
    );
  }
}
