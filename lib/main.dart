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
        _weatherInfo = 'ไม่สามารถโหลดข้อมูล';
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
    }
  }

  Future<void> _saveProducts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String productData = jsonEncode(_products);
    await prefs.setString('products', productData);
  }

  void _addProduct(String name, int quantity, XFile? imageFile, [int? index]) {
    setState(() {
      final imagePath = imageFile?.path; // ใช้ path ของ XFile
      if (index != null) {
        _products[index] = {
          'name': name,
          'quantity': quantity,
          'image': imagePath, // เก็บเฉพาะ path
        };
      } else {
        _products.add({
          'name': name,
          'quantity': quantity,
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
            onAddProduct: (name, quantity, imageFile) {
              _addProduct(name, quantity, imageFile, index);
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
                title: Text(product['name']),
                subtitle: Text('จำนวน: ${product['quantity']}'),
                leading: product['image'] != null
                    ? Image.file(
                        File(product['image']),
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.image),
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

  Future<Widget> fetchWeather() async {
    const city = 'Nakhon Ratchasima'; // ชื่อเมือง
    const apikey = '6086f32e68c2465cb21204519242309'; // ใส่ API Key ที่ถูกต้อง

    final response = await http.get(Uri.parse(
      'https://api.weatherapi.com/v1/current.json?key=$apikey&q=$city&aqi=no',
    ));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Text(
        'นครราชสีมา อุณหภูมิ: ${data['current']['temp_c']} °C',
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold), // ปรับขนาดและสไตล์ที่นี่
      );
    } else {
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      throw Exception('ไม่สามารถโหลดข้อมูลได้');
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
      return product['name'].toLowerCase().contains(_searchQuery.toLowerCase());
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
                            product['image'] != null
                                ? Image.file(
                                    File(product['image']),
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(Icons.image, size: 80),
                            const SizedBox(height: 8),
                            Text(product['name'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text('จำนวน: ${product['quantity']}'),
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
  final Function(String, int, XFile?) onAddProduct;
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
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  XFile? _selectedImage;

  @override
  void initState() {
    super.initState();
    if (widget.existingProduct != null) {
      _nameController.text = widget.existingProduct!['name'];
      _quantityController.text = widget.existingProduct!['quantity'].toString();
      final imagePath = widget.existingProduct!['image'];
      if (imagePath != null) {
        _selectedImage = XFile(imagePath); // แปลง path กลับเป็น XFile
      }
    }
  }

  Future<void> _chooseImage(BuildContext context) async {
    final ImagePicker _picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera),
              title: const Text('ถ่ายรูป'),
              onTap: () async {
                final pickedFile =
                    await _picker.pickImage(source: ImageSource.camera);
                setState(() {
                  _selectedImage = pickedFile;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('เลือกจากแกลเลอรี่'),
              onTap: () async {
                final pickedFile =
                    await _picker.pickImage(source: ImageSource.gallery);
                setState(() {
                  _selectedImage = pickedFile;
                });
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _submit() {
    final name = _nameController.text;
    final quantity = int.tryParse(_quantityController.text) ?? 0;

    if (name.isEmpty || quantity <= 0) {
      return;
    }

    widget.onAddProduct(name, quantity, _selectedImage);
    Navigator.pop(context);
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
            decoration: const InputDecoration(labelText: 'ชื่อสินค้า'),
          ),
          TextField(
            controller: _quantityController,
            decoration: const InputDecoration(labelText: 'จำนวนสินค้า'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _chooseImage(context),
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
              ),
              child: _selectedImage != null
                  ? Image.file(
                      File(_selectedImage!.path),
                      fit: BoxFit.cover,
                    )
                  : const Center(child: Text('เลือกภาพ')),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submit,
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }
}
