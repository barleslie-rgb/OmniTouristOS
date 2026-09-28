import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:local_auth/local_auth.dart';

class SettingsScreen extends StatefulWidget {
  final bool? isDarkMode;
  final Function(bool)? onToggleTheme;
  final Function(bool)? onThemeChanged;
  final String? selectedLanguage;
  final String? currentLanguage;
  final dynamic languageOptions;
  final Function(String)? onLanguageChanged;
  final VoidCallback? onClearCache;
  final String? backendUrl;
  final Function(String)? onBackendUrlChanged;

  const SettingsScreen({
    Key? key,
    this.isDarkMode,
    this.onToggleTheme,
    this.onThemeChanged,
    this.selectedLanguage,
    this.currentLanguage,
    this.languageOptions,
    this.onLanguageChanged,
    this.onClearCache,
    this.backendUrl,
    this.onBackendUrlChanged,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();

  late String _activeLanguage;
  late String _effectiveBackendUrl;
  late bool _darkMode;

  bool _biometricEnabled = false;
  bool _maskSensitiveNumbers = true;
  bool _canCheckBiometrics = false;
  double _cacheSizeMb = 0.0;
  bool _isClearingCache = false;

  bool _isPingingServer = false;
  String _pingStatus = "Ready to Check";
  int? _pingLatencyMs;
  Color _pingStatusColor = const Color(0xFF64748B);

  final List<Map<String, String>> _availableLanguages = [
    {"name": "English", "native": "English", "flag": "🇬🇧"},
    {"name": "Hindi", "native": "हिन्दी", "flag": "🇮🇳"},
    {"name": "Marathi", "native": "मराठी", "flag": "🇮🇳"},
    {"name": "Gujarati", "native": "ગુજરાતી", "flag": "🇮🇳"},
    {"name": "Tamil", "native": "தமிழ்", "flag": "🇮🇳"},
    {"name": "Telugu", "native": "తెలుగు", "flag": "🇮🇳"},
    {"name": "Kannada", "native": "ಕನ್ನಡ", "flag": "🇮🇳"},
    {"name": "Malayalam", "native": "മലയാളം", "flag": "🇮🇳"},
    {"name": "Bengali", "native": "বাংলা", "flag": "🇮🇳"},
    {"name": "Punjabi", "native": "ਪੰਜਾਬੀ", "flag": "🇮🇳"},
    {"name": "Urdu", "native": "اردو", "flag": "🇵🇰"},
    {"name": "Arabic", "native": "العربية", "flag": "🇦🇪"},
    {"name": "Spanish", "native": "Español", "flag": "🇪🇸"},
    {"name": "French", "native": "Français", "flag": "🇫🇷"},
    {"name": "German", "native": "Deutsch", "flag": "🇩🇪"},
    {"name": "Portuguese", "native": "Português", "flag": "🇵🇹"},
    {"name": "Russian", "native": "Русский", "flag": "🇷🇺"},
    {"name": "Japanese", "native": "日本語", "flag": "🇯🇵"},
    {"name": "Chinese", "native": "中文 (简体)", "flag": "🇨🇳"},
    {"name": "Korean", "native": "한국어", "flag": "🇰🇷"},
    {"name": "Italian", "native": "Italiano", "flag": "🇮🇹"},
    {"name": "Dutch", "native": "Nederlands", "flag": "🇳🇱"},
    {"name": "Turkish", "native": "Türkçe", "flag": "🇹🇷"},
  ];

  static const Map<String, Map<String, String>> _dict = {
    "English": {
      "title": "Settings & Preferences",
      "sec_general": "Interface & Theme",
      "dark_mode": "Dark Theme",
      "dark_mode_sub": "Enable high-contrast night mode",
      "app_lang": "App UI Language",
      "app_lang_sub": "Instant zero-latency UI switching",
      "sec_vault": "Travel Vault & Security",
      "biometric_title": "Biometric App Lock",
      "biometric_sub": "Require Fingerprint or Face ID for Travel Vault",
      "mask_title": "Mask ID & Passport Numbers",
      "mask_sub": "Hide numbers until tapped in public spaces",
      "sec_storage": "Storage & Cache Management",
      "cache_label": "Temporary App Cache",
      "clear_cache": "Clear Temporary Cache",
      "cleared_msg": "Temporary cache cleaned successfully!",
      "sec_backend": "Cloud & Railway Sync",
      "cloud_service_label": "Omni Cloud Services",
      "cloud_service_sub": "Transit tracking, currency rates & AI engine",
      "ping_btn": "Check / Wake Server",
      "pinging": "Checking server... (may take 30s)",
    },
    "Marathi": {
      "title": "सेटिंग्ज आणि प्राधान्ये",
      "sec_general": "इंटरफेस आणि थीम",
      "dark_mode": "डार्क मोड",
      "dark_mode_sub": "रात्रीच्या वापरासाठी डार्क थीम सक्षम करा",
      "app_lang": "अ‍ॅपची भाषा",
      "app_lang_sub": "थेट व जलद भाषा बदल",
      "sec_vault": "ट्रॅव्हल व्हॉल्ट व सुरक्षा",
      "biometric_title": "बायोमेट्रिक लॉक",
      "biometric_sub": "व्हॉल्ट उघडण्यासाठी फिंगरप्रिंट किंवा फेस आयडी वापरा",
      "mask_title": "क्रमांक सुरक्षित ठेवा",
      "mask_sub": "सार्वजनिक ठिकाणी क्रमांक लपवून ठेवा",
      "sec_storage": "स्टोरेज व कॅश व्यवस्थापन",
      "cache_label": "तात्पुरती कॅश मेमरी",
      "clear_cache": "कॅश मेमरी साफ करा",
      "cleared_msg": "कॅश मेमरी यशस्वीरीत्या साफ केली!",
      "sec_backend": "क्लाउड व रेल्वे सिंक",
      "cloud_service_label": "ऑम्नी क्लाउड सेवा",
      "cloud_service_sub": "रेल्वे माहिती, थेट चलन दर आणि एआय",
      "ping_btn": "सर्व्हर तपासा / सुरू करा",
      "pinging": "सर्व्हर सुरू होत आहे... (३० सेकंद थांबा)",
    },
    "Hindi": {
      "title": "सेटिंग्स और प्राथमिकताएं",
      "sec_general": "इंटरफ़ेस और थीम",
      "dark_mode": "डार्क मोड",
      "dark_mode_sub": "रात के लिए डार्क थीम सक्षम करें",
      "app_lang": "ऐप भाषा",
      "app_lang_sub": "तत्काल इंटरफ़ेस भाषा परिवर्तन",
      "sec_vault": "ट्रैवल वॉल्ट और सुरक्षा",
      "biometric_title": "बायोमेट्रिक लॉक",
      "biometric_sub": "वॉल्ट खोलने के लिए फ़िंगरप्रिंट या फ़ेस आईडी आवश्यक करें",
      "mask_title": "दस्तावेज़ नंबर छिपाएँ",
      "mask_sub": "सार्वजनिक स्थानों पर नंबर मास्क रखें",
      "sec_storage": "स्टोरेज और कैश प्रबंधन",
      "cache_label": "अस्थायी कैश फ़ाइलें",
      "clear_cache": "कैश साफ़ करें",
      "cleared_msg": "अस्थायी कैश सफलतापूर्वक हटा दिया गया!",
      "sec_backend": "क्लाउड और रेलवे सिंक",
      "cloud_service_label": "ओम्नी क्लाउड सेवाएं",
      "cloud_service_sub": "रेलवे ट्रैकिंग, लाइव मुद्रा दरें और एआई",
      "ping_btn": "सर्वर जांचें / जगाएं",
      "pinging": "सर्वर सक्रिय हो रहा है... (30 सेकंड लग सकते हैं)",
    },
    "Gujarati": {
      "title": "સેટિંગ્સ અને પસંદગીઓ",
      "sec_general": "ઇન્ટરફેસ અને થીમ",
      "dark_mode": "ડાર્ક મોડ",
      "dark_mode_sub": "નાઇટ મોડ સક્ષમ કરો",
      "app_lang": "એપ ભાષા",
      "app_lang_sub": "ત્વરિત ભાષા બદલો",
      "sec_vault": "ટ્રાવેલ વોલ્ટ અને સુરક્ષા",
      "biometric_title": "બાયોમેટ્રિક લોક",
      "biometric_sub": "વોલ્ટ ખોલવા માટે ફિંગરપ્રિન્ટ અથવા ફેસ આઈડી વાપરો",
      "mask_title": "નંબરો છુપાવો",
      "mask_sub": "જાહેર સ્થળોએ નંબર માસ્ક રાખો",
      "sec_storage": "સ્ટોરેજ અને કેશ મેનેજમેન્ટ",
      "cache_label": "કામચલાઉ કેશ મેમરી",
      "clear_cache": "કેશ સાફ કરો",
      "cleared_msg": "કેશ સફળતાપૂર્વક સાફ કરવામાં આવી!",
      "sec_backend": "ક્લાઉડ અને રેલ્વે સિંક",
      "cloud_service_label": "ઓમ્ની ક્લાઉડ સેવાઓ",
      "cloud_service_sub": "રેલ્વે ટ્રેકિંગ, કરન્સી દર અને એઆઈ",
      "ping_btn": "સર્વર ચકાસો / પિંગ કરો",
      "pinging": "સર્વર શરૂ થઈ રહ્યું છે...",
    },
  };

  String _t(String key) {
    final lang = _activeLanguage.trim();
    if (_dict.containsKey(lang) && _dict[lang]!.containsKey(key)) {
      return _dict[lang]![key]!;
    }
    return _dict["English"]![key] ?? key;
  }

  @override
  void initState() {
    super.initState();
    _activeLanguage = widget.selectedLanguage ?? widget.currentLanguage ?? "English";
    _effectiveBackendUrl = widget.backendUrl ?? "https://omni-backend-pk28.onrender.com";
    _darkMode = widget.isDarkMode ?? false;
    _loadPreferences();
    _calculateStorageUsage();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final bool canBio = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();

    setState(() {
      _biometricEnabled = prefs.getBool("vault_biometric_enabled") ?? false;
      _maskSensitiveNumbers = prefs.getBool("vault_mask_numbers") ?? true;
      _canCheckBiometrics = canBio;
      if (widget.isDarkMode == null) {
        _darkMode = prefs.getBool("app_dark_mode") ?? false;
      }
      final savedLang = prefs.getString("app_user_language");
      if (savedLang != null && savedLang.isNotEmpty) {
        _activeLanguage = savedLang;
      }
    });
  }

  Future<void> _calculateStorageUsage() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      double totalBytes = 0;

      if (cacheDir.existsSync()) {
        cacheDir.listSync(recursive: true).forEach((file) {
          if (file is File) {
            totalBytes += file.lengthSync();
          }
        });
      }

      if (mounted) {
        setState(() {
          _cacheSizeMb = totalBytes / (1024 * 1024);
        });
      }
    } catch (_) {}
  }

