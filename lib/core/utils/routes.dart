import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 👈 add this

import '../../features/auth/login_page.dart';
import '../../features/auth/register_screen.dart';
import '../../features/home/home_page.dart';
// import '../../features/auth/register_page.dart'; // থাকলে আনকমেন্ট

class AppRoutes {
  static const String home = '/home';
  static const String login = '/login';
  static const String register = '/register';
}

// মিনিমাল, এক ফাইল রাউটার কনফিগ + auth redirect
final router = GoRouter(
  initialLocation: AppRoutes.home,

  // 👇 এখানে Supabase auth দেখে redirect হবে
  redirect: (context, state) {
    final user = Supabase.instance.client.auth.currentUser;

    final onLogin     = state.matchedLocation == AppRoutes.login;
    final onRegister  = state.matchedLocation == AppRoutes.register;

    // Not signed in → কেবল login/register রুটে থাকতে দাও
    if (user == null) {
      return (onLogin || onRegister) ? null : AppRoutes.login;
    }

    // Signed in → login/register গেলে home-এ পাঠাও
    if (onLogin || onRegister) return AppRoutes.home;

    // নাহলে যেটা আছে সেটাই থাক
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
  ],
);
