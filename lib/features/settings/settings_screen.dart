import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/responsive/responsive.dart';
import '../../core/widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _commission = 15;
  bool _autoApproveKyc = false;
  bool _emailAlerts = true;
  bool _payoutHold = true;

  final _admins = const [
    ('Super Admin', 'admin@aonego9.com', 'Owner'),
    ('Meera Iyer', 'meera@aonego9.com', 'Operations'),
    ('Rahul Dev', 'rahul@aonego9.com', 'Finance'),
    ('Sana Q', 'sana@aonego9.com', 'Support'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(responsiveValue(context, mobile: 16, desktop: 28)),
      children: [
        PageHeader(title: 'Settings', subtitle: 'Platform configuration and admin team'),
        const SizedBox(height: 24),
        ResponsiveLayout(
          mobile: (_) => Column(children: [_platformCard(), const SizedBox(height: 16), _teamCard()]),
          desktop: (_) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _platformCard()),
            const SizedBox(width: 16),
            Expanded(child: _teamCard()),
          ]),
        ),
      ],
    );
  }

  Widget _platformCard() {
    return SectionCard(
      title: 'Platform Settings',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Platform commission: ${_commission.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
        Slider(value: _commission, min: 0, max: 30, divisions: 30, activeColor: AppColors.gold, label: '${_commission.toStringAsFixed(0)}%', onChanged: (v) => setState(() => _commission = v)),
        const Divider(height: 24),
        _toggle('Auto-approve KYC', 'Skip manual review for verified documents', _autoApproveKyc, (v) => setState(() => _autoApproveKyc = v)),
        _toggle('Email alerts', 'Receive notifications for key platform events', _emailAlerts, (v) => setState(() => _emailAlerts = v)),
        _toggle('Hold payouts 48h', 'Delay vendor payouts after booking completion', _payoutHold, (v) => setState(() => _payoutHold = v)),
      ]),
    );
  }

  Widget _toggle(String title, String sub, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5)),
          Text(sub, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ])),
        Switch(value: value, activeColor: AppColors.gold, onChanged: onChanged),
      ]),
    );
  }

  Widget _teamCard() {
    return SectionCard(
      title: 'Admin Team',
      actions: [TextButton(onPressed: () {}, child: const Text('Invite'))],
      child: Column(
        children: [
          for (final a in _admins)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                InitialsAvatar(name: a.$1, size: 36),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.$1, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  Text(a.$2, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ])),
                StatusChip(label: a.$3, color: AppColors.info),
              ]),
            ),
        ],
      ),
    );
  }
}
