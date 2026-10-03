class Product {
  final int id; final String name; final String category; final int price; final int stock; final bool active;
  Product({required this.id, required this.name, required this.category, required this.price, required this.stock, required this.active});
  factory Product.fromMap(Map<String,dynamic> m) => Product(id:m['id'] as int,name:m['name'] as String,category:m['category'] as String,price:m['price'] as int,stock:m['stock'] as int,active:m['active']==1);
}

class CartLine { final Product product; int qty; CartLine(this.product,this.qty); }

class SaleModel {
  final int id; final String no; final String time; final String cashier; final String customerName; final String customerPhone; final String customerType; final String transferBank; final String transferAccount; final String dueDate; final int subtotal; final int discount; final int total; final int cash; final int change; final String payment; final bool returned;
  SaleModel({required this.id,required this.no,required this.time,required this.cashier,required this.customerName,required this.customerPhone,required this.customerType,required this.transferBank,required this.transferAccount,required this.dueDate,required this.subtotal,required this.discount,required this.total,required this.cash,required this.change,required this.payment,required this.returned});
  factory SaleModel.fromMap(Map<String,dynamic> m)=>SaleModel(id:m['id'] as int,no:m['sale_no'] as String,time:m['sale_time'] as String,cashier:m['cashier'] as String,customerName:(m['customer_name'] ?? 'Pelanggan Umum').toString(),customerPhone:(m['customer_phone'] ?? '').toString(),customerType:(m['customer_type'] ?? 'Retail').toString(),transferBank:(m['transfer_bank'] ?? '').toString(),transferAccount:(m['transfer_account'] ?? '').toString(),dueDate:(m['due_date'] ?? '').toString(),subtotal:m['subtotal'] as int,discount:m['discount'] as int,total:m['total'] as int,cash:m['cash'] as int,change:m['change_amount'] as int,payment:m['payment'] as String,returned:m['returned']==1);
}
