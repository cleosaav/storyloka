import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/repositories/chat_repository.dart';
import '../auth/auth_controller.dart';

/// Halaman AI Chat — PRD §9.3.
///
/// UI gelembung chat: pengguna kanan (Deep Teal), asisten kiri (Pale Peach/surfaceDark).
/// Mode demo: balasan berlabel "Jawaban contoh (mode demo)" dari FakeChatRepository.
/// Chip saran prompt di state kosong.
/// Tombol hapus riwayat dengan dialog konfirmasi.
class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  static const Uuid _uuid = Uuid();

  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;

  static const _suggestions = [
    'Rekomendasi novel fantasi',
    'Tips membaca lebih konsisten',
    'Jelaskan konsep buku Atomic Habits',
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<ChatRepository>();
      final history = await repo.getHistory();
      if (mounted) setState(() { _messages = history; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _send([String? overrideText]) async {
    final text = (overrideText ?? _inputCtrl.text).trim();
    if (text.isEmpty || _isSending) return;

    _inputCtrl.clear();
    setState(() => _isSending = true);

    final auth = context.read<AuthController>();
    final userId = auth.currentUser?.id ?? 'demo';
    final repo = context.read<ChatRepository>();

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      userId: userId,
      role: 'user',
      content: text,
      createdAt: DateTime.now(),
    );

    await repo.saveMessage(userMsg);
    setState(() => _messages = [..._messages, userMsg]);
    _scrollToBottom();

    try {
      final history = _messages.length > 10 ? _messages.sublist(_messages.length - 10) : _messages;
      final reply = await repo.sendMessage(text, history);

      final assistantMsg = ChatMessage(
        id: _uuid.v4(),
        userId: userId,
        role: 'model',
        content: reply,
        createdAt: DateTime.now(),
      );
      await repo.saveMessage(assistantMsg);
      if (mounted) {
        setState(() {
          _messages = [..._messages, assistantMsg];
          _isSending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _inputCtrl.text = text;
          _messages = _messages.where((m) => m.id != userMsg.id).toList();
        });
        final rawErr = e.toString().replaceFirst('Exception: ', '');
        final errorMsg = rawErr.isNotEmpty ? rawErr : 'Gagal terhubung ke AI. Coba lagi.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Kirim ulang',
              textColor: AppColors.white,
              onPressed: () => _send(text),
            ),
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Riwayat Chat?'),
        content: const Text('Semua percakapan akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final repo = context.read<ChatRepository>();
      await repo.clearHistory();
      setState(() => _messages = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEmpty = _messages.isEmpty && !_isSending;

    return Scaffold(
      appBar: AppBar(
        title: Text('AI Chat',
          style: AppText.sectionHeading(color: isDark ? AppColors.inkDark : AppColors.ink)),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                color: isDark ? AppColors.mutedDark : AppColors.mutedGray),
              tooltip: 'Hapus riwayat',
              onPressed: _confirmClearHistory,
            ),
        ],
      ),
      body: Column(
        children: [
          // Demo banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: 6),
            color: AppColors.sageGreen.withValues(alpha: 0.15),
            child: Text(
              'Mode Demo — Balasan tidak menggunakan AI nyata',
              style: AppText.caption(color: AppColors.deepTeal).copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),

          // Daftar pesan / empty state
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.deepTeal))
                : isEmpty
                    ? _EmptyState(
                        isDark: isDark,
                        suggestions: _suggestions,
                        onSuggestion: _send,
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.pageMargin,
                          vertical: AppSpacing.m,
                        ),
                        itemCount: _messages.length + (_isSending ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i == _messages.length) {
                            return _TypingIndicator(isDark: isDark);
                          }
                          return _Bubble(
                            message: _messages[i],
                            isDark: isDark,
                          );
                        },
                      ),
          ),

          // Chip saran saat ada pesan
          if (!isEmpty && !_isLoading)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin),
                itemCount: _suggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s),
                itemBuilder: (ctx, i) => _SuggestionChip(
                  label: _suggestions[i],
                  isDark: isDark,
                  onTap: () => _send(_suggestions[i]),
                ),
              ),
            ),

          // Input area
          _InputBar(
            controller: _inputCtrl,
            isDark: isDark,
            isSending: _isSending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// ─── Bubble pesan ─────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;

  const _Bubble({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: isDark ? AppColors.surfaceDark : AppColors.palePeach,
              child: Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.deepTeal),
            ),
            const SizedBox(width: AppSpacing.s),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.l,
                vertical: AppSpacing.m,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.deepTeal
                    : (isDark ? AppColors.surfaceDark : AppColors.palePeach),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
              ),
              child: Text(
                message.content,
                style: AppText.body(
                  color: isUser
                      ? AppColors.white
                      : (isDark ? AppColors.inkDark : AppColors.ink),
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: AppSpacing.s),
        ],
      ),
    );
  }
}

