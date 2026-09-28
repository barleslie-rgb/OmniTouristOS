import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class IndianRailwaysScreen extends StatefulWidget {
  final String language;
  final String backendUrl;

  const IndianRailwaysScreen({
    Key? key,
    required this.language,
    this.backendUrl = "https://omni-backend-pk28.onrender.com",
  }) : super(key: key);

  @override
  State<IndianRailwaysScreen> createState() => _IndianRailwaysScreenState();
}

class _IndianRailwaysScreenState extends State<IndianRailwaysScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const String _affiliateWrapperPrefix = "";

  // Tab 1: PNR Status
  final TextEditingController _pnrCtrl = TextEditingController();
  bool _isLoadingPnr = false;
  Map<String, dynamic>? _pnrData;
  String? _pnrError;

  // Tab 2: Live Train Status
  final TextEditingController _trainNoCtrl = TextEditingController();
  bool _isLoadingLive = false;
  Map<String, dynamic>? _liveTrainData;
  String? _liveError;

  // Tab 3: Station Live Board
  final TextEditingController _stationCodeCtrl = TextEditingController();
  bool _isLoadingStation = false;
  List<Map<String, dynamic>> _stationTrains = [];
  String? _stationError;

  // Quick Station Shortcuts
  final List<Map<String, String>> _hubStations = [
    {"code": "BSR", "name": "Vasai Road"},
    {"code": "VR", "name": "Virar"},
    {"code": "BVI", "name": "Borivali"},
    {"code": "MMCT", "name": "Mumbai Central"},
    {"code": "DDR", "name": "Dadar WR"},
    {"code": "PLG", "name": "Palghar"},
    {"code": "ST", "name": "Surat"},
    {"code": "CSMT", "name": "Mumbai CSMT"},
  ];

  static const Map<String, Map<String, String>> _dict = {
    "English": {
      "title": "Indian Railways Live",
      "tab_pnr": "PNR Status",
      "tab_live": "Live Running",
      "tab_station": "Station Board",
      "hero_tag": "INDIAN RAILWAYS LIVE TRANSIT",
      "hero_title": "High-Speed Express & Local Network Tracker",
      "pnr_header": "Passenger Name Record",
      "pnr_subtitle": "Direct Indian Railways PNR Inquiry",
      "pnr_hint": "Enter 10-digit PNR",
      "pnr_btn": "Check Status",
      "pnr_btn_loading": "Fetching PNR Details...",
      "live_header": "Live Train Tracker",
      "live_subtitle": "Real-time spot and delay tracking",
      "live_hint": "Enter Train Number or Name (e.g. 12951, Tejas)",
      "live_btn": "Locate Train",
      "live_btn_loading": "Tracking Train...",
      "station_header": "Station Arrivals & Departures",
      "station_subtitle": "Live station display board",
      "station_hint": "Station Code or Name (e.g. BSR, MMCT, CSMT)",
      "station_btn": "View Station Board",
      "station_btn_loading": "Loading Station Board...",
      "booking_title": "Book Confirmed Seats & Tatkal Tickets",
      "booking_sub": "Direct official booking links with auto-filled routes:",
      "btn_irctc": "IRCTC Official",
      "btn_confirmtkt": "Book on ConfirmTkt",
      "copied_msg": "Copied to clipboard.",
      "quick_stations": "Quick Transit Hubs:",
    },
    "Marathi": {
      "title": "भारतीय रेल्वे थेट प्रवास",
      "tab_pnr": "पीएनआर स्थिती",
      "tab_live": "थेट गाडी स्थिती",
      "tab_station": "स्थानक वेळापत्रक",
      "hero_tag": "भारतीय रेल्वे थेट प्रवास",
      "hero_title": "जलद एक्सप्रेस व लोकल नेटवर्क ट्रॅकर",
      "pnr_header": "प्रवासी तिकीट नोंद (PNR)",
      "pnr_subtitle": "थेट भारतीय रेल्वे पीएनआर चौकशी",
      "pnr_hint": "१० अंकी PNR क्रमांक प्रविष्ट करा",
      "pnr_btn": "स्थिती तपासा",
      "pnr_btn_loading": "माहिती मिळवत आहे...",
      "live_header": "थेट गाडी शोध",
      "live_subtitle": "गाडीचे चालू स्थान व विलंबाची माहिती",
      "live_hint": "गाडी क्रमांक किंवा नाव प्रविष्ट करा (उदा. 12951)",
      "live_btn": "गाडी शोधा",
      "live_btn_loading": "गाडीचा माग काढत आहे...",
      "station_header": "स्थानक आगमन व प्रस्थान",
      "station_subtitle": "स्थानकावरील थेट डिजिटल फलक",
      "station_hint": "स्थानक कोड किंवा नाव (उदा. BSR, MMCT, CSMT)",
      "station_btn": "वेळापत्रक पहा",
      "station_btn_loading": "वेळापत्रक लोड होत आहे...",
      "booking_title": "कन्फर्म तिकीट व तात्काळ आरक्षण",
      "booking_sub": "थेट आरक्षण प्रणालीवर जा:",
      "btn_irctc": "IRCTC अधिकृत",
      "btn_confirmtkt": "ConfirmTkt वर बुक करा",
      "copied_msg": "क्लिपबोर्डवर सेव्ह केले.",
      "quick_stations": "महत्त्वाची स्थानके:",
    },
    "Hindi": {
      "title": "भारतीय रेल लाइव ट्रांजिट",
      "tab_pnr": "पीएनआर स्थिति",
      "tab_live": "लाइव ट्रेन रनिंग",
      "tab_station": "स्टेशन बोर्ड",
      "hero_tag": "भारतीय रेल लाइव ट्रांजिट",
      "hero_title": "हाई-स्पीड एक्सप्रेस और लोकल नेटवर्क ट्रैकर",
      "pnr_header": "यात्री टिकट रिकॉर्ड (PNR)",
      "pnr_subtitle": "सीधी भारतीय रेल पीएनआर पूछताछ",
      "pnr_hint": "10-अंकों का PNR दर्ज करें",
      "pnr_btn": "स्थिति देखें",
      "pnr_btn_loading": "विवरण प्राप्त कर रहा है...",
      "live_header": "लाइव ट्रेन ट्रैकर",
      "live_subtitle": "ट्रेन की सटीक स्थिति और देरी की जानकारी",
      "live_hint": "ट्रेन नंबर या नाम दर्ज करें (उदा. 12951)",
      "live_btn": "ट्रेन ट्रैक करें",
      "live_btn_loading": "ट्रेन खोजी जा रही है...",
      "station_header": "स्टेशन आगमन और प्रस्थान",
      "station_subtitle": "लाइव स्टेशन डिस्प्ले बोर्ड",
      "station_hint": "स्टेशन कोड या नाम (उदा. BSR, MMCT, CSMT)",
      "station_btn": "स्टेशन बोर्ड देखें",
      "station_btn_loading": "लोड हो रहा है...",
      "booking_title": "कन्फर्म सीट और तत्काल टिकट बुक करें",
      "booking_sub": "सीधे बुकिंग पोर्टल पर जाएँ:",
      "btn_irctc": "IRCTC आधिकारिक",
      "btn_confirmtkt": "ConfirmTkt पर बुक करें",
      "copied_msg": "क्लिपबोर्ड पर कॉपी हो गया।",
      "quick_stations": "प्रमुख रेलवे स्टेशन:",
    },
    "Gujarati": {
      "title": "ભારતીય રેલ્વે લાઇવ ટ્રાન્ઝિટ",
      "tab_pnr": "PNR સ્થિતિ",
      "tab_live": "લાઇવ ટ્રેન સ્થિતિ",
      "tab_station": "સ્ટેશન બોર્ડ",
      "hero_tag": "ભારતીય રેલ્વે લાઇવ ટ્રાન્ઝિટ",
      "hero_title": "હાઇ-સ્પીડ એક્સપ્રેસ અને લોકલ ટ્રેન ટ્રેકર",
      "pnr_header": "પ્રવાસી ટિકિટ રેકોર્ડ (PNR)",
      "pnr_subtitle": "સીધી ભારતીય રેલ્વે PNR પૂછપરછ",
      "pnr_hint": "10 અંકનો PNR દાખલ કરો",
      "pnr_btn": "સ્થિતિ તપાસો",
      "pnr_btn_loading": "વિગતો મેળવી રહ્યું છે...",
      "live_header": "લાઇવ ટ્રેન ટ્રેકર",
      "live_subtitle": "ટ્રેનનું સાચું સ્થાન અને વિલંબની માહિતી",
      "live_hint": "ટ્રેન નંબર અથવા નામ દાખલ કરો (દા.ત. 12951)",
      "live_btn": "ટ્રેન શોધો",
      "live_btn_loading": "શોધ ચાલુ છે...",
      "station_header": "સ્ટેશન આગમન અને પ્રસ્થાન",
      "station_subtitle": "લાઇવ સ્ટેશન ડિસ્પ્લે બોર્ડ",
      "station_hint": "સ્ટેશન કોડ અથવા નામ (દા.ત. BSR, MMCT, ST)",
      "station_btn": "બોર્ડ જુઓ",
      "station_btn_loading": "લોડ થઈ રહ્યું છે...",
      "booking_title": "કન્ફર્મ ટિકિટ અને તત્કાલ બુકિંગ",
      "booking_sub": "સીધા બુકિંગ પોર્ટલ પર જાઓ:",
      "btn_irctc": "IRCTC સત્તાવાર",
      "btn_confirmtkt": "ConfirmTkt પર બુક કરો",
      "copied_msg": "ક્લિપબોર્ડ પર કોપી કર્યું.",
      "quick_stations": "મુખ્ય સ્ટેશનો:",
    },
  };

  String _t(String key) {
    final lang = widget.language.trim();
    if (_dict.containsKey(lang) && _dict[lang]!.containsKey(key)) {
      return _dict[lang]![key]!;
    }
    return _dict["English"]![key] ?? key;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pnrCtrl.dispose();
    _trainNoCtrl.dispose();
    _stationCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _launchBookingUrl(String rawUrl) async {
    String finalUrl = rawUrl;
    if (_affiliateWrapperPrefix.isNotEmpty) {
      finalUrl = "$_affiliateWrapperPrefix${Uri.encodeComponent(rawUrl)}";
    }
    final uri = Uri.parse(finalUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.inAppWebView);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Could not launch browser: $e")),
          );
        }
      }
    }
  }

  Future<void> _checkPnrStatus() async {
    final pnr = _pnrCtrl.text.trim();
    if (pnr.length != 10) {
      setState(() => _pnrError = "Please enter a valid 10-digit PNR number.");
      return;
    }

    setState(() {
      _isLoadingPnr = true;
      _pnrError = null;
      _pnrData = null;
    });

    try {
      final cleanBaseUrl = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
      final res = await http.post(
        Uri.parse("$cleanBaseUrl/api/v1/railway-inquiry"),
        body: {
          "query_type": "pnr",
          "query_value": pnr,
          "target_language": widget.language,
        },
      ).timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        setState(() {
          _pnrData = {
            "pnr": pnr,
            "details": d["answer"] ?? "Status updated.",
          };
        });
      } else {
        setState(() => _pnrError = "Server returned status code: ${res.statusCode}");
      }
    } catch (e) {
      setState(() => _pnrError = "Could not fetch PNR status: $e");
    } finally {
      if (mounted) setState(() => _isLoadingPnr = false);
    }
  }

  Future<void> _checkLiveTrain() async {
    final train = _trainNoCtrl.text.trim();
    if (train.isEmpty) {
      setState(() => _liveError = "Please enter a train number or name.");
      return;
    }

    setState(() {
      _isLoadingLive = true;
      _liveError = null;
      _liveTrainData = null;
    });

    try {
      final cleanBaseUrl = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
      final res = await http.post(
        Uri.parse("$cleanBaseUrl/api/v1/railway-inquiry"),
        body: {
          "query_type": "live_train",
          "query_value": train,
          "target_language": widget.language,
        },
      ).timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        setState(() {
          _liveTrainData = {
            "train": train,
            "status": d["answer"] ?? "Live status retrieved.",
          };
        });
      } else {
        setState(() => _liveError = "Server returned status code: ${res.statusCode}");
      }
    } catch (e) {
      setState(() => _liveError = "Could not track train: $e");
    } finally {
      if (mounted) setState(() => _isLoadingLive = false);
    }
  }

  Future<void> _checkStationBoard() async {
    final stn = _stationCodeCtrl.text.trim().toUpperCase();
    if (stn.isEmpty) {
      setState(() => _stationError = "Please enter a station code or name (e.g. BSR, MMCT, CSMT).");
      return;
    }

    setState(() {
      _isLoadingStation = true;
      _stationError = null;
      _stationTrains.clear();
    });

    try {
      final cleanBaseUrl = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
      final res = await http.post(
        Uri.parse("$cleanBaseUrl/api/v1/railway-inquiry"),
        body: {
          "query_type": "station_board",
          "query_value": stn,
          "target_language": widget.language,
        },
      ).timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        setState(() {
          _stationTrains = [
            {"station": stn, "content": d["answer"] ?? "Station board updated."}
          ];
        });
      } else {
        setState(() => _stationError = "Server returned status code: ${res.statusCode}");
      }
    } catch (e) {
      setState(() => _stationError = "Could not load station board: $e");
    } finally {
      if (mounted) setState(() => _isLoadingStation = false);
    }
  }

  Widget _buildTrainHeroBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 105,
        width: double.infinity,
        decoration: const BoxDecoration(color: Color(0xFF0F172A)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              "https://images.unsplash.com/photo-1532103054090-a339233ec812?auto=format&fit=crop&w=1200&q=80",
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.30),
                    Colors.black.withOpacity(0.85),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_railway_rounded, color: Color(0xFF60A5FA), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _t("hero_tag"),
                        style: const TextStyle(
                          color: Color(0xFF93C5FD),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _t("hero_title"),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
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

  // --- BRANDED LOGOS & BOOKING CARD ---
  Widget _buildBookingBar() {
    final now = DateTime.now();
    final todayFormatted =
        "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}";
    final searchStation = _stationCodeCtrl.text.trim().toUpperCase().isNotEmpty
        ? _stationCodeCtrl.text.trim().toUpperCase()
        : "BSR";

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Icon(Icons.confirmation_number_rounded, color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _t("booking_title"),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _t("booking_sub"),
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.3),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // IRCTC Branded Button
              Expanded(
                child: InkWell(
                  onTap: () => _launchBookingUrl("https://www.irctc.co.in/nget/train-search"),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A), // IRCTC Navy Blue
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A8A).withOpacity(0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // IRCTC Badge Emblem
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              "IR",
                              style: TextStyle(
                                color: Color(0xFF1E3A8A),
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _t("btn_irctc"),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // ConfirmTkt Branded Button
              Expanded(
                child: InkWell(
                  onTap: () => _launchBookingUrl(
                    "https://www.confirmtkt.com/rbooking-d/trains/from/$searchStation/to/MMCT/$todayFormatted",
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669), // ConfirmTkt Vibrant Green
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF059669).withOpacity(0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ConfirmTkt Lightning Emblem
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF059669)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _t("btn_confirmtkt"),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStationShortcuts({required Function(String code) onSelected}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          _t("quick_stations"),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _hubStations.map((st) {
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  label: Text("${st['code']} • ${st['name']}"),
                  labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey.shade300),
                  onPressed: () => onSelected(st['code']!),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  List<Widget> _renderGrokContent(String rawText) {
    final List<Widget> widgets = [];
    final lines = rawText.split("\n");
    List<List<String>> tableBuffer = [];

    void flushTable() {
      if (tableBuffer.isEmpty) return;
      final headers = tableBuffer.first;
      final rows = tableBuffer.skip(1).toList();

      widgets.add(
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Table(
              border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1)),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: headers
                      .map((h) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Text(
                              h.trim(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                            ),
                          ))
                      .toList(),
                ),
                ...rows.map(
                  (r) => TableRow(
                    children: r
                        .map((c) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Text(c.trim(), style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      tableBuffer = [];
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trimRight();
      final trimmed = line.trim();

      if (trimmed.startsWith("|") && trimmed.endsWith("|")) {
        if (RegExp(r'^\|[\s\-:|]+\|$').hasMatch(trimmed)) continue;
        final cols = trimmed.split("|").where((c) => c.isNotEmpty).toList();
        if (cols.isNotEmpty) {
          tableBuffer.add(cols);
          continue;
        }
      } else {
        flushTable();
      }

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      if (trimmed.startsWith("###") || trimmed.startsWith("##") || trimmed.startsWith("#")) {
        final hTitle = trimmed.replaceAll(RegExp(r'^#+\s*'), '').replaceAll("**", "");
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(hTitle, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ),
        );
        continue;
      }

      if (trimmed.startsWith("•") || trimmed.startsWith("-") || trimmed.startsWith("*")) {
        final rawBullet = trimmed.substring(1).trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("• ", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                Expanded(child: _renderInlineBold(rawBullet)),
              ],
            ),
          ),
        );
        continue;
      }

      widgets.add(Padding(padding: const EdgeInsets.only(bottom: 6), child: _renderInlineBold(trimmed)));
    }

    flushTable();
    return widgets;
  }

  Widget _renderInlineBold(String text) {
    final List<TextSpan> spans = [];
    final parts = text.split("**");

    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      final isBold = i % 2 == 1;
      spans.add(
        TextSpan(
          text: parts[i],
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? const Color(0xFF0F172A) : const Color(0xFF334155),
            fontSize: 15.5,
            height: 1.55,
          ),
        ),
      );
    }
    return SelectableText.rich(TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _t("title"),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF2563EB),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(icon: const Icon(Icons.confirmation_number_rounded, size: 20), text: _t("tab_pnr")),
            Tab(icon: const Icon(Icons.train_rounded, size: 20), text: _t("tab_live")),
            Tab(icon: const Icon(Icons.schedule_rounded, size: 20), text: _t("tab_station")),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPnrTab(),
          _buildLiveTrainTab(),
          _buildStationTab(),
        ],
      ),
    );
  }

  // --- Tab 1: PNR Status ---
  Widget _buildPnrTab() {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTrainHeroBanner(),
          const SizedBox(height: 14),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.confirmation_number_rounded, color: Color(0xFF2563EB), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_t("pnr_header"), style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold)),
                          Text(_t("pnr_subtitle"), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pnrCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 10,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 2),
                    decoration: InputDecoration(
                      hintText: _t("pnr_hint"),
                      counterText: "",
                      hintStyle: const TextStyle(fontSize: 13, letterSpacing: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isLoadingPnr ? null : _checkPnrStatus,
                      icon: _isLoadingPnr
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: Text(
                        _isLoadingPnr ? _t("pnr_btn_loading") : _t("pnr_btn"),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildBookingBar(),
          if (_pnrError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_pnrError!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                ],
              ),
            ),
          ],
          if (_pnrData != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "PNR: ${_pnrData!['pnr']}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2563EB)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.grey),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _pnrData!['details'] ?? ""));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t("copied_msg"))));
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  ..._renderGrokContent(_pnrData!['details'] ?? ""),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Tab 2: Live Train Status ---
  Widget _buildLiveTrainTab() {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTrainHeroBanner(),
          const SizedBox(height: 14),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.train_rounded, color: Color(0xFF16A34A), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_t("live_header"), style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold)),
                          Text(_t("live_subtitle"), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _trainNoCtrl,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: _t("live_hint"),
                      hintStyle: const TextStyle(fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      prefixIcon: const Icon(Icons.directions_railway_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isLoadingLive ? null : _checkLiveTrain,
                      icon: _isLoadingLive
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.gps_fixed_rounded),
                      label: Text(
                        _isLoadingLive ? _t("live_btn_loading") : _t("live_btn"),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildBookingBar(),
          if (_liveError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_liveError!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                ],
              ),
            ),
          ],
          if (_liveTrainData != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Train: ${_liveTrainData!['train']}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF16A34A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.grey),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _liveTrainData!['status'] ?? ""));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t("copied_msg"))));
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  ..._renderGrokContent(_liveTrainData!['status'] ?? ""),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Tab 3: Station Board ---
  Widget _buildStationTab() {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTrainHeroBanner(),
          const SizedBox(height: 14),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.schedule_rounded, color: Color(0xFFEA580C), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_t("station_header"), style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold)),
                          Text(_t("station_subtitle"), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _stationCodeCtrl,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: _t("station_hint"),
                      hintStyle: const TextStyle(fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      prefixIcon: const Icon(Icons.location_on_rounded),
                    ),
                  ),
                  _buildQuickStationShortcuts(
                    onSelected: (code) {
                      setState(() {
                        _stationCodeCtrl.text = code;
                      });
                      _checkStationBoard();
                    },
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isLoadingStation ? null : _checkStationBoard,
                      icon: _isLoadingStation
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.developer_board_rounded),
                      label: Text(
                        _isLoadingStation ? _t("station_btn_loading") : _t("station_btn"),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildBookingBar(),
          if (_stationError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_stationError!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                ],
              ),
            ),
          ],
          if (_stationTrains.isNotEmpty) ...[
            const SizedBox(height: 16),
            ..._stationTrains.map(
              (st) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Live Board: ${st['station']}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFEA580C)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.grey),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: st['content'] ?? ""));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t("copied_msg"))));
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    ..._renderGrokContent(st['content'] ?? ""),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}