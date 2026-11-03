import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/typography.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/common.dart';
import '../../data/api/api_errors.dart';
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
  String? _error;
  EventStatus? _filter;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _events.isEmpty;
      _error = null;
    });
    try {
      final e = await _repo.events();
      if (!mounted) return;
      setState(() {
        _events = e;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = apiErrorMessage(e, fallback: 'Could not load events.');
        });
      }
    }
  }

  void _replace(PlatformEvent e) {
    final i = _events.indexWhere((x) => x.id == e.id);
    if (i != -1) setState(() => _events[i] = e);
  }

  Future<void> _togglePoster(PlatformEvent e, bool v) async {
    final m = Toast.of(context);
    _replace(e.copyWith(onPoster: v));
    setState(() => _busy.add(e.id));
    try {
      await _repo.toggleEventPoster(e.id, v);
      Toast.ok(m, v ? '“${e.title}” added to the live poster' : '“${e.title}” removed from the poster');
    } catch (err) {
      _replace(e);
      Toast.error(m, apiErrorMessage(err, fallback: 'Could not update the poster.'));
    } finally {
      if (mounted) setState(() => _busy.remove(e.id));
    }
  }

  Future<void> _setStatus(PlatformEvent e, EventStatus s) async {
    final m = Toast.of(context);
    _replace(e.copyWith(status: s));
    try {
      await _repo.setEventStatus(e.id, s);
      Toast.ok(m, '“${e.title}” → ${StatusUi.event(s).$1}');
    } catch (err) {
      _replace(e);
      Toast.error(m, apiErrorMessage(err, fallback: 'Could not update the event.'));
    }
  }

  Future<void> _delete(PlatformEvent e) async {
    final ok = await confirmAction(
      context,
      title: 'Delete “${e.title}”?',
      message: e.registrations > 0
          ? '${e.registrations} people registered for this event. Consider marking it Ended instead — deleting removes it everywhere.'
          : 'The event is removed from the app and the poster.',
      confirmLabel: 'Delete event',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final m = Toast.of(context);
    try {
      await _repo.deleteEvent(e.id);
      if (mounted) setState(() => _events.removeWhere((x) => x.id == e.id));
      Toast.ok(m, 'Event deleted');
    } catch (err) {
      Toast.error(m, apiErrorMessage(err, fallback: 'Could not delete the event.'));
    }
  }

  Future<void> _edit([PlatformEvent? e]) async {
    final saved = await showAdaptiveSheet<bool>(context, builder: (_) => _EventForm(repo: _repo, existing: e));
    if (saved == true && mounted) {
      Toast.ok(Toast.of(context), e == null ? 'Event created' : 'Event updated');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _events.isEmpty) return ErrorView(message: _error!, onRetry: _load);
    if (_loading) return const LoadingView();
    return PageBody(
      onRefresh: _load,
      children: [
        PageHeader(
          title: 'Events & Poster',
          subtitle: 'Create platform events and curate the live scroll poster in the user app',
          actions: [ElevatedButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add, size: 18), label: const Text('New event'))],
        ),
        const SizedBox(height: 20),
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
    final df = DateFormat('EEE, d MMM yyyy');
    final fmt = NumberFormat.decimalPattern('en_IN');
    final list = _filter == null ? _events : _events.where((e) => e.status == _filter).toList();
    return SectionCard(
      title: 'All events',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PillBar(children: [
          FilterPill(label: 'All', count: _events.length, selected: _filter == null, onTap: () => setState(() => _filter = null)),
          for (final s in EventStatus.values)
            FilterPill(label: StatusUi.event(s).$1, count: _events.where((e) => e.status == s).length, selected: _filter == s, onTap: () => setState(() => _filter = s)),
        ]),
        const SizedBox(height: 12),
        if (list.isEmpty)
          EmptyView(
            icon: Icons.celebration_outlined,
            message: _events.isEmpty ? 'No events yet' : 'No events in this status',
            action: _events.isEmpty ? OutlinedButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add, size: 16), label: const Text('Create the first event')) : null,
          )
        else
          for (final e in list)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 44,
                    height: 44,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: AppColors.posterWash), borderRadius: BorderRadius.circular(8)),
                    child: e.imageUrl.startsWith('http')
                        ? Image.network(e.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.celebration_outlined, color: AppColors.marigold, size: 20))
                        : const Icon(Icons.celebration_outlined, color: AppColors.marigold, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.title, style: AppType.body(size: 14, weight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text([if (e.category.isNotEmpty) e.category, if (e.venue.isNotEmpty) e.venue, if (e.city.isNotEmpty) e.city, df.format(e.date)].join(' · '),
                          style: AppType.body(size: 12, color: AppColors.textMuted)),
                    ]),
                  ),
                  StatusChip(label: StatusUi.event(e.status).$1, color: StatusUi.event(e.status).$2),
                ]),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.people_outline, size: 15, color: AppColors.textMuted),
                    const SizedBox(width: 5),
                    Text('${fmt.format(e.registrations)} registered', style: AppType.body(size: 12.5, color: AppColors.textSecondary)),
                  ]),
                  _statusMenu(e),
                  TextButton.icon(onPressed: () => _edit(e), icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Edit')),
                  IconButton(tooltip: 'Delete', onPressed: () => _delete(e), icon: Icon(Icons.delete_outline, size: 18, color: AppColors.danger)),
                  Tooltip(
                    message: e.onPoster ? 'On live poster' : 'Add to live poster',
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.bolt, size: 15, color: e.onPoster ? AppColors.gold : AppColors.textMuted),
                      Text('Poster', style: AppType.body(size: 12, color: AppColors.textSecondary)),
                      Switch(value: e.onPoster, onChanged: _busy.contains(e.id) ? null : (v) => _togglePoster(e, v)),
                    ]),
                  ),
                ]),
              ]),
            ),
      ]),
    );
  }

  Widget _statusMenu(PlatformEvent e) {
    return PopupMenuButton<EventStatus>(
      tooltip: 'Set status',
      onSelected: (s) => _setStatus(e, s),
      itemBuilder: (_) => [
        for (final s in EventStatus.values)
          PopupMenuItem(value: s, enabled: s != e.status, child: Text(StatusUi.event(s).$1)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Status', style: AppType.body(size: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
        ]),
      ),
    );
  }

  Widget _posterCard() {
    final live = _events.where((e) => e.onPoster).toList();
    return SectionCard(
      title: 'Live scroll poster',
      actions: [StatusChip(label: '${live.length} live', color: AppColors.success)],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Preview of the scrolling poster users see in the app.', style: AppType.body(size: 12, color: AppColors.textMuted)),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: AppColors.posterWash),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.marigold.withValues(alpha: 0.35)),
          ),
          child: live.isEmpty
              ? Text('No events on the poster yet — switch on “Poster” for an event.', style: AppType.body(size: 12.5, color: AppColors.posterInk.withValues(alpha: .8)))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final e in live)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.marigold, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('${e.title}${e.city.isEmpty ? '' : '  ·  ${e.city}'}',
                              overflow: TextOverflow.ellipsis, style: AppType.body(size: 13, weight: FontWeight.w600, color: AppColors.posterInk)),
                        ),
                        if (e.status == EventStatus.live)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFF6AAB88).withValues(alpha: 0.22), borderRadius: BorderRadius.circular(20)),
                            child: Text('● LIVE', style: AppType.mono(size: 9.5, weight: FontWeight.w700, color: const Color(0xFF8FD3AE))),
                          ),
                      ]),
                    ),
                ]),
        ),
        const SizedBox(height: 14),
        Text('Tip: keep 3–5 events on the poster for the best scroll cadence.', style: AppType.body(size: 11.5, color: AppColors.textMuted, height: 1.4)),
      ]),
    );
  }
}

