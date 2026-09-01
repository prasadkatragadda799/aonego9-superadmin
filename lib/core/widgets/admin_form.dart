import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/typography.dart';
import '../responsive/responsive.dart';

/// Form primitives shared by the directory desks (ads, sessions, partners,
/// team, social). The existing `common.dart` had read-only display widgets
/// plus a search box; everything below is for *editing*, which the console
/// previously had no vocabulary for.

class AdminField extends StatelessWidget {
  final String label;
  final Widget child;
  final String? hint;
  const AdminField({super.key, required this.label, required this.child, this.hint});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(),
              style: AppType.body(size: 10, weight: FontWeight.w700, color: AppColors.textMuted)
                  .copyWith(letterSpacing: 1.4)),
          const SizedBox(height: 6),
          child,
          if (hint != null) ...[
            const SizedBox(height: 5),
            Text(hint!, style: AppType.body(size: 11, color: AppColors.textMuted)),
          ],
        ],
      );
}

class AdminInput extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final int minLines;
  final TextInputType? keyboardType;
  const AdminInput({
    super.key,
    required this.controller,
    this.placeholder = '',
    this.minLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.border),
      borderRadius: BorderRadius.all(Radius.circular(9)),
    );
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: minLines > 1 ? minLines + 3 : 1,
      keyboardType: keyboardType,
      style: AppType.body(size: 13, color: AppColors.textPrimary),
      cursorColor: AppColors.gold,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.bg,
        hintText: placeholder,
        hintStyle: AppType.body(size: 13, color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: border,
        enabledBorder: border,
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.gold),
          borderRadius: BorderRadius.all(Radius.circular(9)),
        ),
      ),
    );
  }
}

class AdminSelect<T> extends StatelessWidget {
  final List<({T value, String label})> options;
  final T value;
  final ValueChanged<T> onChanged;
  const AdminSelect({super.key, required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(9),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            isDense: true,
            dropdownColor: AppColors.surfaceAlt,
            icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textMuted),
            style: AppType.body(size: 13, color: AppColors.textPrimary),
            items: [
              for (final o in options)
                DropdownMenuItem(value: o.value, child: Text(o.label, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      );
}

/// Two fields side by side above mobile, stacked below it.
class AdminRow extends StatelessWidget {
  final Widget left;
  final Widget right;
  const AdminRow({super.key, required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    if (Responsive.isMobile(context)) {
      return Column(children: [left, const SizedBox(height: 14), right]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 14),
        Expanded(child: right),
      ],
    );
  }
}

/// Modal editor shell — title, scrollable body, cancel/save footer.
///
/// [onSave] returns false to keep the dialog open (validation failed), true
/// to close it. Returning a bool rather than closing internally keeps
/// validation in the caller where the fields actually live.
class AdminEditor extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<Widget> Function(BuildContext) fields;
  final Future<bool> Function() onSave;
  final String saveLabel;
  const AdminEditor({
    super.key,
    required this.title,
    required this.fields,
    required this.onSave,
    this.subtitle = '',
    this.saveLabel = 'Save',
  });

  @override
  State<AdminEditor> createState() => _AdminEditorState();
}

class _AdminEditorState extends State<AdminEditor> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(Responsive.isMobile(context) ? 14 : 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceAlt,
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(widget.title, style: AppType.display(size: 21, weight: FontWeight.w600)),
                  if (widget.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(widget.subtitle, style: AppType.body(size: 12.5, color: AppColors.textSecondary)),
                  ],
                ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final f in widget.fields(context)) ...[f, const SizedBox(height: 14)],
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            // Captured before the await so the pop doesn't
                            // reach for a context that may have gone away.
                            final nav = Navigator.of(context);
                            setState(() => _busy = true);
                            final ok = await widget.onSave();
                            if (!mounted) return;
                            setState(() => _busy = false);
                            if (ok) nav.maybePop();
                          },
                    child: Text(_busy ? 'Saving…' : widget.saveLabel),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small pill toggle used in list rows (published / active).
class AdminToggle extends StatelessWidget {
  final bool value;
  final String onLabel;
  final String offLabel;
  final ValueChanged<bool> onChanged;
  const AdminToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.onLabel = 'Live',
    this.offLabel = 'Hidden',
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: value ? AppColors.successSoft : AppColors.surfaceAlt,
            border: Border.all(color: value ? AppColors.success : AppColors.border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: value ? AppColors.success : AppColors.textMuted,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(value ? onLabel : offLabel,
                style: AppType.body(
                    size: 11,
                    weight: FontWeight.w700,
                    color: value ? AppColors.success : AppColors.textMuted)),
          ]),
        ),
      );
}

/// Turns a repository failure into something a human can act on. The console's
/// existing screens each hand-rolled this string mangling; this is the same
/// result in one place.
String adminErrorText(Object err) {
  final msg = err
      .toString()
      .replaceFirst('ApiException', '')
      .replaceAll(RegExp(r'^\(\d+\):\s*'), '')
      .trim();
  return msg.isEmpty ? 'Something went wrong' : msg;
}

void showAdminError(BuildContext context, Object err) =>
    showAdminErrorOn(ScaffoldMessenger.of(context), err);

void showAdminOk(BuildContext context, String msg) =>
    showAdminOkOn(ScaffoldMessenger.of(context), msg);

/// Messenger-first variants for use inside async callbacks.
///
/// Capturing the messenger BEFORE an await is what makes these safe: reaching
/// for `BuildContext` after the await is exactly the pattern that crashes when
/// the dialog has already been dismissed.
void showAdminErrorOn(ScaffoldMessengerState m, Object err) {
  m.showSnackBar(
    SnackBar(content: Text(adminErrorText(err)), backgroundColor: AppColors.danger),
  );
}

void showAdminOkOn(ScaffoldMessengerState m, String msg) =>
    m.showSnackBar(SnackBar(content: Text(msg)));
