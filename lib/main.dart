import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/app_theme.dart';
import 'screens/auth_screen.dart';
import 'screens/my_trip_screen.dart';
import 'screens/touristos_chat_screen.dart';
import 'screens/admin_console_screen.dart';
import 'screens/community_gems_screen.dart';
import 'screens/paper_pilot_screen.dart';
import 'screens/street_translator_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/expense_ledger_screen.dart';
import 'screens/omni_family_vault_screen.dart';
import 'screens/indian_railways_screen.dart';
import 'screens/offline_survival_deck_screen.dart';
import 'screens/converter_studio_screen.dart';
import 'screens/about_screen.dart';
import 'screens/travel_hub_screen.dart';
import 'services/supabase_service.dart';
import 'services/auth_service.dart';
import 'services/trip_state_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  await SupabaseService.ensureInitialized();

  runApp(const TouristOSApp());
}

class TouristOSApp extends StatelessWidget {
  const TouristOSApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Omni TouristOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}

// -------------------------------------------------------------
// AUTH GATEWAY
// -------------------------------------------------------------
class AuthGate extends StatefulWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();

    _sub = AuthService.authStateChanges.listen((data) {
      final session = data.session;
      if (session != null) {
        if (mounted) {
          setState(() {
            _isAuthenticated = true;
            _isLoading = false;
          });
        }
      } else {
        _checkGuestStatus();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialAuth() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          _isLoading = false;
        });
      }
      return;
    }
    await _checkGuestStatus();
  }

  Future<void> _checkGuestStatus() async {
    final isGuest = await AuthService.isGuest();
    if (mounted) {
      setState(() {
        _isAuthenticated = isGuest;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2563EB)),
        ),
      );
    }

    if (_isAuthenticated) {
      return const MainNavigationShell();
    }

    return AuthScreen(
      onLoginSuccess: () {
        setState(() => _isAuthenticated = true);
      },
    );
  }
}

