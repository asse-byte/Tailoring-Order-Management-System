import 'package:flutter/material.dart';
import '../../../../core/data/mock_database.dart';
import '../../../../core/theme/app_colors.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Map<String, dynamic>> _products = [];
  String _searchQuery = '';
  String _selectedCategory = 'all';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    final p = await MockDatabase.instance.getProducts();
    setState(() {
      _products = p;
      _loading = false;
    });
  }

  Future<void> _addProduct() async {
    final formKey = GlobalKey<FormState>();
    String name = '';
    String category = 'perfume';
    double price = 0.0;
    int quantity = 0;
    String description = '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Nouveau Produit / New Product'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Nom / Name'),
                    validator: (v) => v == null || v.isEmpty ? 'Requis / Required' : null,
                    onSaved: (v) => name = v ?? '',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Catégorie'),
                    items: const [
                      DropdownMenuItem(value: 'perfume', child: Text('العطور / Parfums')),
                      DropdownMenuItem(value: 'shoes', child: Text('الأحذية / Chaussures')),
                      DropdownMenuItem(value: 'fabric', child: Text('الأقمشة / Tissus')),
                      DropdownMenuItem(value: 'cap', child: Text('القلنسوة / Bonnets')),
                    ],
                    onChanged: (v) => setDlgState(() => category = v ?? 'perfume'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Prix / Price (CFA)'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || double.tryParse(v) == null ? 'Prix invalide' : null,
                    onSaved: (v) => price = double.tryParse(v ?? '') ?? 0.0,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Quantité / Quantity'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || int.tryParse(v) == null ? 'Quantité invalide' : null,
                    onSaved: (v) => quantity = int.tryParse(v ?? '') ?? 0,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Description'),
                    onSaved: (v) => description = v ?? '',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler / Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  final newP = {
                    'id': 'prod_${DateTime.now().millisecondsSinceEpoch}',
                    'name': name,
                    'category': category,
                    'price': price,
                    'quantity': quantity,
                    'description': description,
                    'imageUrl': 'https://images.unsplash.com/photo-1584184924103-e310d9dc82fc?w=300', // fallback
                  };
                  await MockDatabase.instance.saveProduct(newP);
                  Navigator.pop(ctx);
                  _loadProducts();
                }
              },
              child: const Text('Enregistrer / Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _products.where((p) {
      final matchesSearch = p['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p['description'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'all' || p['category'] == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produits / Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadProducts,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search & Filter header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Rechercher / Search...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _selectedCategory,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.filter_alt_rounded, color: AppColors.primary),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Tout')),
                          DropdownMenuItem(value: 'perfume', child: Text('Parfums')),
                          DropdownMenuItem(value: 'shoes', child: Text('Chaussures')),
                          DropdownMenuItem(value: 'fabric', child: Text('Tissus')),
                          DropdownMenuItem(value: 'cap', child: Text('Bonnets')),
                        ],
                        onChanged: (v) => setState(() => _selectedCategory = v ?? 'all'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('Aucun produit trouvé / No products found'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final p = filtered[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withOpacity(0.1),
                                  child: Icon(
                                    p['category'] == 'perfume'
                                        ? Icons.spa_rounded
                                        : p['category'] == 'shoes'
                                            ? Icons.shopping_bag_rounded // fallback
                                            : p['category'] == 'fabric'
                                                ? Icons.texture_rounded
                                                : Icons.store_rounded,
                                    color: AppColors.primary,
                                  ),
                                ),
                                title: Text(
                                  p['name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text('${p['description']}\nStock: ${p['quantity']}'),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${p['price']} CFA',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                      onPressed: () async {
                                        await MockDatabase.instance.deleteProduct(p['id']);
                                        _loadProducts();
                                      },
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProduct,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
