import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class TripExpense {
  final String id;
  final String title;
  final String category;
  final double amountLocal;
  final String currencyLocal;
  final double amountHome;
  final String currencyHome;
  final String paymentMethod;
  final int splitCount;
  final DateTime createdAt;

  TripExpense({
    required this.id,
    required this.title,
    required this.category,
    required this.amountLocal,
    required this.currencyLocal,
    required this.amountHome,
    required this.currencyHome,
    required this.paymentMethod,
    this.splitCount = 1,
    required this.createdAt,
  });

  double get perPersonLocal => amountLocal / (splitCount > 0 ? splitCount : 1);
  double get perPersonHome => amountHome / (splitCount > 0 ? splitCount : 1);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'amount_local': amountLocal,
        'currency_local': currencyLocal,
        'amount_home': amountHome,
        'currency_home': currencyHome,
        'payment_method': paymentMethod,
        'split_count': splitCount,
        'created_at': createdAt.toIso8601String(),
      };

  factory TripExpense.fromJson(Map<String, dynamic> json) => TripExpense(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        category: json['category'] ?? 'General',
        amountLocal: (json['amount_local'] as num?)?.toDouble() ?? 0.0,
        currencyLocal: json['currency_local'] ?? 'INR',
        amountHome: (json['amount_home'] as num?)?.toDouble() ?? 0.0,
        currencyHome: json['currency_home'] ?? 'USD',
        paymentMethod: json['payment_method'] ?? 'Cash',
        splitCount: (json['split_count'] as num?)?.toInt() ?? 1,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
      );

  TripExpense copyWith({
    String? title,
    String? category,
    double? amountLocal,
    String? currencyLocal,
    double? amountHome,
    String? currencyHome,
    String? paymentMethod,
    int? splitCount,
  }) {
    return TripExpense(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      amountLocal: amountLocal ?? this.amountLocal,
      currencyLocal: currencyLocal ?? this.currencyLocal,
      amountHome: amountHome ?? this.amountHome,
      currencyHome: currencyHome ?? this.currencyHome,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      splitCount: splitCount ?? this.splitCount,
      createdAt: createdAt,
    );
  }
}

class ExpenseService {
  static const String _storageKey = 'omni_trip_expenses_v1';
  static const String _budgetKey = 'omni_daily_budget_limit';
  static const String _homeCurrencyKey = 'omni_home_currency_pref';

  static const Map<String, double> inrToForeignRates = {
    'USD': 0.012,
    'EUR': 0.011,
    'GBP': 0.0095,
    'AED': 0.044,
    'AUD': 0.018,
    'CAD': 0.016,
    'SGD': 0.016,
    'JPY': 1.82,
    'INR': 1.0,
  };

  static double convertFromInr(double amountInr, String targetCurrency) {
    final rate = inrToForeignRates[targetCurrency.toUpperCase()] ?? 0.012;
    return amountInr * rate;
  }

  static Future<String> getHomeCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_homeCurrencyKey) ?? 'USD';
  }

  static Future<void> setHomeCurrency(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_homeCurrencyKey, code.toUpperCase());
  }

  static Future<double> getDailyBudget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_budgetKey) ?? 3000.0;
  }

  static Future<void> setDailyBudget(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_budgetKey, amount);
  }

  // 1. LOCAL-FIRST READ
  static Future<List<TripExpense>> loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    List<TripExpense> items = [];

    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        items = list.map((e) => TripExpense.fromJson(e)).toList();
      } catch (e) {
        debugPrint('Error reading local expenses: $e');
      }
    }

    // Cloud background sync if logged in and local storage is empty
    final user = AuthService.currentUser;
    if (user != null && items.isEmpty) {
      try {
        final res = await Supabase.instance.client
            .from('user_profiles')
            .select('trip_expenses')
            .eq('id', user.id)
            .maybeSingle();

        if (res != null && res['trip_expenses'] != null) {
          final cloudList = res['trip_expenses'] as List<dynamic>;
          if (cloudList.isNotEmpty) {
            items = cloudList.map((e) => TripExpense.fromJson(e)).toList();
            await prefs.setString(_storageKey, jsonEncode(cloudList));
          }
        }
      } catch (e) {
        debugPrint('Notice on cloud expense fetch: $e');
      }
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  // 2. CREATE EXPENSE (LOCAL FIRST + CLOUD SYNC)
  static Future<void> addExpense(TripExpense expense) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await loadExpenses();
    items.insert(0, expense);

    final jsonList = items.map((e) => e.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));

    _syncToCloud(jsonList);
  }

  // 3. UPDATE / EDIT EXPENSE
  static Future<void> updateExpense(TripExpense updated) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await loadExpenses();
    final index = items.indexWhere((e) => e.id == updated.id);
    if (index != -1) {
      items[index] = updated;
      final jsonList = items.map((e) => e.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
      _syncToCloud(jsonList);
    }
  }

  // 4. DELETE EXPENSE
  static Future<void> deleteExpense(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await loadExpenses();
    items.removeWhere((e) => e.id == id);

    final jsonList = items.map((e) => e.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));

    _syncToCloud(jsonList);
  }

  static void _syncToCloud(List<Map<String, dynamic>> jsonList) async {
    final user = AuthService.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client
            .from('user_profiles')
            .update({'trip_expenses': jsonList})
            .eq('id', user.id);
      } catch (e) {
        debugPrint('Notice on cloud expense sync: $e');
      }
    }
  }
}