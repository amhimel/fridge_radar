import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final registerLoadingProvider = StateProvider<bool>((ref) => false);