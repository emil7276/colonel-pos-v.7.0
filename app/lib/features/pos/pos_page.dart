import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../models/models.dart';
import '../../services/receipt_service.dart';
import '../../services/quote_service.dart';
class PosPage extends StatefulWidget {
  final String cashier;
  final ValueChanged<String>? onTransactionSuccess;

  const PosPage({
    super.key,
    required this.cashier,
    this.onTransactionSuccess,
  });

  @override
  State<PosPage> createState() =>
      PosPageState();
}
class PosPageState extends State<PosPage> {
  final AudioPlayer _successPlayer = AudioPlayer();
  List<Product> products = [];
  final List<CartLine> cart = [];

  String category = 'Semua';
  int discount = 0;
  String customerType = 'Retail';
  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController customerPhoneController = TextEditingController();
  final TextEditingController menuSearchController = TextEditingController();
  String menuSearch = '';

  @override
  void dispose() {
    _successPlayer.dispose();
    customerNameController.dispose();
    customerPhoneController.dispose();
    menuSearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final raw = await DB.products();

      if (!mounted) return;

      setState(() {
        products = raw
            .map(Product.fromMap)
            .where((p) => p.active)
            .toList();
      });

      // If stock changed while a product was
      // already in the cart, adjust cart quantity.
      for (final line in cart) {
        final fresh = products.where(
          (p) => p.id == line.product.id,
        );

        if (fresh.isNotEmpty &&
            line.qty > fresh.first.stock) {
          line.qty = fresh.first.stock;
        }
      }

      cart.removeWhere(
        (line) => line.qty <= 0,
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memuat stok: $e',
          ),
        ),
      );
    }
  }

  List<String> get categories {
    final x = <String>{'Semua'};
    x.addAll(
      products.map((p) => p.category),
    );
    return x.toList();
  }

  int get subtotal => cart.fold(
        0,
        (sum, x) =>
            sum + x.product.price * x.qty,
      );

  int get total =>
      (subtotal - discount)
          .clamp(0, 1 << 31);

  void add(Product p) {
    final found = cart.where(
      (x) => x.product.id == p.id,
    );

    if (found.isEmpty) {
      if (p.stock <= 0) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content:
                Text('Stok ${p.name} habis.'),
          ),
        );
        return;
      }

      setState(() {
        cart.add(CartLine(p, 1));
      });
    } else {
      final line = found.first;

      if (line.qty >= p.stock) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'Stok ${p.name} hanya ${p.stock}.',
            ),
          ),
        );
        return;
      }

      setState(() => line.qty++);
    }
  }

  void minus(CartLine line) {
    setState(() {
      line.qty--;

      if (line.qty <= 0) {
        cart.remove(line);
      }
    });
  }

  Future<void> discountDialog() async {
    final c = TextEditingController(
      text: discount == 0
          ? ''
          : discount.toString(),
    );

    final value =
        await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Diskon'),
        content: TextField(
          controller: c,
          keyboardType:
              TextInputType.number,
          decoration:
              const InputDecoration(
            labelText:
                'Nominal diskon',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(
                context,
                int.tryParse(c.text) ??
                    0,
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (value != null) {
      setState(() {
        discount = value.clamp(
          0,
          subtotal,
        );
      });
    }
  }

  Future<void> customerDialog() async {
    final n=TextEditingController(text:customerNameController.text);
    final p=TextEditingController(text:customerPhoneController.text);
    final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('Data Pelanggan'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:n,decoration:const InputDecoration(labelText:'Nama Pelanggan')),TextField(controller:p,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Nomor HP'))]),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Batal')),FilledButton(onPressed:(){customerNameController.text=n.text.trim();customerPhoneController.text=p.text.trim();Navigator.pop(context,true);},child:const Text('Simpan'))]));
    n.dispose();p.dispose();if(ok==true&&mounted)setState((){});
  }

  Future<void> payment() async {
    if (cart.isEmpty) return;

    final cashController =
        TextEditingController();

    String method = 'Tunai';
    final bankController=TextEditingController();
    final accountController=TextEditingController();
    DateTime? dueDate;

    final result =
        await showDialog<
            Map<String, dynamic>>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (
            context,
            setDialog,
          ) {
            final cash =
                int.tryParse(
                      cashController
                          .text,
                    ) ??
                    0;

            final change =
                method == 'Tunai'
                    ? cash - total
                    : 0;

            return AlertDialog(
              title:
                  const Text('Pembayaran'),
              content: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Text(
                    'TOTAL ${rp(total)}',
                    style:
                        const TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 15,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final x in const [
                          'Tunai',
                          'Transfer',
                          'Bayar Tunda',
                        ])
                          ChoiceChip(
                            label: Text(x),
                            selected: method == x,
                            onSelected: (_) => setDialog(() => method = x),
                            selectedColor: redSoft,
                            labelStyle: TextStyle(
                              color: method == x ? red : ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                            side: BorderSide(
                              color: method == x ? red : line,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ),
                  if (method == 'Transfer') ...[
                    const SizedBox(height:10),
                    TextField(controller:bankController,decoration:const InputDecoration(labelText:'Nama Bank *')),
                    TextField(controller:accountController,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Nomor Rekening (opsional)')),
                  ],
                  if (method == 'Bayar Tunda') ...[
                    const SizedBox(height:10),
                    ListTile(contentPadding:EdgeInsets.zero,title:const Text('Tanggal Jatuh Tempo'),subtitle:Text(dueDate==null?'Pilih tanggal':displayDate(dueDate!)),onTap:()async{final d=await showDatePicker(context:context,initialDate:DateTime.now(),firstDate:DateTime.now(),lastDate:DateTime(2100));if(d!=null)setDialog(()=>dueDate=d);}),
                  ],
                  if (method ==
                      'Tunai') ...[
                    const SizedBox(
                      height: 10,
                    ),
                    TextField(
                      controller:
                          cashController,
                      keyboardType:
                          TextInputType
                              .number,
                      onChanged: (_) =>
                          setDialog(
                        () {},
                      ),
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Uang diterima',
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    Text(
                      change >= 0
                          ? 'Kembalian '
                            '${rp(change)}'
                          : 'Uang kurang '
                            '${rp(-change)}',
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(
                    context,
                  ),
                  child:
                      const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () {
                    final c =
                        int.tryParse(
                              cashController
                                  .text,
                            ) ??
                            0;

                    if (method ==
                            'Tunai' &&
                        c < total) {
                      ScaffoldMessenger
                              .of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Uang diterima '
                            'belum cukup.',
                          ),
                        ),
                      );
                      return;
                    }

                    if (method == 'Transfer' && bankController.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Nama bank wajib diisi.'))); return; }
                    if (method == 'Bayar Tunda' && dueDate == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Tanggal jatuh tempo wajib dipilih.'))); return; }
                    Navigator.pop(context,{'method':method,'cash':method=='Tunai'?c:0,'change':method=='Tunai'?c-total:0,'bank':bankController.text.trim(),'account':accountController.text.trim(),'dueDate':dueDate});
                  },
                  child:
                      const Text('PROSES'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    try {
      final id = await DB.createSale(
        cashier: widget.cashier,
        customerName: customerNameController.text,
        customerPhone: customerPhoneController.text,
        customerType: customerType,
        items: cart,
        subtotal: subtotal,
        discount: discount,
        total: total,
        cash:
            result['cash'] as int,
        change:
            result['change'] as int,
        payment: result['method'] as String,
        transferBank: result['bank'] as String? ?? '',
        transferAccount: result['account'] as String? ?? '',
        dueDate: result['dueDate'] is DateTime ? (result['dueDate'] as DateTime).toIso8601String() : '',
      );

      // Transaksi sudah berhasil tersimpan.
      // Bunyi hanya dipicu setelah DB.createSale() sukses.
      try {
        await _successPlayer.play(
          AssetSource('audio/transaction_success_tiengdong.mp3'),
          volume: 0.70,
        );
      } catch (_) {
        // Audio gagal tidak boleh menggagalkan transaksi.
      }

      // Quote tidak memengaruhi perhitungan transaksi.
      try {
        final quote = await QuoteService.nextQuote();
        if (mounted) {
          widget.onTransactionSuccess?.call(quote);
        }
      } catch (_) {
        // Jika quote gagal ditampilkan, transaksi tetap dianggap berhasil.
      }

      final db = await DB.database;

      final rows = await db.query(
        'sales',
        where: 'id=?',
        whereArgs: [id],
        limit: 1,
      );

      if (!mounted) return;

      setState(() {
        cart.clear();
        discount = 0;
        customerNameController.clear();
        customerPhoneController.clear();
        customerType = 'Retail';
      });

      await load();

      if (rows.isNotEmpty) {
        final sale =
            SaleModel.fromMap(
          rows.first,
        );

        if (await printerAutoPrint()) {
          await printReceipt(sale);
        }

        await showDialog(
          context: context,
          builder: (_) =>
              AlertDialog(
            title: const Text(
              'Transaksi Berhasil',
            ),
            content: Text(
              '${sale.no}\n'
              'Total ${rp(sale.total)}',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(
                  context,
                ),
                child:
                    const Text('Tutup'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(
                    context,
                  );

                  await printReceipt(
                    sale,
                  );
                },
                child:
                    const Text('Cetak'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          duration:
              const Duration(
            seconds: 5,
          ),
          content: Text(
            'Transaksi gagal diproses:\n$e',
          ),
        ),
      );
    }
  }

  Future<void> showQris() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('qris_image');
    final merchant = prefs.getString('qris_merchant') ?? '';

    if (path == null || path.isEmpty || !File(path).existsSync()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QRIS belum diatur oleh Administrator.'),
        ),
      );
      return;
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.qr_code_2_rounded, color: red),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'QRIS Pembayaran',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                if (merchant.trim().isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      merchant,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: inkMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Flexible(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Image.file(
                      File(path),
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tutup'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accentSoft = AppColors.red.withValues(alpha: .12);
    final baseFiltered = category == 'Semua' ? products : products.where((p) => p.category == category).toList();
    final q = menuSearch.trim().toLowerCase();
    final filtered = q.isEmpty ? baseFiltered : baseFiltered.where((p) => p.name.toLowerCase().contains(q) || p.category.toLowerCase().contains(q)).toList();

    return LayoutBuilder(
      builder: (context, c) {
        final tablet = c.maxWidth >= 700;
        final columns = tablet ? 4 : 2;

        final productGrid = Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 7),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: menuSearchController,
                      onChanged: (v) => setState(() => menuSearch = v),
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Cari menu...', isDense: true, border: OutlineInputBorder()),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: showQris,
                    icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                    label: const Text('Tampilkan QRIS'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '${filtered.length} menu',
                    style: TextStyle(color: colors.onSurfaceVariant, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (_, i) {
                  final x = categories[i];
                  final selected = category == x;
                  return InkWell(
                    borderRadius: BorderRadius.circular(13),
                    onTap: () => setState(() => category = x),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? red : Colors.white,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: selected ? red : line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selected) ...[
                            const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            x,
                            style: TextStyle(
                              color: selected ? Colors.white : ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 7),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: tablet ? 1.55 : 1.32,
                ),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final p = filtered[i];
                  return Card(
                    color: colors.surface,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => add(p),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: accentSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.fastfood_rounded, size: 19, color: red),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              p.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              rp(p.price),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                            Text(
                              'Stok ${p.stock}',
                              style: TextStyle(
                                color: p.stock <= 0 ? red : Colors.green.shade700,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );

        final cartPanel = Card(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: AppColors.red.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark ? .90 : .72,
              ),
              width: 1.6,
            ),
          ),
          child: Column(
            children: [
              const ListTile(
                dense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
                leading: Icon(Icons.shopping_cart_rounded, color: red, size: 20),
                title: Text('Keranjang', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(contentPadding: EdgeInsets.zero,value: customerNameController.text.trim().isNotEmpty || customerPhoneController.text.trim().isNotEmpty,title: const Text('Data Pelanggan'),subtitle: const Text('Nama dan nomor HP'),onChanged: (_) => customerDialog()),
              TextField(
                controller: customerNameController,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Nama Pelanggan',
                        hintText: 'Pelanggan umum / nama pelanggan tetap',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: BorderSide(
                            color: colors.onSurfaceVariant.withValues(alpha: .42),
                            width: 1.2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(
                            color: AppColors.red,
                            width: 1.6,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: 3,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (_, i) {
                          const types = ['Retail', 'Online', 'Grosir/Reseller'];
                          final type = types[i];
                          final selected = customerType == type;
                          return ChoiceChip(
                            label: Text(type),
                            selected: selected,
                            onSelected: (_) => setState(() => customerType = type),
                            selectedColor: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.red.withValues(alpha: .22)
                                : redSoft,
                            labelStyle: TextStyle(
                              color: selected
                                  ? (Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : red)
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? AppColors.red
                                  : colors.onSurfaceVariant.withValues(alpha: .38),
                              width: selected ? 1.3 : 1.0,
                            ),
                            visualDensity: VisualDensity.compact,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: cart.isEmpty
                    ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.red.withValues(alpha: .15),
                                  AppColors.red.withValues(alpha: .035),
                                ],
                              ),
                              border: Border.all(
                                color: AppColors.red.withValues(alpha: .16),
                              ),
                            ),
                            child: Icon(
                              Icons.phone_iphone_rounded,
                              size: 38,
                              color: AppColors.red.withValues(alpha: .72),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Belum ada item',
                            style: TextStyle(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tambahkan produk untuk memulai transaksi',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: cart.length,
                        itemBuilder: (_, i) {
                          final line = cart[i];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                            title: Text(
                              line.product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            subtitle: Text(rp(line.product.price), style: const TextStyle(fontSize: 11)),
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: () => minus(line),
                                  icon: const Icon(Icons.remove_circle_outline, size: 21),
                                ),
                                Text('${line.qty}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: () => add(line.product),
                                  icon: const Icon(Icons.add_circle_outline, size: 21),
                                ),
                              ],
                            ),
                            trailing: Text(
                              rp(line.product.price * line.qty),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                            ),
                          );
                        },
                      ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: AppColors.red.withValues(alpha: .28),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal'), Text(rp(subtotal))]),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Diskon'), Text(rp(discount))]),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                        Text(rp(total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: red)),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: discountDialog,
                            icon: const Icon(Icons.sell_outlined, size: 17),
                            label: const Text('Diskon'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              side: const BorderSide(
                                color: AppColors.red,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              foregroundColor: AppColors.red,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: cart.isEmpty ? null : payment,
                            icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                            label: const Text(
                              'BAYAR',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              backgroundColor: AppColors.red,
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                color: AppColors.red,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        if (tablet) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(flex: 7, child: productGrid),
                const SizedBox(width: 10),
                Expanded(flex: 3, child: cartPanel),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Column(
            children: [
              Expanded(flex: 7, child: productGrid),
              SizedBox(
                height: cart.isEmpty ? 330 : 390,
                child: cartPanel,
              ),
            ],
          ),
        );
      },
    );
  }
}
