import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'app/app.dart';
import 'app/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones(); // PRD §9.5 — inisialisasi database timezone
  await initializeDateFormatting('id_ID', null);

  runApp(
    MultiProvider(
      providers: buildAppProviders(),
      child: const StoryLokaApp(),
    ),
  );
}
