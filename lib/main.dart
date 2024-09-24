import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'โปรแกรมเช็คสต็อก',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const StockCheckScreen(),
    );
  }
}

class StockCheckScreen extends StatefulWidget {
  const StockCheckScreen({super.key});

  @override
  _StockCheckScreenState createState() => _StockCheckScreenState();
}

class _StockCheckScreenState extends State<StockCheckScreen> {
  final List<Map<String, dynamic>> _products = [];
  String _weatherInfo = 'กำลังโหลด...';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
    fetchWeather().then((value) {
      setState(() {
        _weatherInfo = value as String;
      });
    }).catchError((error) {
      setState(() {
        _weatherInfo = '\n ไม่สามารถโหลดข้อมูล';
      });
    });
  }

  Future<void> _loadProducts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? productData = prefs.getString('products');
    if (productData != null) {
      List<dynamic> loadedProducts = jsonDecode(productData);
      setState(() {
        _products.addAll(List<Map<String, dynamic>>.from(loadedProducts));
      });
    } else {
      print('ไม่พบข้อมูลสินค้า');
    }
  }

  Future<void> _saveProducts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String productData = jsonEncode(_products);
    await prefs.setString('products', productData);
  }

  void _addProduct(String name, int quantity, XFile? imageFile, String category,
      double costPrice, double sellingPrice,
      [int? index]) {
    setState(() {
      final imagePath = imageFile?.path ?? '';

      if (index != null) {
        _products[index] = {
          'name': name,
          'quantity': quantity,
          'category': category.isNotEmpty ? category : 'ประเภท 1',
          'costPrice': costPrice,
          'sellingPrice': sellingPrice,
          'image': imagePath.isNotEmpty ? imagePath : _products[index]['image'],
        };
      } else {
        _products.add({
          'name': name,
          'quantity': quantity,
          'category': category.isNotEmpty ? category : 'ประเภท 1',
          'costPrice': costPrice,
          'sellingPrice': sellingPrice,
          'image': imagePath,
        });
      }
      _saveProducts();
    });
  }

  void _openAddProductModal(BuildContext context, {int? index}) {
    final product = index != null ? _products[index] : null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: AddProductModal(
            onAddProduct:
                (name, quantity, imageFile, category, costPrice, sellingPrice) {
              _addProduct(name, quantity, imageFile, category, costPrice,
                  sellingPrice, index);
            },
            existingProduct: product,
          ),
        );
      },
    );
  }

  void _deleteProduct(int index) {
    setState(() {
      _products.removeAt(index);
      _saveProducts();
    });
  }

  void _openProductModal(BuildContext context, int index) {
    final product = _products[index];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(product['name'] ?? 'ไม่ระบุชื่อสินค้า'),
                leading: product['image'] != null && product['image'].isNotEmpty
                    ? Image.file(
                        File(product['image']),
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.image),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('จำนวน: ${product['quantity']} ชิ้น'),
                    Text(
                        'ราคาทุน: ${product['costPrice']?.toStringAsFixed(2) ?? '0.00'} ฿'),
                    Text(
                        'ราคาขาย: ${product['sellingPrice']?.toStringAsFixed(2) ?? '0.00'} ฿'),
                    Text(
                        'กำไร: ${(product['sellingPrice'] ?? 0) - (product['costPrice'] ?? 0)} ฿'),
                    Text(
                        'หมวดหมู่: ${product['category'] ?? 'ไม่ระบุหมวดหมู่'}'),
                  ],
                ),
              ),
              const Divider(),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _openAddProductModal(context, index: index);
                },
                child: const Text('แก้ไข'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteProduct(index);
                },
                child: const Text('ลบ'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String> fetchWeather() async {
    const city = 'Nakhon Ratchasima';
    const apikey = 'a0d63355b66540d793c104957242409';

    final response = await http.get(Uri.parse(
      'http://api.weatherapi.com/v1/current.json?key=$apikey&q=$city&aqi=no',
    ));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return '\n นครราชสีมา อุณหภูมิ: ${data['current']['temp_c']} °C';
    } else {
      return 'ไม่สามารถโหลดข้อมูลสภาพอากาศ';
    }
  }

  void _updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _products.where((product) {
      return product['name']
              ?.toLowerCase()
              .contains(_searchQuery.toLowerCase()) ??
          false;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('โปรแกรมเช็คสต็อก ($_weatherInfo)'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'ค้นหาสินค้า...',
                border: OutlineInputBorder(),
              ),
              onChanged: _updateSearchQuery,
            ),
          ),
        ),
      ),
      body: filteredProducts.isEmpty
          ? const Center(child: Text('ยังไม่มีข้อมูลสต็อก'))
          : SingleChildScrollView(
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: filteredProducts.map((product) {
                  int index = _products.indexOf(product);
                  return GestureDetector(
                    onTap: () => _openProductModal(context, index),
                    child: Card(
                      elevation: 4,
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.45,
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            product['image'] != null &&
                                    product['image'].isNotEmpty
                                ? Image.file(
                                    File(product['image']),
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(Icons.image, size: 80),
                            const SizedBox(height: 8),
                            Text(product['name'] ?? 'ไม่ระบุชื่อสินค้า',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(
                              'จำนวน: ${product['quantity']} ชิ้น',
                              style: const TextStyle(
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddProductModal(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddProductModal extends StatefulWidget {
  final Function(String, int, XFile?, String, double, double) onAddProduct;
  final Map<String, dynamic>? existingProduct;

  const AddProductModal({
    super.key,
    required this.onAddProduct,
    this.existingProduct,
  });

  @override
  _AddProductModalState createState() => _AddProductModalState();
}

class _AddProductModalState extends State<AddProductModal> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _sellingPriceController = TextEditingController();
  XFile? _imageFile;
  // เพิ่มรายการหมวดหมู่ที่เป็นไปได้
  final List<String> _categories = ['หมวดหมู่ 1', 'หมวดหมู่ 2', 'หมวดหมู่ 3'];
  String? _selectedCategory; // ตัวแปรสำหรับเก็บหมวดหมู่ที่เลือก
  @override
  void initState() {
    super.initState();
    if (widget.existingProduct != null) {
      _nameController.text = widget.existingProduct!['name'];
      _quantityController.text = widget.existingProduct!['quantity'].toString();
      _selectedCategory =
          widget.existingProduct!['category']; // กำหนดหมวดหมู่ที่เลือก
      _costPriceController.text =
          widget.existingProduct!['costPrice'].toString();
      _sellingPriceController.text =
          widget.existingProduct!['sellingPrice'].toString();
      _imageFile = widget.existingProduct!['image'] != null &&
              widget.existingProduct!['image'].isNotEmpty
          ? XFile(widget.existingProduct!['image'])
          : null;
    }
  }

  Future<void> _chooseImage() async {
    final picker = ImagePicker();
    final pickedFile = await showDialog<XFile>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('เลือกแหล่งที่มาของภาพ'),
          actions: [
            TextButton(
              child: const Text('กล้อง'),
              onPressed: () async {
                Navigator.pop(context,
                    await picker.pickImage(source: ImageSource.camera));
              },
            ),
            TextButton(
              child: const Text('แกลเลอรี่'),
              onPressed: () async {
                Navigator.pop(context,
                    await picker.pickImage(source: ImageSource.gallery));
              },
            ),
            TextButton(
              child: const Text('ยกเลิก'),
              onPressed: () {
                Navigator.pop(context, null);
              },
            ),
          ],
        );
      },
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
      });
    }
  }

  void _addProduct() {
    final name = _nameController.text.trim();
    final quantity = int.tryParse(_quantityController.text.trim()) ?? -1;
    final costPrice = double.tryParse(_costPriceController.text.trim()) ?? -1;
    final sellingPrice =
        double.tryParse(_sellingPriceController.text.trim()) ?? -1;

    // ตรวจสอบค่าที่ว่าง
    if (name.isEmpty) {
      _showAlertDialog('กรุณากรอกชื่อสินค้า');
      return;
    }

    if (quantity < 0) {
      _showAlertDialog('กรุณากรอกจำนวนสินค้าให้ถูกต้อง');
      return;
    }

    if (costPrice < 0) {
      _showAlertDialog('กรุณากรอกราคาทุนให้ถูกต้อง');
      return;
    }

    if (sellingPrice < 0) {
      _showAlertDialog('กรุณากรอกราคาขายให้ถูกต้อง');
      return;
    }

    // ตรวจสอบว่าราคาขายต้องมากกว่าราคาทุน
    if (sellingPrice < costPrice) {
      _showAlertDialog('ราคาขายต้องมากกว่าราคาทุน');
      return;
    }

    final category = _selectedCategory ?? 'ไม่ระบุหมวดหมู่';

    widget.onAddProduct(
        name, quantity, _imageFile, category, costPrice, sellingPrice);
    Navigator.pop(context);
  }

  void _showAlertDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ข้อผิดพลาด'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // ปิด AlertDialog
              },
              child: const Text('ตกลง'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'ชื่อสินค้า'),
          ),
          TextField(
            controller: _quantityController,
            decoration: const InputDecoration(hintText: 'จำนวนสินค้า'),
            keyboardType: TextInputType.number,
          ),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: const InputDecoration(hintText: 'หมวดหมู่'),
            items: _categories.map((String category) {
              return DropdownMenuItem<String>(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedCategory = newValue; // อัพเดทหมวดหมู่ที่เลือก
              });
            },
          ),
          TextField(
            controller: _costPriceController,
            decoration: const InputDecoration(hintText: 'ราคาทุน'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: _sellingPriceController,
            decoration: const InputDecoration(hintText: 'ราคาขาย'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _chooseImage,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
              ),
              height: 100,
              width: double.infinity,
              child: _imageFile != null
                  ? Image.file(
                      File(_imageFile!.path),
                      fit: BoxFit.cover,
                    )
                  : const Center(child: Text('เลือกภาพ')),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _addProduct,
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }
}
