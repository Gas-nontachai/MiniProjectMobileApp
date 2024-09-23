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
  String? _selectedCategory;
  final List<String> _categories = ['หมวดหมู่ 1', 'หมวดหมู่ 2', 'หมวดหมู่ 3'];
  bool _isDescendingOrder = true; // ควบคุมการเรียงลำดับ

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

  void _addProduct(String name, int quantity, String category, double costPrice,
      double sellingPrice, XFile? imageFile,
      [int? index]) {
    setState(() {
      final imagePath = imageFile?.path; // ใช้ path ของ XFile
      if (index != null) {
        _products[index] = {
          'name': name,
          'quantity': quantity,
          'category': category,
          'cost_price': costPrice,
          'selling_price': sellingPrice,
          'image': imagePath, // เก็บเฉพาะ path
        };
      } else {
        _products.add({
          'name': name,
          'quantity': quantity,
          'category': category,
          'cost_price': costPrice,
          'selling_price': sellingPrice,
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
                (name, quantity, category, costPrice, sellingPrice, imageFile) {
              _addProduct(name, quantity, category, costPrice, sellingPrice,
                  imageFile, index);
            },
            existingProduct: product,
            categories: _categories, // ส่งหมวดหมู่ไปยัง modal
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
                    ? GestureDetector(
                        onTap: () => _fullScreenImage(product['image']),
                        child: Image.file(
                          File(product['image']),
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
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

  void _fullScreenImage(String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImagePage(imagePath: imagePath),
      ),
    );
  }

  Future<String> fetchWeather() async {
    const city = 'Nakhon Ratchasima'; // ชื่อเมือง
    const apikey = '6086f32e68c2465cb21204519242309'; // ใส่ API Key ที่ถูกต้อง

    final response = await http.get(Uri.parse(
      'https://api.weatherapi.com/v1/current.json?key=$apikey&q=$city&aqi=no',
    ));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return 'นครราชสีมา อุณหภูมิ: ${data['current']['temp_c']} °C'; // อุณหภูมิเป็น °C
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

  void _toggleOrder() {
    setState(() {
      _isDescendingOrder = !_isDescendingOrder;
    });
  }

  @override
  Widget build(BuildContext context) {
    // กรองสินค้า
    final filteredProducts = _products.where((product) {
      bool matchesQuery =
          product['name'].toLowerCase().contains(_searchQuery.toLowerCase());
      bool matchesCategory =
          _selectedCategory == null || product['category'] == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();

    // เรียงลำดับตามราคาขาย
    if (_isDescendingOrder) {
      filteredProducts.sort((a, b) {
        double priceA = a['selling_price'] ?? 0; // ถ้าเป็น null ให้ใช้ 0
        double priceB = b['selling_price'] ?? 0; // ถ้าเป็น null ให้ใช้ 0
        return priceB.compareTo(priceA);
      });
    } else {
      filteredProducts.sort((a, b) {
        double priceA = a['selling_price'] ?? 0; // ถ้าเป็น null ให้ใช้ 0
        double priceB = b['selling_price'] ?? 0; // ถ้าเป็น null ให้ใช้ 0
        return priceA.compareTo(priceB);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('โปรแกรมเช็คสต็อก ($_weatherInfo)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _toggleOrder,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _selectedCategory = null; // รีเซ็ตหมวดหมู่
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'ค้นหาสินค้า'),
              onChanged: _updateSearchQuery,
            ),
            DropdownButton<String>(
              hint: const Text('เลือกหมวดหมู่'),
              value: _selectedCategory,
              items: _categories.map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategory = newValue;
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // จำนวนการ์ดในแต่ละแถว
                  childAspectRatio: 0.8, // อัตราส่วนความสูงและความกว้างของการ์ด
                  crossAxisSpacing: 8.0, // ระยะห่างระหว่างการ์ดในแนวนอน
                  mainAxisSpacing: 8.0, // ระยะห่างระหว่างการ์ดในแนวตั้ง
                ),
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  return GestureDetector(
                    onTap: () =>
                        _openProductModal(context, _products.indexOf(product)),
                    child: Card(
                      elevation: 4,
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            product['image'] != null
                                ? GestureDetector(
                                    onTap: () {
                                      _fullScreenImage(product['image']);
                                    },
                                    child: Image.file(
                                      File(product['image']),
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
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
                },
              ),
            ),
          ],
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
  final Function(String, int, String, double, double, XFile?) onAddProduct;
  final Map<String, dynamic>? existingProduct;
  final List<String> categories;

  const AddProductModal({
    Key? key,
    required this.onAddProduct,
    this.existingProduct,
    required this.categories,
  }) : super(key: key);

  @override
  _AddProductModalState createState() => _AddProductModalState();
}

class _AddProductModalState extends State<AddProductModal> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _sellingPriceController = TextEditingController();
  String? _selectedCategory;
  XFile? _imageFile;

  @override
  void initState() {
    super.initState();
    if (widget.existingProduct != null) {
      final product = widget.existingProduct!;
      _nameController.text = product['name'];
      _quantityController.text = product['quantity'].toString();
      _costPriceController.text = product['cost_price'].toString();
      _sellingPriceController.text = product['selling_price'].toString();
      _selectedCategory = product['category'];
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _imageFile = image;
    });
  }

  void _submit() {
    final name = _nameController.text;
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final category = _selectedCategory ?? 'หมวดหมู่ 1';
    final costPrice = double.tryParse(_costPriceController.text) ?? 0.0;
    final sellingPrice = double.tryParse(_sellingPriceController.text) ?? 0.0;

    if (name.isNotEmpty && quantity > 0) {
      widget.onAddProduct(
          name, quantity, category, costPrice, sellingPrice, _imageFile);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบถ้วน')),
      );
    }
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
            decoration: const InputDecoration(labelText: 'จำนวน'),
            keyboardType: TextInputType.number,
          ),
          DropdownButton<String>(
            hint: const Text('เลือกหมวดหมู่'),
            value: _selectedCategory,
            items: widget.categories.map((String category) {
              return DropdownMenuItem<String>(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedCategory = newValue;
              });
            },
          ),
          TextField(
            controller: _costPriceController,
            decoration: const InputDecoration(labelText: 'ราคาทุน'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: _sellingPriceController,
            decoration: const InputDecoration(labelText: 'ราคาขาย'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _pickImage,
            child: const Text('เลือกภาพสินค้า'),
          ),
          const SizedBox(height: 8),
          if (_imageFile != null)
            Image.file(
              File(_imageFile!.path),
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submit,
            child: const Text('บันทึกสินค้า'),
          ),
        ],
      ),
    );
  }
}

class FullScreenImagePage extends StatelessWidget {
  final String imagePath;

  const FullScreenImagePage({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ภาพเต็มจอ'),
      ),
      body: Center(
        child: Image.file(File(imagePath)),
      ),
    );
  }
}
