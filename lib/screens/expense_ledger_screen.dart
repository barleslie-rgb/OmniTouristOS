import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../services/expense_service.dart';

class ExpenseLedgerScreen extends StatefulWidget {
  const ExpenseLedgerScreen({Key? key}) : super(key: key);

  @override
  State<ExpenseLedgerScreen> createState() => _ExpenseLedgerScreenState();
}

class _ExpenseLedgerScreenState extends State<ExpenseLedgerScreen> {
  List<TripExpense> _expenses = [];
  bool _isLoading = true;
  double _dailyBudget = 3000.0;
  String _homeCurrency = 'USD';
  String _selectedCategoryFilter = 'All';

  final List<String> _categories = [
    'All',
    'Transit',
    'Food & Dining',
    'Attractions',
    'Shopping',
    'Stay',
    'Emergency',
  ];

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    final items = await ExpenseService.loadExpenses();
    final budget = await ExpenseService.getDailyBudget();
    final homeCurr = await ExpenseService.getHomeCurrency();

    if (mounted) {
      setState(() {
        _expenses = items;
        _dailyBudget = budget;
        _homeCurrency = homeCurr;
        _isLoading = false;
      });
    }
  }

  double get _todaySpentTotal {
    final now = DateTime.now();
    return _expenses
        .where((e) =>
            e.createdAt.year == now.year &&
            e.createdAt.month == now.month &&
            e.createdAt.day == now.day)
        .fold(0.0, (acc, cur) => acc + cur.amountLocal);
  }

  double get _allTimeSpentTotal {
    return _expenses.fold(0.0, (acc, cur) => acc + cur.amountLocal);
  }

  void _shareLedgerSummary() {
    HapticFeedback.selectionClick();
    if (_expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No expenses recorded to share.")),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln("✈️ *Omni TouristOS • Trip Expense Ledger*");
    buffer.writeln("💰 Total Spent: ₹${_allTimeSpentTotal.toStringAsFixed(0)} (≈ ${ExpenseService.convertFromInr(_allTimeSpentTotal, _homeCurrency).toStringAsFixed(2)} $_homeCurrency)");
    buffer.writeln("📅 Today's Spend: ₹${_todaySpentTotal.toStringAsFixed(0)}");
    buffer.writeln("-----------------------------------------");
    buffer.writeln("🧾 *Itemized Spends:*");

    for (var e in _expenses.take(15)) {
      final splitNote = e.splitCount > 1 ? " (${e.splitCount}-way split: ₹${e.perPersonLocal.toStringAsFixed(0)} each)" : "";
      buffer.writeln("• ${e.title}: ₹${e.amountLocal.toStringAsFixed(0)}$splitNote [${e.category}]");
    }

    buffer.writeln("-----------------------------------------");
    buffer.writeln("📱 Logged via Omni TouristOS");

    Share.share(buffer.toString(), subject: "Trip Expense Ledger Summary");
  }

  void _showExpenseModal(BuildContext context, {TripExpense? existing}) {
    HapticFeedback.selectionClick();
    final bool isEditing = existing != null;
    final titleCtrl = TextEditingController(text: isEditing ? existing.title : '');
    final amountCtrl = TextEditingController(
        text: isEditing ? existing.amountLocal.toStringAsFixed(0) : '');
    String selectedCategory = isEditing ? existing.category : 'Food & Dining';
    String paymentMethod = isEditing ? existing.paymentMethod : 'Cash';
    int splitCount = isEditing ? existing.splitCount : 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final keyboardInset = MediaQuery.of(ctx).viewInsets.bottom;
          final systemBottomInset = MediaQuery.of(ctx).padding.bottom;
          final double parsedAmount = double.tryParse(amountCtrl.text) ?? 0.0;
          final double convertedHome =
              ExpenseService.convertFromInr(parsedAmount, _homeCurrency);
          final double perPerson =
              parsedAmount / (splitCount > 0 ? splitCount : 1);

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              keyboardInset > 0 ? keyboardInset + 20 : (systemBottomInset > 0 ? systemBottomInset + 16 : 24),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isEditing ? Icons.edit_note_rounded : Icons.receipt_long_rounded,
                            color: const Color(0xFF2563EB),
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isEditing ? "Edit Street Spend" : "Log Street Spend",
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: amountCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          autofocus: !isEditing,
                          onChanged: (_) => setModalState(() {}),
                          decoration: InputDecoration(
                            labelText: "Amount (₹)",
                            prefixText: "₹ ",
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: titleCtrl,
                          decoration: InputDecoration(
                            labelText: "What was it for?",
                            hintText: "e.g. Food and snacks",
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (parsedAmount > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "≈ ${convertedHome.toStringAsFixed(2)} $_homeCurrency (${(convertedHome / splitCount).toStringAsFixed(2)}/person)",
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E40AF)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),
                  const Text("Category",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _categories.where((c) => c != 'All').map((c) {
                      final isSelected = c == selectedCategory;
                      return ChoiceChip(
                        label: Text(c, style: const TextStyle(fontSize: 11)),
                        selected: isSelected,
                        selectedColor: const Color(0xFF2563EB),
                        labelStyle: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF475569)),
                        onSelected: (val) {
                          HapticFeedback.selectionClick();
                          if (val) setModalState(() => selectedCategory = c);
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 12),
                  const Text("Payment Method",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  Row(
                    children: ['Cash', 'UPI / QR', 'Card'].map((mode) {
                      final isSelected = mode == paymentMethod;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setModalState(() => paymentMethod = mode);
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              mode,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Split with Group",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5)),
                            Text(
                              splitCount > 1
                                  ? "₹${perPerson.toStringAsFixed(1)} per person ($splitCount ways)"
                                  : "Solo expense",
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Color(0xFF64748B)),
                              onPressed: splitCount > 1
                                  ? () {
                                      HapticFeedback.selectionClick();
                                      setModalState(() => splitCount--);
                                    }
                                  : null,
                            ),
                            Text("$splitCount",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  color: Color(0xFF2563EB)),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                setModalState(() => splitCount++);
                              },
                            ),
                          ],
                        ),
                      ],
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final val =
                            double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                        final desc = titleCtrl.text.trim().isEmpty
                            ? selectedCategory
                            : titleCtrl.text.trim();

                        if (val > 0) {
                          HapticFeedback.mediumImpact();
                          if (isEditing) {
                            final updated = existing.copyWith(
                              title: desc,
                              category: selectedCategory,
                              amountLocal: val,
                              amountHome: ExpenseService.convertFromInr(
                                  val, _homeCurrency),
                              currencyHome: _homeCurrency,
                              paymentMethod: paymentMethod,
                              splitCount: splitCount,
                            );
                            await ExpenseService.updateExpense(updated);
                          } else {
                            final newExpense = TripExpense(
                              id: DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString(),
                              title: desc,
                              category: selectedCategory,
                              amountLocal: val,
                              currencyLocal: 'INR',
                              amountHome: ExpenseService.convertFromInr(
                                  val, _homeCurrency),
                              currencyHome: _homeCurrency,
                              paymentMethod: paymentMethod,
                              splitCount: splitCount,
                              createdAt: DateTime.now(),
                            );
                            await ExpenseService.addExpense(newExpense);
                          }
                          Navigator.pop(ctx);
                          _refreshData();
                        }
                      },
                      child: Text(
                        isEditing ? "Update Spend" : "Save & Record",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteExpense(TripExpense item) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Expense?",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          "Are you sure you want to delete \"${item.title}\" (₹${item.amountLocal.toStringAsFixed(0)})?",
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ExpenseService.deleteExpense(item.id);
              _refreshData();
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    HapticFeedback.selectionClick();
    final budgetCtrl =
        TextEditingController(text: _dailyBudget.toStringAsFixed(0));
    String tempCurr = _homeCurrency;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Budget & Home Currency",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: budgetCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Daily Target Budget (₹)",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: tempCurr,
                decoration: InputDecoration(
                  labelText: "Home Base Currency",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: ExpenseService.inrToForeignRates.keys
                    .map((code) =>
                        DropdownMenuItem(value: code, child: Text(code)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => tempCurr = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                HapticFeedback.lightImpact();
                final newBudget =
                    double.tryParse(budgetCtrl.text) ?? _dailyBudget;
                await ExpenseService.setDailyBudget(newBudget);
                await ExpenseService.setHomeCurrency(tempCurr);
                Navigator.pop(ctx);
                _refreshData();
              },
              child: const Text("Update"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final filtered = _selectedCategoryFilter == 'All'
        ? _expenses
        : _expenses
            .where((e) => e.category == _selectedCategoryFilter)
            .toList();

    final budgetRatio =
        (_todaySpentTotal / (_dailyBudget > 0 ? _dailyBudget : 1))
            .clamp(0.0, 1.0);
    final isOverBudget = _todaySpentTotal > _dailyBudget;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFFF8FAFC), // Unified seamless edge
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Trip Expense & Split Ledger",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A)),
        ),
        actions: [
          IconButton(
            tooltip: "Share Ledger Summary",
            icon: const Icon(Icons.share_rounded, color: Color(0xFF2563EB)),
            onPressed: _shareLedgerSummary,
          ),
          IconButton(
            tooltip: "Budget Preferences",
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF0F172A)),
            onPressed: () => _showSettingsDialog(context),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 8),
        child: FloatingActionButton.extended(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add_rounded),
          label: const Text("Add Spend", style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => _showExpenseModal(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: const Color(0xFF2563EB),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 16, 16, (bottomInset > 0 ? bottomInset : 14) + 84),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Budget Progress Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Today's Spend",
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF64748B))),
                                  Text(
                                    "₹${_todaySpentTotal.toStringAsFixed(0)}",
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: isOverBudget
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text("Daily Target",
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF64748B))),
                                  Text(
                                    "₹${_dailyBudget.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: budgetRatio,
                              minHeight: 8,
                              backgroundColor: const Color(0xFFF1F5F9),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isOverBudget
                                    ? const Color(0xFFDC2626)
                                    : budgetRatio > 0.8
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF16A34A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isOverBudget
                                    ? "⚠️ Over budget by ₹${(_todaySpentTotal - _dailyBudget).toStringAsFixed(0)}"
                                    : "₹${(_dailyBudget - _todaySpentTotal).toStringAsFixed(0)} remaining today",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isOverBudget
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF16A34A),
                                ),
                              ),
                              Text(
                                "Total Trip: ₹${_allTimeSpentTotal.toStringAsFixed(0)} (≈ ${ExpenseService.convertFromInr(_allTimeSpentTotal, _homeCurrency).toStringAsFixed(1)} $_homeCurrency)",
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Filter Chips
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final cat = _categories[i];
                          final isSelected = cat == _selectedCategoryFilter;
                          return ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: const Color(0xFF2563EB),
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                            ),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            onSelected: (val) {
                              HapticFeedback.selectionClick();
                              if (val) {
                                setState(() => _selectedCategoryFilter = cat);
                              }
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 14),

                    filtered.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: const [
                                Icon(Icons.receipt_long_rounded,
                                    size: 40, color: Color(0xFFCBD5E1)),
                                SizedBox(height: 8),
                                Text("No expenses recorded yet.",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF64748B))),
                                Text(
                                    "Tap '+ Add Spend' to log quick street expenses.",
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF94A3B8))),
                              ],
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final item = filtered[i];
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            _getCategoryIcon(item.category),
                                            size: 20,
                                            color: const Color(0xFF2563EB),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.title,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13.5,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                "${item.category} • ${item.paymentMethod}${item.splitCount > 1 ? ' • ${item.splitCount}-way split (₹${item.perPersonLocal.toStringAsFixed(0)} each)' : ''}",
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              "₹${item.amountLocal.toStringAsFixed(0)}",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 15,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            Text(
                                              "≈ ${item.amountHome.toStringAsFixed(2)} ${item.currencyHome}",
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const Divider(
                                        height: 16, color: Color(0xFFF1F5F9)),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                const Color(0xFF2563EB),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          icon: const Icon(Icons.edit_rounded,
                                              size: 15),
                                          label: const Text("Edit",
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold)),
                                          onPressed: () => _showExpenseModal(
                                              context,
                                              existing: item),
                                        ),
                                        const SizedBox(width: 6),
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                const Color(0xFFDC2626),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 15),
                                          label: const Text("Delete",
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold)),
                                          onPressed: () =>
                                              _confirmDeleteExpense(item),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Transit':
        return Icons.directions_subway_rounded;
      case 'Food & Dining':
        return Icons.restaurant_rounded;
      case 'Attractions':
        return Icons.fort_rounded;
      case 'Shopping':
        return Icons.shopping_bag_rounded;
      case 'Stay':
        return Icons.hotel_rounded;
      case 'Emergency':
        return Icons.healing_rounded;
      default:
        return Icons.receipt_rounded;
    }
  }
}