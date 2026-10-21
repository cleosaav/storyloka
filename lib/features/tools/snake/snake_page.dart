import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/sensor_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/models/game_score.dart';
import '../../../data/repositories/score_repository.dart';
import '../../../features/auth/auth_controller.dart';
import 'snake_engine.dart';

/// Halaman Mini Game Snake — PRD §10.1.
///
/// Engine murni Dart ([SnakeEngine]) dipisah dari UI.
/// Papan digambar dengan [CustomPainter]; buku digambar sebagai buku kecil
/// (persegi panjang softApricot + punggung deepTeal), bukan emoji.
class SnakePage extends StatefulWidget {
  const SnakePage({super.key});

  @override
  State<SnakePage> createState() => _SnakePageState();
}

class _SnakePageState extends State<SnakePage> with WidgetsBindingObserver {
  static const int _cols = 15;
  static const String _gameKey = 'snake';
  static const Uuid _uuid = Uuid();

  late SnakeEngine _engine;
  Timer? _ticker;
  int _highScore = 0;
  bool _scoreLoaded = false;
  bool _tiltControlEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engine = SnakeEngine(cols: _cols, rows: _cols);
    _loadHighScore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    SensorService.instance.stopTiltListening();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _engine.pause();
      _ticker?.cancel();
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadHighScore() async {
    try {
      final repo = context.read<ScoreRepository>();
      final hs = await repo.getHighScore(_gameKey);
      if (mounted) {
        setState(() {
          _highScore = hs;
          _scoreLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _scoreLoaded = true);
    }
  }

  void _startGame() {
    _engine.start();
    _scheduleTick();
    setState(() {});
  }

  void _scheduleTick() {
    _ticker?.cancel();
    _ticker = Timer(Duration(milliseconds: _engine.currentIntervalMs), () {
      if (!mounted) return;
      final gameOver = _engine.tick();
      setState(() {});
      if (gameOver) {
        _onGameOver();
      } else if (_engine.status == SnakeStatus.running) {
        _scheduleTick(); // Reschedule with potentially updated interval
      }
    });
  }

  void _togglePause() {
    _engine.togglePause();
    if (_engine.status == SnakeStatus.running) {
      _scheduleTick();
    } else {
      _ticker?.cancel();
    }
    setState(() {});
  }

  void _toggleTiltControl(bool val) {
    setState(() => _tiltControlEnabled = val);
    if (val) {
      SensorService.instance.startTiltListening(
        onDirection: (dir) {
          if (!mounted) return;
          if (_engine.status == SnakeStatus.ready) _startGame();
          _engine.setDirection(dir);
        },
      );
    } else {
      SensorService.instance.stopTiltListening();
    }
  }

  Future<void> _onGameOver() async {
    _ticker?.cancel();
    HapticFeedback.mediumImpact();

    final score = _engine.score;
    if (score > 0) {
      try {
        final repo = context.read<ScoreRepository>();
        final auth = context.read<AuthController>();
        final userId = auth.currentUser?.id ?? 'demo';

        await repo.saveScore(GameScore(
          id: _uuid.v4(),
          userId: userId,
          game: _gameKey,
          score: score,
          playedAt: DateTime.now(),
        ));

        final newHigh = await repo.getHighScore(_gameKey);
        if (mounted) setState(() => _highScore = newHigh);
      } catch (_) {}
    }

    if (mounted) _showGameOverSheet();
  }

  void _showGameOverSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              Text(
                'Game Over!',
                style: AppText.sectionHeading(
                  color: isDark ? AppColors.inkDark : AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(children: [
                    Text(
                      '${_engine.score}',
                      style: AppText.displayLarge(
                        color: isDark ? AppColors.primaryDark : AppColors.deepTeal,
                        fontSize: 40,
                      ),
                    ),
                    Text('Books', style: AppText.caption(color: isDark ? AppColors.mutedDark : AppColors.mutedGray)),
                  ]),
                  Container(width: 1, height: 48, color: isDark ? AppColors.borderDark : AppColors.borderNeutral),
                  Column(children: [
                    Text(
                      '$_highScore',
                      style: AppText.displayLarge(
                        color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
                        fontSize: 40,
                      ),
                    ),
                    Text('Best', style: AppText.caption(color: isDark ? AppColors.mutedDark : AppColors.mutedGray)),
                  ]),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Play again',
                icon: Icons.replay_rounded,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() => _engine.reset());
                  _startGame();
                },
              ),
              const SizedBox(height: AppSpacing.m),
              SecondaryButton(
                label: 'Back to Tools',
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.pop();
                },
              ),
              const SizedBox(height: AppSpacing.s),
            ],
          ),
        );
      },
    );
  }

  void _handleSwipe(DragUpdateDetails details) {
    if (_engine.status != SnakeStatus.running) return;
    final dx = details.delta.dx;
    final dy = details.delta.dy;
    if (dx.abs() > dy.abs()) {
      _engine.setDirection(dx > 0 ? SnakeDirection.right : SnakeDirection.left);
    } else {
      _engine.setDirection(dy > 0 ? SnakeDirection.down : SnakeDirection.up);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final booksCount = _engine.score ~/ 10;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Book Snake',
          style: AppText.sectionHeading(
            color: isDark ? AppColors.inkDark : AppColors.ink,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageMargin,
            vertical: AppSpacing.m,
          ),
          child: Column(
            children: [
              // Skor baris
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ScoreCard(
                    label: 'Books',
                    value: '$booksCount',
                    isDark: isDark,
                    highlight: true,
                  ),
                  if (_engine.status == SnakeStatus.running ||
                      _engine.status == SnakeStatus.paused)
                    GestureDetector(
                      onTap: _togglePause,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.l,
                          vertical: AppSpacing.s,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : AppColors.warmIvory,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _engine.status == SnakeStatus.running
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 18,
                              color: isDark ? AppColors.inkDark : AppColors.ink,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _engine.status == SnakeStatus.running ? 'Pause' : 'Resume',
                              style: AppText.button(
                                color: isDark ? AppColors.inkDark : AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  _ScoreCard(
                    label: 'Best',
                    value: _scoreLoaded ? '${_highScore ~/ 10}' : '-',
                    isDark: isDark,
                    highlight: false,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.m),

              // Papan permainan dalam AppCard
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.warmIvory,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderNeutral,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.deepTeal.withValues(alpha: 0.07),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    child: GestureDetector(
                      onPanUpdate: _handleSwipe,
                      onTap: () {
                        if (_engine.status == SnakeStatus.ready) {
                          _startGame();
                        }
                      },
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          return Stack(
                            children: [
                              CustomPaint(
                                size: Size(constraints.maxWidth, constraints.maxHeight),
                                painter: _SnakePainter(
                                  engine: _engine,
                                  cols: _cols,
                                  isDark: isDark,
                                ),
                              ),
                              // Overlay "Tap to start"
                              if (_engine.status == SnakeStatus.ready)
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.xl,
                                      vertical: AppSpacing.l,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (isDark ? AppColors.bgDark : AppColors.ink)
                                          .withValues(alpha: 0.72),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.menu_book_rounded,
                                          color: AppColors.softApricot,
                                          size: 36,
                                        ),
                                        const SizedBox(height: AppSpacing.s),
                                        Text(
                                          'Tap to start',
                                          style: AppText.bodyMedium(
                                            color: AppColors.white,
                                          ).copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Kumpulkan buku sebanyak mungkin!',
                                          style: AppText.caption(
                                            color: AppColors.sageGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              // Overlay "Paused"
                              if (_engine.status == SnakeStatus.paused)
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.xl,
                                      vertical: AppSpacing.l,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (isDark ? AppColors.bgDark : AppColors.ink)
                                          .withValues(alpha: 0.72),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      'Paused',
                                      style: AppText.sectionHeading(
                                        color: AppColors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s),

              // Opsi Tilt Control (Gyroscope — PRD §10.4)
              FilterChip(
                avatar: Icon(
                  Icons.screen_rotation_rounded,
                  size: 16,
                  color: _tiltControlEnabled ? AppColors.white : AppColors.deepTeal,
                ),
                label: Text(
                  'Tilt Control (Gyroscope)',
                  style: AppText.caption(
                    color: _tiltControlEnabled
                        ? AppColors.white
                        : (isDark ? AppColors.inkDark : AppColors.ink),
                  ),
                ),
                selected: _tiltControlEnabled,
                onSelected: _toggleTiltControl,
                selectedColor:
                    isDark ? AppColors.primaryDark : AppColors.deepTeal,
                backgroundColor:
                    isDark ? AppColors.surfaceDark : AppColors.warmIvory,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color:
                        isDark ? AppColors.borderDark : AppColors.borderNeutral,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s),

              // D-Pad kontrol
              _DPad(
                onDirection: (dir) {
                  if (_engine.status == SnakeStatus.ready) _startGame();
                  _engine.setDirection(dir);
                },
              ),
              const SizedBox(height: AppSpacing.s),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Snake CustomPainter ──────────────────────────────────────────────────────

class _SnakePainter extends CustomPainter {
  final SnakeEngine engine;
  final int cols;
  final bool isDark;

  const _SnakePainter({
    required this.engine,
    required this.cols,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / cols;
    final rows = (size.height / cellW).floor();
    final cellH = size.height / rows;

    // Latar
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = isDark ? AppColors.surfaceDark : AppColors.warmIvory,
    );

    // Grid halus
    final gridPaint = Paint()
      ..color = (isDark ? AppColors.borderDark : AppColors.borderNeutral)
          .withValues(alpha: 0.4)
      ..strokeWidth = 0.5;
    for (int c = 0; c <= cols; c++) {
      canvas.drawLine(Offset(c * cellW, 0), Offset(c * cellW, size.height), gridPaint);
    }
    for (int r = 0; r <= rows; r++) {
      canvas.drawLine(Offset(0, r * cellH), Offset(size.width, r * cellH), gridPaint);
    }

    // Ular — tubuh
    final bodyPaint = Paint()..color = AppColors.oceanTeal;
    final headPaint = Paint()..color = AppColors.deepTeal;
    const bodyRadius = Radius.circular(4);

    for (int i = 0; i < engine.snake.length; i++) {
      final cell = engine.snake[i];
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          cell.col * cellW + 1,
          cell.row * cellH + 1,
          cellW - 2,
          cellH - 2,
        ),
        bodyRadius,
      );
      canvas.drawRRect(rect, i == 0 ? headPaint : bodyPaint);
    }

    // Mata pada kepala
    if (engine.snake.isNotEmpty) {
      final head = engine.snake.first;
      final eyePaint = Paint()..color = AppColors.white;
      final cx = head.col * cellW + cellW / 2;
      final cy = head.row * cellH + cellH / 2;
      canvas.drawCircle(Offset(cx - cellW * 0.15, cy - cellH * 0.1), cellW * 0.1, eyePaint);
      canvas.drawCircle(Offset(cx + cellW * 0.15, cy - cellH * 0.1), cellW * 0.1, eyePaint);
    }

    // Buku — persegi panjang softApricot + punggung deepTeal (bukan emoji)
    final bookBodyPaint = Paint()..color = AppColors.softApricot;
    final bookSpinePaint = Paint()..color = AppColors.deepTeal;

    final bx = engine.book.col * cellW;
    final by = engine.book.row * cellH;
    final bookMargin = cellW * 0.1;
    final spineW = cellW * 0.2;

    // Badan buku
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bx + bookMargin, by + bookMargin, cellW - bookMargin * 2, cellH - bookMargin * 2),
        const Radius.circular(3),
      ),
      bookBodyPaint,
    );
    // Punggung buku (strip kiri)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bx + bookMargin, by + bookMargin, spineW, cellH - bookMargin * 2),
        const Radius.circular(3),
      ),
      bookSpinePaint,
    );
    // Garis halaman (2 garis horisontal pada body)
    final linePaint = Paint()
      ..color = AppColors.deepTeal.withValues(alpha: 0.35)
      ..strokeWidth = 0.8;
    final lineX1 = bx + bookMargin + spineW + 2;
    final lineX2 = bx + cellW - bookMargin - 2;
    final lineY1 = by + cellH * 0.38;
    final lineY2 = by + cellH * 0.58;
    canvas.drawLine(Offset(lineX1, lineY1), Offset(lineX2, lineY1), linePaint);
    canvas.drawLine(Offset(lineX1, lineY2), Offset(lineX2, lineY2), linePaint);
  }

  @override
  bool shouldRepaint(_SnakePainter old) => true;
}

// ─── D-Pad Widget ─────────────────────────────────────────────────────────────

class _DPad extends StatelessWidget {
  final ValueChanged<SnakeDirection> onDirection;

  const _DPad({required this.onDirection});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget btn(SnakeDirection dir, IconData icon) {
      return SizedBox(
        width: 56,
        height: 56,
        child: Material(
          color: isDark ? AppColors.surfaceDark : AppColors.warmIvory,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onDirection(dir),
            child: Icon(
              icon,
              size: 28,
              color: isDark ? AppColors.inkDark : AppColors.deepTeal,
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(SnakeDirection.up, Icons.keyboard_arrow_up_rounded),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            btn(SnakeDirection.left, Icons.keyboard_arrow_left_rounded),
            const SizedBox(width: 4),
            btn(SnakeDirection.down, Icons.keyboard_arrow_down_rounded),
            const SizedBox(width: 4),
            btn(SnakeDirection.right, Icons.keyboard_arrow_right_rounded),
          ],
        ),
      ],
    );
  }
}

// ─── Score Card ───────────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final bool highlight;

  const _ScoreCard({
    required this.label,
    required this.value,
    required this.isDark,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.s),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.warmIvory,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight
              ? AppColors.deepTeal.withValues(alpha: 0.4)
              : (isDark ? AppColors.borderDark : AppColors.borderNeutral),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppText.sectionHeading(
              color: highlight
                  ? (isDark ? AppColors.primaryDark : AppColors.deepTeal)
                  : (isDark ? AppColors.mutedDark : AppColors.mutedGray),
            ),
          ),
          Text(
            label,
            style: AppText.caption(
              color: isDark ? AppColors.mutedDark : AppColors.mutedGray,
            ),
          ),
        ],
      ),
    );
  }
}
