import 'package:flutter/material.dart';
import '../../../../core/data/mock_database.dart';
import '../../../../core/theme/app_colors.dart';

class ReadyToWearScreen extends StatefulWidget {
  const ReadyToWearScreen({super.key});

  @override
  State<ReadyToWearScreen> createState() => _ReadyToWearScreenState();
}

class _ReadyToWearScreenState extends State<ReadyToWearScreen> {
  List<Map<String, dynamic>> _models = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() => _loading = true);
    final m = await MockDatabase.instance.getRtw();
    setState(() {
      _models = m;
      _loading = false;
    });
  }

  Future<void> _addOrEditModel([Map<String, dynamic>? existing]) async {
    final formKey = GlobalKey<FormState>();
    String title = existing?['title'] ?? '';
    String fabric = existing?['fabric'] ?? '';
    double price = (existing?['price'] as num?)?.toDouble() ?? 85000.0;
    String description = existing?['description'] ?? '';
    String imageUrl = existing?['imageUrl'] ?? 'https://images.unsplash.com/photo-1595777457583-95e059d581b8?w=300';
    String videoUrl = existing?['videoUrl'] ?? 'https://www.w3schools.com/html/mov_bbb.mp4';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(existing == null ? 'Nouveau Modèle / New Model' : 'Modifier Modèle / Edit Model'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: title,
                  decoration: const InputDecoration(labelText: 'Titre / Name'),
                  validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                  onSaved: (v) => title = v ?? '',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: fabric,
                  decoration: const InputDecoration(labelText: 'Type de tissu / Fabric Type'),
                  validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                  onSaved: (v) => fabric = v ?? '',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: price.toString(),
                  decoration: const InputDecoration(labelText: 'Prix / Price (CFA)'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || double.tryParse(v) == null ? 'Invalide' : null,
                  onSaved: (v) => price = double.tryParse(v ?? '') ?? 0.0,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: description,
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
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                final model = {
                  'id': existing?['id'] ?? 'rtw_${DateTime.now().millisecondsSinceEpoch}',
                  'title': title,
                  'fabric': fabric,
                  'price': price,
                  'description': description,
                  'imageUrl': imageUrl,
                  'videoUrl': videoUrl,
                };
                await MockDatabase.instance.saveRtwItem(model);
                Navigator.pop(ctx);
                _loadModels();
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _viewModelDetails(Map<String, dynamic> m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            // Model Image
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                m['imageUrl'],
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 250,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image_rounded, size: 50),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  m['title'],
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${m['price']} CFA',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Chip(
              avatar: const Icon(Icons.texture_rounded, size: 16),
              label: Text('Tissu: ${m['fabric']}'),
            ),
            const SizedBox(height: 12),
            Text(
              m['description'] ?? 'Aucune description fournie / No description.',
              style: TextStyle(fontSize: 16, color: Colors.grey[800], height: 1.4),
            ),
            const SizedBox(height: 24),
            const Text(
              'Référence Vidéo / Video Preview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // Mock Video Player Card
            Card(
              color: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Container(
                height: 150,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 50),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lecture de la vidéo / Playing video preview...')),
                        );
                      },
                    ),
                    const Text('Lire la vidéo / Play video', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prêt-à-porter / Ready-To-Wear'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadModels,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: _models.length,
              itemBuilder: (context, index) {
                final m = _models[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _viewModelDetails(m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                m['imageUrl'],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(color: Colors.grey[200]),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${m['price']} CFA',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m['title'],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m['fabric'],
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 18),
                                    onPressed: () => _addOrEditModel(m),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                                    onPressed: () async {
                                      await MockDatabase.instance.deleteRtwItem(m['id']);
                                      _loadModels();
                                    },
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditModel(),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
