import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const AuthScreen({Key? key, required this.onLoginSuccess}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with WidgetsBindingObserver {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _isSignUpMode = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;

  StreamSubscription<AuthState>? _authSubscription;
  Timer? _googleTimeoutTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        _googleTimeoutTimer?.cancel();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('omni_is_guest_mode', false);

        if (mounted) {
          setState(() {
            _isGoogleLoading = false;
            _isLoading = false;
          });
          widget.onLoginSuccess();
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isGoogleLoading) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isGoogleLoading && Supabase.instance.client.auth.currentUser == null) {
          setState(() {
            _isGoogleLoading = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _googleTimeoutTimer?.cancel();
    _authSubscription?.cancel();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    HapticFeedback.selectionClick();
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    _googleTimeoutTimer?.cancel();
    _googleTimeoutTimer = Timer(const Duration(seconds: 35), () {
      if (mounted && _isGoogleLoading) {
        setState(() {
          _isGoogleLoading = false;
          _errorMessage = "Sign-in timed out or was cancelled. Please try again.";
        });
      }
    });

    try {
      await AuthService.signInWithGoogle();
    } catch (e) {
      _googleTimeoutTimer?.cancel();
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
          _errorMessage = "Google sign-in could not be completed: $e";
        });
      }
    }
  }

  Future<void> _handleEmailAuth() async {
    HapticFeedback.selectionClick();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    if (!email.contains("@") || !email.contains(".")) {
      setState(() => _errorMessage = "Please enter a valid email address.");
      return;
    }

    if (password.length < 6) {
      setState(() => _errorMessage = "Password must be at least 6 characters long.");
      return;
    }

    if (_isSignUpMode && name.isEmpty) {
      setState(() => _errorMessage = "Please enter your full name.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = _isSignUpMode
          ? await AuthService.signUpWithPassword(
              email: email,
              password: password,
              fullName: name,
            )
          : await AuthService.signInWithPassword(
              email: email,
              password: password,
            );

      if (profile != null) {
        if (profile.isBanned) {
          await AuthService.signOut();
          if (mounted) {
            setState(() {
              _errorMessage = "This account has been deactivated due to policy violations.";
            });
          }
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('omni_is_guest_mode', false);
        widget.onLoginSuccess();
      } else {
        setState(() {
          _errorMessage = _isSignUpMode
              ? "Could not create account. Email may already be in use."
              : "Invalid email or password. Please try again.";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final errStr = e.toString().toLowerCase();
          if (errStr.contains("invalid login credentials")) {
            _errorMessage = "Incorrect email or password.";
          } else if (errStr.contains("already registered")) {
            _errorMessage = "An account with this email already exists. Please sign in.";
          } else {
            _errorMessage = "Authentication notice: $e";
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleContinueAsGuest() async {
    HapticFeedback.selectionClick();
    setState(() => _isLoading = true);
    await AuthService.setGuestMode(true);
    widget.onLoginSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SingleChildScrollView(
            // Uses precise system padding without duplicate artificial offsets
            padding: EdgeInsets.fromLTRB(24, topPadding + 14, 24, bottomPadding + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.travel_explore_rounded, color: Color(0xFF60A5FA), size: 42),
                ),
                const SizedBox(height: 14),
                const Text(
                  "Omni TouristOS",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Your Unified Travel Operating System",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 22),

                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            backgroundColor: Colors.white,
                          ),
                          onPressed: (_isLoading || _isGoogleLoading) ? null : _handleGoogleSignIn,
                          child: _isGoogleLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.network(
                                      'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
                                      height: 22,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.account_circle_rounded,
                                        color: Color(0xFF4285F4),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      "Continue with Google",
                                      style: TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      Row(
                        children: const [
                          Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              "or with email",
                              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                            ),
                          ),
                          Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _isSignUpMode = false;
                                  _errorMessage = null;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: !_isSignUpMode ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: !_isSignUpMode
                                        ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                                        : null,
                                  ),
                                  child: Text(
                                    "Sign In",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: !_isSignUpMode ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _isSignUpMode = true;
                                  _errorMessage = null;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _isSignUpMode ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: _isSignUpMode
                                        ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                                        : null,
                                  ),
                                  child: Text(
                                    "Create Account",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: _isSignUpMode ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      if (_isSignUpMode) ...[
                        TextField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            labelText: "Full Name",
                            hintText: "e.g. Leslie Barretto",
                            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: "Email Address",
                          hintText: "traveler@example.com",
                          prefixIcon: const Icon(Icons.email_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          isDense: true,
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: "Password",
                          hintText: "••••••••",
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 18,
                              color: const Color(0xFF64748B),
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          isDense: true,
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: (_isLoading || _isGoogleLoading) ? null : _handleEmailAuth,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  _isSignUpMode ? "Create Account & Enter" : "Sign In to TouristOS",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                ),
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red, fontSize: 12, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                TextButton.icon(
                  onPressed: (_isLoading || _isGoogleLoading) ? null : _handleContinueAsGuest,
                  icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF93C5FD), size: 18),
                  label: const Text(
                    "Continue as Guest (Explore Destinations)",
                    style: TextStyle(
                      color: Color(0xFF93C5FD),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),

                const SizedBox(height: 6),
                const Text(
                  "30 Days Free Trial • No Credit Card Required",
                  style: TextStyle(color: Colors.white54, fontSize: 11.5, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}