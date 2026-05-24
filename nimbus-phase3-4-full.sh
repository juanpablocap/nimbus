#!/bin/bash
# ============================================
# Nimbus — Phase 3+4 Complete Setup
# Creates ALL new files (Edge Functions, Flutter, docs, scripts)
# ============================================
# Usage:
#   cd ~/Development/nimbus
#   chmod +x nimbus-phase3-4-full.sh
#   bash nimbus-phase3-4-full.sh
#   git add -A && git commit -m "feat: QR edge functions + Flutter mobile app + docs" && git push origin main
# ============================================

set -e
echo "🚀 Creating all Phase 3+4 files..."

# ============================================
# EDGE FUNCTIONS
# ============================================

mkdir -p supabase/functions/_shared
mkdir -p supabase/functions/generate-qr
mkdir -p supabase/functions/validate-qr
mkdir -p supabase/functions/confirm-access
mkdir -p scripts


mkdir -p supabase/functions/_shared
cat > supabase/functions/_shared/qr-jwt.ts << 'FILEEOF'
import { create, verify, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const QR_SECRET = Deno.env.get("QR_JWT_SECRET") || "nimbus-qr-secret-change-me";

// Import key for HMAC signing
async function getKey(): Promise<CryptoKey> {
  const encoder = new TextEncoder();
  return await crypto.subtle.importKey(
    "raw",
    encoder.encode(QR_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
}

export interface QRPayload {
  visit_id: string;
  community_id: string;
  property_id: string;
  visitor_name: string;
  max_uses: number;
  exp: number;
}

export async function generateQRToken(payload: Omit<QRPayload, "exp">, expiresAt: Date): Promise<string> {
  const key = await getKey();
  const jwt = await create(
    { alg: "HS256", typ: "JWT" },
    {
      visit_id: payload.visit_id,
      community_id: payload.community_id,
      property_id: payload.property_id,
      visitor_name: payload.visitor_name,
      max_uses: payload.max_uses,
      exp: getNumericDate(expiresAt),
    },
    key,
  );
  return jwt;
}

export async function verifyQRToken(token: string): Promise<QRPayload> {
  const key = await getKey();
  const payload = await verify(token, key);
  return payload as unknown as QRPayload;
}

FILEEOF

mkdir -p supabase/functions/_shared
cat > supabase/functions/_shared/supabase.ts << 'FILEEOF'
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

export function getSupabaseAdmin() {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
}

export function getSupabaseUser(authHeader: string) {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      global: { headers: { Authorization: authHeader } },
    },
  );
}

FILEEOF

mkdir -p supabase/functions/_shared
cat > supabase/functions/_shared/cors.ts << 'FILEEOF'
export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function corsResponse() {
  return new Response("ok", { headers: corsHeaders });
}

export function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export function errorResponse(message: string, status = 400) {
  return jsonResponse({ error: message }, status);
}

FILEEOF

mkdir -p supabase/functions/generate-qr
cat > supabase/functions/generate-qr/index.ts << 'FILEEOF'
import { corsResponse, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { getSupabaseAdmin, getSupabaseUser } from "../_shared/supabase.ts";
import { generateQRToken } from "../_shared/qr-jwt.ts";

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") return corsResponse();

  try {
    // Verify user is authenticated
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return errorResponse("Missing authorization header", 401);

    const supabaseUser = getSupabaseUser(authHeader);
    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();
    if (authError || !user) return errorResponse("Unauthorized", 401);

    // Parse request body
    const { visit_id } = await req.json();
    if (!visit_id) return errorResponse("visit_id is required");

    const supabaseAdmin = getSupabaseAdmin();

    // Get the visit and verify ownership
    const { data: visit, error: visitError } = await supabaseAdmin
      .from("visits")
      .select("*, properties(name)")
      .eq("id", visit_id)
      .single();

    if (visitError || !visit) return errorResponse("Visit not found", 404);

    // Verify the user owns this visit
    if (visit.created_by !== user.id) {
      return errorResponse("You can only generate QR for your own visits", 403);
    }

    // Verify visit is active
    if (visit.status !== "active") {
      return errorResponse("Visit is not active", 400);
    }

    // Generate expiration: use valid_until or default to 24 hours
    const expiresAt = visit.valid_until
      ? new Date(visit.valid_until)
      : new Date(Date.now() + 24 * 60 * 60 * 1000);

    // Check if already expired
    if (expiresAt < new Date()) {
      return errorResponse("Visit has already expired", 400);
    }

    // Generate QR token
    const qrToken = await generateQRToken(
      {
        visit_id: visit.id,
        community_id: visit.community_id,
        property_id: visit.property_id,
        visitor_name: visit.visitor_name,
        max_uses: visit.max_uses,
      },
      expiresAt,
    );

    // Save token to visit
    await supabaseAdmin
      .from("visits")
      .update({ qr_token: qrToken, updated_at: new Date().toISOString() })
      .eq("id", visit_id);

    return jsonResponse({
      qr_token: qrToken,
      visit_id: visit.id,
      visitor_name: visit.visitor_name,
      property_name: visit.properties?.name,
      expires_at: expiresAt.toISOString(),
      max_uses: visit.max_uses,
      times_used: visit.times_used,
    });
  } catch (err) {
    console.error("generate-qr error:", err);
    return errorResponse("Internal server error", 500);
  }
});

FILEEOF

