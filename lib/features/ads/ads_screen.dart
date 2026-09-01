import 'package:flutter/material.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/admin_form.dart';
import '../../core/widgets/common.dart';
import '../../data/models/directory_models.dart';
import '../../data/repositories/admin_repository.dart';

/// Ads & Promotions — the video and photo creatives the marketplace shows in
/// its display slots. A creative either promotes a vendor/artist profile or
/// the AOneGo9 site itself.
class AdsScreen extends StatefulWidget {
  const AdsScreen({super.key});
  @override
  State<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends State<AdsScreen> {
  final _repo = AdminRepository();
  List<AdCreative> _ads = [];
  bool _loading = true;
  String _filter = 'all'; // all | video | photo

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ads = await _repo.ads();
    if (!mounted) return;
    setState(() {
      _ads = ads;
      _loading = false;
    });
  }

  List<AdCreative> get _visible =>
      _filter == 'all' ? _ads : _ads.where((a) => a.media == _filter).toList();

  Future<void> _toggle(AdCreative ad, bool active) async {
    final i = _ads.indexWhere((x) => x.id == ad.id);
    if (i != -1) setState(() => _ads[i] = _ads[i].copyWith(active: active));
    try {
      await _repo.setAdActive(ad.id, active);
    } catch (err) {
      // Optimistic update rolled back — the row must not lie about what the
      // marketplace is actually serving.
      if (i != -1 && mounted) setState(() => _ads[i] = ad);
      if (mounted) showAdminError(context, err);
    }
  }

