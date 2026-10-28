import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/ledger_block.dart';
import '../../data/models/user_book.dart';
import '../../data/repositories/ledger_repository.dart';

/// Hasil verifikasi rantai blok ledger — PRD §10.2.
class ChainVerificationResult {
  final bool isValid;
  final int? invalidIndex;
  final String? reason;

  const ChainVerificationResult({
    required this.isValid,
    this.invalidIndex,
    this.reason,
  });

  @override
  String toString() => isValid
      ? 'ChainVerificationResult(isValid: true)'
      : 'ChainVerificationResult(isValid: false, invalidIndex: $invalidIndex, reason: $reason)';
}

/// Layanan Reading Ledger (Blockchain Sederhana) — PRD §10.2.
///
/// CATATAN JUJUR ARSITEKTUR:
/// Fitur ini merupakan simulasi edukatif single-node untuk mencatat buku yang selesai
/// dibaca ke dalam rantai blok terhubung lewat cryptographic hash (SHA-256) dan Proof of Work,
/// bukan jaringan peer-to-peer / desentralisasi nyata.
class LedgerService {
  final LedgerRepository _ledgerRepository;
  static const Uuid _uuid = Uuid();
  static const String targetPrefix = '00';
  static final DateTime genesisTimestamp = DateTime.utc(2025, 1, 1, 0, 0, 0);

  LedgerService(this._ledgerRepository);

  /// Menghasilkan format JSON yang kanonikal (kunci map terurut alfabetis)
  /// agar perhitungan hash bersifat deterministik — PRD §10.2.
  static String canonicalJson(dynamic data) {
    if (data is Map) {
      final sortedKeys = data.keys.map((k) => k.toString()).toList()..sort();
      final sortedMap = <String, dynamic>{};
      for (final k in sortedKeys) {
        sortedMap[k] = _canonicalValue(data[k]);
      }
      return jsonEncode(sortedMap);
    } else if (data is List) {
      return jsonEncode(data.map(_canonicalValue).toList());
    }
    return jsonEncode(data);
  }

  static dynamic _canonicalValue(dynamic val) {
    if (val is Map) {
      final sortedKeys = val.keys.map((k) => k.toString()).toList()..sort();
      final sortedMap = <String, dynamic>{};
      for (final k in sortedKeys) {
        sortedMap[k] = _canonicalValue(val[k]);
      }
      return sortedMap;
    } else if (val is List) {
      return val.map(_canonicalValue).toList();
    }
    return val;
  }

  /// Menghitung SHA-256 hash untuk blok:
  /// "$index|$timestamp|$canonicalJson(data)|$previousHash|$nonce"
  static String calculateHash({
    required int index,
    required DateTime timestamp,
    required Map<String, dynamic> data,
    required String previousHash,
    required int nonce,
  }) {
    final timestampStr = timestamp.toUtc().toIso8601String();
    final dataStr = canonicalJson(data);
    final rawString = '$index|$timestampStr|$dataStr|$previousHash|$nonce';
    return sha256.convert(utf8.encode(rawString)).toString();
  }

  /// Menjalankan Proof of Work sederhana (mencari nonce yang menghasilkan hash berawalan '00').
  static ({int nonce, String hash}) mineBlock({
    required int index,
    required DateTime timestamp,
    required Map<String, dynamic> data,
    required String previousHash,
  }) {
    int nonce = 0;
    while (true) {
      final hash = calculateHash(
        index: index,
        timestamp: timestamp,
        data: data,
        previousHash: previousHash,
        nonce: nonce,
      );
      if (hash.startsWith(targetPrefix)) {
        return (nonce: nonce, hash: hash);
      }
      nonce++;
    }
  }

  /// Memastikan Genesis Block (`index = 0`, `previousHash = "0"`) ada pada repository.
  /// F1.3: ID dibuat secara deterministik (UUID v5 dari user_id) dan timestamp tetap
  /// agar dua perangkat menghasilkan blok #0 yang identik tanpa melanggar UNIQUE (user_id, block_index).
  Future<LedgerBlock> ensureGenesisBlock(String userId) async {
    final existingBlocks = await _ledgerRepository.getBlocks();
    if (existingBlocks.isNotEmpty) {
      return existingBlocks.first;
    }

    final timestamp = genesisTimestamp;
    final genesisId = _uuid.v5(Namespace.url.value, 'storyloka:genesis:$userId');
    final data = <String, dynamic>{
      'message': 'StoryLoka genesis',
      'user_id': userId,
    };

    final mined = mineBlock(
      index: 0,
      timestamp: timestamp,
      data: data,
      previousHash: '0',
    );

    final genesisBlock = LedgerBlock(
      id: genesisId,
      userId: userId,
      blockIndex: 0,
      timestamp: timestamp,
      dataJson: data,
      previousHash: '0',
      nonce: mined.nonce,
      hash: mined.hash,
      createdAt: timestamp,
      syncStatus: 'pending',
    );

    await _ledgerRepository.saveBlock(genesisBlock);
    return genesisBlock;
  }

