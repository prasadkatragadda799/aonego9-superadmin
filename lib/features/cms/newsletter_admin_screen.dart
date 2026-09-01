import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/common.dart';
import '../../data/repositories/admin_repository.dart';

/// Super-admin digest desk. Every published issue carries the poster’s
/// credentials so the user-app newsletter is never anonymous.
class NewsletterAdminScreen extends StatefulWidget {
  const NewsletterAdminScreen({super.key});
  @override
  State<NewsletterAdminScreen> createState() => _NewsletterAdminScreenState();
}

class _NewsletterAdminScreenState extends State<NewsletterAdminScreen> {
  final _repo = AdminRepository();
  final _author = TextEditingController();
  final _email = TextEditingController();
  final _org = TextEditingController();
  final _cred = TextEditingController();
  final _title = TextEditingController();
  final _excerpt = TextEditingController();
  final _body = TextEditingController();
  final _tag = TextEditingController();
  final _city = TextEditingController(text: 'Mumbai');
  String _kind = 'happening';
  bool _loading = true;
  bool _busy = false;
  List<Map<String, dynamic>> _issues = [];
  List<Map<String, dynamic>> _inbox = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _author.dispose();
    _email.dispose();
    _org.dispose();
    _cred.dispose();
    _title.dispose();
    _excerpt.dispose();
    _body.dispose();
    _tag.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final issues = await _repo.newsletters();
    final inbox = await _repo.newsletterContributions();
    if (!mounted) return;
    setState(() {
      _issues = issues;
      _inbox = inbox;
      _loading = false;
    });
  }

  Future<void> _deleteIssue(Map<String, dynamic> issue) async {
    final id = issue['id']?.toString();
    if (id == null || id.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete issue?'),
        content: Text('Remove “${issue['title']}” from the user digest?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteNewsletter(id);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _issues = _issues.where((n) => n['id']?.toString() != id).toList());
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Issue removed')));
  }

  Future<void> _editIssue(Map<String, dynamic> issue) async {
    final title = TextEditingController(text: issue['title']?.toString() ?? '');
    final body = TextEditingController(text: issue['body']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Edit issue'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Headline')),
            const SizedBox(height: 12),
            TextField(controller: body, maxLines: 4, decoration: const InputDecoration(labelText: 'Body')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final id = issue['id']?.toString();
    if (id == null) return;
    final payload = {'title': title.text.trim(), 'body': body.text.trim()};
    try {
      await _repo.updateNewsletter(id, payload);
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved locally — API update failed')));
      setState(() {
        final i = _issues.indexWhere((n) => n['id']?.toString() == id);
        if (i >= 0) _issues[i] = {..._issues[i], ...payload};
      });
    }
  }

  Future<void> _publish() async {
    if (_author.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _org.text.trim().isEmpty ||
        _title.text.trim().isEmpty ||
        _body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Author name, work email, organisation, headline and body are required'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }
    setState(() => _busy = true);
    final payload = {
      'kind': _kind,
      'title': _title.text.trim(),
      'excerpt': _excerpt.text.trim(),
      'body': _body.text.trim(),
      'tag': _tag.text.trim().isEmpty ? (_kind == 'trend' ? 'Trend' : 'Digest') : _tag.text.trim(),
      'city': _city.text.trim(),
      'author': _author.text.trim(),
      'author_email': _email.text.trim(),
      'organisation': _org.text.trim(),
      'credentials_url': _cred.text.trim(),
      'date': DateTime.now().toIso8601String().split('T').first,
    };
    try {
      await _repo.publishNewsletter(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Issue published to the user digest')));
    } catch (e) {
      if (!mounted) return;
      // Still keep it on the desk so the operator can see what they wrote.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Saved on this desk. API: ${e.toString().replaceFirst(RegExp(r'^[^:]+:\\s*'), '')}'),
      ));
    }
    setState(() {
      _issues = [payload, ..._issues];
      _busy = false;
      _title.clear();
      _excerpt.clear();
      _body.clear();
      _tag.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    return ListView(
      padding: EdgeInsets.all(responsiveValue(context, mobile: 16, desktop: 28)),
      children: [
        PageHeader(
          title: 'Newsletter',
          subtitle: 'Publish what’s happening and trends. Every post carries the author’s credentials.',
          actions: [
            ElevatedButton.icon(
              onPressed: _busy ? null : _publish,
              icon: const Icon(Icons.publish_outlined, size: 18),
              label: Text(_busy ? 'Publishing…' : 'Publish issue'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ResponsiveLayout(
          mobile: (_) => Column(children: [
            _composeCard(),
            const SizedBox(height: 16),
            _liveCard(),
            const SizedBox(height: 16),
            _inboxCard(),
          ]),
          desktop: (_) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 5, child: _composeCard()),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: Column(children: [_liveCard(), const SizedBox(height: 16), _inboxCard()]),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _composeCard() {
    return SectionCard(
      title: 'Compose issue',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Poster credentials', style: TextStyle(color: AppColors.textMuted, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _field('Author name', _author, 'As it should appear on the digest'),
          _field('Work email', _email, 'desk@aonego9.com'),
          _field('Organisation / desk', _org, 'AOneGo9 Casting Desk'),
          _field('Credential or site URL', _cred, 'https://…'),
          const Divider(height: 32),
          const Text('The story', style: TextStyle(color: AppColors.textMuted, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('What’s happening'),
                selected: _kind == 'happening',
                onSelected: (_) => setState(() => _kind = 'happening'),
                selectedColor: AppColors.gold.withValues(alpha: .25),
              ),
              ChoiceChip(
                label: const Text('Trend'),
                selected: _kind == 'trend',
                onSelected: (_) => setState(() => _kind = 'trend'),
                selectedColor: AppColors.gold.withValues(alpha: .25),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _field('Headline', _title, 'What should the floor know?'),
          _field('Excerpt', _excerpt, 'One or two lines for the card'),
          _field('Body', _body, 'Dates, city, who is booking, why it matters.', lines: 6),
          Row(children: [
            Expanded(child: _field('City', _city, 'Mumbai')),
            const SizedBox(width: 12),
            Expanded(child: _field('Tag', _tag, 'Casting / Venues / Sets')),
          ]),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c, String hint, {int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        minLines: lines,
        maxLines: lines,
        style: const TextStyle(fontSize: 13.5),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: AppColors.surfaceAlt,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
        ),
      ),
    );
  }

  Widget _liveCard() {
    return SectionCard(
      title: 'Live on the user app',
      child: _issues.isEmpty
          ? const Text('Nothing published yet. The user app still shows the seeded Friday digest until the first issue lands.',
              style: TextStyle(color: AppColors.textMuted, height: 1.5, fontSize: 13))
          : Column(
              children: [
                for (final n in _issues.take(8))
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            (n['kind'] ?? 'happening').toString().toUpperCase(),
                            style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(n['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                            Text(
                              '${n['author'] ?? n['author_name'] ?? ''}  ·  ${n['organisation'] ?? ''}  ·  ${n['city'] ?? ''}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ]),
                        ),
                        if (n['id'] != null) ...[
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _editIssue(n),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                            onPressed: () => _deleteIssue(n),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _inboxCard() {
    return SectionCard(
      title: 'Contributor inbox',
      child: _inbox.isEmpty
          ? const Text('Stories submitted from the user app land here with name, phone, organisation and credential URL for verification.',
              style: TextStyle(color: AppColors.textMuted, height: 1.5, fontSize: 13))
          : Column(
              children: [
                for (final c in _inbox)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(c['title']?.toString() ?? 'Untitled', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${c['author_name'] ?? ''}  ·  ${c['organisation'] ?? ''}  ·  ${c['author_email'] ?? ''}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
