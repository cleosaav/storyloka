import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'app/app.dart';
import 'app/providers.dart';
import 'core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones(); // PRD §9.5 — inisialisasi database timezone
  await initializeDateFormatting('id_ID', null);

  // Muat file .env sebagai satu-satunya titik akses konfigurasi — PRD §3
  await Env.load();

  // Inisialisasi Supabase jika kredensial .env tersedia
  if (Env.isSupabaseConfigured) {
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseAnonKey,
      );
    } catch (_) {
      // Tangani error inisialisasi dengan anggun tanpa crash
    }
  }

  runApp(
    MultiProvider(
      providers: buildAppProviders(),
      child: const StoryLokaApp(),
    ),
  );
}
