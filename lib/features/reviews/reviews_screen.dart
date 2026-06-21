import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../data/repositories/admin_repository.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});
  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final _repo = AdminRepository();
  List<Review> _all = [];
  bool _loading = true;
  bool _flaggedOnly = false;

  @override
  void initState() {
    super.initState();
    _repo.reviews().then((r) {
      if (mounted) setState(() { _all = r; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = _flaggedOnly ? _all.where((r) => r.flagged).toList() : _all;
    return ListView(
      padding: EdgeInsets.all(responsiveValue(context, mobile: 16, desktop: 28)),
      children: [
        PageHeader(
          title: 'Reviews',
          subtitle: 'Moderate ratings and flagged content',
          actions: [
            FilterToggle(label: 'Flagged only', value: _flaggedOnly, onChanged: (v) => setState(() => _flaggedOnly = v)),
          ],
        ),
        const SizedBox(height: 20),
        if (_loading) const LoadingView() else if (list.isEmpty) const EmptyView() else
          ...list.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: SectionCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      InitialsAvatar(name: r.author, size: 38),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.author, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('on ${r.target} · ${DateFormat('d MMM yyyy').format(r.date)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ])),
                      Row(children: List.generate(5, (i) => Icon(i < r.stars ? Icons.star : Icons.star_border, size: 16, color: AppColors.gold))),
                      if (r.flagged) const Padding(padding: EdgeInsets.only(left: 10), child: StatusChip(label: 'Flagged', color: AppColors.danger)),
                    ]),
                    const SizedBox(height: 12),
                    Text(r.text, style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
                    const SizedBox(height: 14),
                    Row(children: [
                      OutlinedButton(onPressed: () => _act(r, 'kept'), child: const Text('Keep')),
                      const SizedBox(width: 10),
                      OutlinedButton(onPressed: () => _act(r, 'hidden'), style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger), child: const Text('Remove')),
                    ]),
                  ]),
                ),
              )),
      ],
    );
  }

  void _act(Review r, String action) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Review by ${r.author} $action'), backgroundColor: AppColors.surfaceAlt));
  }
}

class FilterToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const FilterToggle({super.key, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      const SizedBox(width: 6),
      Switch(value: value, activeColor: AppColors.gold, onChanged: onChanged),
    ]);
  }
}
