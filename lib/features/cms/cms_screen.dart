import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/typography.dart';
import '../../core/responsive/responsive.dart';
import '../../core/utils/launch_util.dart';
import '../../core/widgets/common.dart';
import '../../data/api/api_errors.dart';
import '../../data/models/models.dart';
import '../../data/repositories/admin_repository.dart';

/// Promotional banners and marketplace categories.
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
  String? _error;
  final Set<String> _busy = {};

  static const _placements = ['home_hero', 'browse_top', 'profile_sidebar', 'events', 'newsletter'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _banners.isEmpty && _categories.isEmpty;
      _error = null;
    });
    try {
      final r = await Future.wait<Object?>([_repo.banners(), _repo.categories()]);
      if (!mounted) return;
      setState(() {
        _banners = r[0] as List<CmsBanner>;
        _categories = (r[1] as List<Category>)..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = apiErrorMessage(e, fallback: 'Could not load content.');
        });
      }
    }
  }

  Future<void> _toggleBanner(CmsBanner b, bool v) async {
    final m = Toast.of(context);
    final i = _banners.indexWhere((x) => x.id == b.id);
    setState(() {
      if (i != -1) _banners[i] = b.copyWith(active: v);
      _busy.add(b.id);
    });
    try {
      await _repo.updateBanner(b.id, {'active': v});
      Toast.ok(m, v ? '“${b.title}” is live' : '“${b.title}” is hidden');
    } catch (e) {
      if (i != -1 && mounted) setState(() => _banners[i] = b);
      Toast.error(m, apiErrorMessage(e, fallback: 'Could not update the banner.'));
    } finally {
      if (mounted) setState(() => _busy.remove(b.id));
    }
  }

  Future<void> _deleteBanner(CmsBanner b) async {
    final ok = await confirmAction(context, title: 'Delete banner?', message: '“${b.title}” is removed from the marketplace.', confirmLabel: 'Delete', destructive: true);
    if (!ok || !mounted) return;
    final m = Toast.of(context);
    try {
      await _repo.deleteBanner(b.id);
      if (mounted) setState(() => _banners.removeWhere((x) => x.id == b.id));
      Toast.ok(m, 'Banner deleted');
    } catch (e) {
      Toast.error(m, apiErrorMessage(e, fallback: 'Could not delete the banner.'));
    }
  }

  Future<void> _toggleCategory(Category c) async {
    final m = Toast.of(context);
    final i = _categories.indexWhere((x) => x.id == c.id);
    setState(() {
      if (i != -1) _categories[i] = c.copyWith(active: !c.active);
      _busy.add(c.id);
    });
    try {
      await _repo.toggleCategory(c.id);
      Toast.ok(m, c.active ? '${c.name} hidden from browse' : '${c.name} visible in browse');
    } catch (e) {
      if (i != -1 && mounted) setState(() => _categories[i] = c);
      Toast.error(m, apiErrorMessage(e, fallback: 'Could not update the category.'));
    } finally {
      if (mounted) setState(() => _busy.remove(c.id));
    }
  }

  Future<void> _newBanner() async {
    final done = await showAdaptiveSheet<bool>(context, builder: (_) => _BannerForm(repo: _repo, placements: _placements));
    if (done == true && mounted) {
      Toast.ok(Toast.of(context), 'Banner created');
      _load();
    }
  }

  Future<void> _newCategory() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add category'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'e.g. Choreographers')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    c.dispose();
    if (name == null || name.length < 2 || !mounted) return;
    if (_categories.any((x) => x.name.toLowerCase() == name.toLowerCase())) {
      Toast.info(Toast.of(context), '$name already exists');
      return;
    }
    final m = Toast.of(context);
    try {
      await _repo.createCategory(name);
      Toast.ok(m, '$name added');
      _load();
    } catch (e) {
      Toast.error(m, apiErrorMessage(e, fallback: 'Could not add the category.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _banners.isEmpty && _categories.isEmpty) return ErrorView(message: _error!, onRetry: _load);
    if (_loading) return const LoadingView();
    return PageBody(
      onRefresh: _load,
      children: [
        PageHeader(
          title: 'CMS & Content',
          subtitle: 'Promotional banners and the categories clients browse by',
          actions: [ElevatedButton.icon(onPressed: _newBanner, icon: const Icon(Icons.add, size: 18), label: const Text('New banner'))],
        ),
        const SizedBox(height: 20),
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
      title: 'Promotional banners',
      actions: [StatusChip(label: '${_banners.where((b) => b.active).length} live', color: AppColors.success)],
      child: _banners.isEmpty
          ? EmptyView(
              icon: Icons.image_outlined,
              message: 'No banners yet',
              action: OutlinedButton.icon(onPressed: _newBanner, icon: const Icon(Icons.add, size: 16), label: const Text('Create banner')),
            )
          : Column(children: [
              for (final b in _banners)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    Container(
                      width: 64,
                      height: 44,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: AppColors.posterWash), borderRadius: BorderRadius.circular(8)),
                      child: b.imageUrl.startsWith('http')
                          ? Image.network(b.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, color: AppColors.posterInk))
                          : const Icon(Icons.image_outlined, color: AppColors.posterInk, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(b.title.isEmpty ? 'Untitled banner' : b.title, overflow: TextOverflow.ellipsis, style: AppType.body(size: 13.5, weight: FontWeight.w600)),
                        Text(b.placement.replaceAll('_', ' '), style: AppType.mono(size: 11.5)),
                      ]),
                    ),
                    if (b.link.startsWith('http'))
                      IconButton(tooltip: 'Open link', onPressed: () => openExternal(context, Uri.parse(b.link)), icon: const Icon(Icons.open_in_new, size: 18)),
                    IconButton(tooltip: 'Delete', onPressed: () => _deleteBanner(b), icon: Icon(Icons.delete_outline, size: 18, color: AppColors.danger)),
                    Switch(value: b.active, onChanged: _busy.contains(b.id) ? null : (v) => _toggleBanner(b, v)),
                  ]),
                ),
            ]),
    );
  }

  Widget _categoriesCard() {
    return SectionCard(
      title: 'Categories',
      actions: [TextButton.icon(onPressed: _newCategory, icon: const Icon(Icons.add, size: 16), label: const Text('Add'))],
      child: _categories.isEmpty
          ? const EmptyView(icon: Icons.category_outlined, message: 'No categories yet')
          : Column(children: [
              for (final c in _categories)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Icon(Icons.category_outlined, size: 18, color: c.active ? AppColors.gold : AppColors.textMuted),
                    const SizedBox(width: 12),
                    Expanded(child: Text(c.name, style: AppType.body(size: 13.5, weight: FontWeight.w500, color: c.active ? AppColors.textPrimary : AppColors.textMuted))),
                    Text('${c.listings} listings', style: AppType.mono(size: 11.5)),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: c.active ? 'Visible in browse — tap to hide' : 'Hidden — tap to show',
                      child: Switch(value: c.active, onChanged: _busy.contains(c.id) ? null : (_) => _toggleCategory(c)),
                    ),
                  ]),
                ),
            ]),
    );
  }
}

