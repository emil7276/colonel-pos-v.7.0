#!/usr/bin/env python3
from pathlib import Path
import argparse

R=Path(__file__).resolve().parent
F={
'db':R/'app/lib/data/database.dart',
'models':R/'app/lib/models/models.dart',
'pos':R/'app/lib/features/pos/pos_page.dart',
'finance':R/'app/lib/features/settings/finance_page.dart',
'report':R/'app/lib/features/reports/report_page.dart',
'workflow':R/'.github/workflows/build.yml'}

def rep(s,a,b,n):
    if a not in s: raise RuntimeError(n)
    return s.replace(a,b,1)

def db(s):
    s=rep(s,"version: 3,","version: 4,","db version")
    s=rep(s,"returned INTEGER NOT NULL DEFAULT 0\n          )","returned INTEGER NOT NULL DEFAULT 0,\n            customer_phone TEXT NOT NULL DEFAULT '',\n            transfer_bank TEXT NOT NULL DEFAULT '',\n            transfer_account TEXT NOT NULL DEFAULT '',\n            due_date TEXT NOT NULL DEFAULT ''\n          )","sales schema")
    up="""        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE expenses(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              expense_date TEXT NOT NULL,
              category TEXT NOT NULL,
              note TEXT NOT NULL,
              amount INTEGER NOT NULL
            )
          ''');
        }"""
    add=up+"""
        if (oldVersion < 4) {
          await db.execute("ALTER TABLE sales ADD COLUMN customer_phone TEXT NOT NULL DEFAULT ''");
          await db.execute("ALTER TABLE sales ADD COLUMN transfer_bank TEXT NOT NULL DEFAULT ''");
          await db.execute("ALTER TABLE sales ADD COLUMN transfer_account TEXT NOT NULL DEFAULT ''");
          await db.execute("ALTER TABLE sales ADD COLUMN due_date TEXT NOT NULL DEFAULT ''");
          await db.execute("ALTER TABLE expenses ADD COLUMN payment_status TEXT NOT NULL DEFAULT 'Sudah Dibayar'");
          await db.execute("ALTER TABLE expenses ADD COLUMN due_date TEXT NOT NULL DEFAULT ''");
        }"""
    s=rep(s,up,add,"upgrade")
    s=rep(s,"required String customerName,\n    required String customerType,","required String customerName,\n    required String customerPhone,\n    required String customerType,","createSale phone")
    s=rep(s,"required int change,\n    required String payment,\n  }) async {","required int change,\n    required String payment,\n    String transferBank = '',\n    String transferAccount = '',\n    String dueDate = '',\n  }) async {","createSale extra")
    s=rep(s,"'customer_name': customerName.trim().isEmpty ? 'Pelanggan Umum' : customerName.trim(),\n          'customer_type': customerType,","'customer_name': customerName.trim().isEmpty ? 'Pelanggan Umum' : customerName.trim(),\n          'customer_phone': customerPhone.trim(),\n          'customer_type': customerType,","sale customer")
    s=rep(s,"'payment': payment,\n          'returned': 0,","'payment': payment,\n          'transfer_bank': transferBank.trim(),\n          'transfer_account': transferAccount.trim(),\n          'due_date': dueDate.trim(),\n          'returned': 0,","sale payment")
    s=s.replace("AND returned=0\n      )","AND returned=0\n          AND payment != 'Bayar Tunda'\n      )")
    s=s.replace("AND returned=0\n      GROUP BY","AND returned=0\n        AND payment != 'Bayar Tunda'\n      GROUP BY")
    s=s.replace("AND returned=0\n      '''","AND returned=0\n        AND payment != 'Bayar Tunda'\n      '''")
    s=s.replace("AND s.returned=0'","AND s.returned=0 AND s.payment != 'Bayar Tunda'")
    s=s.replace("'omzet': valid.fold<int>(0, (sum, x) => sum + (x['total'] as num).toInt()), 'transaksi': valid.length,","'omzet': valid.where((x) => x['payment'] != 'Bayar Tunda').fold<int>(0, (sum, x) => sum + (x['total'] as num).toInt()), 'transaksi': valid.where((x) => x['payment'] != 'Bayar Tunda').length,")
    # Add expense fields to onCreate (only the expenses CREATE block).
    s=rep(s,"note TEXT NOT NULL,\n            amount INTEGER NOT NULL\n          )\n        ''');","note TEXT NOT NULL,\n            amount INTEGER NOT NULL,\n            payment_status TEXT NOT NULL DEFAULT 'Sudah Dibayar',\n            due_date TEXT NOT NULL DEFAULT ''\n          )\n        ''');","expense schema")
    marker="  static Future<void> saveExpense({"
    debt="""  static Future<int> expenseDebtTotal(DateTime from, DateTime to) async {
    final db = await database;
    final rows = await db.rawQuery("SELECT COALESCE(SUM(amount),0) total FROM expenses WHERE expense_date >= ? AND expense_date < ? AND payment_status='Jatuh Tempo'", [_dbDate(from), _dbDate(to)]);
    return (rows.first['total'] as num).toInt();
  }

"""
    s=rep(s,marker,debt+marker,"debt method")
    s=rep(s,"required String note,\n    required int amount,\n  }) async {","required String note,\n    required int amount,\n    String paymentStatus = 'Sudah Dibayar',\n    DateTime? dueDate,\n  }) async {","expense args")
    s=rep(s,"'note': note.trim(),\n      'amount': amount,","'note': note.trim(),\n      'amount': amount,\n      'payment_status': paymentStatus,\n      'due_date': paymentStatus == 'Jatuh Tempo' && dueDate != null ? _dbDate(dueDate) : '',","expense data")
    s=s.replace("'version': '6.5.0'","'version': '7.0.0'",1)
    return s

