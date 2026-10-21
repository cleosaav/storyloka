/// Tes Unit Wajib Fase A4 — LedgerService (PRD §10.2)
///
/// Mencakup semua skenario yang diwajibkan:
/// 1. Rantai valid — verifyChain mengembalikan isValid: true
/// 2. Data diubah — verifyChain mendeteksi blok tidak valid
/// 3. previousHash diubah — verifyChain mendeteksi tautan hash terputus
/// 4. Idempotensi appendFinishedBook — tidak membuat blok duplikat
/// 5. Hash selalu diawali prefix "00" (Proof of Work)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:storyloka/core/services/ledger_service.dart';
import 'package:storyloka/data/models/ledger_block.dart';
import 'package:storyloka/data/models/user_book.dart';
import 'package:storyloka/data/repositories/ledger_repository.dart';

// ─── In-Memory LedgerRepository untuk keperluan test ──────────────────────────

class InMemoryLedgerRepository implements LedgerRepository {
  final List<LedgerBlock> _blocks = [];

  @override
  Future<List<LedgerBlock>> getBlocks() async =>
      List.unmodifiable(_blocks);

  @override
  Future<void> saveBlock(LedgerBlock block) async {
    _blocks.add(block);
  }

  @override
  Future<LedgerBlock?> getLastBlock() async =>
      _blocks.isEmpty ? null : _blocks.last;

  void clear() => _blocks.clear();
}

// ─── Helper: buat UserBook minimal untuk test ─────────────────────────────────

