import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import '../services/offline_cache_service.dart';

class OfflineSurvivalDeckScreen extends StatefulWidget {
  final String language;
  final String backendUrl;

  const OfflineSurvivalDeckScreen({
    Key? key,
    required this.language,
    this.backendUrl = "https://omni-backend-pk28.onrender.com",
  }) : super(key: key);

  @override
  State<OfflineSurvivalDeckScreen> createState() => _OfflineSurvivalDeckScreenState();
}

class _OfflineSurvivalDeckScreenState extends State<OfflineSurvivalDeckScreen> {
  late FlutterTts _flutterTts;
  late String _activeFourthLang;
  bool _isFemaleVoice = false; // Default to male acoustic voice
  List<dynamic> _availableTtsVoices = [];

  String _selectedCategory = "All";
  String _searchQuery = "";
  final TextEditingController _searchCtrl = TextEditingController();

  final TextEditingController _customInputCtrl = TextEditingController();
  bool _isTranslatingCustom = false;
  Map<String, String>? _customTranslationResult;

  final List<String> _categories = [
    "All",
    "Emergency & Medical",
    "Transit & Directions",
    "Street & Dining",
    "Haggling & Shopping",
  ];

  static const List<Map<String, dynamic>> _catalogLanguages = [
    {"name": "German", "code": "DE", "native": "Deutsch", "tts": "de-DE", "iso": "de", "region": "European"},
    {"name": "French", "code": "FR", "native": "Français", "tts": "fr-FR", "iso": "fr", "region": "European"},
    {"name": "Spanish", "code": "ES", "native": "Español", "tts": "es-ES", "iso": "es", "region": "European"},
    {"name": "Italian", "code": "IT", "native": "Italiano", "tts": "it-IT", "iso": "it", "region": "European"},
    {"name": "Portuguese", "code": "PT", "native": "Português", "tts": "pt-PT", "iso": "pt", "region": "European"},
    {"name": "Russian", "code": "RU", "native": "Русский", "tts": "ru-RU", "iso": "ru", "region": "European"},
    {"name": "Gujarati", "code": "GU", "native": "ગુજરાતી", "tts": "gu-IN", "iso": "gu", "region": "Indian Regional"},
    {"name": "Bengali", "code": "BN", "native": "বাংলা", "tts": "bn-IN", "iso": "bn", "region": "Indian Regional"},
    {"name": "Tamil", "code": "TA", "native": "தமிழ்", "tts": "ta-IN", "iso": "ta", "region": "Indian Regional"},
    {"name": "Telugu", "code": "TE", "native": "తెలుగు", "tts": "te-IN", "iso": "te", "region": "Indian Regional"},
    {"name": "Kannada", "code": "KN", "native": "ಕನ್ನಡ", "tts": "kn-IN", "iso": "kn", "region": "Indian Regional"},
    {"name": "Urdu", "code": "UR", "native": "اردو", "tts": "ur-PK", "iso": "ur", "region": "Indian Regional"},
    {"name": "Punjabi", "code": "PA", "native": "ਪੰਜਾਬੀ", "tts": "pa-IN", "iso": "pa", "region": "Indian Regional"},
    {"name": "Malayalam", "code": "ML", "native": "മലയാളം", "tts": "ml-IN", "iso": "ml", "region": "Indian Regional"},
    {"name": "Arabic", "code": "AR", "native": "العربية", "tts": "ar-SA", "iso": "ar", "region": "Middle Eastern"},
    {"name": "Persian", "code": "FA", "native": "فارسی", "tts": "fa-IR", "iso": "fa", "region": "Middle Eastern"},
    {"name": "Hebrew", "code": "HE", "native": "עברית", "tts": "he-IL", "iso": "he", "region": "Middle Eastern"},
    {"name": "Turkish", "code": "TR", "native": "Türkçe", "tts": "tr-TR", "iso": "tr", "region": "Middle Eastern"},
    {"name": "Japanese", "code": "JA", "native": "日本語", "tts": "ja-JP", "iso": "ja", "region": "East & SE Asian"},
    {"name": "Vietnamese", "code": "VI", "native": "Tiếng Việt", "tts": "vi-VN", "iso": "vi", "region": "East & SE Asian"},
    {"name": "Chinese", "code": "ZH", "native": "简体中文", "tts": "zh-CN", "iso": "zh-CN", "region": "East & SE Asian"},
    {"name": "Thai", "code": "TH", "native": "ไทย", "tts": "th-TH", "iso": "th", "region": "East & SE Asian"},
    {"name": "Indonesian", "code": "ID", "native": "Bahasa Indonesia", "tts": "id-ID", "iso": "id", "region": "East & SE Asian"},
    {"name": "Korean", "code": "KO", "native": "한국어", "tts": "ko-KR", "iso": "ko", "region": "East & SE Asian"},
  ];

