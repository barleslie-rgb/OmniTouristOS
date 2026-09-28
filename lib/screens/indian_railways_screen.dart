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

  // Line Filter (`ALL`, `W`, `C`, `H`)
  String _selectedLine = "ALL";

  // Station Board State
  final TextEditingController _stationCodeCtrl = TextEditingController(text: "BSR");
  bool _isLoadingStation = false;
  Map<String, dynamic>? _stationBoardData;
  String? _stationError;

  // Live Running State
  final TextEditingController _trainNoCtrl = TextEditingController();
  bool _isLoadingLive = false;
  Map<String, dynamic>? _liveTrainData;
  String? _liveError;

  // PNR State
  final TextEditingController _pnrCtrl = TextEditingController();
  bool _isLoadingPnr = false;
  Map<String, dynamic>? _pnrData;
  String? _pnrError;

  final List<Map<String, String>> _hubStations = [
    {"code": "BSR", "name": "Vasai Road", "line": "W"},
    {"code": "VR", "name": "Virar", "line": "W"},
    {"code": "NAI", "name": "Naigaon", "line": "W"},
    {"code": "BVI", "name": "Borivali", "line": "W"},
    {"code": "DDR", "name": "Dadar", "line": "WC"},
    {"code": "CCG", "name": "Churchgate", "line": "W"},
    {"code": "CSMT", "name": "Mumbai CSMT", "line": "CH"},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkStationBoard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stationCodeCtrl.dispose();
    _trainNoCtrl.dispose();
    _pnrCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkStationBoard() async {
    final stn = _stationCodeCtrl.text.trim().toUpperCase();
    if (stn.isEmpty) return;

    setState(() {
      _isLoadingStation = true;
      _stationError = null;
    });

    try {
      final cleanBaseUrl = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
      final res = await http.post(
        Uri.parse("$cleanBaseUrl/api/v1/railway-inquiry"),
        body: {"query_type": "station_board", "query_value": stn, "target_language": widget.language},
      ).timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        setState(() => _stationBoardData = jsonDecode(res.body));
      } else {
        setState(() => _stationError = "Server status: ${res.statusCode}");
      }
    } catch (e) {
      setState(() => _stationError = "Error loading station board: $e");
    } finally {
      if (mounted) setState(() => _isLoadingStation = false);
    }
  }

  Future<void> _checkLiveTrain() async {
    final train = _trainNoCtrl.text.trim();
    if (train.isEmpty) return;

    setState(() {
      _isLoadingLive = true;
      _liveError = null;
    });

    try {
      final cleanBaseUrl = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
      final res = await http.post(
        Uri.parse("$cleanBaseUrl/api/v1/railway-inquiry"),
        body: {"query_type": "live_train", "query_value": train, "target_language": widget.language},
      ).timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        setState(() => _liveTrainData = jsonDecode(res.body));
      } else {
        setState(() => _liveError = "Server status: ${res.statusCode}");
      }
    } catch (e) {
      setState(() => _liveError = "Error tracking train: $e");
    } finally {
      if (mounted) setState(() => _isLoadingLive = false);
    }
  }

  Future<void> _checkPnrStatus() async {
    final pnr = _pnrCtrl.text.trim();
    if (pnr.length != 10) return;

    setState(() {
      _isLoadingPnr = true;
      _pnrError = null;
    });

    try {
      final cleanBaseUrl = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
      final res = await http.post(
        Uri.parse("$cleanBaseUrl/api/v1/railway-inquiry"),
        body: {"query_type": "pnr", "query_value": pnr, "target_language": widget.language},
      ).timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        setState(() => _pnrData = jsonDecode(res.body));
      } else {
        setState(() => _pnrError = "Server status: ${res.statusCode}");
      }
    } catch (e) {
      setState(() => _pnrError = "Error fetching PNR: $e");
    } finally {
      if (mounted) setState(() => _isLoadingPnr = false);
    }
  }

  int _getCurrentMinutesFromMidnight() {
    final now = DateTime.now();
    return now.hour * 60 + now.minute;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF8FAFC),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Mumbai Suburban & Railways",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF2563EB),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.schedule_rounded, size: 18), text: "Station Board"),
            Tab(icon: Icon(Icons.train_rounded, size: 18), text: "Live Running"),
            Tab(icon: Icon(Icons.confirmation_number_rounded, size: 18), text: "PNR & Booking"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStationBoardTab(),
          _buildLiveRunningTab(),
          _buildPnrTab(),
        ],
      ),
    );
  }

  // --- TAB 1: STATION BOARD WITH TIME-SORTED ENGINE ---
  Widget _buildStationBoardTab() {
    List trains = (_stationBoardData?['trains'] as List?) ?? [];
    final currentMin = _getCurrentMinutesFromMidnight();

    // Sort chronologically by timestamp
    trains.sort((a, b) => (a['timestamp_minutes'] ?? 0).compareTo(b['timestamp_minutes'] ?? 0));

    // Separate into "Next in Line" (upcoming) vs "Full Day Schedule"
    final upcomingTrains = trains.where((t) => (t['timestamp_minutes'] ?? 0) >= currentMin).toList();
    final pastTrains = trains.where((t) => (t['timestamp_minutes'] ?? 0) < currentMin).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line Filter Pills (ALL, W, C, H)
          Row(
            children: ["ALL", "W", "C", "H"].map((line) {
              final isSelected = _selectedLine == line;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(line == "ALL" ? "All Lines" : "$line Line"),
                  selected: isSelected,
                  selectedColor: const Color(0xFF2563EB),
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
                  onSelected: (_) => setState(() => _selectedLine = line),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Station Search Input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _stationCodeCtrl,
                  decoration: InputDecoration(
                    labelText: "Station Code (e.g. BSR, NAI, DDR)",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoadingStation ? null : _checkStationBoard,
                child: _isLoadingStation
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Load Board", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Quick Station Hubs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _hubStations.map((st) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text("${st['code']} •${st['name']}"),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey.shade300),
                    onPressed: () {
                      _stationCodeCtrl.text = st['code']!;
                      _checkStationBoard();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          if (_stationError != null)
            Text(_stationError!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          if (_stationBoardData != null) ...[
            Text(
              "Station: ${_stationBoardData!['station_name']}",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),

            // NEXT IN LINE SECTION
            const Text("⚡ NEXT IN LINE (Upcoming Trains)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
            const SizedBox(height: 6),
            if (upcomingTrains.isEmpty)
              const Text("No more trains scheduled for today.", style: TextStyle(color: Colors.grey, fontSize: 12))
            else
              ...upcomingTrains.map((train) => _buildTrainCard(train, isUpcoming: true)),

            const SizedBox(height: 16),
            const Text("🕒 FULL DAY MASTER SCHEDULE (3:30 AM onwards)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF64748B))),
            const SizedBox(height: 6),
            ...pastTrains.map((train) => _buildTrainCard(train, isUpcoming: false)),
            ...upcomingTrains.map((train) => _buildTrainCard(train, isUpcoming: false)),
          ],
        ],
      ),
    );
  }

  Widget _buildTrainCard(Map<String, dynamic> train, {required bool isUpcoming}) {
    final type = train['service_type'] ?? 'S';
    final isFast = type == 'F';
    final isAc = type == 'AC';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUpcoming ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isUpcoming ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0), width: isUpcoming ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isAc ? const Color(0xFF0D9488) : (isFast ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(type, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(train['time'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                      child: Text("PF ${train['platform']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF2563EB))),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text("${train['train_no']} :${train['name']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155))),
                Text(train['status'] ?? '', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: LIVE RUNNING & COMMUTER FLASHER ---
  Widget _buildLiveRunningTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("⚡ M-INDICATOR LIVE FLASHER", style: TextStyle(color: Color(0xFFFDE68A), fontSize: 10, fontWeight: FontWeight.w900)),
                      SizedBox(height: 2),
                      Text("Approaching: Dadar (Platform 4) • Doors: Right", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _trainNoCtrl,
                  decoration: InputDecoration(
                    labelText: "Enter Train No (e.g. 90508)",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                    prefixIcon: const Icon(Icons.train_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
                onPressed: _isLoadingLive ? null : _checkLiveTrain,
                child: const Text("Track", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_liveTrainData != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Train: ${_liveTrainData!['train_no']} -${_liveTrainData!['train_name']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(height: 14),
                  Text("📍 Current Location: ${_liveTrainData!['current_station']}"),
                  Text("⚡ Next Approaching Stop: ${_liveTrainData!['next_station']}", style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                  Text("🚪 Platform & Exit: PF ${_liveTrainData!['platform']} (Doors open:${_liveTrainData!['door_side']})"),
                  Text("⏱ Status: ${_liveTrainData!['status_msg']} • Crowd: ${_liveTrainData!['crowd']}"),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --- TAB 3: PNR & BOOKING ---
  Widget _buildPnrTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _pnrCtrl,
            keyboardType: TextInputType.number,
            maxLength: 10,
            decoration: InputDecoration(
              labelText: "Enter 10-digit PNR",
              counterText: "",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
              prefixIcon: const Icon(Icons.confirmation_number_rounded),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: _isLoadingPnr ? null : _checkPnrStatus,
              child: const Text("Check PNR Status", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
          const Text("Official Ticketing Portals", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
                  onPressed: () => launchUrl(Uri.parse("https://www.irctc.co.in"), mode: LaunchMode.externalApplication),
                  child: const Text("IRCTC Official"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
                  onPressed: () => launchUrl(Uri.parse("https://www.confirmtkt.com"), mode: LaunchMode.externalApplication),
                  child: const Text("ConfirmTkt"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}