UserBook _makeBook({
  String id = 'book-001',
  String title = 'Test Book',
  String userId = 'user-test',
  BookStatus status = BookStatus.finished,
  int? pageCount = 200,
  int? rating = 4,
}) {
  return UserBook(
    id: id,
    userId: userId,
    googleBooksId: 'gbooks-$id',
    title: title,
    listType: ListType.collection,
    status: status,
    currentPage: pageCount ?? 0,
    pageCount: pageCount,
    rating: rating,
    createdAt: DateTime.utc(2025, 1, 1),
    updatedAt: DateTime.utc(2025, 1, 2),
    finishedAt: DateTime.utc(2025, 1, 2),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late InMemoryLedgerRepository repo;
  late LedgerService service;

  setUp(() {
    repo = InMemoryLedgerRepository();
    service = LedgerService(repo);
  });

  group('LedgerService — PRD §10.2', () {
    // ─── Tes 1: Rantai valid ────────────────────────────────────────────────
    test('T4-01: verifyChain mengembalikan isValid:true untuk rantai valid',
        () async {
      final book = _makeBook(id: 'book-001');
      await service.appendFinishedBook(book,
          userId: 'user-test', totalReadingSeconds: 3600);

      final blocks = await repo.getBlocks();
      expect(blocks.length, 2, reason: 'genesis + 1 blok buku');

      final result = LedgerService.verifyChain(blocks);
      expect(result.isValid, isTrue);
      expect(result.invalidIndex, isNull);
    });

    // ─── Tes 2: Data diubah setelah mining ─────────────────────────────────
    test('T4-02: verifyChain mendeteksi data diubah (hash tidak cocok)',
        () async {
      final book = _makeBook(id: 'book-002');
      await service.appendFinishedBook(book,
          userId: 'user-test', totalReadingSeconds: 1200);

      final blocks = await repo.getBlocks();
      expect(blocks.length, 2);

      // Tamper: ubah data blok terakhir
      final tamperedBlock = LedgerBlock(
        id: blocks[1].id,
        userId: blocks[1].userId,
        blockIndex: blocks[1].blockIndex,
        timestamp: blocks[1].timestamp,
        dataJson: {
          ...blocks[1].dataJson,
          'title': 'JUDUL DIPALSUKAN', // data diubah
        },
        previousHash: blocks[1].previousHash,
        nonce: blocks[1].nonce,
        hash: blocks[1].hash, // hash lama, tidak dihitung ulang
        createdAt: blocks[1].createdAt,
      );

      final tamperedChain = [blocks[0], tamperedBlock];
      final result = LedgerService.verifyChain(tamperedChain);

      expect(result.isValid, isFalse);
      expect(result.invalidIndex, 1);
      expect(result.reason, contains('hash'));
    });

    // ─── Tes 3: previousHash dimodifikasi ──────────────────────────────────
    test('T4-03: verifyChain mendeteksi previousHash yang diubah', () async {
      final book = _makeBook(id: 'book-003');
      await service.appendFinishedBook(book,
          userId: 'user-test', totalReadingSeconds: 600);

      final blocks = await repo.getBlocks();
      expect(blocks.length, 2);

      // Tamper: ganti previousHash blok[1] dengan hash palsu
      final fakeHash = '00${'a' * 62}'; // format valid tapi salah
      final tamperedBlock = LedgerBlock(
        id: blocks[1].id,
        userId: blocks[1].userId,
        blockIndex: blocks[1].blockIndex,
        timestamp: blocks[1].timestamp,
        dataJson: blocks[1].dataJson,
        previousHash: fakeHash, // previousHash dipalsukan
        nonce: blocks[1].nonce,
        hash: blocks[1].hash,
        createdAt: blocks[1].createdAt,
      );

      final tamperedChain = [blocks[0], tamperedBlock];
      final result = LedgerService.verifyChain(tamperedChain);

      expect(result.isValid, isFalse);
      // Bisa karena previousHash tidak cocok ATAU hash re-compute berbeda
      expect(result.invalidIndex, greaterThanOrEqualTo(0));
    });

    // ─── Tes 4: Idempotensi appendFinishedBook ──────────────────────────────
    test(
        'T4-04: appendFinishedBook idempoten — panggil dua kali tidak buat duplikat',
        () async {
      final book = _makeBook(id: 'book-004');

      final block1 = await service.appendFinishedBook(book,
          userId: 'user-test', totalReadingSeconds: 7200);
      final block2 = await service.appendFinishedBook(book,
          userId: 'user-test', totalReadingSeconds: 7200);

      // Kedua panggil harus mengembalikan blok yang sama
      expect(block1.id, equals(block2.id));
      expect(block1.hash, equals(block2.hash));

      // Total blok di repo harus 2 (genesis + 1 buku), bukan 3
      final blocks = await repo.getBlocks();
      expect(blocks.length, 2, reason: 'Tidak boleh ada duplikat di ledger');
    });

    // ─── Tes 5: Hash diawali "00" (Proof of Work) ──────────────────────────
    test('T4-05: setiap blok di rantai memiliki hash diawali "00"', () async {
      final book1 = _makeBook(id: 'book-005a', title: 'Buku Satu');
      final book2 = _makeBook(id: 'book-005b', title: 'Buku Dua');

      await service.appendFinishedBook(book1,
          userId: 'user-test', totalReadingSeconds: 1800);
      await service.appendFinishedBook(book2,
          userId: 'user-test', totalReadingSeconds: 900);

      final blocks = await repo.getBlocks();
      expect(blocks.length, 3, reason: 'genesis + 2 blok buku');

      for (final block in blocks) {
        expect(
          block.hash.startsWith('00'),
          isTrue,
          reason:
              'Blok index ${block.blockIndex} hash "${block.hash}" harus diawali "00"',
        );
      }
    });

    // ─── Tes 6: Rantai kosong dianggap valid ───────────────────────────────
    test('T4-06: verifyChain pada rantai kosong mengembalikan isValid:true',
        () {
      final result = LedgerService.verifyChain([]);
      expect(result.isValid, isTrue);
    });

    // ─── Tes 7: canonicalJson deterministik ────────────────────────────────
    test('T4-07: canonicalJson menghasilkan output yang sama terlepas urutan kunci',
        () {
      final map1 = {'z': 1, 'a': 2, 'm': 3};
      final map2 = {'a': 2, 'm': 3, 'z': 1};
      final map3 = {'m': 3, 'z': 1, 'a': 2};

      expect(LedgerService.canonicalJson(map1), equals(LedgerService.canonicalJson(map2)));
      expect(LedgerService.canonicalJson(map2), equals(LedgerService.canonicalJson(map3)));
    });

    // ─── Tes 8: calculateHash deterministik ────────────────────────────────
    test('T4-08: calculateHash menghasilkan hash yang sama untuk input yang sama',
        () {
      final ts = DateTime.utc(2025, 6, 15, 12, 0, 0);
      final data = {'title': 'Buku A', 'page_count': 300};
      const prevHash = '00abcdef1234';
      const idx = 1;
      const nonce = 42;

      final hash1 = LedgerService.calculateHash(
        index: idx,
        timestamp: ts,
        data: data,
        previousHash: prevHash,
        nonce: nonce,
      );
      final hash2 = LedgerService.calculateHash(
        index: idx,
        timestamp: ts,
        data: data,
        previousHash: prevHash,
        nonce: nonce,
      );

      expect(hash1, equals(hash2));
      expect(hash1.length, 64, reason: 'SHA-256 menghasilkan 64 hex chars');
    });

    // ─── Tes 9: verifyChain pada rantai dengan 1 blok (genesis only) ───────
    test('T4-09: rantai dengan hanya genesis block dinyatakan valid', () async {
      await service.ensureGenesisBlock('user-test');
      final blocks = await repo.getBlocks();

      expect(blocks.length, 1);
      expect(blocks[0].blockIndex, 0);
      expect(blocks[0].previousHash, '0');

      final result = LedgerService.verifyChain(blocks);
      expect(result.isValid, isTrue);
    });

    // ─── Tes 10: ensureGenesisBlock idempoten ──────────────────────────────
    test('T4-10: ensureGenesisBlock idempoten — tidak membuat genesis duplikat',
        () async {
      await service.ensureGenesisBlock('user-test');
      await service.ensureGenesisBlock('user-test');
      await service.ensureGenesisBlock('user-test');

      final blocks = await repo.getBlocks();
      expect(blocks.where((b) => b.blockIndex == 0).length, 1,
          reason: 'Hanya satu genesis block');
    });
  });
}
