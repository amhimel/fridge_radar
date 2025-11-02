import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstant {
  static final String supabaseUrl = dotenv.get('SUPABASE_URL');
  static final String supabaseANON_KEY = dotenv.get('SUPABASE_ANON_KEY');
}