  @override
  void initState() {
    super.initState();
    _activeFourthLang = _resolveInitialLang(widget.language);
    _flutterTts = FlutterTts();
    _initEngine();
  }

  String _resolveInitialLang(String lang) {
    final match = _catalogLanguages.firstWhere(
      (l) => l["name"].toString().toLowerCase() == lang.toLowerCase(),
      orElse: () => _catalogLanguages.first,
    );
    return match["name"] as String;
  }

  Future<void> _initEngine() async {
    try {
      final voices = await _flutterTts.getVoices;
      if (voices is List && voices.isNotEmpty) {
        _availableTtsVoices = voices;
      }
    } catch (_) {}
  }

  Future<void> _applyVoiceProfile(String locale) async {
    // 1. Refresh voices dynamically if cold start was empty
    if (_availableTtsVoices.isEmpty) {
      try {
        final voices = await _flutterTts.getVoices;
        if (voices is List) _availableTtsVoices = voices;
      } catch (_) {}
    }

    // 2. Set language first
    await _flutterTts.setLanguage(locale);

    // 3. Scan and select exact gender voice model
    if (_availableTtsVoices.isNotEmpty) {
      try {
        final prefix = locale.split(RegExp(r'[-_]')).first.toLowerCase();
        final matches = _availableTtsVoices.where((v) {
          final l = (v["locale"] ?? "").toString().toLowerCase();
          return l.contains(prefix);
        }).toList();

        Map<dynamic, dynamic>? chosen;
        for (var v in matches) {
          final name = (v["name"] ?? "").toString().toLowerCase();
          if (!_isFemaleVoice) {
            if (name.contains("male") ||
                name.contains("man") ||
                name.contains("#m") ||
                name.contains("-m-") ||
                name.contains("iom") ||
                name.contains("hid") ||
                name.contains("male_1")) {
              chosen = v as Map<dynamic, dynamic>;
              break;
            }
          } else {
            if (name.contains("female") ||
                name.contains("woman") ||
                name.contains("#f") ||
                name.contains("-f-") ||
                name.contains("sfg") ||
                name.contains("hie") ||
                name.contains("female_1")) {
              chosen = v as Map<dynamic, dynamic>;
              break;
            }
          }
        }

        if (chosen != null) {
          await _flutterTts.setVoice({
            "name": chosen["name"].toString(),
            "locale": chosen["locale"].toString(),
          });
        }
      } catch (_) {}
    }

    // 4. Force pitch & rate immediately after setting voice to override system defaults
    if (_isFemaleVoice) {
      await _flutterTts.setPitch(1.18);
      await _flutterTts.setSpeechRate(0.50);
    } else {
      await _flutterTts.setPitch(0.60); // Deep resonant masculine pitch
      await _flutterTts.setSpeechRate(0.46);
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _searchCtrl.dispose();
    _customInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _speakPhrase(String text, String langName) async {
    if (text.trim().isEmpty) return;
    HapticFeedback.selectionClick();

    String locale = "en-US";
    if (langName == "Hindi") {
      locale = "hi-IN";
    } else if (langName == "Marathi") {
      locale = "mr-IN";
    } else if (langName == "English") {
      locale = "en-US";
    } else {
      final match = _catalogLanguages.firstWhere(
        (l) => l["name"] == langName,
        orElse: () => _catalogLanguages.first,
      );
      locale = match["tts"] as String;
    }

    await _flutterTts.stop();
    await _applyVoiceProfile(locale);
    await _flutterTts.speak(text);
  }

  String _sanitizeInput(String input) {
    return input
        .replaceAll(RegExp(r'\bu\b', caseSensitive: false), "you")
        .replaceAll(RegExp(r'\bur\b', caseSensitive: false), "your")
        .replaceAll(RegExp(r'\br\b', caseSensitive: false), "are")
        .replaceAll(RegExp(r'\bpls\b', caseSensitive: false), "please")
        .trim();
  }

  String _getLanguageIso(String langName) {
    if (langName == "Hindi") return "hi";
    if (langName == "Marathi") return "mr";
    if (langName == "English") return "en";
    final match = _catalogLanguages.firstWhere(
      (l) => l["name"] == langName,
      orElse: () => {"iso": "de"},
    );
    return match["iso"] as String;
  }

  Future<String> _translateSingleTarget(String text, String targetIso) async {
    try {
      final url = Uri.parse(
        "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=$targetIso&dt=t&q=${Uri.encodeComponent(text)}",
      );
      final res = await http.get(url).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final List parsed = jsonDecode(res.body);
        final buffer = StringBuffer();
        for (var part in parsed[0]) {
          if (part[0] != null) buffer.write(part[0]);
        }
        final result = buffer.toString().trim();
        if (result.isNotEmpty) return result;
      }
    } catch (_) {}
    return text;
  }

  Future<void> _translateArbitraryTextOffline() async {
    final rawText = _customInputCtrl.text.trim();
    if (rawText.isEmpty) return;

    final sanitizedText = _sanitizeInput(rawText);
    FocusScope.of(context).unfocus();
    setState(() => _isTranslatingCustom = true);

    final String fourthIso = _getLanguageIso(_activeFourthLang);

    // Run parallel neural translation across all 3 non-English targets
    try {
      final results = await Future.wait([
        _translateSingleTarget(sanitizedText, "mr"),       // Marathi
        _translateSingleTarget(sanitizedText, "hi"),       // Hindi
        _translateSingleTarget(sanitizedText, fourthIso),  // Active 4th Language
      ]).timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(() {
          _customTranslationResult = {
            "English": sanitizedText,
            "Marathi": results[0],
            "Hindi": results[1],
            _activeFourthLang: results[2],
          };
          _isTranslatingCustom = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _customTranslationResult = {
            "English": sanitizedText,
            "Marathi": sanitizedText,
            "Hindi": sanitizedText,
            _activeFourthLang: sanitizedText,
          };
          _isTranslatingCustom = false;
        });
      }
    }
  }