class _BannerForm extends StatefulWidget {
  final AdminRepository repo;
  final List<String> placements;
  const _BannerForm({required this.repo, required this.placements});
  @override
  State<_BannerForm> createState() => _BannerFormState();
}

class _BannerFormState extends State<_BannerForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _image = TextEditingController();
  final _link = TextEditingController();
  late String _placement = widget.placements.first;
  bool _active = true;
  bool _saving = false;
  String _error = '';

  @override
  void dispose() {
    _title.dispose();
    _image.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      await widget.repo.createBanner(CmsBanner(
        id: '',
        title: _title.text.trim(),
        placement: _placement,
        active: _active,
        imageUrl: _image.text.trim(),
        link: _link.text.trim(),
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = apiErrorMessage(e, fallback: 'Could not create the banner.');
        });
      }
    }
  }

  String? _url(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    return Uri.tryParse(s)?.hasScheme == true && s.startsWith('http') ? null : 'Enter a full https:// URL';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('New banner', style: AppType.display(size: 20)),
          const SizedBox(height: 16),
          if (_error.isNotEmpty) ...[InlineNotice(message: _error, icon: Icons.error_outline, color: AppColors.danger), const SizedBox(height: 12)],
          LabeledField(
            label: 'Title',
            child: TextFormField(controller: _title, decoration: const InputDecoration(hintText: 'e.g. Wedding season — 20% off shoots'), validator: (v) => (v ?? '').trim().length < 3 ? 'Enter a title' : null),
          ),
          LabeledField(
            label: 'Placement',
            child: DropdownButtonFormField<String>(
              initialValue: _placement,
              dropdownColor: AppColors.surfaceAlt,
              items: [for (final p in widget.placements) DropdownMenuItem(value: p, child: Text(p.replaceAll('_', ' ')))],
              onChanged: (v) => setState(() => _placement = v ?? _placement),
            ),
          ),
          LabeledField(label: 'Image URL', hint: 'A 16:6 image works best.', child: TextFormField(controller: _image, decoration: const InputDecoration(hintText: 'https://…'), validator: _url)),
          LabeledField(label: 'Link (optional)', child: TextFormField(controller: _link, decoration: const InputDecoration(hintText: 'https://…'), validator: _url)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _active,
            onChanged: (v) => setState(() => _active = v),
            title: const Text('Live immediately'),
          ),
          const SizedBox(height: 6),
          SizedBox(height: 48, child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const ButtonSpinner() : const Text('Create banner'))),
        ]),
      ),
    );
  }
}
