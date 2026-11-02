import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/typography.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/common.dart';
import '../../data/api/api_client.dart';
import '../../data/api/api_errors.dart';
import '../../data/repositories/admin_repository.dart';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _city = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String _error = '';
  final _repo = AdminRepository();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = '');
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await _repo.login(_email.text.trim().toLowerCase(), _password.text, city: _city.text.trim());
      TextInput.finishAutofillContext();
      if (!mounted) return;
      final from = GoRouterState.of(context).uri.queryParameters['from'];
      context.go(from != null && from.startsWith('/') && !from.startsWith('/login') ? from : '/dashboard');
    } catch (e) {
      if (!mounted) return;
      final bad = e is ApiException && (e.statusCode == 401 || e.statusCode == 400);
      final forbidden = e is ApiException && e.statusCode == 403;
      setState(() => _error = bad
          ? 'That email and password do not match an admin account.'
          : forbidden
              ? 'This account does not have admin access${_city.text.trim().isEmpty ? '' : ' for ${_city.text.trim()}'}.'
              : apiErrorMessage(e, fallback: 'Could not sign in.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgot() async {
    final c = TextEditingController(text: _email.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset admin password'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Admin resets are approved by another administrator. Your request lands in the Leads inbox as a password reset.'),
            const SizedBox(height: 16),
            TextField(controller: c, autofocus: true, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'you@aonego9.com')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final v = c.text.trim().toLowerCase();
              if (_emailRe.hasMatch(v)) Navigator.pop(ctx, v);
            },
            child: const Text('Send request'),
          ),
        ],
      ),
    );
    c.dispose();
    if (email == null || !mounted) return;
    final m = Toast.of(context);
    try {
      await _repo.requestPasswordReset(email);
      Toast.ok(m, 'Request sent — another admin will verify and reset your password.');
    } catch (e) {
      Toast.error(m, apiErrorMessage(e, fallback: 'Could not send the request.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    final form = _form();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        if (mobile)
          AmbientBackground(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 56, 20, 32),
                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: form),
                ),
              ),
            ),
          )
        else
          Row(children: [
            Expanded(flex: Responsive.isTablet(context) ? 4 : 5, child: const _BrandPanel()),
            Expanded(
              flex: 5,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400), child: form),
                ),
              ),
            ),
          ]),
        const Positioned(top: 8, right: 8, child: SafeArea(child: ThemeCycleButton())),
      ]),
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          if (Responsive.isMobile(context)) ...[
            const Center(child: BrandLogo(size: 26)),
            const SizedBox(height: 6),
            Center(child: Text('SUPER ADMIN', style: AppType.eyebrow(color: AppColors.gold, size: 9.5))),
            const SizedBox(height: 28),
          ],
          Text('Welcome back', style: AppType.display(size: 26)),
          const SizedBox(height: 4),
          Text('Sign in to the Super Admin console', style: AppType.body(size: 13.5, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          if (_error.isNotEmpty) ...[
            InlineNotice(message: _error, icon: Icons.error_outline, color: AppColors.danger),
            const SizedBox(height: 16),
          ],
          LabeledField(
            label: 'Email',
            child: TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
              decoration: const InputDecoration(hintText: 'you@aonego9.com', prefixIcon: Icon(Icons.mail_outline, size: 19)),
              validator: (v) => _emailRe.hasMatch((v ?? '').trim()) ? null : 'Enter a valid email address',
            ),
          ),
          LabeledField(
            label: 'Password',
            child: TextFormField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outline, size: 19),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v ?? '').isEmpty ? 'Enter your password' : null,
            ),
          ),
          LabeledField(
            label: 'City scope (optional)',
            hint: 'For city-scoped admins. Leave blank to manage all cities.',
            child: TextFormField(
              controller: _city,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.words,
              onFieldSubmitted: (_) => _login(),
              decoration: const InputDecoration(hintText: 'e.g. Mumbai', prefixIcon: Icon(Icons.location_city_outlined, size: 19)),
            ),
          ),
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _forgot, child: const Text('Forgot password?'))),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: ElevatedButton(onPressed: _loading ? null : _login, child: _loading ? const ButtonSpinner() : const Text('Sign in')),
          ),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.lock_outline, size: 13, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text('Restricted to AOneGo9 administrators. Activity is logged.',
                  textAlign: TextAlign.center, style: AppType.body(size: 11.5, color: AppColors.textMuted)),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();
  @override
  Widget build(BuildContext context) {
    const points = [
      (Icons.verified_user_outlined, 'Approve & verify', 'Vendors, KYC, subscription receipts and advance payments.'),
      (Icons.insights_outlined, 'See the whole marketplace', 'Bookings, revenue, signups and category share.'),
      (Icons.web_outlined, 'Run the storefront', 'Events, ads, newsletter, partners, team and CMS content.'),
    ];
    return Container(
      decoration: BoxDecoration(border: Border(right: BorderSide(color: AppColors.border))),
      child: AmbientBackground(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 48),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  const ConsoleLockup(label: 'Super Admin', size: 30),
                  const SizedBox(height: 44),
                  const Eyebrow('Platform owner console'),
                  const SizedBox(height: 16),
                  Text.rich(TextSpan(
                    style: AppType.display(size: 36, weight: FontWeight.w600, height: 1.2),
                    children: [
                      const TextSpan(text: 'Govern the entire '),
                      TextSpan(text: 'marketplace', style: TextStyle(color: AppColors.gold)),
                      const TextSpan(text: '.'),
                    ],
                  )),
                  const SizedBox(height: 32),
                  for (final p in points)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: .14), borderRadius: BorderRadius.circular(10)),
                          child: Icon(p.$1, size: 18, color: AppColors.gold),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.$2, style: AppType.body(size: 13.5, weight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(p.$3, style: AppType.body(size: 12.5, color: AppColors.textSecondary, height: 1.45)),
                          ]),
                        ),
                      ]),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
