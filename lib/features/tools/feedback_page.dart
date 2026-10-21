import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/models/feedback_entry.dart';
import '../../../data/repositories/feedback_repository.dart';
import '../auth/auth_controller.dart';

/// Halaman Kesan & Pesan — PRD §7.7.1.
///
/// Form: Nama (prefill), Kesan, Pesan. Semua wajib.
/// Hasil langsung tampil sebagai daftar di bawah form (terbaru di atas).
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  static const Uuid _uuid = Uuid();

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  final _impressionCtrl = TextEditingController();
  final _suggestionCtrl = TextEditingController();

  List<FeedbackEntry> _entries = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    _nameCtrl = TextEditingController(text: auth.currentUser?.name ?? '');
    _loadEntries();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _impressionCtrl.dispose();
    _suggestionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final repo = context.read<FeedbackRepository>();
      final list = await repo.getAll();
      if (mounted) setState(() { _entries = list; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = 'Gagal memuat data: $e'; });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      final repo = context.read<FeedbackRepository>();
      final auth = context.read<AuthController>();

      final entry = FeedbackEntry(
        id: _uuid.v4(),
        userId: auth.currentUser?.id ?? 'demo',
        name: _nameCtrl.text.trim(),
        impression: _impressionCtrl.text.trim(),
        suggestion: _suggestionCtrl.text.trim(),
        createdAt: DateTime.now(),
      );
      await repo.save(entry);

      _impressionCtrl.clear();
      _suggestionCtrl.clear();

      if (mounted) {
        AppSnackBar.show(context, message: 'Kesan & Pesan berhasil disimpan!', type: SnackBarType.info);
        await _loadEntries();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppSnackBar.show(context, message: 'Gagal menyimpan: $e', type: SnackBarType.error);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Kesan & Pesan',
          style: AppText.sectionHeading(color: isDark ? AppColors.inkDark : AppColors.ink)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.deepTeal))
          : ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageMargin,
                vertical: AppSpacing.m,
              ),
              children: [
                // Form
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Kesan & Pesan Mata Kuliah',
                          style: AppText.cardHeading(color: isDark ? AppColors.inkDark : AppColors.ink)),
                        const SizedBox(height: AppSpacing.xs),
                        Text('Pemrograman Aplikasi Mobile',
                          style: AppText.caption(color: isDark ? AppColors.mutedDark : AppColors.mutedGray)),
                        const SizedBox(height: AppSpacing.l),
                        _FormField(
                          label: 'Nama',
                          controller: _nameCtrl,
                          hint: 'Nama Anda',
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                        ),
                        const SizedBox(height: AppSpacing.m),
                        _FormField(
                          label: 'Kesan',
                          controller: _impressionCtrl,
                          hint: 'Kesan Anda selama mengikuti mata kuliah ini...',
                          maxLines: 3,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Kesan wajib diisi' : null,
                        ),
                        const SizedBox(height: AppSpacing.m),
                        _FormField(
                          label: 'Pesan',
                          controller: _suggestionCtrl,
                          hint: 'Saran atau pesan untuk mata kuliah ini...',
                          maxLines: 3,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Pesan wajib diisi' : null,
                        ),
                        const SizedBox(height: AppSpacing.l),
                        PrimaryButton(
                          label: _isSaving ? 'Menyimpan...' : 'Simpan',
                          icon: Icons.send_rounded,
                          onPressed: _isSaving ? null : _submit,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Daftar entri
                if (_entries.isNotEmpty) ...[
                  Text('Kesan & Pesan Tersimpan',
                    style: AppText.sectionHeading(color: isDark ? AppColors.inkDark : AppColors.ink)),
                  const SizedBox(height: AppSpacing.m),
                  ..._entries.map((e) => _FeedbackCard(entry: e, isDark: isDark)),
                ],

                if (_errorMessage != null)
                  Center(child: Text(_errorMessage!,
                    style: AppText.body(color: AppColors.error))),
              ],
            ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final FormFieldValidator<String>? validator;

  const _FormField({
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: (_) => validator?.call(controller.text),
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            label: label,
            controller: controller,
            hintText: hint,
            maxLines: maxLines,
            errorText: field.errorText,
            keyboardType: maxLines > 1 ? TextInputType.multiline : TextInputType.text,
            textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
            onChanged: (_) => field.didChange(controller.text),
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final FeedbackEntry entry;
  final bool isDark;

  const _FeedbackCard({required this.entry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.sageGreen.withValues(alpha: 0.3),
                  child: Text(
                    entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
                    style: AppText.bodyMedium(color: AppColors.deepTeal)
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.name,
                        style: AppText.bodyMedium(
                          color: isDark ? AppColors.inkDark : AppColors.ink,
                        ).copyWith(fontWeight: FontWeight.bold)),
                      Text(
                        _formatDate(entry.createdAt),
                        style: AppText.caption(
                          color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            _Row(label: 'Kesan', value: entry.impression, isDark: isDark),
            const SizedBox(height: AppSpacing.s),
            _Row(label: 'Pesan', value: entry.suggestion, isDark: isDark),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _Row({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(label,
            style: AppText.caption(
              color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
            ).copyWith(fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(value,
            style: AppText.body(
              color: isDark ? AppColors.inkDark : AppColors.ink,
            )),
        ),
      ],
    );
  }
}
