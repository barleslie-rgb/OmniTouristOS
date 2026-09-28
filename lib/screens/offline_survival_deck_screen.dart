import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/offline_cache_service.dart';

class OfflineSurvivalDeckScreen extends StatefulWidget {
  final String language;

  const OfflineSurvivalDeckScreen({
    Key? key,
    required this.language,
  }) : super(key: key);

  @override
  State<OfflineSurvivalDeckScreen> createState() => _OfflineSurvivalDeckScreenState();
}

class _OfflineSurvivalDeckScreenState extends State<OfflineSurvivalDeckScreen> {
  late FlutterTts _flutterTts;
  String _selectedCategory = "All";
  String _searchQuery = "";
  final TextEditingController _searchCtrl = TextEditingController();

  final List<String> _categories = [
    "All",
    "Emergency & Medical",
    "Transit & Directions",
    "Street & Dining",
    "Haggling & Shopping",
  ];

  static const Map<String, String> _ttsLocaleMap = {
    "English": "en-US",
    "Hindi": "hi-IN",
    "Marathi": "mr-IN",
    "Spanish": "es-ES",
    "French": "fr-FR",
    "German": "de-DE",
    "Italian": "it-IT",
    "Portuguese": "pt-PT",
    "Russian": "ru-RU",
    "Arabic": "ar-SA",
    "Chinese": "zh-CN",
    "Japanese": "ja-JP",
    "Tamil": "ta-IN",
    "Gujarati": "gu-IN",
  };

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setPitch(1.0);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _speakPhrase(String text, String langName) async {
    final locale = _ttsLocaleMap[langName] ?? "en-US";
    await _flutterTts.stop();
    await _flutterTts.setLanguage(locale);
    await _flutterTts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final userLang = widget.language.trim();
    final bool isUserEnglish = userLang.toLowerCase() == "english";
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    final phrases = OfflineCacheService.survivalPhrases.where((p) {
      final matchesCat = _selectedCategory == "All" || p.category == _selectedCategory;
      final q = _searchQuery.toLowerCase();
      if (q.isEmpty) return matchesCat;

      final engMatch = p.english.toLowerCase().contains(q);
      final userTransMatch = p.getTranslation(userLang).toLowerCase().contains(q);
      final hindiMatch = (p.translations["Hindi"] ?? "").toLowerCase().contains(q);
      final marathiMatch = (p.translations["Marathi"] ?? "").toLowerCase().contains(q);

      return matchesCat && (engMatch || userTransMatch || hindiMatch || marathiMatch);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Offline Survival Deck",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)),
        ),
      ),
      body: Column(
        children: [
          // Offline Security & Active Language Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFFEF3C7),
            child: Row(
              children: [
                const Icon(Icons.wifi_off_rounded, size: 18, color: Color(0xFFB45309)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "100% Offline Multilingual Voice Deck • Displaying in $userLang",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: "Search words or phrases across all languages...",
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = "");
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ),

          // Horizontal Category Filter
          SizedBox(
            height: 44,
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
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategory = cat);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 6),

          // Phrase List
          Expanded(
            child: phrases.isEmpty
                ? const Center(
                    child: Text(
                      "No survival phrases match your filter.",
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 20),
                    itemCount: phrases.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final p = phrases[i];
                      final userTranslation = p.getTranslation(userLang);
                      final userPhonetic = p.getPhonetic(userLang);

                      final hindiPhrase = p.translations["Hindi"] ?? "";
                      final hindiPhonetic = p.phonetics["Hindi"];

                      final marathiPhrase = p.translations["Marathi"] ?? "";
                      final marathiPhonetic = p.phonetics["Marathi"];

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Category
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                p.category.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2563EB),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Traveler's Selected Language Card
                            if (!isUserEnglish) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          userTranslation,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        if (userPhonetic != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            userPhonetic,
                                            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                        const SizedBox(height: 2),
                                        Text(
                                          "English: ${p.english}",
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: "Pronounce in $userLang",
                                    icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF0284C7)),
                                    onPressed: () => _speakPhrase(userTranslation, userLang),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.english,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: "Speak English Out Loud",
                                    icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF0284C7)),
                                    onPressed: () => _speakPhrase(p.english, "English"),
                                  ),
                                ],
                              ),
                            ],

                            const Divider(height: 18, color: Color(0xFFF1F5F9)),

                            // Host Language Subtitle
                            const Text(
                              "Speak to Local Hosts (Audio & Phonetics):",
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 8),

                            // Hindi Phrase & Offline Audio
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        hindiPhrase,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFD97706),
                                        ),
                                      ),
                                      if (hindiPhonetic != null)
                                        Text(
                                          hindiPhonetic,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFEF3C7),
                                    foregroundColor: const Color(0xFFB45309),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.volume_up_rounded, size: 15),
                                  label: const Text("Hindi", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                  onPressed: () => _speakPhrase(hindiPhrase, "Hindi"),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Marathi Phrase & Offline Audio
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        marathiPhrase,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                      if (marathiPhonetic != null)
                                        Text(
                                          marathiPhonetic,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEFF6FF),
                                    foregroundColor: const Color(0xFF1D4ED8),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.volume_up_rounded, size: 15),
                                  label: const Text("Marathi", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                  onPressed: () => _speakPhrase(marathiPhrase, "Marathi"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}