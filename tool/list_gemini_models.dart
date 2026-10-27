import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Skrip dev untuk memverifikasi model-model Gemini yang aktif dan mendukung
/// generateContent via endpoint official ListModels — Fase S1.
/// CATATAN KEAMANAN: Skrip ini tidak pernah mencetak kunci API.
void main() async {
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    stdout.writeln('[ListModels] File .env tidak ditemukan.');
    return;
  }

  String apiKey = '';
  for (final line in envFile.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.startsWith('GEMINI_API_KEY=')) {
      apiKey = trimmed.substring('GEMINI_API_KEY='.length).trim();
      if ((apiKey.startsWith('"') && apiKey.endsWith('"')) ||
          (apiKey.startsWith("'") && apiKey.endsWith("'"))) {
        apiKey = apiKey.substring(1, apiKey.length - 1);
      }
      break;
    }
  }

  if (apiKey.isEmpty) {
    stdout.writeln('[ListModels] GEMINI_API_KEY kosong.');
    return;
  }

  final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models');
  try {
    final resp = await http.get(uri, headers: {'x-goog-api-key': apiKey});
    stdout.writeln('[ListModels] HTTP Status Code: ${resp.statusCode}');

    if (resp.statusCode == 200) {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final models = json['models'] as List<dynamic>? ?? [];
      final validModels = <String>[];

      for (final m in models) {
        final map = m as Map<String, dynamic>;
        final name = (map['name'] as String? ?? '').replaceFirst('models/', '');
        final methods = (map['supportedGenerationMethods'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();

        if (methods.contains('generateContent')) {
          validModels.add(name);
        }
      }

      stdout.writeln('[ListModels] Model yang mendukung generateContent:');
      for (final m in validModels) {
        stdout.writeln('  - $m');
      }
    } else {
      stdout.writeln('[ListModels] Gagal mengambil daftar model: HTTP ${resp.statusCode}');
    }
  } catch (e) {
    stdout.writeln('[ListModels] Terjadi kesalahan: $e');
  }
}
