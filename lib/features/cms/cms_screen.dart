import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../data/repositories/admin_repository.dart';

class CmsScreen extends StatefulWidget {
  const CmsScreen({super.key});
  @override
  State<CmsScreen> createState() => _CmsScreenState();
}

class _CmsScreenState extends State<CmsScreen> {
  final _repo = AdminRepository();
  List<CmsBanner> _banners = [];
  List<Category> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await _repo.banners();
    final c = await _repo.categories();
    if (!mounted) return;
    setState(() { _banners = b; _categories = c; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    return ListView(
      padding: EdgeInsets.all(responsiveValue(context, mobile: 16, desktop: 28)),
      children: [
        PageHeader(
          title: 'CMS & Content',
          subtitle: 'Banners, categories and platform content',
          actions: [ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.add, size: 18), label: const Text('New Banner'))],
        ),
        const SizedBox(height: 24),
        ResponsiveLayout(
          mobile: (_) => Column(children: [_bannersCard(), const SizedBox(height: 16), _categoriesCard()]),
          desktop: (_) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _bannersCard()),
            const SizedBox(width: 16),
            Expanded(child: _categoriesCard()),
          ]),
        ),
      ],
    );
  }

  Widget _bannersCard() {
    return SectionCard(
      title: 'Promotional Banners',
      child: Column(
        children: [
          for (final b in _banners)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.goldDark, AppColors.gold]), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.image_outlined, color: Color(0xFF1A1407), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  Text(b.placement, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ])),
                Switch(value: b.active, activeColor: AppColors.gold, onChanged: (_) {}),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _categoriesCard() {
    return SectionCard(
      title: 'Categories',
      actions: [TextButton(onPressed: () {}, child: const Text('Add'))],
      child: Column(
        children: [
          for (final c in _categories)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Icon(Icons.category_outlined, size: 18, color: c.active ? AppColors.gold : AppColors.textMuted),
                const SizedBox(width: 12),
                Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5))),
                Text('${c.listings} listings', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(width: 12),
                StatusChip(label: c.active ? 'Active' : 'Hidden', color: c.active ? AppColors.success : AppColors.textMuted),
              ]),
            ),
        ],
      ),
    );
  }
}