mkdir -p supabase/functions/validate-qr
cat > supabase/functions/validate-qr/index.ts << 'FILEEOF'
import { corsResponse, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { getSupabaseAdmin, getSupabaseUser } from "../_shared/supabase.ts";
import { verifyQRToken } from "../_shared/qr-jwt.ts";

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") return corsResponse();

  try {
    // Verify user is authenticated (guard)
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return errorResponse("Missing authorization header", 401);

    const supabaseUser = getSupabaseUser(authHeader);
    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();
    if (authError || !user) return errorResponse("Unauthorized", 401);

    // Parse request body
    const { qr_token, action = "entry" } = await req.json();
    if (!qr_token) return errorResponse("qr_token is required");

    // Step 1: Verify JWT signature and expiration
    let payload;
    try {
      payload = await verifyQRToken(qr_token);
    } catch (err) {
      const message = err instanceof Error ? err.message : "Invalid token";
      if (message.includes("exp")) {
        return jsonResponse({
          valid: false,
          reason: "expired",
          message: "This QR code has expired",
        });
      }
      return jsonResponse({
        valid: false,
        reason: "invalid",
        message: "Invalid QR code",
      });
    }

    const supabaseAdmin = getSupabaseAdmin();

    // Step 2: Get visit from database
    const { data: visit, error: visitError } = await supabaseAdmin
      .from("visits")
      .select("*, properties(name, address), profiles!visits_created_by_fkey(full_name, phone)")
      .eq("id", payload.visit_id)
      .single();

    if (visitError || !visit) {
      return jsonResponse({
        valid: false,
        reason: "not_found",
        message: "Visit not found in the system",
      });
    }

    // Step 3: Verify visit is active
    if (visit.status !== "active") {
      return jsonResponse({
        valid: false,
        reason: "inactive",
        message: `Visit is ${visit.status}`,
      });
    }

    // Step 4: Check usage limit
    if (visit.times_used >= visit.max_uses) {
      return jsonResponse({
        valid: false,
        reason: "max_uses_reached",
        message: "This QR code has reached its maximum number of uses",
      });
    }

    // Step 5: Check time validity
    if (visit.valid_until && new Date(visit.valid_until) < new Date()) {
      // Update status to expired
      await supabaseAdmin
        .from("visits")
        .update({ status: "expired", updated_at: new Date().toISOString() })
        .eq("id", visit.id);

      return jsonResponse({
        valid: false,
        reason: "expired",
        message: "This visit has expired",
      });
    }

    // Step 6: Verify guard belongs to the same community
    const { data: guardProfile } = await supabaseAdmin
      .from("profiles")
      .select("community_id")
      .eq("id", user.id)
      .single();

    if (!guardProfile || guardProfile.community_id !== visit.community_id) {
      return jsonResponse({
        valid: false,
        reason: "wrong_community",
        message: "This visit belongs to a different community",
      });
    }

    // QR is valid — return visit details for guard confirmation
    return jsonResponse({
      valid: true,
      visit: {
        id: visit.id,
        visitor_name: visit.visitor_name,
        visitor_document: visit.visitor_document,
        visit_type: visit.visit_type,
        notes: visit.notes,
        times_used: visit.times_used,
        max_uses: visit.max_uses,
        valid_until: visit.valid_until,
        property: {
          name: visit.properties?.name,
          address: visit.properties?.address,
        },
        resident: {
          name: visit.profiles?.full_name,
          phone: visit.profiles?.phone,
        },
      },
    });
  } catch (err) {
    console.error("validate-qr error:", err);
    return errorResponse("Internal server error", 500);
  }
});

FILEEOF

mkdir -p supabase/functions/confirm-access
cat > supabase/functions/confirm-access/index.ts << 'FILEEOF'
import { corsResponse, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { getSupabaseAdmin, getSupabaseUser } from "../_shared/supabase.ts";

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") return corsResponse();

  try {
    // Verify user is authenticated (guard)
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return errorResponse("Missing authorization header", 401);

    const supabaseUser = getSupabaseUser(authHeader);
    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();
    if (authError || !user) return errorResponse("Unauthorized", 401);

    // Parse request body
    const { visit_id, action = "entry", notes = null } = await req.json();
    if (!visit_id) return errorResponse("visit_id is required");

    const supabaseAdmin = getSupabaseAdmin();

    // Get visit
    const { data: visit, error: visitError } = await supabaseAdmin
      .from("visits")
      .select("*")
      .eq("id", visit_id)
      .single();

    if (visitError || !visit) return errorResponse("Visit not found", 404);

    // Verify visit is still active and within limits
    if (visit.status !== "active") return errorResponse("Visit is not active", 400);
    if (visit.times_used >= visit.max_uses) return errorResponse("Visit has reached max uses", 400);

    // Register access log
    const { error: logError } = await supabaseAdmin
      .from("access_logs")
      .insert({
        community_id: visit.community_id,
        visit_id: visit.id,
        property_id: visit.property_id,
        visitor_name: visit.visitor_name,
        validated_by: user.id,
        action,
        method: "qr",
        notes,
      });

    if (logError) return errorResponse("Failed to register access log", 500);

    // Update visit usage count
    const newTimesUsed = visit.times_used + 1;
    const newStatus = newTimesUsed >= visit.max_uses ? "used" : "active";

    await supabaseAdmin
      .from("visits")
      .update({
        times_used: newTimesUsed,
        status: newStatus,
        updated_at: new Date().toISOString(),
      })
      .eq("id", visit.id);

    return jsonResponse({
      success: true,
      access_log: {
        action,
        visitor_name: visit.visitor_name,
        times_used: newTimesUsed,
        max_uses: visit.max_uses,
        visit_status: newStatus,
      },
    });
  } catch (err) {
    console.error("confirm-access error:", err);
    return errorResponse("Internal server error", 500);
  }
});

FILEEOF

mkdir -p apps/mobile
cat > apps/mobile/pubspec.yaml << 'FILEEOF'
name: nimbus_mobile
description: Nimbus - Mobile app for private communities
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # Supabase
  supabase_flutter: ^2.8.0

  # State Management
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1

  # Navigation
  go_router: ^14.8.1

  # QR
  qr_flutter: ^4.1.0
  mobile_scanner: ^6.0.2

  # UI
  google_fonts: ^6.2.1
  flutter_svg: ^2.0.17
  cached_network_image: ^3.4.1
  shimmer: ^3.0.0

  # Utils
  intl: ^0.19.0
  url_launcher: ^6.3.1
  share_plus: ^10.1.4
  flutter_secure_storage: ^9.2.4

  # Icons
  lucide_icons: ^0.257.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  riverpod_generator: ^2.6.3
  build_runner: ^2.4.14

flutter:
  uses-material-design: true

FILEEOF

mkdir -p apps/mobile/lib
cat > apps/mobile/lib/main.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: NimbusApp(),
    ),
  );
}

class NimbusApp extends ConsumerWidget {
  const NimbusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Nimbus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

FILEEOF

mkdir -p apps/mobile/lib/core/constants
cat > apps/mobile/lib/core/constants/app_constants.dart << 'FILEEOF'
class AppConstants {
  AppConstants._();

  // Supabase
  static const String supabaseUrl = 'https://yxdwshujxsnamnmllljc.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_ewJwkoSbTSQ-q49QUMGgbg_JqVqtF6b';

  // Edge Functions
  static String get edgeFunctionsUrl => '$supabaseUrl/functions/v1';
  static String get generateQrUrl => '$edgeFunctionsUrl/generate-qr';
  static String get validateQrUrl => '$edgeFunctionsUrl/validate-qr';
  static String get confirmAccessUrl => '$edgeFunctionsUrl/confirm-access';

