import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';

class AdminConsoleScreen extends StatefulWidget {
  final String backendUrl;

  const AdminConsoleScreen({
    Key? key,
    this.backendUrl = "https://omni-backend-pk28.onrender.com",
  }) : super(key: key);

  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen> {
  bool _isLoading = true;
  bool _isAuthorized = false;

  int _totalUsers = 0;
  int _activeTrials = 0;
  int _bannedUsers = 0;
  int _communityGemsCount = 0;

  bool _backendOnline = false;
  int _pingLatencyMs = 0;
  String _backendVersion = "--";
  int _geminiKeysCount = 0;
  bool _groqActive = false;

  List<Map<String, dynamic>> _recentUsers = [];
  List<Map<String, dynamic>> _recentGems = [];

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  Future<void> _checkAccessAndLoad() async {
    final user = AuthService.currentUser;
    final isMaster = user?.email?.toLowerCase().trim() ==
        UserProfile.masterAdminEmail.toLowerCase().trim();

    if (!isMaster) {
      if (mounted) {
        setState(() {
          _isAuthorized = false;
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isAuthorized = true;
      _isLoading = true;
    });

    await Future.wait([
      _fetchBackendHealth(),
      _fetchSupabaseMetrics(),
    ]);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchBackendHealth() async {
    final cleanUrl = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
    final stopwatch = Stopwatch()..start();

    try {
      final res = await http.get(Uri.parse("$cleanUrl/api/v1/wake")).timeout(const Duration(seconds: 8));
      stopwatch.stop();

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _backendOnline = true;
            _pingLatencyMs = stopwatch.elapsedMilliseconds;
            _backendVersion = data["version"] ?? "Unknown";
            _groqActive = data["groq"] ?? false;
            _geminiKeysCount = data["gemini_keys_count"] ?? 0;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _backendOnline = false;
          _pingLatencyMs = 0;
        });
      }
    }
  }

  Future<void> _fetchSupabaseMetrics() async {
    final client = Supabase.instance.client;

    try {
      final usersRes = await client
          .from('user_profiles')
          .select()
          .order('created_at', ascending: false);

      final gemsRes = await client
          .from('community_places')
          .select()
          .order('created_at', ascending: false)
          .limit(10);

      final List<Map<String, dynamic>> usersList = List<Map<String, dynamic>>.from(usersRes);
      final List<Map<String, dynamic>> gemsList = List<Map<String, dynamic>>.from(gemsRes);

      final now = DateTime.now();
      int active = 0;
      int banned = 0;

      for (var u in usersList) {
        if (u['is_banned'] == true) banned++;
        if (u['trial_ends_at'] != null) {
          final expiry = DateTime.tryParse(u['trial_ends_at']);
          if (expiry != null && expiry.isAfter(now)) active++;
        }
      }

      if (mounted) {
        setState(() {
          _totalUsers = usersList.length;
          _activeTrials = active;
          _bannedUsers = banned;
          _communityGemsCount = gemsList.length;
          _recentUsers = usersList.take(6).toList();
          _recentGems = gemsList;
        });
      }
    } catch (e) {
      debugPrint("Admin metrics fetch error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    if (!_isAuthorized && !_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text("Access Denied", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.gpp_bad_rounded, size: 64, color: Color(0xFFEF4444)),
              SizedBox(height: 16),
              Text(
                "Restricted Console",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 8),
              Text(
                "This telemetry area requires Master Administrator rights.",
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

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
          "Master Admin Console",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)),
        ),
        actions: [
          IconButton(
            tooltip: "Refresh Telemetry",
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
            onPressed: _checkAccessAndLoad,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : RefreshIndicator(
              onRefresh: _checkAccessAndLoad,
              color: const Color(0xFF2563EB),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFF2563EB),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "God-Mode Active",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  UserProfile.masterAdminEmail,
                                  style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF4ADE80)),
                            ),
                            child: const Text(
                              "Root Owner",
                              style: TextStyle(color: Color(0xFF4ADE80), fontWeight: FontWeight.w700, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      "Backend & AI Infrastructure",
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            label: "Backend Server",
                            value: _backendOnline ? "Online" : "Offline",
                            sub: _backendOnline ? "$_pingLatencyMs ms latency" : "Unreachable",
                            icon: Icons.dns_rounded,
                            color: _backendOnline ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricCard(
                            label: "Intelligence Layer",
                            value: "v$_backendVersion",
                            sub: "Groq: ${_groqActive ? 'Active' : 'Off'} • Gemini: $_geminiKeysCount keys",
                            icon: Icons.psychology_rounded,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      "User Directory & Subscriptions",
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            label: "Total Accounts",
                            value: "$_totalUsers",
                            sub: "Registered in Supabase",
                            icon: Icons.people_alt_rounded,
                            color: const Color(0xFF0284C7),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricCard(
                            label: "Active 30d Trials",
                            value: "$_activeTrials",
                            sub: "$_bannedUsers deactivated",
                            icon: Icons.access_time_rounded,
                            color: const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      "Recent User Profiles",
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: _recentUsers.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(
                                child: Text("No users registered yet.", style: TextStyle(color: Color(0xFF64748B))),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _recentUsers.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (context, i) {
                                final u = _recentUsers[i];
                                final email = u['email'] ?? "Unknown";
                                final role = u['role'] ?? "user";
                                final isMaster = email == UserProfile.masterAdminEmail;

                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    backgroundColor: isMaster ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                    child: Icon(
                                      isMaster ? Icons.security_rounded : Icons.person_rounded,
                                      color: isMaster ? Colors.white : const Color(0xFF64748B),
                                      size: 18,
                                    ),
                                  ),
                                  title: Text(
                                    email,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  subtitle: Text(
                                    "Role: $role • ID: ${(u['id'] ?? '').toString().substring(0, 8)}...",
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                  trailing: isMaster
                                      ? const Chip(
                                          label: Text("Owner", style: TextStyle(fontSize: 10, color: Colors.white)),
                                          backgroundColor: Color(0xFF2563EB),
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                        )
                                      : null,
                                );
                              },
                            ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
              Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}