// -------------------------------------------------------------
// MAIN NAVIGATION SHELL
// -------------------------------------------------------------
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({Key? key}) : super(key: key);

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _currentCity = "Vasai-Virar";
  String _currentState = "Maharashtra";
  String _currentCountry = "India";
  String _selectedLanguage = "English";
  final String _backendUrl = "https://omni-backend-pk28.onrender.com";

  void _onCityChanged(String city, String state, String country) {
    setState(() {
      _currentCity = city;
      _currentState = state;
      _currentCountry = country;
    });
    TripStateService.syncActiveCityAndTransit(city: city, state: state, country: country);
  }

  String _getUserEmail() {
    final user = AuthService.currentUser;
    if (user != null && user.email != null && user.email!.isNotEmpty) {
      return user.email!;
    }
    return "barleslie@gmail.com";
  }

  void _handleToolNavigation(int targetIndex) {
    switch (targetIndex) {
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => PaperPilotScreen(
              language: _selectedLanguage,
              backendUrl: _backendUrl,
            ),
          ),
        );
        break;

      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => TravelHubScreen(
              language: _selectedLanguage,
              activeCity: _currentCity,
              activeState: _currentState,
              activeCountry: _currentCountry,
              backendUrl: _backendUrl,
              initialTabIndex: 0,
            ),
          ),
        );
        break;

      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => TouristOSChatScreen(
              language: _selectedLanguage,
              activeCity: _currentCity,
              backendUrl: _backendUrl,
            ),
          ),
        );
        break;

      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => StreetTranslatorScreen(
              language: _selectedLanguage,
              backendUrl: _backendUrl,
            ),
          ),
        );
        break;

      case 5:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => IndianRailwaysScreen(
              language: _selectedLanguage,
              backendUrl: _backendUrl,
            ),
          ),
        );
        break;

      case 6:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => OmniFamilyVaultScreen(
              language: _selectedLanguage,
              backendUrl: _backendUrl,
            ),
          ),
        );
        break;

      case 7:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => CommunityGemsScreen(
              activeCity: _currentCity,
              language: _selectedLanguage,
              backendUrl: _backendUrl,
            ),
          ),
        );
        break;

      case 8:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => ConverterStudioScreen(backendUrl: _backendUrl),
          ),
        );
        break;

      case 9:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => SettingsScreen(
              currentLanguage: _selectedLanguage,
              backendUrl: _backendUrl,
              onLanguageChanged: (lang) => setState(() => _selectedLanguage = lang),
            ),
          ),
        );
        break;

      case 10:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => OfflineSurvivalDeckScreen(language: _selectedLanguage),
          ),
        );
        break;

      case 13:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => const ExpenseLedgerScreen(),
          ),
        );
        break;

      case 14:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => TravelHubScreen(
              language: _selectedLanguage,
              activeCity: _currentCity,
              activeState: _currentState,
              activeCountry: _currentCountry,
              backendUrl: _backendUrl,
              initialTabIndex: 1,
            ),
          ),
        );
        break;

      case 15:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => const AboutFeaturesScreen(),
          ),
        );
        break;

      case 99: // Master Admin Console Direct
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => AdminConsoleScreen(backendUrl: _backendUrl),
          ),
        );
        break;

      default:
        _scaffoldKey.currentState?.openDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF8FAFC),
        drawer: _buildAppDrawer(),
        body: MyTripScreen(
          language: _selectedLanguage,
          backendUrl: _backendUrl,
          onNavigateTab: _handleToolNavigation,
          onCityChange: _onCityChanged,
          onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
          onLanguageChanged: (lang) => setState(() => _selectedLanguage = lang),
        ),
      ),
    );
  }

  Widget _buildAppDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: const Color(0xFF2563EB),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Omni TouristOS",
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.account_circle_rounded, color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _getUserEmail(),
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.pin_drop_rounded, color: Colors.white54, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        "Active: $_currentCity, $_currentState",
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _handleToolNavigation(99);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Color(0xFF1E3A8A), shape: BoxShape.circle),
                        child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF60A5FA), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text("Master Admin Console", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            Text("Telemetry, Profiles & Server Status", style: TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _buildDrawerSectionHeader("TRIP & EXPLORATION"),
            _buildDrawerItem(Icons.grid_view_rounded, "Home Dashboard", () => Navigator.pop(context), isSelected: true),
            _buildDrawerItem(Icons.explore_rounded, "Destinations Explorer", () {
              Navigator.pop(context);
              _handleToolNavigation(2);
            }),
            _buildDrawerItem(Icons.flight_takeoff_rounded, "Flights & Stays Hub", () {
              Navigator.pop(context);
              _handleToolNavigation(14);
            }),
            _buildDrawerItem(Icons.train_rounded, "Railway Transit", () {
              Navigator.pop(context);
              _handleToolNavigation(5);
            }),
            _buildDrawerItem(Icons.star_rounded, "Community Gems", () {
              Navigator.pop(context);
              _handleToolNavigation(7);
            }),
            _buildDrawerSectionHeader("STREET SURVIVAL & AI"),
            _buildDrawerItem(Icons.offline_bolt_rounded, "Offline Survival Deck", () {
              Navigator.pop(context);
              _handleToolNavigation(10);
            }, trailingBadge: "No-Data"),
            _buildDrawerItem(Icons.record_voice_over_rounded, "Street Voice Interpreter", () {
              Navigator.pop(context);
              _handleToolNavigation(4);
            }),
            _buildDrawerItem(Icons.document_scanner_rounded, "Paper Pilot Scanner", () {
              Navigator.pop(context);
              _handleToolNavigation(1);
            }),
            _buildDrawerItem(Icons.support_agent_rounded, "TouristOS Guide Chat", () {
              Navigator.pop(context);
              _handleToolNavigation(3);
            }),
            _buildDrawerSectionHeader("MONEY & UTILITIES"),
            _buildDrawerItem(Icons.account_balance_wallet_rounded, "Trip Expense & Split Ledger", () {
              Navigator.pop(context);
              _handleToolNavigation(13);
            }, trailingBadge: "Split"),
            _buildDrawerItem(Icons.currency_exchange_rounded, "Converter Studio", () {
              Navigator.pop(context);
              _handleToolNavigation(8);
            }),
            _buildDrawerItem(Icons.folder_special_rounded, "Family Travel Vault", () {
              Navigator.pop(context);
              _handleToolNavigation(6);
            }),
            _buildDrawerSectionHeader("SYSTEM & PREFERENCES"),
            _buildDrawerItem(Icons.info_outline_rounded, "About & Features", () {
              Navigator.pop(context);
              _handleToolNavigation(15);
            }),
            _buildDrawerItem(Icons.settings_rounded, "Settings", () {
              Navigator.pop(context);
              _handleToolNavigation(9);
            }),
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
              title: const Text("Sign Out", style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 13.5)),
              onTap: () async {
                Navigator.pop(context);
                await AuthService.signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text(
        title,
        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap, {bool isSelected = false, String? trailingBadge}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 1.5),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569), size: 20),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
        trailing: trailingBadge != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(trailingBadge, style: const TextStyle(fontSize: 9.5, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}