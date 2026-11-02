import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/common.dart';
import '../../data/api/api_errors.dart';
import '../../data/models/models.dart';
import '../../data/repositories/admin_repository.dart';

/// Review moderation. "Keep" clears a flag; "Remove" deletes the review from
/// the vendor's public profile. (Both used to only show a snackbar.)
class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});
  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final _repo = AdminRepository();
  List<Review> _all = [];
  bool _loading = true;
  String? _error;
  String _filter = 'flagged';
  String _query = '';
  final Set<String> _busy = {};

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
      final r = await _repo.reviews();
      if (!mounted) return;
      setState(() {
        _all = r;
        _loading = false;
        if (_filter == 'flagged' && !r.any((x) => x.flagged)) _filter = 'all';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = apiErrorMessage(e, fallback: 'Could not load reviews.');
        });
      }
    }
  }

  List<Review> get _visible {
    final q = _query.trim().toLowerCase();
    return _all.where((r) {
      if (_filter == 'flagged' && !r.flagged) return false;
      if (_filter == 'low' && r.stars > 2) return false;
      return q.isEmpty || '${r.author} ${r.target} ${r.text}'.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _toggleFlag(Review r) async {
    final m = Toast.of(context);
    setState(() => _busy.add(r.id));
    try {
      await _repo.toggleReviewFlag(r.id);
      final i = _all.indexWhere((x) => x.id == r.id);
      if (i != -1 && mounted) setState(() => _all[i] = r.copyWith(flagged: !r.flagged));
      Toast.ok(m, r.flagged ? 'Review kept and flag cleared' : 'Review flagged for follow-up');
    } catch (e) {
      Toast.error(m, apiErrorMessage(e, fallback: 'Could not update the review.'));
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  Future<void> _remove(Review r) async {
    final ok = await confirmAction(
      context,
      title: 'Remove this review?',
      message: 'The ${r.stars}★ review by ${r.author} is deleted from the vendor\'s public profile permanently and their rating is recalculated.',
      confirmLabel: 'Remove review',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final m = Toast.of(context);
    setState(() => _busy.add(r.id));
    try {
      await _repo.deleteReview(r.id);
      if (mounted) setState(() => _all.removeWhere((x) => x.id == r.id));
      Toast.ok(m, 'Review removed');
    } catch (e) {
      Toast.error(m, apiErrorMessage(e, fallback: 'Could not remove the review.'));
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _all.isEmpty) return ErrorView(message: _error!, onRetry: _load);
    if (_loading) return const LoadingView();
    final list = _visible;
    final avg = _all.isEmpty ? 0.0 : _all.map((r) => r.stars).reduce((a, b) => a + b) / _all.length;

    return PageBody(
      onRefresh: _load,
      children: [
        const PageHeader(title: 'Reviews', subtitle: 'Moderate ratings and flagged content across all vendors'),
        const SizedBox(height: 18),
        ResponsiveGrid(minTileWidth: 180, children: [
          StatCard(label: 'Total reviews', value: '${_all.length}', icon: Icons.reviews_outlined, color: AppColors.info),
          StatCard(label: 'Platform average', value: _all.isEmpty ? '—' : '${avg.toStringAsFixed(1)} ★', icon: Icons.star, color: AppColors.gold),
          StatCard(label: 'Flagged', value: '${_all.where((r) => r.flagged).length}', icon: Icons.flag_outlined, color: AppColors.danger),
        ]),
        const SizedBox(height: 16),
        PillBar(children: [
          FilterPill(label: 'Flagged', count: _all.where((r) => r.flagged).length, color: AppColors.danger, selected: _filter == 'flagged', onTap: () => setState(() => _filter = 'flagged')),
          FilterPill(label: '1–2 ★', count: _all.where((r) => r.stars <= 2).length, selected: _filter == 'low', onTap: () => setState(() => _filter = 'low')),
          FilterPill(label: 'All', count: _all.length, selected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
        ]),
        const SizedBox(height: 12),
        SearchField(hint: 'Search reviewer, vendor or text…', onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 14),
        if (list.isEmpty)
          EmptyView(
            icon: _filter == 'flagged' ? Icons.verified_outlined : Icons.reviews_outlined,
            message: _filter == 'flagged' ? 'No flagged reviews' : 'No reviews here',
            detail: _filter == 'flagged' ? 'Nothing needs moderation right now.' : null,
          )
        else
          for (final r in list) Padding(padding: const EdgeInsets.only(bottom: 12), child: _card(r)),
      ],
    );
  }

  Widget _card(Review r) {
    final busy = _busy.contains(r.id);
    return SectionCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          InitialsAvatar(name: r.author, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.author, style: AppType.body(size: 14, weight: FontWeight.w600)),
              Text('on ${r.target.isEmpty ? 'a vendor' : r.target} · ${DateFormat('d MMM yyyy').format(r.date)}',
                  style: AppType.body(size: 12, color: AppColors.textMuted)),
            ]),
          ),
          Row(children: List.generate(5, (i) => Icon(i < r.stars ? Icons.star : Icons.star_border, size: 15, color: AppColors.gold))),
        ]),
        if (r.flagged) ...[const SizedBox(height: 10), StatusChip(label: 'Flagged', color: AppColors.danger)],
        const SizedBox(height: 10),
        Text(r.text.isEmpty ? 'No written comment.' : r.text, style: AppType.body(size: 13.5, color: AppColors.textSecondary, height: 1.55)),
        if (r.reply.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: AppColors.gold.withValues(alpha: .6), width: 3)),
            ),
            child: Text('Vendor reply: ${r.reply}', style: AppType.body(size: 12.5, color: AppColors.textSecondary, height: 1.45)),
          ),
        ],
        const SizedBox(height: 14),
        if (busy)
          ButtonSpinner(color: AppColors.gold)
        else
          Wrap(spacing: 10, runSpacing: 10, children: [
            OutlinedButton.icon(
              onPressed: () => _toggleFlag(r),
              icon: Icon(r.flagged ? Icons.check : Icons.flag_outlined, size: 16),
              label: Text(r.flagged ? 'Keep (clear flag)' : 'Flag'),
            ),
            OutlinedButton.icon(
              onPressed: () => _remove(r),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Remove'),
            ),
          ]),
      ]),
    );
  }
}

/// Kept for screens that still import it.
class FilterToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const FilterToggle({super.key, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: AppType.body(size: 13, color: AppColors.textSecondary)),
      const SizedBox(width: 6),
      Switch(value: value, onChanged: onChanged),
    ]);
  }
}