def models(s):
    s=rep(s,"final String customerName; final String customerType;","final String customerName; final String customerPhone; final String customerType; final String transferBank; final String transferAccount; final String dueDate;","model fields")
    s=rep(s,"required this.customerName,required this.customerType,","required this.customerName,required this.customerPhone,required this.customerType,required this.transferBank,required this.transferAccount,required this.dueDate,","model ctor")
    s=rep(s,"customerName:(m['customer_name'] ?? 'Pelanggan Umum').toString(),customerType:","customerName:(m['customer_name'] ?? 'Pelanggan Umum').toString(),customerPhone:(m['customer_phone'] ?? '').toString(),customerType:","model phone")
    s=rep(s,"customerType:(m['customer_type'] ?? 'Retail').toString(),subtotal:","customerType:(m['customer_type'] ?? 'Retail').toString(),transferBank:(m['transfer_bank'] ?? '').toString(),transferAccount:(m['transfer_account'] ?? '').toString(),dueDate:(m['due_date'] ?? '').toString(),subtotal:","model transfer")
    return s

def pos(s):
    s=rep(s,"final TextEditingController customerNameController = TextEditingController();","final TextEditingController customerNameController = TextEditingController();\n  final TextEditingController customerPhoneController = TextEditingController();\n  final TextEditingController menuSearchController = TextEditingController();\n  String menuSearch = '';","pos state")
    s=rep(s,"customerNameController.dispose();","customerNameController.dispose();\n    customerPhoneController.dispose();\n    menuSearchController.dispose();","pos dispose")
    s=rep(s,"final filtered = category == 'Semua'\n        ? products\n        : products.where((p) => p.category == category).toList();","final baseFiltered = category == 'Semua' ? products : products.where((p) => p.category == category).toList();\n    final q = menuSearch.trim().toLowerCase();\n    final filtered = q.isEmpty ? baseFiltered : baseFiltered.where((p) => p.name.toLowerCase().contains(q) || p.category.toLowerCase().contains(q)).toList();","pos filter")
    old="""                  const Expanded(
                    child: Text(
                      'Transaksi',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                    ),
                  ),"""
    new="""                  Expanded(
                    child: TextField(
                      controller: menuSearchController,
                      onChanged: (v) => setState(() => menuSearch = v),
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Cari menu...', isDense: true, border: OutlineInputBorder()),
                    ),
                  ),"""
    s=rep(s,old,new,"pos header")
    s=rep(s,"TextField(\n                      controller: customerNameController,","CheckboxListTile(contentPadding: EdgeInsets.zero,value: customerNameController.text.trim().isNotEmpty || customerPhoneController.text.trim().isNotEmpty,title: const Text('Data Pelanggan'),subtitle: const Text('Nama dan nomor HP'),onChanged: (_) => customerDialog()),\n              TextField(\n                controller: customerNameController,","customer checkbox")
    marker="  Future<void> payment() async {"
    dialog="""  Future<void> customerDialog() async {
    final n=TextEditingController(text:customerNameController.text);
    final p=TextEditingController(text:customerPhoneController.text);
    final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('Data Pelanggan'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:n,decoration:const InputDecoration(labelText:'Nama Pelanggan')),TextField(controller:p,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Nomor HP'))]),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Batal')),FilledButton(onPressed:(){customerNameController.text=n.text.trim();customerPhoneController.text=p.text.trim();Navigator.pop(context,true);},child:const Text('Simpan'))]));
    n.dispose();p.dispose();if(ok==true&&mounted)setState((){});
  }

"""
    s=rep(s,marker,dialog+marker,"customer dialog")
    s=rep(s,"String method = 'Tunai';","String method = 'Tunai';\n    final bankController=TextEditingController();\n    final accountController=TextEditingController();\n    DateTime? dueDate;","payment state")
    s=rep(s,"'Tunai',\n                          'QRIS',\n                          'Transfer',\n                          'Wallet (Platform)',","'Tunai',\n                          'Transfer',\n                          'Bayar Tunda',","payment methods")
    ins="""                  if (method == 'Transfer') ...[
                    const SizedBox(height:10),
                    TextField(controller:bankController,decoration:const InputDecoration(labelText:'Nama Bank *')),
                    TextField(controller:accountController,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Nomor Rekening (opsional)')),
                  ],
                  if (method == 'Bayar Tunda') ...[
                    const SizedBox(height:10),
                    ListTile(contentPadding:EdgeInsets.zero,title:const Text('Tanggal Jatuh Tempo'),subtitle:Text(dueDate==null?'Pilih tanggal':displayDate(dueDate!)),onTap:()async{final d=await showDatePicker(context:context,initialDate:DateTime.now(),firstDate:DateTime.now(),lastDate:DateTime(2100));if(d!=null)setDialog(()=>dueDate=d);}),
                  ],
"""
    s=rep(s,"                  if (method ==\n                      'Tunai') ...[",ins+"                  if (method ==\n                      'Tunai') ...[","payment ui")
    s=rep(s,"""                    Navigator.pop(
                      context,
                      {
                        'method': method,
                        'cash':
                            method ==
                                    'Tunai'
                                ? c
                                : total,
                        'change':
                            method ==
                                    'Tunai'
                                ? c - total
                                : 0,
                      },
                    );""","""                    if (method == 'Transfer' && bankController.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Nama bank wajib diisi.'))); return; }
                    if (method == 'Bayar Tunda' && dueDate == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Tanggal jatuh tempo wajib dipilih.'))); return; }
                    Navigator.pop(context,{'method':method,'cash':method=='Tunai'?c:0,'change':method=='Tunai'?c-total:0,'bank':bankController.text.trim(),'account':accountController.text.trim(),'dueDate':dueDate});""","payment result")
    s=rep(s,"customerName: customerNameController.text,\n        customerType: customerType,","customerName: customerNameController.text,\n        customerPhone: customerPhoneController.text,\n        customerType: customerType,","sale call phone")
    s=rep(s,"payment:\n            result['method'] as String,\n      );","payment: result['method'] as String,\n        transferBank: result['bank'] as String? ?? '',\n        transferAccount: result['account'] as String? ?? '',\n        dueDate: result['dueDate'] is DateTime ? (result['dueDate'] as DateTime).toIso8601String() : '',\n      );","sale call fields")
    s=s.replace("customerNameController.clear();\n        customerType = 'Retail';","customerNameController.clear();\n        customerPhoneController.clear();\n        customerType = 'Retail';",1)
    return s