class _EventForm extends StatefulWidget {
  final AdminRepository repo;
  final PlatformEvent? existing;
  const _EventForm({required this.repo, this.existing});
  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _category = TextEditingController(text: widget.existing?.category ?? '');
  late final _city = TextEditingController(text: widget.existing?.city ?? '');
  late final _venue = TextEditingController(text: widget.existing?.venue ?? '');
  late final _desc = TextEditingController(text: widget.existing?.description ?? '');
  late final _image = TextEditingController(text: widget.existing?.imageUrl ?? '');
  late DateTime _date = widget.existing?.date ?? DateTime.now().add(const Duration(days: 14));
  late EventStatus _status = widget.existing?.status ?? EventStatus.upcoming;
  late bool _onPoster = widget.existing?.onPoster ?? false;
  bool _saving = false;
  String _error = '';

  @override
  void dispose() {
    for (final c in [_title, _category, _city, _venue, _desc, _image]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
    setState(() => _date = DateTime(d.year, d.month, d.day, t?.hour ?? _date.hour, t?.minute ?? _date.minute));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      final e = widget.existing;
      await widget.repo.saveEvent(PlatformEvent(
        id: e?.id ?? '',
        title: _title.text.trim(),
        category: _category.text.trim(),
        city: _city.text.trim(),
        venue: _venue.text.trim(),
        description: _desc.text.trim(),
        imageUrl: _image.text.trim(),
        date: _date,
        status: _status,
        onPoster: _onPoster,
        registrations: e?.registrations ?? 0,
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (err) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = apiErrorMessage(err, fallback: 'Could not save the event.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.existing == null ? 'New event' : 'Edit event', style: AppType.display(size: 20)),
          const SizedBox(height: 16),
          if (_error.isNotEmpty) ...[InlineNotice(message: _error, icon: Icons.error_outline, color: AppColors.danger), const SizedBox(height: 12)],
          LabeledField(
            label: 'Title',
            child: TextFormField(controller: _title, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'e.g. Lakmé Fashion Week Casting'), validator: (v) => (v ?? '').trim().length < 3 ? 'Enter a title' : null),
          ),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: LabeledField(label: 'Category', child: TextFormField(controller: _category, decoration: const InputDecoration(hintText: 'Fashion show')))),
            const SizedBox(width: 12),
            Expanded(
              child: LabeledField(
                label: 'City',
                child: TextFormField(controller: _city, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Mumbai'), validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a city' : null),
              ),
            ),
          ]),
          LabeledField(label: 'Venue', child: TextFormField(controller: _venue, decoration: const InputDecoration(hintText: 'Venue name and area'))),
          LabeledField(
            label: 'Date & time',
            child: InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.event_outlined, size: 19)),
                child: Text(DateFormat('EEE, d MMM yyyy · h:mm a').format(_date), style: AppType.body(size: 14)),
              ),
            ),
          ),
          LabeledField(label: 'Description', child: TextFormField(controller: _desc, minLines: 3, maxLines: 6, decoration: const InputDecoration(hintText: 'What, who it is for, how to register'))),
          LabeledField(
            label: 'Poster image URL (optional)',
            child: TextFormField(
              controller: _image,
              decoration: const InputDecoration(hintText: 'https://…'),
              validator: (v) => (v ?? '').trim().isEmpty || (v ?? '').trim().startsWith('http') ? null : 'Enter a full https:// URL',
            ),
          ),
          LabeledField(
            label: 'Status',
            child: DropdownButtonFormField<EventStatus>(
              initialValue: _status,
              dropdownColor: AppColors.surfaceAlt,
              items: [for (final s in EventStatus.values) DropdownMenuItem(value: s, child: Text(StatusUi.event(s).$1))],
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _onPoster,
            onChanged: (v) => setState(() => _onPoster = v),
            title: const Text('Show on the live poster'),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 48,
            child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const ButtonSpinner() : Text(widget.existing == null ? 'Create event' : 'Save changes')),
          ),
        ]),
      ),
    );
  }
}