  /// Menambahkan buku yang selesai dibaca ke ledger.
  ///
  /// Bersifat IDEMPOTEN: jika buku dengan [UserBook.id] sudah pernah dicatat di ledger,
  /// blok yang sudah ada akan dikembalikan tanpa membuat blok duplikat.
  Future<LedgerBlock> appendFinishedBook(
    UserBook userBook, {
    required String userId,
    int totalReadingSeconds = 0,
  }) async {
    // 1. Pastikan genesis block ada
    await ensureGenesisBlock(userId);

    // 2. Cek idempotensi: cari apakah user_book_id sudah tercatat
    final allBlocks = await _ledgerRepository.getBlocks();
    for (final block in allBlocks) {
      if (block.blockIndex > 0 &&
          block.dataJson['user_book_id'] == userBook.id) {
        return block;
      }
    }

    // 3. Ambil blok terakhir
    final lastBlock = await _ledgerRepository.getLastBlock() ?? allBlocks.last;
    final nextIndex = lastBlock.blockIndex + 1;
    final previousHash = lastBlock.hash;
    final timestamp = (userBook.finishedAt ?? DateTime.now()).toUtc();

    final data = <String, dynamic>{
      'user_book_id': userBook.id,
      'google_books_id': userBook.googleBooksId,
      'title': userBook.title,
      'authors': userBook.authors ?? '',
      'page_count': userBook.pageCount ?? 0,
      'total_reading_seconds': totalReadingSeconds,
      'rating': userBook.rating,
      'finished_at': timestamp.toIso8601String(),
    };

    // 4. Tambang blok (Proof of Work)
    final mined = mineBlock(
      index: nextIndex,
      timestamp: timestamp,
      data: data,
      previousHash: previousHash,
    );

    final newBlock = LedgerBlock(
      id: _uuid.v4(),
      userId: userId,
      blockIndex: nextIndex,
      timestamp: timestamp,
      dataJson: data,
      previousHash: previousHash,
      nonce: mined.nonce,
      hash: mined.hash,
      createdAt: DateTime.now().toUtc(),
      syncStatus: 'pending',
    );

    await _ledgerRepository.saveBlock(newBlock);
    return newBlock;
  }

  /// Verifikasi keabsahan rantai blok — PRD §10.2:
  /// (a) hash tersimpan = hash dihitung ulang
  /// (b) hash memenuhi prefix "00"
  /// (c) previousHash = hash blok sebelumnya
  /// (d) index berurutan mulai 0
  static ChainVerificationResult verifyChain(List<LedgerBlock> blocks) {
    if (blocks.isEmpty) {
      return const ChainVerificationResult(isValid: true);
    }

    for (int i = 0; i < blocks.length; i++) {
      final block = blocks[i];

      // (d) Index harus berurutan mulai dari 0
      if (block.blockIndex != i) {
        return ChainVerificationResult(
          isValid: false,
          invalidIndex: i,
          reason: 'Indeks tidak berurutan: diharapkan $i tetapi ditemukan ${block.blockIndex}',
        );
      }

      // (b) Hash harus diawali prefix target ("00")
      if (!block.hash.startsWith(targetPrefix)) {
        return ChainVerificationResult(
          isValid: false,
          invalidIndex: i,
          reason: 'Hash tidak memenuhi kesulitan (prefix "$targetPrefix"): ${block.hash}',
        );
      }

      // (a) Hash tersimpan harus sama persis dengan hash dihitung ulang
      final recomputedHash = calculateHash(
        index: block.blockIndex,
        timestamp: block.timestamp,
        data: block.dataJson,
        previousHash: block.previousHash,
        nonce: block.nonce,
      );

      if (block.hash != recomputedHash) {
        return ChainVerificationResult(
          isValid: false,
          invalidIndex: i,
          reason: 'Data atau nonce telah diubah (hash tidak valid)',
        );
      }

      // (c) previousHash harus cocok
      if (i == 0) {
        if (block.previousHash != '0') {
          return const ChainVerificationResult(
            isValid: false,
            invalidIndex: 0,
            reason: 'Genesis block harus memiliki previousHash = "0"',
          );
        }
      } else {
        final prevBlock = blocks[i - 1];
        if (block.previousHash != prevBlock.hash) {
          return ChainVerificationResult(
            isValid: false,
            invalidIndex: i,
            reason: 'Tautan hash terputus: previousHash (${block.previousHash}) != hash blok sebelumnya (${prevBlock.hash})',
          );
        }
      }
    }

    return const ChainVerificationResult(isValid: true);
  }
}