  Future<void> _clearTemporaryCache() async {
    setState(() => _isClearingCache = true);
    try {
      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.existsSync()) {
        cacheDir.listSync(recursive: true).forEach((file) {
          try {
            if (file is File) file.deleteSync();
          } catch (_) {}
        });
      }
      await _calculateStorageUsage();

      if (widget.onClearCache != null) {
        widget.onClearCache!();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Text(_t("cleared_msg")),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearingCache = false);
    }
  }

  Future<void> _pingOrWakeServer() async {
    final baseUrl = _effectiveBackendUrl.trim();
    if (baseUrl.isEmpty) return;

    setState(() {
      _isPingingServer = true;
      _pingStatus = "Connecting...";
      _pingLatencyMs = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final uri = Uri.parse("$cleanBase/");

      final response = await http.get(uri).timeout(const Duration(seconds: 45));
      stopwatch.stop();

      if (mounted) {
        setState(() {
          _pingLatencyMs = stopwatch.elapsedMilliseconds;
          if (response.statusCode >= 200 && response.statusCode < 400) {
            _pingStatus = "Connected";
            _pingStatusColor = const Color(0xFF16A34A);
          } else {
            _pingStatus = "HTTP ${response.statusCode}";
            _pingStatusColor = const Color(0xFFEA580C);
          }
        });
      }
    } catch (e) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _pingStatus = "Asleep / Offline";
          _pingStatusColor = const Color(0xFFDC2626);
          _pingLatencyMs = null;
        });
      }
    } finally {
      if (mounted) setState(() => _isPingingServer = false);
    }
  }

  void _onLanguageSelected(String newLang) async {
    setState(() => _activeLanguage = newLang);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("app_user_language", newLang);
    if (widget.onLanguageChanged != null) {
      widget.onLanguageChanged!(newLang);
    }
    if (mounted) Navigator.pop(context);
  }

  void _showLanguagePickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.language_rounded, color: Color(0xFF2563EB), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    _t("app_lang"),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${_availableLanguages.length} Languages",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _availableLanguages.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final lang = _availableLanguages[index];
                  final isSelected = _activeLanguage == lang["name"];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: Text(lang["flag"]!, style: const TextStyle(fontSize: 24)),
                    title: Text(
                      "${lang['native']} (${lang['name']})",
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 20)
                        : null,
                    onTap: () => _onLanguageSelected(lang["name"]!),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleDarkMode(bool val) async {
    setState(() => _darkMode = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("app_dark_mode", val);
    if (widget.onToggleTheme != null) {
      widget.onToggleTheme!(val);
    }
    if (widget.onThemeChanged != null) {
      widget.onThemeChanged!(val);
    }
  }

  void _toggleBiometrics(bool val) async {
    if (val) {
      final authenticated = await _localAuth.authenticate(
        localizedReason: "Please authenticate to enable Biometric Protection for Travel Vault",
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
      );
      if (!authenticated) return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("vault_biometric_enabled", val);
    setState(() => _biometricEnabled = val);
  }

  void _toggleMasking(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("vault_mask_numbers", val);
    setState(() => _maskSensitiveNumbers = val);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final activeLangObj = _availableLanguages.firstWhere(
      (l) => l["name"] == _activeLanguage,
      orElse: () => {"name": "English", "native": "English", "flag": "🇬🇧"},
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            // Borderless Header ($y = 0$)
            Container(
              padding: EdgeInsets.fromLTRB(16, topInset + 6, 16, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: const Color(0xFFE2E8F0).withOpacity(0.6), width: 0.6)),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.6),
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("PREFERENCES & CONFIG", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
                        Text(_t("title"), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A))),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset > 0 ? bottomInset + 16 : 24),
                children: [
                  // 1. INTERFACE & THEME
                  _buildSectionHeader(_t("sec_general")),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 0.6),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_t("dark_mode"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
                          subtitle: Text(_t("dark_mode_sub"), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          value: _darkMode,
                          activeColor: const Color(0xFF2563EB),
                          onChanged: _toggleDarkMode,
                        ),
                        const Divider(height: 16),
                        InkWell(
                          onTap: _showLanguagePickerModal,
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_t("app_lang"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
                                      const SizedBox(height: 2),
                                      Text(_t("app_lang_sub"), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFBFDBFE), width: 0.6),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(activeLangObj["flag"]!, style: const TextStyle(fontSize: 15)),
                                      const SizedBox(width: 6),
                                      Text(
                                        activeLangObj["name"]!,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF), fontSize: 12),
                                      ),
                                      const SizedBox(width: 2),
                                      const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF2563EB), size: 16),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 2. TRAVEL VAULT & SECURITY
                  _buildSectionHeader(_t("sec_vault")),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 0.6),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_t("biometric_title"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
                          subtitle: Text(
                            _canCheckBiometrics ? _t("biometric_sub") : "Biometrics unavailable on device",
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          value: _biometricEnabled && _canCheckBiometrics,
                          activeColor: const Color(0xFF2563EB),
                          onChanged: _canCheckBiometrics ? _toggleBiometrics : null,
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_t("mask_title"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
                          subtitle: Text(_t("mask_sub"), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          value: _maskSensitiveNumbers,
                          activeColor: const Color(0xFF2563EB),
                          onChanged: _toggleMasking,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. STORAGE & CACHE HYGIENE
                  _buildSectionHeader(_t("sec_storage")),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 0.6),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_t("cache_label"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
                                const SizedBox(height: 2),
                                const Text("Temporary previews & cached maps", style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ],
                            ),
                            Text(
                              "${_cacheSizeMb.toStringAsFixed(2)} MB",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2563EB)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              side: const BorderSide(color: Color(0xFFFCA5A5), width: 0.8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _isClearingCache ? null : _clearTemporaryCache,
                            icon: _isClearingCache
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC2626)))
                                : const Icon(Icons.delete_sweep_rounded, size: 18),
                            label: Text(_t("clear_cache"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 4. CLOUD & RAILWAY SYNC
                  _buildSectionHeader(_t("sec_backend")),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 0.6),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
                              child: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF2563EB), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_t("cloud_service_label"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
                                  Text(_t("cloud_service_sub"), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _pingStatusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _pingStatusColor.withOpacity(0.25), width: 0.6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 6, height: 6, decoration: BoxDecoration(color: _pingStatusColor, shape: BoxShape.circle)),
                                  const SizedBox(width: 4),
                                  Text(
                                    _pingLatencyMs != null ? "$_pingStatus • ${_pingLatencyMs}ms" : _pingStatus,
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _pingStatusColor),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _isPingingServer ? null : _pingOrWakeServer,
                            icon: _isPingingServer
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.bolt_rounded, size: 18),
                            label: Text(
                              _isPingingServer ? _t("pinging") : _t("ping_btn"),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF64748B),
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}