def finance(s):
    s=rep(s,"int income = 0;\n  int expense = 0;","int income = 0;\n  int expense = 0;\n  int debt = 0;","finance state")
    s=rep(s,"DB.expenseTotal(from, to),\n      DB.expenses(from, to),","DB.expenseTotal(from, to),\n      DB.expenseDebtTotal(from, to),\n      DB.expenses(from, to),","finance query")
    s=rep(s,"expense = results[1] as int;\n      expenseRows =\n          results[2] as List<Map<String, dynamic>>;","expense = results[1] as int;\n      debt = results[2] as int;\n      expenseRows = results[3] as List<Map<String, dynamic>>;","finance values")
    s=rep(s,"final amount = TextEditingController(\n      text: item?['amount']?.toString() ?? '',\n    );","final amount = TextEditingController(text: item?['amount']?.toString() ?? '');\n    String paymentStatus = item?['payment_status']?.toString() ?? 'Sudah Dibayar';","finance dialog")
    s=rep(s,"const SizedBox(height: 8),\n                    ListTile(","DropdownButtonFormField<String>(value:paymentStatus,decoration:const InputDecoration(labelText:'Status Pembayaran'),items:const [DropdownMenuItem(value:'Sudah Dibayar',child:Text('Sudah Dibayar')),DropdownMenuItem(value:'Jatuh Tempo',child:Text('Jatuh Tempo'))],onChanged:(v){if(v!=null)setDialogState(()=>paymentStatus=v);}),\n                    const SizedBox(height: 8),\n                    ListTile(","finance status")
    s=rep(s,"amount: nominal ?? 0,\n                      );","amount: nominal ?? 0,\n                        paymentStatus: paymentStatus,\n                        dueDate: paymentStatus == 'Jatuh Tempo' ? date : null,\n                      );","finance save")
    s=rep(s,"final net = income - expense;","final net = income - (expense - debt);","finance net")
    return s

