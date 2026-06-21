import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/typography.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: 'admin@aonego9.com');
  final _password = TextEditingController(text: 'demo1234');
  bool _obscure = true;
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600)); // TODO: POST /api/admin/auth/login
    if (mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final form = _LoginForm(
      email: _email,
      password: _password,
      obscure: _obscure,
      loading: _loading,
      onToggle: () => setState(() => _obscure = !_obscure),
      onSubmit: _login,
    );

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Responsive.isMobile(context)
          ? SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: form)))
          : Row(
              children: [
                const Expanded(child: _BrandPanel()),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(48),
                      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 380), child: form),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();
  @override
  Widget build(BuildContext context) {
    return AmbientBackground(
      accent: AppColors.gold,
      child: Padding(
        padding: const EdgeInsets.all(56),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58, height: 58, alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.goldLight, AppColors.goldDark]),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 22, offset: const Offset(0, 8))],
              ),
              child: Text('A9', style: AppType.display(color: const Color(0xFF1A1407), weight: FontWeight.w700, size: 22)),
            ),
            const SizedBox(height: 30),
            const Eyebrow('Platform Owner Console'),
            const SizedBox(height: 16),
            Text.rich(
              TextSpan(
                style: AppType.display(size: 40, weight: FontWeight.w600, height: 1.08),
                children: [
                  const TextSpan(text: 'Govern the\nentire '),
                  TextSpan(text: 'marketplace', style: AppType.display(size: 40, weight: FontWeight.w600, height: 1.08, color: AppColors.gold, fontStyle: FontStyle.italic)),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 380,
              child: Text(
                'Approve vendors, manage talent and users, oversee bookings & payments, and control platform content from one place.',
                style: AppType.body(size: 14, color: AppColors.textSecondary, height: 1.6),
              ),
            ),
            const SizedBox(height: 40),
            Row(children: [
              _stat('7', 'Vendors'),
              _stat('1.2k+', 'Talent'),
              _stat('₹6.4Cr', 'GMV'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _stat(String v, String l) => Padding(
        padding: const EdgeInsets.only(right: 36),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v, style: AppType.display(color: AppColors.gold, size: 26, weight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(l, style: AppType.eyebrow(color: AppColors.textMuted, size: 11)),
        ]),
      );
}

class _LoginForm extends StatelessWidget {
  final TextEditingController email, password;
  final bool obscure, loading;
  final VoidCallback onToggle, onSubmit;
  const _LoginForm({
    required this.email,
    required this.password,
    required this.obscure,
    required this.loading,
    required this.onToggle,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Welcome back', style: AppType.display(size: 28, weight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Sign in to the Super Admin console', style: AppType.body(color: AppColors.textSecondary)),
        const SizedBox(height: 32),
        const Text('Email', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: email, decoration: const InputDecoration(hintText: 'you@aonego9.com')),
        const SizedBox(height: 18),
        const Text('Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: password,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: '••••••••',
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
              onPressed: onToggle,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: () {}, child: const Text('Forgot password?')),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: loading ? null : onSubmit,
            child: loading
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1407)))
                : const Text('Sign In'),
          ),
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text('Demo build • credentials pre-filled', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ),
      ],
    );
  }
}