  void _openLanguagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.70,
          minChildSize: 0.45,
          maxChildSize: 0.90,
          expand: false,
          builder: (_, scrollCtrl) {
            return Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Select 4th Language",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollCtrl,
                      itemCount: _catalogLanguages.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, idx) {
                        final item = _catalogLanguages[idx];
                        final name = item["name"] as String;
                        final native = item["native"] as String;
                        final code = item["code"] as String;
                        final isSelected = name == _activeFourthLang;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isSelected ? const Color(0xFF2563EB) : const Color(0xFFEFF6FF),
                            child: Text(
                              code,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                          title: Text("$name ($native)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(item["region"] as String, style: const TextStyle(fontSize: 11)),
                          trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB)) : null,
                          onTap: () {
                            setState(() {
                              _activeFourthLang = name;
                              if (_customTranslationResult != null) _translateArbitraryTextOffline();
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showFullscreenCard({
    required String title,
    required String phrase,
    required String lang,
    String? phonetic,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(lang.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 12),
              SelectableText(phrase, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              if (phonetic != null) ...[
                const SizedBox(height: 6),
                Text(phonetic, style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Color(0xFF2563EB))),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                  icon: const Icon(Icons.volume_up_rounded),
                  label: Text("Speak ($lang)"),
                  onPressed: () => _speakPhrase(phrase, lang),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final phrases = OfflineCacheService.survivalPhrases.where((p) {
      final matchesCat = _selectedCategory == "All" || p.category == _selectedCategory;
      final q = _searchQuery.toLowerCase();
      if (q.isEmpty) return matchesCat;

      final engMatch = p.english.toLowerCase().contains(q);
      final hindiMatch = (p.translations["Hindi"] ?? "").toLowerCase().contains(q);
      final marathiMatch = (p.translations["Marathi"] ?? "").toLowerCase().contains(q);
      final intlMatch = (p.translations[_activeFourthLang] ?? "").toLowerCase().contains(q);

      return matchesCat && (engMatch || hindiMatch || marathiMatch || intlMatch);
    }).toList();

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
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: const Color(0xFFF8FAFC),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 24),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            "Survival Deck",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)),
          ),
          actions: [
            IconButton(
              tooltip: _isFemaleVoice ? "Voice: Female (Tap for Male)" : "Voice: Male (Tap for Female)",
              icon: Icon(
                _isFemaleVoice ? Icons.female_rounded : Icons.male_rounded,
                color: _isFemaleVoice ? const Color(0xFFEC4899) : const Color(0xFF2563EB),
                size: 26,
              ),
              onPressed: () async {
                HapticFeedback.selectionClick();
                setState(() => _isFemaleVoice = !_isFemaleVoice);
                await _applyVoiceProfile("en-US");
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 1),
                      content: Text(_isFemaleVoice ? "Voice Profile: Female" : "Voice Profile: Male (Deep Acoustic Profile)"),
                    ),
                  );
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
              child: InkWell(
                onTap: _openLanguagePicker,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.language_rounded, size: 14, color: Color(0xFF2563EB)),
                      const SizedBox(width: 4),
                      Text(
                        _activeFourthLang,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                      ),
                      const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Color(0xFF2563EB)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFFEF3C7),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 16, color: Color(0xFFB45309)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Quad Deck • Voice: ${_isFemaleVoice ? 'Female Profile' : 'Male Profile (Deep Resonant)'} • 4th: $_activeFourthLang",
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Type Any Sentence (Accurate Quad Translation)",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customInputCtrl,
                    maxLines: 2,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      hintText: "e.g., hello where do you want to go, need a doctor immediately...",
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      counterText: "",
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isTranslatingCustom ? null : _translateArbitraryTextOffline,
                      icon: _isTranslatingCustom
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: Text(
                        _isTranslatingCustom ? "Translating into 4 Languages..." : "Translate into 4 Languages",
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_customTranslationResult != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _buildQuadCard(
                  title: "Custom Input",
                  category: "DYNAMIC INPUT",
                  english: _customTranslationResult!["English"] ?? "",
                  marathi: _customTranslationResult!["Marathi"] ?? "",
                  hindi: _customTranslationResult!["Hindi"] ?? "",
                  fourthLang: _activeFourthLang,
                  fourthPhrase: _customTranslationResult![_activeFourthLang] ?? "",
                  isCustom: true,
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: "Search survival phrases...",
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final cat = _categories[i];
                  final isSelected = cat == _selectedCategory;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: const Color(0xFF2563EB),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : const Color(0xFF64748B)),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedCategory = cat);
                    },
                  );
                },
              ),
            ),
            Expanded(
              child: phrases.isEmpty
                  ? const Center(child: Text("No matching phrases found.", style: TextStyle(color: Color(0xFF64748B))))
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(16, 6, 16, (bottomInset > 0 ? bottomInset : 14) + 20),
                      itemCount: phrases.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final p = phrases[i];
                        return _buildQuadCard(
                          title: p.english,
                          category: p.category,
                          english: p.english,
                          marathi: p.translations["Marathi"] ?? "",
                          hindi: p.translations["Hindi"] ?? "",
                          fourthLang: _activeFourthLang,
                          fourthPhrase: p.translations[_activeFourthLang] ?? p.english,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuadCard({
    required String title,
    required String category,
    required String english,
    required String marathi,
    required String hindi,
    required String fourthLang,
    required String fourthPhrase,
    bool isCustom = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isCustom ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category.toUpperCase(), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              if (isCustom)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: () => setState(() => _customTranslationResult = null),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _buildRow("English", const Color(0xFF0F172A), english, () => _speakPhrase(english, "English")),
          const Divider(height: 14),
          _buildRow("Marathi (मराठी)", const Color(0xFF1D4ED8), marathi, () => _speakPhrase(marathi, "Marathi")),
          const Divider(height: 14),
          _buildRow("Hindi (हिन्दी)", const Color(0xFFB45309), hindi, () => _speakPhrase(hindi, "Hindi")),
          const Divider(height: 14),
          _buildRow("$fourthLang (Selected)", const Color(0xFF15803D), fourthPhrase, () => _speakPhrase(fourthPhrase, fourthLang)),
        ],
      ),
    );
  }

  Widget _buildRow(String label, Color color, String text, VoidCallback onSpeak) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 2),
              Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.fullscreen_rounded, size: 20, color: Color(0xFF64748B)),
          onPressed: () => _showFullscreenCard(title: label, phrase: text, lang: label),
        ),
        IconButton(
          icon: Icon(Icons.volume_up_rounded, size: 20, color: color),
          onPressed: onSpeak,
        ),
      ],
    );
  }
}