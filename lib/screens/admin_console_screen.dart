import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          _recentUsers = usersList.take(15).toList();
          _recentGems = gemsList;
        });
      }
    } catch (e) {
      debugPrint("Admin metrics fetch error: $e");
    }
  }

  Future<void> _toggleUserBan(String userId, bool currentStatus) async {
    HapticFeedback.heavyImpact();
    try {
      await Supabase.instance.client
          .from('user_profiles')
          .update({'is_banned': !currentStatus})
          .eq('id', userId);

      await _fetchSupabaseMetrics();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: !currentStatus ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
            content: Text(!currentStatus ? "Account deactivated / banned" : "Account restored & active"),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Action failed: $e")));
      }
    }
  }

  void _showUserDetailsModal(Map<String, dynamic> u) {
    HapticFeedback.lightImpact();
    final String email = u['email'] ?? "No Email";
    final String name = (u['full_name'] ?? u['name'] ?? email.split('@').first).toString();
    final String? avatarUrl = u['avatar_url'] ?? u['photo_url'] ?? u['image_url'];
    final String role = u['role'] ?? "user";
    final bool isBanned = u['is_banned'] == true;
    final String userId = (u['id'] ?? "").toString();
    final bool isMaster = email.toLowerCase().trim() == UserProfile.masterAdminEmail.toLowerCase().trim();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFFEFF6FF),
              backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
              child: (avatarUrl == null || avatarUrl.isEmpty)
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : "U",
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF2563EB)),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A))),
            Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isMaster ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isMaster ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0)),
              ),
              child: Text(
                "Role: ${role.toUpperCase()} • ${isBanned ? 'BANNED' : 'ACTIVE'}",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isBanned ? const Color(0xFFDC2626) : (isMaster ? const Color(0xFF2563EB) : const Color(0xFF334155)),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text("Copy UUID", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: userId));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User ID copied to clipboard")));
                      },
                    ),
                  ),
                ),
                if (!isMaster) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isBanned ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: Icon(isBanned ? Icons.check_circle_rounded : Icons.block_rounded, size: 16),
                        label: Text(
                          isBanned ? "Reactivate" : "Ban Account",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _toggleUserBan(userId, isBanned);
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar(Map<String, dynamic> u, bool isMaster) {
    final String? avatarUrl = u['avatar_url'] ?? u['photo_url'] ?? u['image_url'];
    final String email = u['email'] ?? "";
    final String name = (u['full_name'] ?? u['name'] ?? email.split('@').first).toString();
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : (email.isNotEmpty ? email[0].toUpperCase() : "U");

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 19,
        backgroundColor: const Color(0xFFEFF6FF),
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }

    return CircleAvatar(
      radius: 19,
      backgroundColor: isMaster ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
      child: Text(
        initial,
        style: TextStyle(
          color: isMaster ? Colors.white : const Color(0xFF2563EB),
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top;
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    if (!_isAuthorized && !_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gpp_bad_rounded, size: 64, color: Color(0xFFDC2626)),
                const SizedBox(height: 16),
                const Text(
                  "Restricted Console",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  "This telemetry area requires Master Administrator rights.",
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Return to App", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
            // Luxury Borderless Header ($y = 0$)
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
                      children: const [
                        Text("ROOT TELEMETRY & AUDIT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
                        Text("Master Admin Console", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A))),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: "Refresh Telemetry",
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB), size: 22),
                    onPressed: _checkAccessAndLoad,
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                  : RefreshIndicator(
                      onRefresh: _checkAccessAndLoad,
                      color: const Color(0xFF2563EB),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset + 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // God Mode Card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF334155), width: 0.6),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
                                ],
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
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13.5),
                                        ),
                                        Text(
                                          UserProfile.masterAdminEmail,
                                          style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 11.5),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFF4ADE80), width: 0.6),
                                    ),
                                    child: const Text(
                                      "Root Owner",
                                      style: TextStyle(color: Color(0xFF4ADE80), fontWeight: FontWeight.w700, fontSize: 10.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),

                            const Text(
                              "Backend & AI Infrastructure",
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A)),
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
                                    sub: "Groq: ${_groqActive ? 'Active' : 'Off'} • Gemini: $_geminiKeysCount",
                                    icon: Icons.psychology_rounded,
                                    color: const Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 18),

                            const Text(
                              "User Directory & Subscriptions",
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A)),
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

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Recent Registered Profiles",
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A)),
                                ),
                                Text(
                                  "Tap user to inspect",
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 0.6),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 8, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: _recentUsers.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(24),
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
                                        final email = u['email'] ?? "No Email";
                                        final name = (u['full_name'] ?? u['name'] ?? email.split('@').first).toString();
                                        final role = u['role'] ?? "user";
                                        final isBanned = u['is_banned'] == true;
                                        final isMaster = email.toLowerCase().trim() == UserProfile.masterAdminEmail.toLowerCase().trim();

                                        return ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                                          onTap: () => _showUserDetailsModal(u),
                                          leading: _buildUserAvatar(u, isMaster),
                                          title: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isBanned) ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(4)),
                                                  child: const Text("BANNED", style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                                                ),
                                              ],
                                            ],
                                          ),
                                          subtitle: Text(
                                            "$email • Role: $role",
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          trailing: isMaster
                                              ? Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                                                  child: const Text("Owner", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                                )
                                              : const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCBD5E1)),
                                        );
                                      },
                                    ),
                            ),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.6),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}