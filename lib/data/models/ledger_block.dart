import 'dart:convert';

/// Model blok ledger blockchain — PRD §10.2.
class LedgerBlock {
  final String id;
  final String userId;
  final int blockIndex;
  final DateTime timestamp;
  final Map<String, dynamic> dataJson;
  final String previousHash;
  final int nonce;
  final String hash;
  final DateTime createdAt;
  final String syncStatus;

  const LedgerBlock({
    required this.id,
    required this.userId,
    required this.blockIndex,
    required this.timestamp,
    required this.dataJson,
    required this.previousHash,
    required this.nonce,
    required this.hash,
    required this.createdAt,
    this.syncStatus = 'pending',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'block_index': blockIndex,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'data_json': jsonEncode(dataJson),
        'previous_hash': previousHash,
        'nonce': nonce,
        'hash': hash,
        'created_at': createdAt.toUtc().toIso8601String(),
        'sync_status': syncStatus,
      };

  factory LedgerBlock.fromMap(Map<String, dynamic> m) {
    Map<String, dynamic> parsedData = {};
    final rawData = m['data_json'];
    if (rawData is Map<String, dynamic>) {
      parsedData = rawData;
    } else if (rawData is String && rawData.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawData);
        if (decoded is Map<String, dynamic>) {
          parsedData = decoded;
        }
      } catch (_) {}
    }

    return LedgerBlock(
      id: m['id'] as String,
      userId: m['user_id'] as String,
      blockIndex: m['block_index'] as int,
      timestamp: DateTime.parse(m['timestamp'] as String),
      dataJson: parsedData,
      previousHash: m['previous_hash'] as String,
      nonce: m['nonce'] as int,
      hash: m['hash'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
      syncStatus: (m['sync_status'] as String?) ?? 'pending',
    );
  }
}
