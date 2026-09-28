import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/app_theme.dart';
import 'screens/auth_screen.dart';
import 'screens/my_trip_screen.dart';
import 'screens/touristos_explorer_screen.dart';
import 'screens/flights_and_stays_hub_screen.dart';
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
import 'services/supabase_service.dart';
import 'services/auth_service.dart';
import 'services/trip_state_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enforce zero-scrim edge-to-edge layout across the entire Flutter runtime
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

  // Initialize Supabase Client
  await SupabaseService.ensureInitialized();

  runApp(const TouristOSApp());
}

class TouristOSApp extends StatelessWidget {
  const TouristOSApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TouristOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}

// -------------------------------------------------------------
// AUTH GATE
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
// MAIN SHELL & ROUTER
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

  // Comprehensive language catalog: Indian Regional, European, Southeast Asian, & Arabic
  final List<Map<String, String>> _availableLanguages = [
    // Global Default
    {"code": "EN", "name": "English", "native": "English"},

    // Indian Regional Languages
    {"code": "HI", "name": "Hindi", "native": "हिन्दी"},
    {"code": "MR", "name": "Marathi", "native": "मराठी"},
    {"code": "GU", "name": "Gujarati", "native": "ગુજરાતી"},
    {"code": "BN", "name": "Bengali", "native": "বাংলা"},
    {"code": "TA", "name": "Tamil", "native": "தமிழ்"},
    {"code": "TE", "name": "Telugu", "native": "తెలుగు"},
    {"code": "KN", "name": "Kannada", "native": "ಕನ್ನಡ"},
    {"code": "ML", "name": "Malayalam", "native": "മലയാളം"},
    {"code": "PA", "name": "Punjabi", "native": "ਪੰਜਾਬੀ"},
    {"code": "OR", "name": "Odia", "native": "ଓଡ଼ିଆ"},

    // Middle Eastern & Arabic
    {"code": "AR", "name": "Arabic", "native": "العربية"},
    {"code": "FA", "name": "Persian", "native": "فارسی"},
    {"code": "UR", "name": "Urdu", "native": "اردو"},
    {"code": "HE", "name": "Hebrew", "native": "עברית"},
    {"code": "TR", "name": "Turkish", "native": "Türkçe"},
    {"code": "SW", "name": "Swahili", "native": "Kiswahili"},
    {"code": "AM", "name": "Amharic", "native": "አማርኛ"},
    {"code": "AR", "name": "Arabic (Egyptian)", "native": "العربية (المصرية)"},
    {"code": "AR", "name": "Arabic (Levantine)", "native": "العربية (الشامية)"},

    // European Languages
    {"code": "FR", "name": "French", "native": "Français"},
    {"code": "DE", "name": "German", "native": "Deutsch"},
    {"code": "ES", "name": "Spanish", "native": "Español"},
    {"code": "IT", "name": "Italian", "native": "Italiano"},
    {"code": "PT", "name": "Portuguese", "native": "Português"},
    {"code": "NL", "name": "Dutch", "native": "Nederlands"},
    {"code": "PL", "name": "Polish", "native": "Polski"},
    {"code": "RU", "name": "Russian", "native": "Русский"},

    // Southeast & East Asian Languages
    {"code": "JA", "name": "Japanese", "native": "日本語"},
    {"code": "ZH", "name": "Chinese", "native": "简体中文"},
    {"code": "TH", "name": "Thai", "native": "ไทย"},
    {"code": "VI", "name": "Vietnamese", "native": "Tiếng Việt"},
    {"code": "KO", "name": "Korean", "native": "한국어"},
    {"code": "MS", "name": "Malay", "native": "Bahasa Melayu"},
        {"code": "ID", "name": "Indonesian", "native": "Bahasa Indonesia"},
  ];

  void _onCityChanged(String city, String state, String country) {
    setState(() {
      _currentCity = city;
      _currentState = state;
      _currentCountry = country;
    });
    TripStateService.syncActiveCityAndTransit(city: city, state: state, country: country);
  }

  void _showCityPickerDialog() {
    final ctrl = TextEditingController(text: _currentCity);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Switch Active Destination", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: "City Name",
            hintText: "e.g., Jaipur, Mumbai, Tokyo",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            onPressed: () {
              final newCity = ctrl.text.trim();
              if (newCity.isNotEmpty) {
                _onCityChanged(newCity, _currentState, _currentCountry);
                Navigator.pop(ctx);
              }
            },
            child: const Text("UPDATE"),
          ),
        ],
      ),
    );
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
      case 1: // Paper Pilot Document Scanner
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

      case 2: // Destination Explorer
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => TouristOSExplorerScreen(
              language: _selectedLanguage,
              initialCity: _currentCity,
              initialState: _currentState,
              initialCountry: _currentCountry,
              backendUrl: _backendUrl,
            ),
          ),
        );
        break;

      case 3: // Guide Chat Concierge
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

      case 4: // Street Voice Interpreter & Lens
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

      case 5: // Indian Railways Live Transit & Booking
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

      case 6: // Family Travel Vault
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

      case 7: // Community Gems Hyperlocal Directory
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => CommunityGemsScreen(activeCity: _currentCity),
          ),
        );
        break;

      case 8: // Converter Studio (Forex & Bullion)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => ConverterStudioScreen(backendUrl: _backendUrl),
          ),
        );
        break;

      case 10: // Offline Survival Deck
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => OfflineSurvivalDeckScreen(language: _selectedLanguage),
          ),
        );
        break;

      case 13: // Trip Expense & Split Ledger
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => const ExpenseLedgerScreen(),
          ),
        );
        break;

      case 14: // Compare Flights & Stays Booking Hub
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => FlightsAndStaysHubScreen(
              initialCity: _currentCity,
              initialCountry: _currentCountry,
              initialTab: 0,
            ),
          ),
        );
        break;

      case 9: // Settings
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

      default:
        _scaffoldKey.currentState?.openDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine the short code of the current language for the AppBar badge
    final currentMatch = _availableLanguages.firstWhere(
      (l) => l["name"] == _selectedLanguage,
      orElse: () => _availableLanguages.first,
    );
    final String currentCode = currentMatch["code"] ?? "EN";

    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: false,
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: _buildAppDrawer(),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemStatusBarContrastEnforced: false,
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Color(0xFF0F172A), size: 26),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        titleSpacing: 0,
        title: InkWell(
          onTap: _showCityPickerDialog,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currentCity,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16.5, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.near_me_rounded, size: 14, color: Color(0xFF2563EB)),
                  ],
                ),
                Text(
                  "$_currentState, $_currentCountry",
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14),
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.download_done_rounded, size: 14, color: Colors.white),
          ),
          IconButton(
            icon: const Icon(Icons.my_location_rounded, color: Color(0xFF2563EB), size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 2),
                  content: Text("GPS Locked: $_currentCity, $_currentState"),
                ),
              );
            },
          ),
          // Complete International & Regional Language Dropdown
          Container(
            margin: const EdgeInsets.only(right: 14, left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLanguage,
                isDense: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF2563EB)),
                items: _availableLanguages.map((langMap) {
                  final String name = langMap["name"]!;
                  final String code = langMap["code"]!;
                  final String native = langMap["native"]!;

                  return DropdownMenuItem<String>(
                    value: name,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.language_rounded, size: 13, color: Color(0xFF2563EB)),
                        const SizedBox(width: 4),
                        Text(
                          "$code ($native)",
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedLanguage = val);
                },
              ),
            ),
          ),
        ],
      ),
      body: MyTripScreen(
        language: _selectedLanguage,
        backendUrl: _backendUrl,
        onNavigateTab: _handleToolNavigation,
        onCityChange: _onCityChanged,
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
                        "Active Location: $_currentCity, $_currentState",
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Master Admin Console
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => AdminConsoleScreen(backendUrl: _backendUrl),
                    ),
                  );
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
                        decoration: const BoxDecoration(color: Color(0xFF1E293B), shape: BoxShape.circle),
                        child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF38BDF8), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text("Master Admin Console", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            Text("Telemetry & Key Health", style: TextStyle(color: Colors.white54, fontSize: 11)),
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
            _buildDrawerItem(Icons.explore_rounded, "Destination Explorer", () {
              Navigator.pop(context);
              _handleToolNavigation(2);
            }),
            _buildDrawerItem(Icons.flight_takeoff_rounded, "Compare Flights & Stays", () {
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
            _buildDrawerItem(Icons.settings_rounded, "Settings", () {
              Navigator.pop(context);
              _handleToolNavigation(9);
            }),
            _buildDrawerItem(Icons.info_outline_rounded, "About Omni TouristOS", () {
              Navigator.pop(context);
              showAboutDialog(
                context: context,
                applicationName: "Omni TouristOS",
                applicationVersion: "Version 85.0.0 (Production Release)",
                applicationLegalese: "The comprehensive travel operating system engineered for seamless navigation.",
              );
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        title,
        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap, {bool isSelected = false, String? trailingBadge}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
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
                child: Text(trailingBadge, style: const TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}