  Future<void> _delete(AdCreative ad) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete creative?'),
        content: Text('“${ad.headline}” will stop showing in the marketplace immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteAd(ad.id);
      await _load();
      if (mounted) showAdminOk(context, 'Creative deleted');
    } catch (err) {
      if (mounted) showAdminError(context, err);
    }
  }

  void _edit([AdCreative? existing]) {
    showDialog<void>(
      context: context,
      builder: (_) => _AdEditor(
        existing: existing,
        onSaved: () {
          _load();
          if (mounted) showAdminOk(context, existing == null ? 'Creative created' : 'Creative updated');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    final live = _ads.where((a) => a.active).length;

    return ListView(
      padding: EdgeInsets.all(responsiveValue(context, mobile: 16, desktop: 28)),
      children: [
        PageHeader(
          eyebrow: 'Display advertising',
          title: 'Ads & Promotions',
          subtitle: 'Video and photo creatives shown across the marketplace',
          actions: [
            ElevatedButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New creative'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(spacing: 14, runSpacing: 14, children: [
          StatCard(label: 'Creatives', value: '${_ads.length}', icon: Icons.campaign_outlined, color: AppColors.gold),
          StatCard(label: 'Live now', value: '$live', icon: Icons.play_circle_outline, color: AppColors.success),
          StatCard(
            label: 'Video',
            value: '${_ads.where((a) => a.isVideo).length}',
            icon: Icons.videocam_outlined,
            color: AppColors.info,
          ),
          StatCard(
            label: 'Total clicks',
            value: '${_ads.fold<int>(0, (s, a) => s + a.clicks)}',
            icon: Icons.ads_click,
            color: AppColors.gold,
          ),
        ]),
        const SizedBox(height: 20),
        SectionCard(
          title: 'Creatives',
          actions: [
            _Seg(
              options: const [('all', 'All'), ('video', 'Video'), ('photo', 'Photo')],
              value: _filter,
              onChanged: (v) => setState(() => _filter = v),
            ),
          ],
          child: _visible.isEmpty
              ? const EmptyView(message: 'No creatives yet — add one to fill the display slot')
              : Column(
                  children: [
                    for (final ad in _visible) _row(ad),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _row(AdCreative ad) {
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
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (ad.isVideo ? AppColors.info : AppColors.gold).withValues(alpha: .14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(ad.isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                  size: 20, color: ad.isVideo ? AppColors.info : AppColors.gold),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(ad.headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body(size: 14, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  ad.profileId.isNotEmpty
                      ? 'Promotes profile: ${ad.profileName.isEmpty ? ad.profileId : ad.profileName}'
                      : (ad.websiteUrl.isEmpty ? 'No destination set' : ad.websiteUrl),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body(
                    size: 12,
                    color: ad.profileId.isEmpty && ad.websiteUrl.isEmpty
                        ? AppColors.warning
                        : AppColors.textSecondary,
                  ),
                ),
              ]),
            ),
            if (!narrow) ...[
              const SizedBox(width: 12),
              _metric('${ad.impressions}', 'Impressions'),
              const SizedBox(width: 18),
              _metric('${ad.clicks}', 'Clicks'),
              const SizedBox(width: 18),
              _metric('${ad.ctr.toStringAsFixed(1)}%', 'CTR'),
              const SizedBox(width: 18),
            ],
            AdminToggle(value: ad.active, onLabel: 'Serving', offLabel: 'Paused', onChanged: (v) => _toggle(ad, v)),
            IconButton(
              onPressed: () => _edit(ad),
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Edit',
              color: AppColors.textSecondary,
            ),
            IconButton(
              onPressed: () => _delete(ad),
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Delete',
              color: AppColors.textMuted,
            ),
          ]),
          if (narrow) ...[
            const SizedBox(height: 10),
            Row(children: [
              _metric('${ad.impressions}', 'Impr.'),
              const SizedBox(width: 20),
              _metric('${ad.clicks}', 'Clicks'),
              const SizedBox(width: 20),
              _metric('${ad.ctr.toStringAsFixed(1)}%', 'CTR'),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _metric(String value, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: AppType.display(size: 15, weight: FontWeight.w600)),
          Text(label, style: AppType.body(size: 10, color: AppColors.textMuted)),
        ],
      );
}

class _Seg extends StatelessWidget {
  final List<(String, String)> options;
  final String value;
  final ValueChanged<String> onChanged;
  const _Seg({required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final o in options)
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

class _AdEditor extends StatefulWidget {
  final AdCreative? existing;
  final VoidCallback onSaved;
  const _AdEditor({this.existing, required this.onSaved});

  @override
  State<_AdEditor> createState() => _AdEditorState();
}

class _AdEditorState extends State<_AdEditor> {
  late final _headline = TextEditingController(text: widget.existing?.headline ?? '');
  late final _sub = TextEditingController(text: widget.existing?.sub ?? '');
  late final _image = TextEditingController(text: widget.existing?.imageUrl ?? '');
  late final _video = TextEditingController(text: widget.existing?.videoUrl ?? '');
  late final _profileId = TextEditingController(text: widget.existing?.profileId ?? '');
  late final _profileName = TextEditingController(text: widget.existing?.profileName ?? '');
  late final _website = TextEditingController(text: widget.existing?.websiteUrl ?? '');
  late final _label = TextEditingController(text: widget.existing?.label ?? 'AOneGo9');
  late final _city = TextEditingController(text: widget.existing?.city ?? '');
  late String _media = widget.existing?.media ?? 'photo';

  @override
  void dispose() {
    for (final c in [_headline, _sub, _image, _video, _profileId, _profileName, _website, _label, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminEditor(
      title: widget.existing == null ? 'New creative' : 'Edit creative',
      subtitle: 'Shown in the marketplace display slot with an “AD” disclosure',
      saveLabel: widget.existing == null ? 'Create' : 'Save',
      fields: (c) => [
        AdminRow(
          left: AdminField(
            label: 'Media type',
            child: AdminSelect<String>(
              options: const [(value: 'photo', label: 'Photo'), (value: 'video', label: 'Video')],
              value: _media,
              onChanged: (v) => setState(() => _media = v),
            ),
          ),
          right: AdminField(
            label: 'Badge label',
            child: AdminInput(controller: _label, placeholder: 'Featured Artist / AOneGo9'),
          ),
        ),
        AdminField(label: 'Headline', child: AdminInput(controller: _headline, placeholder: 'One line that earns the click')),
        AdminField(label: 'Sub copy', child: AdminInput(controller: _sub, placeholder: 'Supporting line', minLines: 2)),
        AdminField(
          label: _media == 'video' ? 'Poster image URL' : 'Image URL',
          hint: _media == 'video' ? 'Shown while the video loads, and if it fails' : null,
          child: AdminInput(controller: _image, placeholder: 'https://…'),
        ),
        if (_media == 'video')
          AdminField(
            label: 'Video URL',
            hint: 'Plays muted and looping. MP4 or WebM.',
            child: AdminInput(controller: _video, placeholder: 'https://…/clip.mp4'),
          ),
        AdminRow(
          left: AdminField(
            label: 'Promoted profile ID',
            hint: 'Leave blank to send traffic to the website instead',
            child: AdminInput(controller: _profileId, placeholder: 'vendor id'),
          ),
          right: AdminField(
            label: 'Profile name',
            child: AdminInput(controller: _profileName, placeholder: 'Shown under the CTA'),
          ),
        ),
        AdminRow(
          left: AdminField(label: 'Website URL', child: AdminInput(controller: _website, placeholder: 'https://aonego9.com')),
          right: AdminField(label: 'City', child: AdminInput(controller: _city, placeholder: 'Mumbai')),
        ),
      ],
      onSave: () async {
        final messenger = ScaffoldMessenger.of(context);
        if (_headline.text.trim().isEmpty) {
          showAdminErrorOn(messenger, 'A headline is required');
          return false;
        }
        if (_profileId.text.trim().isEmpty && _website.text.trim().isEmpty) {
          // An ad with nowhere to go is worse than no ad — it burns a click.
          showAdminErrorOn(messenger, 'Give the creative a destination: a profile ID or a website URL');
          return false;
        }
        if (_media == 'video' && _video.text.trim().isEmpty && _image.text.trim().isEmpty) {
          showAdminErrorOn(messenger, 'A video creative needs a video URL or at least a poster image');
          return false;
        }
        try {
          await AdminRepository().saveAd(AdCreative(
            id: widget.existing?.id ?? '',
            media: _media,
            headline: _headline.text.trim(),
            sub: _sub.text.trim(),
            imageUrl: _image.text.trim(),
            videoUrl: _video.text.trim(),
            profileId: _profileId.text.trim(),
            profileName: _profileName.text.trim(),
            websiteUrl: _website.text.trim(),
            label: _label.text.trim(),
            city: _city.text.trim(),
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
