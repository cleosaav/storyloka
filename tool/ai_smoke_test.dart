import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Skrip dev untuk menguji konektivitas dan latensi tiap penyedia AI Chat — Fase S1.
/// ATURAN KEAMANAN: Jangan mencetak nilai .env (API key, token).
void main() async {
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    stdout.writeln('[SmokeTest] File .env tidak ditemukan.');
    return;
  }

  final envMap = <String, String>{};
  for (final line in envFile.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final eqIdx = trimmed.indexOf('=');
    if (eqIdx > 0) {
      final key = trimmed.substring(0, eqIdx).trim();
      var val = trimmed.substring(eqIdx + 1).trim();
      if ((val.startsWith('"') && val.endsWith('"')) ||
          (val.startsWith("'") && val.endsWith("'"))) {
        val = val.substring(1, val.length - 1);
      }
      envMap[key] = val;
    }
  }

  final deepseekKey = (envMap['DEEPSEEK_API_KEY'] ?? '').trim();
  final geminiKey = (envMap['GEMINI_API_KEY'] ?? '').trim();
  final geminiMainModel = (envMap['GEMINI_MODEL'] ?? 'gemini-3.5-flash-lite').trim();
  final geminiFallbacksRaw = envMap['GEMINI_MODEL_FALLBACKS'] ?? 'gemini-2.5-flash,gemini-3.5-flash';
  final geminiFallbacks = geminiFallbacksRaw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  final client = http.Client();

  stdout.writeln('====================================================');
  stdout.writeln(' StoryLoka AI Smoke Test — Fase S1');
  stdout.writeln('====================================================');

  // 1. Uji DeepSeek
  stdout.writeln('\n[1/3] Menguji DeepSeek (deepseek-chat)...');
  if (deepseekKey.isEmpty) {
    stdout.writeln('  -> DEEPSEEK_API_KEY kosong.');
  } else {
    final sw = Stopwatch()..start();
    try {
      final resp = await client
          .post(
            Uri.parse('https://api.deepseek.com/chat/completions'),
            headers: {
              'Authorization': 'Bearer $deepseekKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'deepseek-chat',
              'messages': [
                {'role': 'user', 'content': 'halo'}
              ],
              'max_tokens': 20,
            }),
          )
          .timeout(const Duration(seconds: 20));
      sw.stop();
      stdout.writeln('  -> Nama: DeepSeek (deepseek-chat)');
      stdout.writeln('  -> Status Code: ${resp.statusCode}');
      stdout.writeln('  -> Latensi: ${sw.elapsedMilliseconds} ms');
    } catch (e) {
      sw.stop();
      stdout.writeln('  -> Error (${sw.elapsedMilliseconds} ms): $e');
    }
  }

  // 2. Uji Gemini Model Utama
  stdout.writeln('\n[2/3] Menguji Gemini Utama ($geminiMainModel)...');
  if (geminiKey.isEmpty) {
    stdout.writeln('  -> GEMINI_API_KEY kosong.');
  } else {
    final sw = Stopwatch()..start();
    try {
      final resp = await client
          .post(
            Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$geminiMainModel:generateContent',
            ),
            headers: {
              'x-goog-api-key': geminiKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': 'halo'}
                  ]
                }
              ],
              'generationConfig': {'maxOutputTokens': 20},
            }),
          )
          .timeout(const Duration(seconds: 20));
      sw.stop();
      stdout.writeln('  -> Nama: Gemini ($geminiMainModel)');
      stdout.writeln('  -> Status Code: ${resp.statusCode}');
      stdout.writeln('  -> Latensi: ${sw.elapsedMilliseconds} ms');
    } catch (e) {
      sw.stop();
      stdout.writeln('  -> Error (${sw.elapsedMilliseconds} ms): $e');
    }
  }

  // 3. Uji Gemini Model Cadangan
  stdout.writeln('\n[3/3] Menguji Gemini Cadangan (${geminiFallbacks.join(', ')})...');
  for (final fbModel in geminiFallbacks) {
    if (geminiKey.isEmpty) continue;
    final sw = Stopwatch()..start();
    try {
      final resp = await client
          .post(
            Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$fbModel:generateContent',
            ),
            headers: {
              'x-goog-api-key': geminiKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': 'halo'}
                  ]
                }
              ],
              'generationConfig': {'maxOutputTokens': 20},
            }),
          )
          .timeout(const Duration(seconds: 20));
      sw.stop();
      stdout.writeln('  -> Cadangan: Gemini ($fbModel)');
      stdout.writeln('     Status Code: ${resp.statusCode}');
      stdout.writeln('     Latensi: ${sw.elapsedMilliseconds} ms');
    } catch (e) {
      sw.stop();
      stdout.writeln('  -> Cadangan: Gemini ($fbModel) Error (${sw.elapsedMilliseconds} ms): $e');
    }
  }

  client.close();
  stdout.writeln('\n====================================================');
  stdout.writeln(' Smoke Test Selesai.');
  stdout.writeln('====================================================');
}
