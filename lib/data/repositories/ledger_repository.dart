import '../models/ledger_block.dart';

/// Kontrak Reading Ledger — PRD §13.0.
abstract class LedgerRepository {
  /// Ambil semua blok milik pengguna, urut block_index.
  Future<List<LedgerBlock>> getBlocks();

  /// Simpan blok baru.
  Future<void> saveBlock(LedgerBlock block);

  /// Ambil blok terakhir.
  Future<LedgerBlock?> getLastBlock();
}
