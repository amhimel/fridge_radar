import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fridge_radar/core/utils/api_constant.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then((
    _,
  ) async {
    await dotenv.load(fileName: "assets/.env");
    await Supabase.initialize(
      url: ApiConstant.supabaseUrl,
      anonKey: ApiConstant.supabaseANON_KEY,
    );
    runApp(const ProviderScope(child: FridgeRadarApp()));
  });
}