  // App
  static const String appName = 'Nimbus';
  static const int qrDefaultExpirationHours = 24;
}

FILEEOF

mkdir -p apps/mobile/lib/core/theme
cat > apps/mobile/lib/core/theme/app_theme.dart << 'FILEEOF'
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Brand colors
  static const Color accent = Color(0xFF2563EB);
  static const Color accentLight = Color(0xFF3B82F6);

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: accent,
    scaffoldBackgroundColor: const Color(0xFFFAFAFA),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF09090B),
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE4E4E7)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF4F4F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: accent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: accent,
      unselectedItemColor: Color(0xFFA1A1AA),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE4E4E7),
      thickness: 1,
    ),
  );

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorSchemeSeed: accentLight,
    scaffoldBackgroundColor: const Color(0xFF09090B),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF18181B),
      foregroundColor: Color(0xFFFAFAFA),
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF18181B),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF27272A)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF18181B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF27272A)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF27272A)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: accentLight, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentLight,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF18181B),
      selectedItemColor: accentLight,
      unselectedItemColor: Color(0xFF71717A),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF27272A),
      thickness: 1,
    ),
  );
}

FILEEOF

mkdir -p apps/mobile/lib/core/router
cat > apps/mobile/lib/core/router/app_router.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/visits/screens/visits_screen.dart';
import '../../features/visits/screens/create_visit_screen.dart';
import '../../features/visits/screens/visit_detail_screen.dart';
import '../../features/scanner/screens/scanner_screen.dart';
import '../../features/news/screens/news_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../constants/app_constants.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isLoginPage = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginPage) return '/login';
      if (isLoggedIn && isLoginPage) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/visits',
            builder: (context, state) => const VisitsScreen(),
          ),
          GoRoute(
            path: '/visits/create',
            builder: (context, state) => const CreateVisitScreen(),
          ),
          GoRoute(
            path: '/visits/:id',
            builder: (context, state) => VisitDetailScreen(
              visitId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/scanner',
            builder: (context, state) => const ScannerScreen(),
          ),
          GoRoute(
            path: '/news',
            builder: (context, state) => const NewsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});

/// Bottom navigation shell
class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  int _getIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/visits')) return 1;
    if (location == '/scanner') return 2;
    if (location == '/news') return 3;
    if (location == '/profile') return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _getIndex(context),
        onTap: (index) {
          switch (index) {
            case 0: context.go('/');
            case 1: context.go('/visits');
            case 2: context.go('/scanner');
            case 3: context.go('/news');
            case 4: context.go('/profile');
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today), label: 'Visits'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner_outlined), activeIcon: Icon(Icons.qr_code_scanner), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.newspaper_outlined), activeIcon: Icon(Icons.newspaper), label: 'News'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

FILEEOF

mkdir -p apps/mobile/lib/features/auth/providers
cat > apps/mobile/lib/features/auth/providers/auth_provider.dart << 'FILEEOF'
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  return Supabase.instance.client.auth.currentUser;
});

final currentSessionProvider = Provider<Session?>((ref) {
  return Supabase.instance.client.auth.currentSession;
});

class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    return await _client.auth.signUp(email: email, password: password);
  }

  Future<void> signInWithMagicLink(String email) async {
    await _client.auth.signInWithOtp(email: email);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<Map<String, dynamic>?> getProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final response = await _client.from('profiles').select().eq('id', user.id).single();
    return response;
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(supabaseClientProvider));
});

FILEEOF

mkdir -p apps/mobile/lib/features/auth/screens
cat > apps/mobile/lib/features/auth/screens/login_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) context.go('/');
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text('N', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Nimbus', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Sign in to your community', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                const SizedBox(height: 40),

                // Email
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Email', hintText: 'your@email.com'),
                ),
                const SizedBox(height: 16),

                // Password
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _signIn(),
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 24),

                // Error
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),

                // Submit
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _signIn,
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Sign in'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

FILEEOF