def report(s):
    s=rep(s,"DateTime selectedDate = DateTime.now();","DateTime selectedDate = DateTime.now();\n  DateTime? selectedEndDate;","report state")
    s=rep(s,"DateTime get start => DateTime(selectedDate.year, selectedDate.month, selectedDate.day);\n  DateTime get end => start.add(const Duration(days: 1));","DateTime get start => DateTime(selectedDate.year, selectedDate.month, selectedDate.day);\n  DateTime get end => selectedEndDate == null ? start.add(const Duration(days: 1)) : DateTime(selectedEndDate!.year,selectedEndDate!.month,selectedEndDate!.day).add(const Duration(days:1));","report range")
    old="""Future<void> pickDate() async {
    final d=await showDatePicker(context:context,initialDate:selectedDate,firstDate:DateTime(2020),lastDate:DateTime.now());
    if(d!=null){setState(()=>selectedDate=d); await load();}
  }"""
    new="""Future<void> pickDate() async {
    final r=await showDateRangePicker(context:context,firstDate:DateTime(2020),lastDate:DateTime.now(),initialDateRange:DateTimeRange(start:selectedDate,end:selectedEndDate??selectedDate));
    if(r!=null){setState((){selectedDate=r.start;selectedEndDate=r.end;});await load();}
  }"""
    s=rep(s,old,new,"report picker")
    s=s.replace("const Text('Laporan Harian',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900)),Text(displayDate(selectedDate),","const Text('Laporan',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900)),Text('${displayDate(start)} - ${displayDate(end.subtract(const Duration(days:1)))}',",1)
    s=s.replace("label:const Text('Pilih tanggal')","label:const Text('Pilih rentang tanggal')",1)
    return s

def workflow(s):
    return s.replace("name: CP Colonel POS 6.5","name: CP POS V.7.0").replace("CP-COLONEL-POS-6.5-NEW-UI-DARK-MODE.apk","CP POS V.7.0.apk")

FUN={'db':db,'models':models,'pos':pos,'finance':finance,'report':report,'workflow':workflow}

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--check',action='store_true'); a=ap.parse_args()
    out={}
    try:
        for k,fn in FUN.items(): out[k]=fn(F[k].read_text(encoding='utf-8'))
    except Exception as e:
        print("CHECK FAILED:",e); raise SystemExit(2)
    if a.check:
        print("CHECK OK: all v7 patterns matched.")
        return
    for k,v in out.items(): F[k].write_text(v,encoding='utf-8')
    print("PATCH APPLIED to v7 repo only.")
main()
