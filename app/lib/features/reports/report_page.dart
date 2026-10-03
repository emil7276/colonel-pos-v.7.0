import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../models/models.dart';
import '../../services/receipt_service.dart';

class ReportPage extends StatefulWidget {
  final String role;
  const ReportPage({super.key, required this.role});
  @override State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  DateTime selectedDate = DateTime.now();
  DateTime? selectedEndDate;
  bool loading = true;
  int omzet = 0, transaksi = 0, item = 0, retur = 0;
  Map<String,int> payments = {};
  List<SaleModel> sales = [];
  List<SaleModel> returnedSales = [];
  List<Map<String,dynamic>> best = [], hours = [];
  List<Map<String,dynamic>> customers = [], trend = [];
  int monthSales = 0;
  String trendMode = 'Hari';

  DateTime get start => DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
  DateTime get end => selectedEndDate == null ? start.add(const Duration(days: 1)) : DateTime(selectedEndDate!.year,selectedEndDate!.month,selectedEndDate!.day).add(const Duration(days:1));

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final summary = await DB.daySummary(selectedDate);
      final b = await DB.bestSelling(start, end);
      final h = await DB.hourly(start, end);
      final month = await DB.monthOmzet(DateTime.now());
      final c = await DB.customerSales(start, end);
      final now = DateTime.now();
      final t = trendMode == 'Hari'
          ? await DB.daily(now.subtract(const Duration(days: 29)), now.add(const Duration(days: 1)))
          : trendMode == 'Bulan'
              ? await DB.monthlyTrend(DateTime(now.year, now.month - 11, 1), DateTime(now.year, now.month + 1, 1))
              : await DB.yearlyTrend(DateTime(now.year - 4, 1, 1), DateTime(now.year + 1, 1, 1));
      if (!mounted) return;
      setState(() {
        omzet = summary['omzet'] as int; transaksi = summary['transaksi'] as int; item = summary['item'] as int; retur = summary['returned'] as int;
        payments = Map<String,int>.from(summary['payments'] as Map);
        sales = (summary['sales'] as List).map((e)=>SaleModel.fromMap(e as Map<String,dynamic>)).toList();
        returnedSales = (summary['returnedSales'] as List).map((e)=>SaleModel.fromMap(e as Map<String,dynamic>)).toList();
        best = b; hours = h; customers = c; monthSales = month; trend = t; loading = false;
      });
    } catch(e) { if (!mounted) return; setState(()=>loading=false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Gagal memuat laporan: $e'))); }
  }

  @override void initState(){ super.initState(); load(); }

  Future<void> pickDate() async {
    final r=await showDateRangePicker(context:context,firstDate:DateTime(2020),lastDate:DateTime.now(),initialDateRange:DateTimeRange(start:selectedDate,end:selectedEndDate??selectedDate));
    if(r!=null){setState((){selectedDate=r.start;selectedEndDate=r.end;});await load();}
  }

  @override Widget build(BuildContext context){
    return RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.fromLTRB(16,16,16,28),children:[
      Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Laporan',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900)),Text('${displayDate(start)} - ${displayDate(end.subtract(const Duration(days:1)))}',style:TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant))])),OutlinedButton.icon(onPressed:pickDate,icon:const Icon(Icons.calendar_month_outlined),label:const Text('Pilih rentang tanggal'))]),
      const SizedBox(height:16),
      if(loading) const LinearProgressIndicator(minHeight:3),
      const SizedBox(height:8),
      LayoutBuilder(builder:(context,c){final cols=c.maxWidth>=900?4:2; return GridView.count(crossAxisCount:cols,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisSpacing:10,mainAxisSpacing:10,childAspectRatio:2.15,children:[_metric('Omzet',rp(omzet),Icons.payments_outlined),_metric('Transaksi','$transaksi',Icons.receipt_long_outlined,onTap:showTransactions),_metric('Item Terjual','$item',Icons.fastfood_outlined,onTap:showItemsSold),_metric('Retur','$retur',Icons.assignment_return_outlined,onTap:showReturns) ]);}),
      const SizedBox(height:16),
      _monthSalesCard(),
      _trendCard(),
      _customerSection(),
      _paymentSummary(),
      _itemSalesSection(),
      _section('Jam Transaksi',hours.isEmpty?[const ListTile(title:Text('Belum ada penjualan.'))]:hours.take(8).map((x)=>ListTile(leading:const Icon(Icons.schedule_outlined),title:Text('${x['jam']}:00'),trailing:Text('${x['transaksi']} transaksi'))).toList()),
      const SizedBox(height:6),
      const Text('Transaksi Hari Ini',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),
      const SizedBox(height:8),
      if(sales.isEmpty) Card(child:Padding(padding:const EdgeInsets.all(18),child:Text('Tidak ada transaksi pada ${displayDate(selectedDate)}.'))),
      ...sales.map((s)=>Card(child:ListTile(onTap:()=>saleDetail(s),leading:CircleAvatar(child:Icon(s.returned?Icons.undo:Icons.receipt_long_outlined)),title:Text(s.no,style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text('${s.time} • ${s.cashier} • ${s.payment}'),trailing:Text(s.returned?'RETUR':rp(s.total),style:TextStyle(fontWeight:FontWeight.w800,color:s.returned?Colors.red:null))))),
      const CopyrightFooter(),
    ]));
  }



  Widget _monthSalesCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: redSoft, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.calendar_month_rounded, color: red),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Penjualan Bulan Ini', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: inkMuted)),
                  const SizedBox(height: 3),
                  Text(rp(monthSales), style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: red)),
                  Text('Omzet bulan berjalan', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trendCard() {
    final data = List<Map<String,dynamic>>.from(trend);
    data.sort((a,b) => (a['periode'] ?? a['tanggal']).toString().compareTo((b['periode'] ?? b['tanggal']).toString()));
    final max = data.fold<double>(0, (m,x) => ((x['omzet'] as num?)?.toDouble() ?? 0) > m ? (x['omzet'] as num).toDouble() : m);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Grafik Penjualan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (_, i) {
                  const modes = ['Hari','Bulan','Tahun'];
                  final mode = modes[i];
                  final selected = trendMode == mode;
                  return ChoiceChip(
                    label: Text(mode),
                    selected: selected,
                    onSelected: (_) async { setState(() => trendMode = mode); await load(); },
                    selectedColor: redSoft,
                    labelStyle: TextStyle(color: selected ? red : ink, fontWeight: FontWeight.w800, fontSize: 12),
                    side: BorderSide(color: selected ? red : line),
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            if (data.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Text('Belum ada data penjualan.'))
            else
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: data.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final row = data[i];
                    final value = (row['omzet'] as num).toDouble();
                    final h = (max <= 0 ? 4.0 : (value / max * 104).clamp(4.0, 104.0).toDouble());
                    final label = (row['periode'] ?? row['tanggal']).toString();
                    final short = trendMode == 'Hari' && label.length >= 10 ? label.substring(8) : label;
                    return SizedBox(
                      width: trendMode == 'Hari' ? 34 : 58,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(value >= 1000000 ? '${(value/1000000).toStringAsFixed(1)}jt' : value >= 1000 ? '${(value/1000).toStringAsFixed(0)}k' : value.toStringAsFixed(0), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Container(height: h, decoration: BoxDecoration(color: red, borderRadius: BorderRadius.circular(7))),
                          const SizedBox(height: 4),
                          Text(short, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _customerSection() {
    final sortedCustomers = List<Map<String,dynamic>>.from(customers)
      ..sort((a, b) => a['customer_name'].toString().toLowerCase()
          .compareTo(b['customer_name'].toString().toLowerCase()));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text(
          'Penjualan Berdasarkan Pelanggan',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        children: sortedCustomers.isEmpty
            ? [const ListTile(title: Text('Belum ada penjualan pada periode ini.'))]
            : [
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: sortedCustomers.length,
                    itemBuilder: (_, i) {
                      final x = sortedCustomers[i];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 17,
                          backgroundColor: redSoft,
                          foregroundColor: red,
                          child: const Icon(Icons.person_outline_rounded, size: 18),
                        ),
                        title: Text(
                          x['customer_name'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text('${x['customer_type']} • ${x['transaksi']} transaksi'),
                        trailing: Text(
                          rp(x['omzet'] as num),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      );
                    },
                  ),
                ),
              ],
      ),
    );
  }

  Widget _itemSalesSection() {
    final sortedItems = List<Map<String,dynamic>>.from(best)
      ..sort((a, b) => (b['qty'] as num).compareTo(a['qty'] as num));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: const Text(
          'Penjualan Berdasarkan Item',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        children: sortedItems.isEmpty
            ? [const ListTile(title: Text('Belum ada penjualan.'))]
            : [
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: sortedItems.length,
                    itemBuilder: (_, i) {
                      final x = sortedItems[i];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          child: Text('${x['qty']}'),
                        ),
                        title: Text(
                          x['name'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        trailing: Text(
                          rp(x['omzet'] as num),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      );
                    },
                  ),
                ),
              ],
      ),
    );
  }

  Widget _paymentSummary() {
    final total = payments.values.fold<int>(0, (a, b) => a + b);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ringkasan Pembayaran', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            if (payments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Belum ada transaksi pada tanggal ini.'),
              )
            else
              Row(
                children: [
                  SizedBox(
                    width: 118,
                    height: 118,
                    child: CustomPaint(
                      painter: _DonutPainter(values: payments.values.toList()),
                      child: Center(
                        child: Text(
                          '$total\\ntransaksi',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: payments.entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _paymentColor(e.key),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e.key,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(
                                '${e.value}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _paymentColor(String key) {
    final i = payments.keys.toList().indexOf(key);
    const colors = [
      red,
      navy,
      Color(0xFF2E7D32),
      Color(0xFFF59E0B),
      Color(0xFF7C3AED),
    ];
    return colors[i % colors.length];
  }

  Widget _metric(String title, String value, IconData icon, {VoidCallback? onTap}) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: redSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: red, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: inkMuted,
                            ),
                          ),
                        ),
                        if (onTap != null)
                          const Icon(Icons.chevron_right_rounded, size: 17, color: inkMuted),
                      ],
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> showReturns() async {
    final returned = returnedSales;

    if (returnedSales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada transaksi retur pada tanggal ini.')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .72,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Transaksi Retur',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: returned.length,
                    itemBuilder: (_, i) {
                      final s = returned[i];
                      return ListTile(
                        onTap: () => saleDetail(s),
                        dense: true,
                        leading: const Icon(
                          Icons.assignment_return_outlined,
                          color: red,
                        ),
                        title: Text(
                          s.no,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text('${s.time} • Kasir: ${s.cashier}'),
                        trailing: const Text(
                          'RETUR',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.red,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> showTransactions() async {
    if (sales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada transaksi pada tanggal ini.')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .72,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Transaksi', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: sales.length,
                    itemBuilder: (_, i) {
                      final s = sales[i];
                      return ListTile(
                        onTap: () => saleDetail(s),
                        dense: true,
                        leading: const Icon(Icons.receipt_long_rounded, color: red),
                        title: Text(s.no, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${s.time} • ${s.payment}'),
                        trailing: Text(
                          s.returned ? 'RETUR' : rp(s.total),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> showItemsSold() async {
    if (best.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada item terjual pada tanggal ini.')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Item Terjual', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              ...best.take(12).map(
                (x) => ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 17,
                    backgroundColor: redSoft,
                    foregroundColor: red,
                    child: Text('${x['qty']}'),
                  ),
                  title: Text(x['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                  trailing: Text(rp(x['omzet'] as num), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title,List<Widget> children)=>Card(margin:const EdgeInsets.only(bottom:12),child:ExpansionTile(initiallyExpanded:true,title:Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),children:children));

  Future<void> saleDetail(SaleModel s) async {
    final items = await DB.saleItems(s.id);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            children: [
              Text(s.no, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
              Text('${s.time} • Kasir: ${s.cashier}'),
              if (s.returned)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      avatar: Icon(Icons.assignment_return_outlined, size: 18),
                      label: Text('RETUR'),
                    ),
                  ),
                ),
              const Divider(),
              ...items.map((i) => ListTile(
                    dense: true,
                    title: Text(i['name'].toString()),
                    subtitle: Text('Qty ${i['qty']}'),
                    trailing: Text(rp((i['price'] as int) * (i['qty'] as int))),
                  )),
              ListTile(
                title: const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w800)),
                trailing: Text(rp(s.total), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        printReceipt(s);
                      },
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Cetak'),
                    ),
                  ),
                  if (widget.role == 'Administrator' && !s.returned) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          authorizeReturn(s);
                        },
                        icon: const Icon(Icons.undo),
                        label: const Text('Retur'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> authorizeReturn(SaleModel sale) async {
    final pass = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Otorisasi Retur Admin'),
        content: TextField(
          controller: pass,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password Admin'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              final admin = await DB.login('admin', pass.text);
              if (!context.mounted) return;
              Navigator.pop(context, admin != null && admin['role'] == 'Administrator');
            },
            child: const Text('OTORISASI'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await DB.returnSale(sale.id, 'admin');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Retur berhasil. Stok dikembalikan.')));
      await load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Retur gagal: $e')));
    }
  }
}

class _DonutPainter extends CustomPainter {
  final List<int> values;

  _DonutPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (a, b) => a + b);
    if (total <= 0) return;

    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final stroke = radius * .28;

    final rect = Rect.fromCircle(
      center: center,
      radius: radius - stroke / 2,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    const colors = [
      red,
      navy,
      Color(0xFF2E7D32),
      Color(0xFFF59E0B),
      Color(0xFF7C3AED),
    ];

    var start = -1.5708;

    for (var i = 0; i < values.length; i++) {
      final sweep = 6.283185307 * values[i] / total;
      paint.color = colors[i % colors.length];
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return true;
  }
}