// ─── Typing indicator ─────────────────────────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  final bool isDark;
  const _TypingIndicator({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: isDark ? AppColors.surfaceDark : AppColors.palePeach,
          child: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.deepTeal),
        ),
        const SizedBox(width: AppSpacing.s),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.m),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.palePeach,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Dot(delay: 0),
              const SizedBox(width: 4),
              _Dot(delay: 150),
              const SizedBox(width: 4),
              _Dot(delay: 300),
            ],
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Opacity(
        opacity: 0.3 + _anim.value * 0.7,
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: AppColors.deepTeal,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ─── Empty State dengan chip saran ───────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isDark;
  final List<String> suggestions;
  final ValueChanged<String> onSuggestion;

  const _EmptyState({
    required this.isDark,
    required this.suggestions,
    required this.onSuggestion,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageMargin,
          vertical: AppSpacing.m,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.palePeach.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 40, color: AppColors.deepTeal),
            ),
            const SizedBox(height: AppSpacing.l),
            Text('StoryLoka AI',
              style: AppText.sectionHeading(
                color: isDark ? AppColors.inkDark : AppColors.ink,
              )),
            const SizedBox(height: AppSpacing.s),
            Text('Tanya apa saja seputar buku dan membaca!',
              style: AppText.body(
                color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
              ),
              textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xl),
            Text('Coba tanya:',
              style: AppText.caption(
                color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
              ).copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.m),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.s,
              children: suggestions.map((s) => _SuggestionChip(
                label: s,
                isDark: isDark,
                onTap: () => onSuggestion(s),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.s),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.warmIvory,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
          ),
        ),
        child: Text(label,
          style: AppText.caption(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ).copyWith(fontWeight: FontWeight.w500)),
      ),
    );
  }
}

// ─── Input Bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final bool isSending;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.isDark,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageMargin,
          vertical: AppSpacing.m,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgDark : AppColors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.warmIvory,
                  borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
                  ),
                ),
                child: TextField(
                  controller: controller,
                  maxLength: 500,
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  style: AppText.body(color: isDark ? AppColors.inkDark : AppColors.ink),
                  decoration: InputDecoration(
                    hintText: 'Tanya seputar buku...',
                    hintStyle: AppText.body(
                      color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.l,
                      vertical: AppSpacing.m,
                    ),
                    counterText: '',
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            AnimatedBuilder(
              animation: controller,
              builder: (_, _) {
                final canSend = controller.text.trim().isNotEmpty && !isSending;
                return IconButton(
                  tooltip: 'Kirim pesan',
                  onPressed: canSend ? onSend : null,
                  style: IconButton.styleFrom(
                    backgroundColor: canSend ? AppColors.deepTeal : AppColors.sageGreen.withValues(alpha: 0.3),
                    foregroundColor: AppColors.white,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(12),
                    minimumSize: const Size(48, 48),
                  ),
                  icon: isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppColors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 20),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
