import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'app/app.dart';
import 'app/providers.dart';
import 'core/config/env.dart';
import 'core/config/startup_status.dart';
import 'core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones(); // PRD §9.5 — inisialisasi database timezone
  await initializeDateFormatting('id_ID', null);

  // Inisialisasi NotificationService secara eksplisit sebelum runApp — PRD §10.5 & Bagian 12
  await NotificationService.instance.initialize();

  // Muat preferensi tema sebelum runApp agar tidak ada kedipan tema — PRD §8.1 & Fase F1.2
  final themeController = await ThemeController.create();

  // Muat file .env sebagai satu-satunya titik akses konfigurasi — PRD §3
  await Env.load();

  // Inisialisasi Supabase jika kredensial .env tersedia — PRD §3 & Fase R1
  if (Env.isSupabaseConfigured) {
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseAnonKey,
      );
      StartupStatus.instance.recordSupabaseSuccess();
    } catch (e) {
      StartupStatus.instance.recordSupabaseError(e.toString());
    }
  }

  runApp(
    MultiProvider(
      providers: buildAppProviders(
        themeController: themeController,
      ),
      child: const StoryLokaApp(),
    ),
  );
}
