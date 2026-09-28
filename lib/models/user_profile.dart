class UserProfile {
  final String id;
  final String email;
  final String role;
  final DateTime createdAt;
  final DateTime trialEndsAt;
  final bool isPremium;
  final bool isBanned;

  static const String masterAdminEmail = "barleslie@gmail.com";

  UserProfile({
    required this.id,
    required this.email,
    required this.role,
    required this.createdAt,
    required this.trialEndsAt,
    required this.isPremium,
    required this.isBanned,
  });

  // OWNER CHECK: True if email matches your master address or role is admin
  bool get isOwner =>
      email.toLowerCase().trim() == masterAdminEmail.toLowerCase().trim() ||
      role.toLowerCase() == "admin";

  // TRIAL CHECK: 30-day free trial active
  bool get isTrialActive => DateTime.now().isBefore(trialEndsAt);

  // DAYS REMAINING in free trial
  int get trialDaysRemaining {
    if (isOwner) return 99999;
    final diff = trialEndsAt.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  // FEATURE ACCESS GATE: You (owner) are NEVER blocked.
  bool get hasFeatureAccess {
    if (isOwner) return true; // Lifetime God-Mode
    if (isBanned) return false;
    if (isPremium) return true;
    return isTrialActive; // True for first 30 days, false on day 31+
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final email = json["email"] ?? "";
    final isMaster = email.toLowerCase().trim() == masterAdminEmail.toLowerCase().trim();
    
    return UserProfile(
      id: json["id"] ?? "",
      email: email,
      role: isMaster ? "admin" : (json["role"] ?? "user"),
      createdAt: json["created_at"] != null
          ? DateTime.parse(json["created_at"])
          : DateTime.now(),
      trialEndsAt: json["trial_ends_at"] != null
          ? DateTime.parse(json["trial_ends_at"])
          : DateTime.now().add(const Duration(days: 30)),
      isPremium: isMaster ? true : (json["is_premium"] ?? false),
      isBanned: isMaster ? false : (json["is_banned"] ?? false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "email": email,
      "role": isOwner ? "admin" : role,
      "created_at": createdAt.toIso8601String(),
      "trial_ends_at": trialEndsAt.toIso8601String(),
      "is_premium": isOwner ? true : isPremium,
      "is_banned": isOwner ? false : isBanned,
    };
  }
}