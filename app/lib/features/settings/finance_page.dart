import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../data/database.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  String period = 'Hari';
  DateTime selectedDate = DateTime.now();

  int income = 0;
  int expense = 0;
  int debt = 0;
  List<Map<String, dynamic>> expenseRows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime get from {
    final d = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    if (period == 'Hari') return d;
    if (period == 'Minggu') {
      return d.subtract(Duration(days: d.weekday - 1));
    }
    if (period == 'Bulan') {
      return DateTime(d.year, d.month, 1);
    }
    return DateTime(d.year, 1, 1);
  }

  DateTime get to {
    if (period == 'Hari') return from.add(const Duration(days: 1));
    if (period == 'Minggu') return from.add(const Duration(days: 7));
    if (period == 'Bulan') return DateTime(from.year, from.month + 1, 1);
    return DateTime(from.year + 1, 1, 1);
  }

  Future<void> _load() async {
    final results = await Future.wait([
      DB.omzet(from, to),
      DB.expenseTotal(from, to),
      DB.expenseDebtTotal(from, to),
      DB.expenses(from, to),
    ]);

    if (!mounted) return;

    setState(() {
      income = results[0] as int;
      expense = results[1] as int;
      debt = results[2] as int;
      expenseRows = results[3] as List<Map<String, dynamic>>;
    });
  }

  String _periodLabel() {
    if (period == 'Hari') {
      return displayDate(from);
    }

    if (period == 'Minggu') {
      final end = to.subtract(const Duration(days: 1));
      return '${displayDate(from)} - ${displayDate(end)}';
    }

    if (period == 'Bulan') {
      return displayDate(from);
    }

    return '${from.year}';
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (result == null) return;

    setState(() => selectedDate = result);
    _load();
  }

  Future<void> _showExpenseDialog([
    Map<String, dynamic>? item,
  ]) async {
    final category = TextEditingController(
      text: item?['category']?.toString() ?? '',
    );
    final note = TextEditingController(
      text: item?['note']?.toString() ?? '',
    );
    final amount = TextEditingController(text: item?['amount']?.toString() ?? '');
    String paymentStatus = item?['payment_status']?.toString() ?? 'Sudah Dibayar';

    DateTime date = item == null
        ? DateTime.now()
        : DateTime.tryParse(
              item['expense_date'].toString(),
            ) ??
            DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                item == null
                    ? 'Catat Pengeluaran'
                    : 'Edit Pengeluaran',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: category,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        hintText: 'Contoh: Listrik',
                      ),
                    ),
                    TextField(
                      controller: note,
                      decoration: const InputDecoration(
                        labelText: 'Keterangan',
                      ),
                    ),
                    TextField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Nominal',
                        prefixText: 'Rp ',
                      ),
                    ),
                    DropdownButtonFormField<String>(value:paymentStatus,decoration:const InputDecoration(labelText:'Status Pembayaran'),items:const [DropdownMenuItem(value:'Sudah Dibayar',child:Text('Sudah Dibayar')),DropdownMenuItem(value:'Jatuh Tempo',child:Text('Jatuh Tempo'))],onChanged:(v){if(v!=null)setDialogState(()=>paymentStatus=v);}),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.calendar_today_outlined,
                      ),
                      title: const Text('Tanggal'),
                      subtitle: Text(displayDate(date)),
                      onTap: () async {
                        final result = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );

                        if (result != null) {
                          setDialogState(() => date = result);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () async {
                    final nominal = int.tryParse(
                      amount.text
                          .replaceAll('.', '')
                          .replaceAll(',', '')
                          .trim(),
                    );

                    try {
                      await DB.saveExpense(
                        id: item?['id'] as int?,
                        date: date,
                        category: category.text,
                        note: note.text,
                        amount: nominal ?? 0,
                        paymentStatus: paymentStatus,
                        dueDate: paymentStatus == 'Jatuh Tempo' ? date : null,
                      );

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      }
                    } catch (e) {
                      if (!dialogContext.mounted) return;

                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceFirst(
                              'Exception: ',
                              '',
                            ),
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    category.dispose();
    note.dispose();
    amount.dispose();

    if (saved == true) {
      _load();
    }
  }

  Future<void> _deleteExpense(
    Map<String, dynamic> item,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pengeluaran?'),
        content: Text(
          '${item['category']} • ${rp(item['amount'] as num)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DB.deleteExpense(item['id'] as int);
      _load();
    }
  }

  Widget _metric(
    String title,
    int value,
    IconData icon,
  ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: red),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: inkMuted,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                alignment: Alignment.centerLeft,
                child: Text(
                  rp(value),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
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
    final net = income - (expense - debt);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keuangan'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExpenseDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Pengeluaran'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: period,
                    decoration: const InputDecoration(
                      labelText: 'Periode',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Hari',
                        child: Text('Hari'),
                      ),
                      DropdownMenuItem(
                        value: 'Minggu',
                        child: Text('Minggu'),
                      ),
                      DropdownMenuItem(
                        value: 'Bulan',
                        child: Text('Bulan'),
                      ),
                      DropdownMenuItem(
                        value: 'Tahun',
                        child: Text('Tahun'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() => period = value);
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month),
                  tooltip: 'Pilih tanggal',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _periodLabel(),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: inkMuted,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                _metric(
                  'Pendapatan',
                  income,
                  Icons.trending_up_rounded,
                ),
                const SizedBox(width: 8),
                _metric(
                  'Pengeluaran',
                  expense,
                  Icons.trending_down_rounded,
                ),
              ],
            ),

            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: red,
                ),
                title: const Text(
                  'Hasil Bersih',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                subtitle: const Text(
                  'Pendapatan - Pengeluaran',
                ),
                trailing: Text(
                  rp(net),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: net >= 0
                        ? Colors.green.shade700
                        : red,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            const Text(
              'Riwayat Pengeluaran',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),

            if (expenseRows.isEmpty)
              const Card(
                child: ListTile(
                  title: Text(
                    'Belum ada pengeluaran pada periode ini.',
                  ),
                ),
              )
            else
              ...expenseRows.map(
                (item) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: redSoft,
                      foregroundColor: red,
                      child: const Icon(
                        Icons.receipt_long_outlined,
                      ),
                    ),
                    title: Text(
                      item['category'].toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      '${item['note']} • '
                      '${item['expense_date'].toString().substring(0, 10)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          rp(item['amount'] as num),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showExpenseDialog(item);
                            } else if (value == 'delete') {
                              _deleteExpense(item);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Hapus'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }
}