mkdir -p apps/mobile/lib/features/home/screens
cat > apps/mobile/lib/features/home/screens/home_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Map<String, dynamic>? _profile;
  int _activeVisits = 0;
  List<Map<String, dynamic>> _recentNews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final results = await Future.wait([
      client.from('profiles').select().eq('id', userId).single(),
      client.from('visits').select('id').eq('created_by', userId).eq('status', 'active'),
      client.from('news').select('id, title, created_at').eq('is_published', true).order('created_at', ascending: false).limit(5),
    ]);

    if (mounted) {
      setState(() {
        _profile = results[0] as Map<String, dynamic>;
        _activeVisits = (results[1] as List).length;
        _recentNews = List<Map<String, dynamic>>.from(results[2] as List);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final name = _profile?['full_name'] ?? 'Resident';
    final firstName = name.split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, $firstName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Quick actions
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.add_circle_outline,
                    label: 'New Visit',
                    onTap: () => context.go('/visits/create'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.qr_code,
                    label: 'My QR Codes',
                    onTap: () => context.go('/visits'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Stats
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text('$_activeVisits', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Active Visits', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Recent news
            Text('Latest News', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (_recentNews.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('No announcements yet.', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                ),
              )
            else
              ..._recentNews.map((n) => Card(
                child: ListTile(
                  title: Text(n['title'], style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(_formatDate(n['created_at']), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => context.go('/news'),
                ),
              )),
          ],
        ),
      ),
    );
  }

  String _formatDate(String date) {
    final d = DateTime.parse(date);
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            children: [
              Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

FILEEOF

mkdir -p apps/mobile/lib/features/visits/screens
cat > apps/mobile/lib/features/visits/screens/visits_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VisitsScreen extends StatefulWidget {
  const VisitsScreen({super.key});

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  List<Map<String, dynamic>> _visits = [];
  bool _loading = true;
  String _filter = 'active';

  @override
  void initState() {
    super.initState();
    _fetchVisits();
  }

  Future<void> _fetchVisits() async {
    setState(() => _loading = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    var query = client
        .from('visits')
        .select('*, properties(name)')
        .eq('created_by', userId!)
        .order('created_at', ascending: false);

    if (_filter != 'all') {
      query = query.eq('status', _filter);
    }

    final data = await query;
    if (mounted) {
      setState(() {
        _visits = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Visits'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/visits/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Visit'),
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(label: 'Active', value: 'active', selected: _filter, onTap: (v) { setState(() => _filter = v); _fetchVisits(); }),
                const SizedBox(width: 8),
                _FilterChip(label: 'Used', value: 'used', selected: _filter, onTap: (v) { setState(() => _filter = v); _fetchVisits(); }),
                const SizedBox(width: 8),
                _FilterChip(label: 'Expired', value: 'expired', selected: _filter, onTap: (v) { setState(() => _filter = v); _fetchVisits(); }),
                const SizedBox(width: 8),
                _FilterChip(label: 'All', value: 'all', selected: _filter, onTap: (v) { setState(() => _filter = v); _fetchVisits(); }),
              ],
            ),
          ),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _visits.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text('No visits found', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchVisits,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _visits.length,
                          itemBuilder: (context, index) {
                            final visit = _visits[index];
                            return _VisitCard(visit: visit, onTap: () => context.go('/visits/${visit['id']}'));
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final Function(String) onTap;

  const _FilterChip({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  final Map<String, dynamic> visit;
  final VoidCallback onTap;

  const _VisitCard({required this.visit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColors = {
      'active': Colors.green,
      'used': Colors.blue,
      'expired': Colors.red,
      'cancelled': Colors.grey,
    };
    final color = statusColors[visit['status']] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(visit['visitor_name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      visit['properties']?['name'] ?? '—',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${visit['times_used']}/${visit['max_uses']} uses',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  visit['status'].toString().toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

FILEEOF

mkdir -p apps/mobile/lib/features/visits/screens
cat > apps/mobile/lib/features/visits/screens/create_visit_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateVisitScreen extends StatefulWidget {
  const CreateVisitScreen({super.key});

  @override
  State<CreateVisitScreen> createState() => _CreateVisitScreenState();
}

class _CreateVisitScreenState extends State<CreateVisitScreen> {
  final _nameController = TextEditingController();
  final _documentController = TextEditingController();
  final _notesController = TextEditingController();
  String _visitType = 'one_time';
  int _maxUses = 1;
  DateTime _validUntil = DateTime.now().add(const Duration(hours: 24));
  String? _selectedPropertyId;
  List<Map<String, dynamic>> _properties = [];
  bool _loading = false;
  bool _fetchingProperties = true;

  @override
  void initState() {
    super.initState();
    _fetchProperties();
  }

  Future<void> _fetchProperties() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    // Get properties assigned to this resident
    final assignments = await client
        .from('resident_properties')
        .select('property_id, properties(id, name)')
        .eq('profile_id', userId!);

    if (mounted) {
      setState(() {
        _properties = List<Map<String, dynamic>>.from(
          (assignments as List).map((a) => a['properties']),
        );
        if (_properties.isNotEmpty) {
          _selectedPropertyId = _properties.first['id'];
        }
        _fetchingProperties = false;
      });
    }
  }

  Future<void> _createVisit() async {
    if (_nameController.text.trim().isEmpty || _selectedPropertyId == null) return;

    setState(() => _loading = true);

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      final profile = await client.from('profiles').select('community_id').eq('id', userId!).single();

      await client.from('visits').insert({
        'community_id': profile['community_id'],
        'property_id': _selectedPropertyId,
        'created_by': userId,
        'visitor_name': _nameController.text.trim(),
        'visitor_document': _documentController.text.trim().isEmpty ? null : _documentController.text.trim(),
        'visit_type': _visitType,
        'status': 'active',
        'valid_until': _validUntil.toIso8601String(),
        'max_uses': _maxUses,
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visit created successfully')),
        );
        context.go('/visits');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _validUntil,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_validUntil),
    );
    if (time == null || !mounted) return;

    setState(() {
      _validUntil = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _documentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Visit'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/visits'),
        ),
      ),
      body: _fetchingProperties
          ? const Center(child: CircularProgressIndicator())
          : _properties.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.home_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'No property assigned',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Contact your community administrator to assign you a property.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Visitor name
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Visitor name *', hintText: 'Full name of the visitor'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),

                      // Document
                      TextField(
                        controller: _documentController,
                        decoration: const InputDecoration(labelText: 'Document / ID', hintText: 'Optional'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),

                      // Property selector
                      DropdownButtonFormField<String>(
                        value: _selectedPropertyId,
                        decoration: const InputDecoration(labelText: 'Property'),
                        items: _properties.map((p) => DropdownMenuItem(
                          value: p['id'] as String,
                          child: Text(p['name'] as String),
                        )).toList(),
                        onChanged: (v) => setState(() => _selectedPropertyId = v),
                      ),
                      const SizedBox(height: 16),

                      // Visit type
                      DropdownButtonFormField<String>(
                        value: _visitType,
                        decoration: const InputDecoration(labelText: 'Visit type'),
                        items: const [
                          DropdownMenuItem(value: 'one_time', child: Text('One time')),
                          DropdownMenuItem(value: 'recurring', child: Text('Recurring')),
                        ],
                        onChanged: (v) => setState(() {
                          _visitType = v!;
                          if (v == 'recurring') _maxUses = 10;
                          else _maxUses = 1;
                        }),
                      ),
                      const SizedBox(height: 16),

                      // Max uses
                      Row(
                        children: [
                          Text('Max uses: ', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _maxUses > 1 ? () => setState(() => _maxUses--) : null,
                            icon: const Icon(Icons.remove_circle_outline),
                            iconSize: 28,
                          ),
                          Text('$_maxUses', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          IconButton(
                            onPressed: () => setState(() => _maxUses++),
                            icon: const Icon(Icons.add_circle_outline),
                            iconSize: 28,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Valid until
                      GestureDetector(
                        onTap: _pickDateTime,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Valid until'),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_validUntil.day}/${_validUntil.month}/${_validUntil.year} ${_validUntil.hour.toString().padLeft(2, '0')}:${_validUntil.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const Icon(Icons.calendar_today, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Notes
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(labelText: 'Notes', hintText: 'Optional instructions for the guard'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 32),

                      // Submit
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _createVisit,
                          child: _loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Create Visit'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

FILEEOF

mkdir -p apps/mobile/lib/features/visits/screens
cat > apps/mobile/lib/features/visits/screens/visit_detail_screen.dart << 'FILEEOF'
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';

class VisitDetailScreen extends StatefulWidget {
  final String visitId;
  const VisitDetailScreen({super.key, required this.visitId});

  @override
  State<VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends State<VisitDetailScreen> {
  Map<String, dynamic>? _visit;
  String? _qrToken;
  bool _loading = true;
  bool _generatingQr = false;

  @override
  void initState() {
    super.initState();
    _fetchVisit();
  }

  Future<void> _fetchVisit() async {
    final client = Supabase.instance.client;
    final data = await client
        .from('visits')
        .select('*, properties(name, address)')
        .eq('id', widget.visitId)
        .single();

    if (mounted) {
      setState(() {
        _visit = data;
        _qrToken = data['qr_token'];
        _loading = false;
      });
    }
  }

  Future<void> _generateQR() async {
    setState(() => _generatingQr = true);

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final response = await Supabase.instance.client.functions.invoke(
        'generate-qr',
        body: {'visit_id': widget.visitId},
      );

      if (response.data != null && response.data['qr_token'] != null) {
        setState(() {
          _qrToken = response.data['qr_token'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating QR: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingQr = false);
    }
  }

  void _shareQR() {
    if (_qrToken == null) return;
    Share.share(
      'You have been invited to visit ${_visit?['properties']?['name'] ?? 'our community'}.\n\nShow this code at the entrance:\n$_qrToken',
      subject: 'Visit invitation - ${_visit?['visitor_name']}',
    );
  }

  Future<void> _cancelVisit() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Visit'),
        content: const Text('Are you sure you want to cancel this visit?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, cancel')),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.from('visits').update({
        'status': 'cancelled',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.visitId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visit cancelled')),
        );
        context.go('/visits');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Visit')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final visit = _visit!;
    final isActive = visit['status'] == 'active';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visit Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/visits'),
        ),
        actions: [
          if (isActive)
            IconButton(icon: const Icon(Icons.share), onPressed: _qrToken != null ? _shareQR : null),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // QR Code
            if (isActive) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      if (_qrToken != null) ...[
                        QrImageView(
                          data: _qrToken!,
                          version: QrVersions.auto,
                          size: 240,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        Text('Show this code at the entrance', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                      ] else ...[
                        Icon(Icons.qr_code_2, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _generatingQr ? null : _generateQR,
                          child: _generatingQr
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Generate QR Code'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Visit info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _InfoRow(label: 'Visitor', value: visit['visitor_name']),
                    if (visit['visitor_document'] != null)
                      _InfoRow(label: 'Document', value: visit['visitor_document']),
                    _InfoRow(label: 'Property', value: visit['properties']?['name'] ?? '—'),
                    _InfoRow(label: 'Type', value: visit['visit_type'] == 'one_time' ? 'One time' : 'Recurring'),
                    _InfoRow(label: 'Status', value: visit['status'].toString().toUpperCase(), valueColor: isActive ? Colors.green : Colors.grey),
                    _InfoRow(label: 'Uses', value: '${visit['times_used']}/${visit['max_uses']}'),
                    if (visit['valid_until'] != null)
                      _InfoRow(label: 'Valid until', value: _formatDateTime(visit['valid_until'])),
                    if (visit['notes'] != null)
                      _InfoRow(label: 'Notes', value: visit['notes']),
                  ],
                ),
              ),
            ),

            if (isActive) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _cancelVisit,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Cancel Visit'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(String date) {
    final d = DateTime.parse(date);
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: valueColor)),
          ),
        ],
      ),
    );
  }
}

FILEEOF

mkdir -p apps/mobile/lib/features/scanner/screens
cat > apps/mobile/lib/features/scanner/screens/scanner_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  MobileScannerController? _controller;
  bool _isProcessing = false;
  Map<String, dynamic>? _result;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _showResult) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    setState(() => _isProcessing = true);
    _controller?.stop();

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'validate-qr',
        body: {'qr_token': barcode!.rawValue},
      );

      if (mounted) {
        setState(() {
          _result = response.data;
          _showResult = true;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = {'valid': false, 'reason': 'error', 'message': e.toString()};
          _showResult = true;
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _confirmAccess() async {
    if (_result == null || _result!['visit'] == null) return;

    setState(() => _isProcessing = true);

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'confirm-access',
        body: {'visit_id': _result!['visit']['id'], 'action': 'entry'},
      );

      if (mounted) {
        final success = response.data?['success'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Access granted' : 'Failed to register access'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        _resetScanner();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _resetScanner() {
    setState(() {
      _result = null;
      _showResult = false;
      _isProcessing = false;
    });
    _controller?.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR'),
      ),
      body: _showResult ? _buildResult() : _buildScanner(),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller!,
          onDetect: _onDetect,
        ),
        // Overlay
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
        // Instructions
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Text(
            'Point the camera at the visitor\'s QR code',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 14, shadows: [Shadow(blurRadius: 8, color: Colors.black)]),
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final isValid = _result?['valid'] == true;
    final visit = _result?['visit'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Status icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isValid ? Colors.green : Colors.red).withOpacity(0.1),
            ),
            child: Icon(
              isValid ? Icons.check_circle : Icons.cancel,
              size: 48,
              color: isValid ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isValid ? 'Valid QR Code' : 'Invalid QR Code',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isValid ? Colors.green : Colors.red,
            ),
          ),

          if (!isValid) ...[
            const SizedBox(height: 8),
            Text(
              _result?['message'] ?? 'Unknown error',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],

          if (isValid && visit != null) ...[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _DetailRow(icon: Icons.person, label: 'Visitor', value: visit['visitor_name']),
                    if (visit['visitor_document'] != null)
                      _DetailRow(icon: Icons.badge, label: 'Document', value: visit['visitor_document']),
                    _DetailRow(icon: Icons.home, label: 'Property', value: visit['property']?['name'] ?? '—'),
                    if (visit['property']?['address'] != null)
                      _DetailRow(icon: Icons.location_on, label: 'Address', value: visit['property']['address']),
                    _DetailRow(icon: Icons.person_outline, label: 'Resident', value: visit['resident']?['name'] ?? '—'),
                    if (visit['resident']?['phone'] != null)
                      _DetailRow(icon: Icons.phone, label: 'Phone', value: visit['resident']['phone']),
                    _DetailRow(icon: Icons.repeat, label: 'Uses', value: '${visit['times_used']}/${visit['max_uses']}'),
                    if (visit['notes'] != null)
                      _DetailRow(icon: Icons.notes, label: 'Notes', value: visit['notes']),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _confirmAccess,
                icon: const Icon(Icons.check),
                label: _isProcessing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Approve Entry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _resetScanner,
              child: const Text('Scan Another'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

FILEEOF

mkdir -p apps/mobile/lib/features/news/screens
cat > apps/mobile/lib/features/news/screens/news_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<Map<String, dynamic>> _news = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    setState(() => _loading = true);
    final data = await Supabase.instance.client
        .from('news')
        .select('*, profiles!news_author_id_fkey(full_name)')
        .eq('is_published', true)
        .order('published_at', ascending: false);

    if (mounted) {
      setState(() {
        _news = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    }
  }

  String _formatDate(String date) {
    final d = DateTime.parse(date);
    final now = DateTime.now();
    final diff = now.difference(d);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('News'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _news.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.newspaper_outlined, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('No news yet', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchNews,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _news.length,
                    itemBuilder: (context, index) {
                      final item = _news[index];
                      final authorName = item['profiles']?['full_name'] ?? 'Admin';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    child: Text(
                                      authorName[0].toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(authorName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                      Text(
                                        _formatDate(item['published_at'] ?? item['created_at']),
                                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                item['title'],
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item['body'],
                                style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

FILEEOF

mkdir -p apps/mobile/lib/features/profile/screens
cat > apps/mobile/lib/features/profile/screens/profile_screen.dart << 'FILEEOF'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _properties = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final results = await Future.wait([
      client.from('profiles').select('*, communities(name)').eq('id', userId).single(),
      client.from('resident_properties').select('properties(name, address)').eq('profile_id', userId),
    ]);

    if (mounted) {
      setState(() {
        _profile = results[0] as Map<String, dynamic>;
        _properties = List<Map<String, dynamic>>.from(
          (results[1] as List).map((r) => r['properties']),
        );
        _loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign Out')),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final name = _profile?['full_name'] ?? '';
    final phone = _profile?['phone'];
    final community = _profile?['communities']?['name'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar & name
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(community, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Info
          Card(
            child: Column(
              children: [
                _ProfileTile(icon: Icons.email_outlined, label: 'Email', value: email),
                const Divider(height: 1),
                _ProfileTile(icon: Icons.phone_outlined, label: 'Phone', value: phone ?? 'Not set'),
                const Divider(height: 1),
                _ProfileTile(icon: Icons.location_city_outlined, label: 'Community', value: community),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Properties
          Text('My Properties', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_properties.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No properties assigned', style: TextStyle(color: Colors.grey[500])),
              ),
            )
          else
            ..._properties.map((p) => Card(
              child: ListTile(
                leading: const Icon(Icons.home_outlined),
                title: Text(p['name'] ?? '—'),
                subtitle: p['address'] != null ? Text(p['address'], style: TextStyle(fontSize: 13, color: Colors.grey[600])) : null,
              ),
            )),

          const SizedBox(height: 32),

          // Sign out
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
    );
  }
}

FILEEOF

mkdir -p docs
cat > docs/edge-functions.md << 'FILEEOF'
# Nimbus — Edge Functions (QR System)

## Overview

The QR access system runs on Supabase Edge Functions (Deno). Three functions handle the full lifecycle:

1. **generate-qr** — Creates a signed JWT token for a visit
2. **validate-qr** — Validates a scanned QR token
3. **confirm-access** — Approves entry and registers it in access_logs

---

## Architecture

```
Resident creates visit → generate-qr → JWT token saved to visits.qr_token
                                       ↓
                              QR rendered in mobile app (qr_flutter)
                                       ↓
Guard scans QR → validate-qr → checks JWT signature, expiry, usage, status
                                       ↓
                              Guard sees visitor details on screen
                                       ↓
Guard taps "Approve" → confirm-access → creates access_log + increments times_used
```

---

## Functions

### generate-qr

**POST** `/functions/v1/generate-qr`

**Auth:** Required (resident's JWT in Authorization header)

**Body:**
```json
{ "visit_id": "uuid" }
```

**Logic:**
1. Verify user is authenticated
2. Fetch visit, verify ownership (created_by === user.id)
3. Verify visit is active
4. Generate HMAC-SHA256 signed JWT with visit data
5. Save token to visits.qr_token
6. Return token + visit metadata

**Response:**
```json
{
  "qr_token": "eyJ...",
  "visit_id": "...",
  "visitor_name": "...",
  "property_name": "...",
  "expires_at": "...",
  "max_uses": 1,
  "times_used": 0
}
```

### validate-qr

**POST** `/functions/v1/validate-qr`

**Auth:** Required (guard's JWT)

**Body:**
```json
{ "qr_token": "eyJ..." }
```

**Logic:**
1. Verify guard is authenticated
2. Verify JWT signature and expiration
3. Fetch visit from database
4. Check: status === active, times_used < max_uses, not expired
5. Verify guard belongs to same community as visit
6. Return visit details for guard confirmation

**Response (valid):**
```json
{
  "valid": true,
  "visit": {
    "id": "...",
    "visitor_name": "...",
    "visitor_document": "...",
    "property": { "name": "...", "address": "..." },
    "resident": { "name": "...", "phone": "..." },
    "times_used": 0,
    "max_uses": 1
  }
}
```

**Response (invalid):**
```json
{
  "valid": false,
  "reason": "expired|inactive|max_uses_reached|wrong_community|invalid",
  "message": "Human-readable explanation"
}
```

### confirm-access

**POST** `/functions/v1/confirm-access`

**Auth:** Required (guard's JWT)

**Body:**
```json
{
  "visit_id": "uuid",
  "action": "entry",
  "notes": "optional"
}
```

**Logic:**
1. Verify guard is authenticated
2. Fetch visit, verify it's active and within usage limits
3. Insert row into access_logs
4. Increment visits.times_used
5. If times_used >= max_uses, set status to "used"

---

## Environment Variables

Required in Supabase Edge Functions settings:

- `QR_JWT_SECRET` — Secret key for signing QR tokens (HMAC-SHA256)
- `SUPABASE_URL` — Auto-provided by Supabase
- `SUPABASE_SERVICE_ROLE_KEY` — Auto-provided by Supabase
- `SUPABASE_ANON_KEY` — Auto-provided by Supabase

---

## Deployment

```bash
# Install Supabase CLI
npm install -g supabase

# Login
supabase login

# Link project
supabase link --project-ref yxdwshujxsnamnmllljc

# Deploy all functions
supabase functions deploy generate-qr
supabase functions deploy validate-qr
supabase functions deploy confirm-access

# Set secret
supabase secrets set QR_JWT_SECRET=your-secret-here
```

---

## Security

- All functions require authentication (JWT in Authorization header)
- QR tokens are HMAC-SHA256 signed, tamper-proof
- generate-qr verifies ownership (only the visit creator can generate)
- validate-qr verifies community match (guards can't validate visits from other communities)
- confirm-access verifies visit is still active before registering
- Tokens have time-based expiration (valid_until) AND usage limits (max_uses)

FILEEOF

mkdir -p docs
cat > docs/mobile-app.md << 'FILEEOF'
# Nimbus — Mobile App Architecture

## Overview

Flutter app for residents and guards. Two user experiences in one app, role-determined at login.

---

## Stack

- Flutter 3.x + Dart
- State management: Riverpod
- Navigation: GoRouter
- Backend: Supabase (supabase_flutter)
- QR generation: qr_flutter
- QR scanning: mobile_scanner
- Sharing: share_plus

---

## Project Structure

```
apps/mobile/lib/
├── main.dart                          # Entry point, Supabase init
├── core/
│   ├── constants/app_constants.dart   # Supabase URLs, Edge Function endpoints
│   ├── theme/app_theme.dart           # Light/dark themes
│   └── router/app_router.dart         # GoRouter config + bottom nav shell
├── features/
│   ├── auth/
│   │   ├── screens/login_screen.dart
│   │   └── providers/auth_provider.dart
│   ├── home/
│   │   └── screens/home_screen.dart   # Dashboard with quick actions + stats
│   ├── visits/
│   │   └── screens/
│   │       ├── visits_screen.dart     # List with filter chips
│   │       ├── create_visit_screen.dart # Create form
│   │       └── visit_detail_screen.dart # QR display + share + cancel
│   ├── scanner/
│   │   └── screens/scanner_screen.dart # QR scanner + validation + approve
│   ├── news/
│   │   └── screens/news_screen.dart   # Community feed
│   └── profile/
│       └── screens/profile_screen.dart # User info + properties + sign out
└── shared/
    ├── widgets/                        # Reusable UI components
    ├── models/                         # Data models
    └── services/                       # API service classes
```

---

## Navigation

Bottom navigation bar with 5 tabs:
1. **Home** — Dashboard with quick actions and stats
2. **Visits** — My visits list + create new
3. **Scan** — QR scanner (guard mode)
4. **News** — Community announcements
5. **Profile** — User info + sign out

Auth redirect: unauthenticated users are redirected to `/login`.

---

## QR Flow

### Resident Flow
1. Create visit (name, document, property, type, expiration, max uses)
2. Visit saved to Supabase with status "active"
3. Open visit detail → tap "Generate QR Code"
4. Calls `generate-qr` Edge Function → gets signed JWT
5. QR rendered with qr_flutter
6. Share via WhatsApp/messages with share_plus

### Guard Flow
1. Open Scan tab → camera activates
2. Scan QR code → sends token to `validate-qr` Edge Function
3. If valid: shows visitor name, document, property, resident info
4. Guard taps "Approve Entry" → calls `confirm-access` Edge Function
5. Access logged, visit usage incremented
6. If invalid: shows error reason (expired, used, cancelled, etc.)

---

## Theme

Matches admin dashboard design system:
- Primary accent: #2563EB (blue)
- Dark mode support (follows system)
- Material Design 3
- Card-based UI with subtle borders

---

## Dependencies

See `pubspec.yaml` for full list. Key ones:
- supabase_flutter: ^2.8.0
- flutter_riverpod: ^2.6.1
- go_router: ^14.8.1
- qr_flutter: ^4.1.0
- mobile_scanner: ^6.0.2
- share_plus: ^10.1.4

---

## Requirements

- macOS 14+ (for Flutter development)
- Xcode 15+ (for iOS builds)
- Android Studio (for Android builds)
- Flutter SDK 3.2+

FILEEOF

mkdir -p docs
cat > docs/project-list.md << 'FILEEOF'
# Nimbus — MVP Project List

## Estado actual

- [x] Monorepo + pnpm workspaces
- [x] GitHub repo
- [x] Documentación fundacional (architecture, conventions, roadmap, permissions, db, stack, vision, goal)
- [x] Admin dashboard inicializado (Next.js 16 + React 19 + Tailwind 4)
- [x] Layout shell (sidebar, topbar, theme toggle, design tokens)

---

## FASE 1 — Foundation (Backend)

Lo que necesitás antes de escribir una línea de UI funcional.

### 1.1 Supabase Setup ✅
- [x] Crear proyecto en Supabase Cloud
- [x] Configurar variables de entorno (.env.local para admin)
- [x] Instalar Supabase client en admin (`@supabase/supabase-js`)
- [x] Crear cliente Supabase compartido (`lib/supabase.ts`)

### 1.2 Schema de Base de Datos ✅
- [x] Tabla `communities` (tenant principal)
- [x] Tabla `profiles` (datos de usuario extendidos, vinculado a auth.users)
- [x] Tabla `properties` (lotes/casas/departamentos)
- [x] Tabla `resident_properties` (relación N:N residente ↔ propiedad)
- [x] Tabla `roles` + `permissions` + `role_permissions` (RBAC dinámico)
- [x] Tabla `user_roles` (asignación de roles por comunidad)
- [x] Tabla `visits` (visitas temporales con QR)
- [x] Tabla `access_logs` (registro de entradas/salidas)
- [x] Tabla `news` (novedades/anuncios comunitarios)
- [x] Seed data: comunidad "Barrio Los Álamos", 3 roles default, 21 permisos

### 1.3 Row Level Security (RLS) ✅
- [x] RLS en todas las tablas tenant-aware (`community_id`)
- [x] Helper functions: `get_user_community_id()`, `user_has_permission()`
- [x] Políticas para admin (CRUD completo en su comunidad)
- [x] Políticas para resident (lectura propia, CRUD visitas propias)
- [x] Políticas para guard (lectura visitas activas, escritura access_logs)

### 1.4 Autenticación ✅
- [x] Configurar auth en Supabase (email + password)
- [x] Flujo de login en admin dashboard
- [x] AuthProvider context con protección de rutas
- [x] Redirect a login si no autenticado
- [x] Datos del usuario logueado en topbar + logout

---

## FASE 2 — Admin Dashboard (MVP funcional)

### 2.1 Dashboard Home ✅
- [x] Stats reales: total residentes, propiedades, visitas activas, entradas hoy
- [x] Lista de accesos recientes (últimas 10 entradas)
- [x] Lista de últimas novedades publicadas

### 2.2 Gestión de Propiedades ✅
- [x] Listado de propiedades (tabla con búsqueda)
- [x] Crear propiedad (modal: nombre, tipo, dirección)
- [x] Editar propiedad
- [x] Eliminar propiedad

### 2.3 Gestión de Residentes ✅
- [x] Listado de residentes (tabla con búsqueda)
- [x] Crear residente (API route con service_role: crea auth user + profile + role + property)
- [x] Editar datos de residente
- [x] Activar/desactivar residente

### 2.4 Gestión de Novedades ✅
- [x] Listado de novedades (cards)
- [x] Crear novedad (título, cuerpo)
- [x] Editar novedad
- [x] Publicar/despublicar toggle
- [x] Eliminar novedad

### 2.5 Logs de Acceso ✅
- [x] Listado de accesos con filtro por fecha

### 2.6 Visitas (read-only) ✅
- [x] Listado de visitas con filtro por estado (active/used/expired/cancelled)

---

## FASE 3 — QR System + Edge Functions

### 3.1 Edge Functions ⏳ (código listo, falta deploy)
- [x] `_shared/qr-jwt.ts` — Firma y verificación JWT (HMAC-SHA256)
- [x] `_shared/supabase.ts` — Clientes admin y user para Edge Functions
- [x] `_shared/cors.ts` — Headers CORS y helpers de respuesta
- [x] `generate-qr/index.ts` — Genera token firmado para una visita
- [x] `validate-qr/index.ts` — Valida token QR (firma, expiración, usos, estado, comunidad)
- [x] `confirm-access/index.ts` — Aprueba entrada, crea access_log, incrementa usos
- [ ] **Deploy** a Supabase (requiere CLI: `supabase functions deploy`)
- [ ] **Set secret** QR_JWT_SECRET en Supabase

### 3.2 Documentación ✅
- [x] `docs/edge-functions.md` — Arquitectura, endpoints, payloads, deployment

---

## FASE 4 — App Mobile (Flutter) — MVP

### 4.1 Setup ⏳ (código listo, falta Flutter SDK)
- [x] Estructura de proyecto en `apps/mobile/`
- [x] `pubspec.yaml` con todas las dependencias
- [x] Configuración Supabase client
- [x] Estructura de carpetas (features, core, shared)
- [ ] **Ejecutar** `flutter pub get` (requiere macOS 14+ con Flutter SDK)

### 4.2 Auth
- [x] Pantalla de login (email + password)
- [x] AuthProvider con Riverpod
- [x] Redirect automático si no autenticado

### 4.3 Residente — Features
- [x] Home con resumen (visitas activas, novedades recientes, quick actions)
- [x] Crear visita (nombre, documento, propiedad, tipo, max uses, expiración, notas)
- [x] Generar QR dinámico (llama a Edge Function + qr_flutter)
- [x] Compartir QR por WhatsApp / mensaje (share_plus)
- [x] Listar mis visitas (con filter chips: active/used/expired/all)
- [x] Cancelar visita
- [x] Feed de novedades comunitarias (con relative time)
- [x] Perfil y configuración (info, propiedades, sign out)

### 4.4 Guardia — Features
- [x] Escáner de QR (mobile_scanner con overlay)
- [x] Validación de QR → mostrar datos de visita + residente + propiedad
- [x] Aprobar entrada (llama a confirm-access Edge Function)
- [x] Resultado visual (✅ valid / ❌ invalid con razón)
- [x] "Scan Another" para siguiente visitante

### 4.5 Navegación
- [x] GoRouter con auth redirect
- [x] Bottom nav shell (Home, Visits, Scan, News, Profile)
- [x] Deep linking a visit detail

### 4.6 Documentación ✅
- [x] `docs/mobile-app.md` — Arquitectura, estructura, flujos, dependencias

---

## FASE 5 — Pulido y Lanzamiento

### 5.1 Testing
- [ ] Testing manual del flujo completo: admin crea propiedad → invita residente → residente crea visita → guardia valida QR
- [ ] Testing en dispositivos reales (iOS + Android)
- [ ] Edge cases: QR expirado, visita cancelada, residente desactivado

### 5.2 Deploy
- [ ] Deploy Edge Functions a Supabase
- [ ] Admin dashboard: deploy en Vercel
- [ ] App mobile: build de release iOS (TestFlight)
- [ ] App mobile: build de release Android (APK / Play Internal Testing)

### 5.3 Piloto
- [ ] Conseguir 1 comunidad piloto
- [ ] Onboarding: cargar propiedades y residentes
- [ ] Feedback loop: iteración rápida sobre problemas reales

---

## Orden de ejecución recomendado

```
FASE 1 (Foundation)     → 1.1 ✅ → 1.2 ✅ → 1.3 ✅ → 1.4 ✅
                              ↓
FASE 2 (Admin)          → 2.2 ✅ → 2.3 ✅ → 2.4 ✅ → 2.1 ✅ → 2.5 ✅ → 2.6 ✅
                              ↓
FASE 3 (QR + Edge Fn)   → 3.1 ⏳ (code done, deploy pending)
                              ↓
FASE 4 (Mobile)         → 4.1 ⏳ → 4.2 ✅ → 4.3 ✅ → 4.4 ✅ → 4.5 ✅
                              ↓
FASE 5 (Lanzamiento)    → 5.1 → 5.2 → 5.3
```

---

## Próximos pasos inmediatos

1. **Deploy Edge Functions** → necesita Supabase CLI (`npx supabase functions deploy`)
2. **Probar Flutter app** → necesita MacBook nuevo con macOS 14+
3. **Test flujo completo** end-to-end
4. **Deploy admin a Vercel**

---

## Fuera del MVP (documentado pero no se toca)

- Incidentes y reportes
- Gestión de vehículos
- Empleados domésticos / permisos recurrentes
- Analytics avanzado
- Amenities / reservas
- Pagos / expensas
- Marketplace
- IoT / smart gates / CCTV
- AI monitoring
- EV / energía
- Push notifications (Firebase Cloud Messaging)
- Magic link / OTP auth
- Registro manual de entrada (sin QR)
- Onboarding flow para primer login

FILEEOF

mkdir -p scripts
cat > scripts/deploy-edge-functions.sh << 'FILEEOF'
#!/bin/bash
# ============================================
# Nimbus — Deploy Edge Functions to Supabase
# ============================================
# Run from the nimbus root directory:
#   chmod +x scripts/deploy-edge-functions.sh
#   ./scripts/deploy-edge-functions.sh
# ============================================

set -e

PROJECT_REF="yxdwshujxsnamnmllljc"

echo "🔗 Linking Supabase project..."
npx supabase link --project-ref $PROJECT_REF

echo ""
echo "🚀 Deploying generate-qr..."
npx supabase functions deploy generate-qr --no-verify-jwt

echo ""
echo "🚀 Deploying validate-qr..."
npx supabase functions deploy validate-qr --no-verify-jwt

echo ""
echo "🚀 Deploying confirm-access..."
npx supabase functions deploy confirm-access --no-verify-jwt

echo ""
echo "🔐 Setting QR_JWT_SECRET..."
echo "Enter a secret key for signing QR tokens (or press Enter for default):"
read -r SECRET
if [ -z "$SECRET" ]; then
  SECRET="nimbus-qr-$(openssl rand -hex 16)"
  echo "Generated secret: $SECRET"
fi
npx supabase secrets set QR_JWT_SECRET="$SECRET"

echo ""
echo "✅ All Edge Functions deployed!"
echo ""
echo "Endpoints:"
echo "  POST https://$PROJECT_REF.supabase.co/functions/v1/generate-qr"
echo "  POST https://$PROJECT_REF.supabase.co/functions/v1/validate-qr"
echo "  POST https://$PROJECT_REF.supabase.co/functions/v1/confirm-access"
echo ""
echo "Test with:"
echo "  curl -X POST https://$PROJECT_REF.supabase.co/functions/v1/validate-qr \\"
echo "    -H 'Authorization: Bearer YOUR_JWT' \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"qr_token\": \"test\"}'"

FILEEOF

chmod +x scripts/deploy-edge-functions.sh

echo ""
echo "✅ All files created! $(find supabase apps/mobile docs/edge-functions.md docs/mobile-app.md scripts -type f 2>/dev/null | wc -l | tr -d ' ') files total."
echo ""
echo "Next steps:"
echo "  1. git add -A"
echo "  2. git commit -m 'feat: QR edge functions + Flutter mobile app + docs + updated project list'"
echo "  3. git push origin main"
echo "  4. Deploy Edge Functions: cd nimbus && ./scripts/deploy-edge-functions.sh"
