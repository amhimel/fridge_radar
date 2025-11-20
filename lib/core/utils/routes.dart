import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // auth gate
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/home/home_page.dart';
import '../../features/households/presentation/create_join_household_screen.dart';
import '../../features/households/presentation/household_detail_screen.dart';
import '../../features/households/presentation/join_code_autoload_screen.dart';
import '../../features/items/presentation/fridge_items_page.dart';


class AppRoutes {
  static const String home = '/home';
  static const String login = '/login';
  static const String register = '/register';
  static const String households = '/households';
  static const String householdDetail = '/households/:id';
  static const String joinCode = '/join/:code'; // optional deep link
  static const String fridgeItems = '/fridges/:id/items';
}

final router = GoRouter(
  initialLocation: AppRoutes.home,

  // Auth-aware redirect
  redirect: (context, state) {
    final user = Supabase.instance.client.auth.currentUser;

    final onLogin    = state.matchedLocation == AppRoutes.login;
    final onRegister = state.matchedLocation == AppRoutes.register;

    if (user == null) {
      return (onLogin || onRegister) ? null : AppRoutes.login;
    }
    if (onLogin || onRegister) return AppRoutes.home;

    return null;
  },

  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (ctx, st) => const HomePage(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (ctx, st) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (ctx, st) => const RegisterScreen(),
    ),
    GoRoute(
      path: AppRoutes.households,
      name: 'households.createJoin',
      builder: (ctx, st) => const CreateJoinHouseholdScreen(),
    ),
    GoRoute(
      path: AppRoutes.householdDetail,
      name: 'households.detail',
      builder: (ctx, st) {
        final id = st.pathParameters['id']!;
        return HouseholdDetailScreen(householdId: id);
      },
    ),
// /join/ABC123 → auto-join then redirect
    GoRoute(
      path: AppRoutes.joinCode,
      name: 'households.joinCode',
      builder: (ctx, st) => JoinCodeAutoloadScreen(
        code: st.pathParameters['code']!,
      ),
    ),
    GoRoute(
      path: AppRoutes.fridgeItems,
      name: 'fridges.items',
      builder: (ctx, st) {
        final id = st.pathParameters['id']!;
        // we’ll pass the fridgeName through `extra`
        final fridgeName = st.extra as String? ?? 'Fridge';
        return FridgeItemsPage(
          fridgeId: id,
          fridgeName: fridgeName,
        );
      },
    ),
  ],
);
