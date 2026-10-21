import 'dart:math';

/// Status permainan Snake — PRD §10.1.
enum SnakeStatus { ready, running, paused, gameOver }

/// Arah gerak ular.
enum SnakeDirection { up, down, left, right }

/// Satu sel pada papan (kolom, baris).
class SnakeCell {
  final int col;
  final int row;

  const SnakeCell(this.col, this.row);

  @override
  bool operator ==(Object other) =>
      other is SnakeCell && other.col == col && other.row == row;

  @override
  int get hashCode => Object.hash(col, row);

  @override
  String toString() => '($col,$row)';
}

/// Engine murni Dart untuk permainan Snake — PRD §10.1.
///
/// Tanpa dependensi Flutter. Dapat diinstansiasi dan dites secara mandiri.
///
/// Papan: [cols] kolom × [rows] baris.
/// Posisi awal: ular panjang 3 di tengah, arah kanan.
/// Kecepatan awal: 200 ms/tick, turun 8 ms setiap 3 buku, minimum 90 ms.
class SnakeEngine {
  // ─── Konfigurasi Papan ───
  final int cols;
  final int rows;
  final Random _random;

  // ─── State ───
  late List<SnakeCell> snake; // kepala di indeks 0
  late SnakeDirection direction;
  late SnakeDirection _pendingDirection;
  late SnakeCell book;
  late int score;
  late SnakeStatus status;

  // ─── Konstanta Kecepatan ───
  static const int _initialIntervalMs = 200;
  static const int _speedDecreasePerThree = 8;
  static const int _minIntervalMs = 90;
  static const int _booksPerSpeedUp = 3;

  SnakeEngine({
    required this.cols,
    required this.rows,
    Random? random,
  }) : _random = random ?? Random() {
    _init();
  }

  /// Inisialisasi / reset permainan.
  void _init() {
    // Ular panjang 3 di tengah, arah kanan
    final midRow = rows ~/ 2;
    final midCol = cols ~/ 2;
    snake = [
      SnakeCell(midCol, midRow),
      SnakeCell(midCol - 1, midRow),
      SnakeCell(midCol - 2, midRow),
    ];
    direction = SnakeDirection.right;
    _pendingDirection = SnakeDirection.right;
    score = 0;
    status = SnakeStatus.ready;
    _spawnBook();
  }

  /// Reset ke state awal untuk bermain ulang.
  void reset() => _init();

  /// Mulai permainan (dari state ready).
  void start() {
    if (status == SnakeStatus.ready || status == SnakeStatus.gameOver) {
      if (status == SnakeStatus.gameOver) _init();
      status = SnakeStatus.running;
    }
  }

  /// Jeda / lanjut permainan.
  void togglePause() {
    if (status == SnakeStatus.running) {
      status = SnakeStatus.paused;
    } else if (status == SnakeStatus.paused) {
      status = SnakeStatus.running;
    }
  }

  /// Paksa pause (saat app ke background).
  void pause() {
    if (status == SnakeStatus.running) {
      status = SnakeStatus.paused;
    }
  }

  /// Interval tick saat ini (ms) — berkurang seiring skor.
  int get currentIntervalMs {
    final booksEaten = score ~/ 10;
    final speedUps = booksEaten ~/ _booksPerSpeedUp;
    final interval = _initialIntervalMs - speedUps * _speedDecreasePerThree;
    return interval.clamp(_minIntervalMs, _initialIntervalMs);
  }

  /// Ubah arah — tidak boleh berbalik 180°.
  void setDirection(SnakeDirection newDir) {
    if (!_isOpposite(direction, newDir)) {
      _pendingDirection = newDir;
    }
  }

  bool _isOpposite(SnakeDirection a, SnakeDirection b) {
    return (a == SnakeDirection.up && b == SnakeDirection.down) ||
        (a == SnakeDirection.down && b == SnakeDirection.up) ||
        (a == SnakeDirection.left && b == SnakeDirection.right) ||
        (a == SnakeDirection.right && b == SnakeDirection.left);
  }

  /// Satu langkah tick — gerakkan ular, cek tabrakan, makan buku.
  ///
  /// Kembalikan true jika game over.
  bool tick() {
    if (status != SnakeStatus.running) return false;

    // Terapkan pending direction
    direction = _pendingDirection;

    final head = snake.first;
    final newHead = _nextCell(head, direction);

    // Cek tabrakan dinding
    if (newHead.col < 0 ||
        newHead.col >= cols ||
        newHead.row < 0 ||
        newHead.row >= rows) {
      status = SnakeStatus.gameOver;
      return true;
    }

    // Cek tabrakan tubuh sendiri (tidak termasuk ekor yang akan dipindah)
    final bodyWithoutTail = snake.sublist(0, snake.length - 1);
    if (bodyWithoutTail.contains(newHead)) {
      status = SnakeStatus.gameOver;
      return true;
    }

    // Gerakkan ular
    final newSnake = [newHead, ...snake];

    if (newHead == book) {
      // Makan buku — ular memanjang, score bertambah
      snake = newSnake;
      score += 10;
      _spawnBook();
    } else {
      // Buang ekor
      snake = newSnake.sublist(0, newSnake.length - 1);
    }

    return false;
  }

  SnakeCell _nextCell(SnakeCell cell, SnakeDirection dir) {
    return switch (dir) {
      SnakeDirection.up => SnakeCell(cell.col, cell.row - 1),
      SnakeDirection.down => SnakeCell(cell.col, cell.row + 1),
      SnakeDirection.left => SnakeCell(cell.col - 1, cell.row),
      SnakeDirection.right => SnakeCell(cell.col + 1, cell.row),
    };
  }

  /// Spawn buku di sel kosong acak.
  void _spawnBook() {
    final occupied = Set<SnakeCell>.from(snake);
    final emptyCells = <SnakeCell>[];
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        final cell = SnakeCell(c, r);
        if (!occupied.contains(cell)) {
          emptyCells.add(cell);
        }
      }
    }
    if (emptyCells.isEmpty) {
      // Papan penuh — game over (kasus ekstrem)
      status = SnakeStatus.gameOver;
      return;
    }
    book = emptyCells[_random.nextInt(emptyCells.length)];
  }
}
