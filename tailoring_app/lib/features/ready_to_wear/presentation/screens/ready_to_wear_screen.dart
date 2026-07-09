import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/pret_a_porter_repository.dart';
import '../../../settings/presentation/providers/shop_settings_provider.dart';

class ReadyToWearScreen extends StatefulWidget {
  const ReadyToWearScreen({super.key});

  @override
  State<ReadyToWearScreen> createState() => _ReadyToWearScreenState();
}

class _ReadyToWearScreenState extends State<ReadyToWearScreen> {
  final PretAPorterRepository _repo = PretAPorterRepository();
  List<PretAPorterModel> _models = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.list();
      setState(() {
        _models = items;
      });
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _recordSale(PretAPorterModel model) async {
    final formKey = GlobalKey<FormState>();
    int qty = 1;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Vendre Modèle - ${model.name}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            decoration: const InputDecoration(
              labelText: 'Quantité à vendre',
              suffixText: 'unités',
            ),
            keyboardType: TextInputType.number,
            initialValue: '1',
            validator: (v) {
              final val = int.tryParse(v ?? '');
              if (val == null || val < 1) return 'Quantité invalide';
              return null;
            },
            onSaved: (v) => qty = int.tryParse(v ?? '') ?? 1,
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
                Navigator.pop(ctx);
                try {
                  setState(() => _loading = true);
                  await _repo.sellModel(modelId: model.id, quantity: qty);
                  setState(() => _loading = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vente de prêt-à-porter enregistrée avec succès !'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  setState(() => _loading = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _addOrEditModel([PretAPorterModel? existing]) async {
    final formKey = GlobalKey<FormState>();
    String name = existing?.name ?? '';
    String fabric = existing?.fabricType ?? '';
    double price = existing?.price ?? 45000.0;
    double costPrice = existing?.costPrice ?? 0.0;
    String description = existing?.description ?? '';

    final List<Map<String, String>> currentMedia = existing != null
        ? existing.media.map((e) => {'id': e.id, 'url': e.url, 'kind': e.kind, 'thumb_url': e.thumbUrl ?? ''}).toList()
        : [];

    bool uploading = false;
    final ImagePicker picker = ImagePicker();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(existing == null ? 'Nouveau Modèle' : 'Modifier Modèle'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: name,
                    decoration: const InputDecoration(labelText: 'Nom du modèle'),
                    validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                    onSaved: (v) => name = v ?? '',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: fabric,
                    decoration: const InputDecoration(labelText: 'Tissu'),
                    validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                    onSaved: (v) => fabric = v ?? '',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: price > 0 ? price.toInt().toString() : '',
                    decoration: const InputDecoration(labelText: 'Prix de vente (FCFA)'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || double.tryParse(v) == null ? 'Invalide' : null,
                    onChanged: (v) => setDlgState(() => price = double.tryParse(v) ?? 0.0),
                    onSaved: (v) => price = double.tryParse(v ?? '') ?? 0.0,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: costPrice > 0 ? costPrice.toInt().toString() : '',
                    decoration: const InputDecoration(labelText: 'Prix d\'achat (FCFA)'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || double.tryParse(v) == null ? 'Invalide' : null,
                    onChanged: (v) => setDlgState(() => costPrice = double.tryParse(v) ?? 0.0),
                    onSaved: (v) => costPrice = double.tryParse(v ?? '') ?? 0.0,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Bénéfice unitaire: ${(price - costPrice).toInt()} FCFA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: (price - costPrice) >= 0 ? Colors.green.shade700 : Colors.red,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: description,
                    decoration: const InputDecoration(labelText: 'Description'),
                    onSaved: (v) => description = v ?? '',
                  ),
                  const SizedBox(height: 16),
                  
                  // Media preview list
                  if (currentMedia.isNotEmpty) ...[
                    const Text('Médias:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: currentMedia.length,
                        itemBuilder: (context, index) {
                          final m = currentMedia[index];
                          final isVideo = m['kind'] == 'video';
                          final rawUrl = m['url']!;
                          final resolvedUrl = rawUrl.startsWith('http') ? rawUrl : '${ApiClient.baseUrl}$rawUrl';

                          return Stack(
                            children: [
                              Container(
                                width: 80,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: isVideo
                                      ? Container(
                                          color: Colors.black,
                                          child: const Icon(Icons.videocam_rounded, color: Colors.white),
                                        )
                                      : CachedNetworkImage(
                                          imageUrl: resolvedUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                                          errorWidget: (_, __, ___) => const Icon(Icons.broken_image_rounded),
                                        ),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 8,
                                child: InkWell(
                                  onTap: () {
                                    setDlgState(() {
                                      currentMedia.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                                  ),
                                ),
                              )
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // The global theme makes ElevatedButtons full-width
                      // (minimumSize: Size.fromHeight → infinite width), which
                      // crashes inside a Row. Expanded gives each a bounded
                      // width so they share the row instead.
                      Expanded(
                      child: ElevatedButton.icon(
                        onPressed: uploading
                            ? null
                            : () async {
                                final XFile? file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800);
                                if (file != null) {
                                  setDlgState(() => uploading = true);
                                  try {
                                    final uploaded = await _repo.uploadMedia(File(file.path));
                                    setDlgState(() {
                                      currentMedia.add({
                                        'url': uploaded['url']!,
                                        'kind': 'image',
                                        'thumb_url': uploaded['thumb_url'] ?? '',
                                      });
                                    });
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                                    }
                                  } finally {
                                    setDlgState(() => uploading = false);
                                  }
                                }
                              },
                        icon: const Icon(Icons.image_rounded, size: 16),
                        label: const Text('Image'),
                      ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                      child: ElevatedButton.icon(
                        onPressed: uploading
                            ? null
                            : () async {
                                final XFile? file = await picker.pickVideo(source: ImageSource.gallery);
                                if (file != null) {
                                  setDlgState(() => uploading = true);
                                  try {
                                    final uploaded = await _repo.uploadMedia(File(file.path));
                                    setDlgState(() {
                                      currentMedia.add({
                                        'url': uploaded['url']!,
                                        'kind': 'video',
                                        'thumb_url': '',
                                      });
                                    });
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                                    }
                                  } finally {
                                    setDlgState(() => uploading = false);
                                  }
                                }
                              },
                        icon: const Icon(Icons.videocam_rounded, size: 16),
                        label: const Text('Vidéo'),
                      ),
                      ),
                    ],
                  ),
                  if (uploading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: uploading ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: uploading
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        formKey.currentState!.save();
                        try {
                          if (existing == null) {
                            await _repo.create(
                              name: name,
                              fabricType: fabric,
                              price: price,
                              costPrice: costPrice,
                              description: description,
                              media: currentMedia,
                            );
                          } else {
                            await _repo.update(
                              existing.id,
                              name: name,
                              fabricType: fabric,
                              price: price,
                              costPrice: costPrice,
                              description: description,
                              media: currentMedia,
                            );
                          }
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          _loadModels();
                        } catch (e) {
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _viewModelDetails(PretAPorterModel m, bool isSec) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) {
        final hasImg = m.media.any((x) => x.kind == 'image');
        final hasVideo = m.media.any((x) => x.kind == 'video');
        
        final imgUrl = hasImg 
            ? m.media.firstWhere((x) => x.kind == 'image').url
            : '';
        final resolvedImg = imgUrl.isNotEmpty
            ? (imgUrl.startsWith('http') ? imgUrl : '${ApiClient.baseUrl}$imgUrl')
            : '';
            
        final videoUrl = hasVideo
            ? m.media.firstWhere((x) => x.kind == 'video').url
            : '';
        final resolvedVideo = videoUrl.isNotEmpty
            ? (videoUrl.startsWith('http') ? videoUrl : '${ApiClient.baseUrl}$videoUrl')
            : '';

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) => ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              // Model Image
              if (resolvedImg.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CachedNetworkImage(
                    imageUrl: resolvedImg,
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (_, __, ___) => Container(
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
                    m.name,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${m.price.toInt()} F',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary),
                  ),
                ],
              ),
              // Profit is financial data — manager only.
              if (!isSec) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Bénéfice unitaire: ${m.profit.toInt()} F',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: m.profit >= 0 ? Colors.green.shade700 : Colors.red,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Chip(
                avatar: const Icon(Icons.texture_rounded, size: 16),
                label: Text('Tissu: ${m.fabricType}'),
              ),
              const SizedBox(height: 12),
              Text(
                m.description ?? 'Aucune description fournie.',
                style: TextStyle(fontSize: 16, color: Colors.grey[800], height: 1.4),
              ),
              if (resolvedVideo.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Référence Vidéo (Lazy Loaded)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                // Lazy-loaded Video Player
                LazyVideoPlayer(videoUrl: resolvedVideo),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isSec = auth.isSecretary;
    final shopName = context.watch<ShopSettingsProvider>().shopName;

    return Scaffold(
      appBar: AppBar(
        title: Text('$shopName - Prêt-à-porter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadModels,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur: $_error'))
              : _models.isEmpty
                  ? const Center(child: Text('Aucun modèle de prêt-à-porter enregistré.'))
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
                        final hasImg = m.media.any((x) => x.kind == 'image');
                        final imgUrl = hasImg ? m.media.firstWhere((x) => x.kind == 'image').url : '';
                        final resolvedImg = imgUrl.isNotEmpty
                            ? (imgUrl.startsWith('http') ? imgUrl : '${ApiClient.baseUrl}$imgUrl')
                            : '';

                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _viewModelDetails(m, isSec),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      resolvedImg.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: resolvedImg,
                                              fit: BoxFit.cover,
                                              placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                              errorWidget: (_, __, ___) => Container(color: Colors.grey[200]),
                                            )
                                          : Container(color: Colors.grey[200], child: const Icon(Icons.image_rounded, color: Colors.grey)),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.6),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '${m.price.toInt()} F',
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
                                        m.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        m.fabricType,
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (!isSec)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            'Bénéf: ${m.profit.toInt()} F',
                                            style: TextStyle(
                                              color: m.profit >= 0 ? Colors.green.shade700 : Colors.red,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          // Counter sale button (both roles)
                                          IconButton(
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(4),
                                            icon: const Icon(Icons.shopping_cart_rounded, color: Colors.green, size: 18),
                                            tooltip: 'Vendre',
                                            onPressed: () => _recordSale(m),
                                          ),
                                          if (!isSec) ...[
                                            IconButton(
                                              constraints: const BoxConstraints(),
                                              padding: const EdgeInsets.all(4),
                                              icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 18),
                                              onPressed: () => _addOrEditModel(m),
                                            ),
                                            IconButton(
                                              constraints: const BoxConstraints(),
                                              padding: const EdgeInsets.all(4),
                                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                                              onPressed: () async {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: const Text('Supprimer modèle ?'),
                                                    content: Text('Voulez-vous supprimer "${m.name}" ?'),
                                                    actions: [
                                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                                                      ElevatedButton(
                                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                        onPressed: () => Navigator.pop(ctx, true),
                                                        child: const Text('Supprimer'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                if (confirm == true) {
                                                  await _repo.delete(m.id);
                                                  _loadModels();
                                                }
                                              },
                                            ),
                                          ],
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
      floatingActionButton: isSec
          ? null
          : FloatingActionButton(
              onPressed: () => _addOrEditModel(),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            ),
    );
  }
}

/// Custom Lazy Loaded Video Player Widget
class LazyVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const LazyVideoPlayer({super.key, required this.videoUrl});

  @override
  State<LazyVideoPlayer> createState() => _LazyVideoPlayerState();
}

class _LazyVideoPlayerState extends State<LazyVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _error = false;

  Future<void> _initPlayer() async {
    if (_initialized || _controller != null) return;
    
    // We initialize the player only when requested
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    setState(() {
      _controller = controller;
    });

    try {
      await controller.initialize();
      setState(() {
        _initialized = true;
      });
      controller.play();
      controller.setLooping(true);
    } catch (e) {
      debugPrint('Video initialization failed: $e');
      setState(() {
        _error = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Card(
        color: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Container(
          height: 180,
          alignment: Alignment.center,
          child: const Text('Échec de la lecture vidéo', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    if (!_initialized) {
      return Card(
        color: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: InkWell(
          onTap: _initPlayer,
          child: Container(
            height: 180,
            alignment: Alignment.center,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 56),
                SizedBox(height: 8),
                Text('Charger la vidéo / Load video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      color: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
          VideoProgressIndicator(_controller!, allowScrubbing: true),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  _controller!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.replay_rounded, color: Colors.white),
                onPressed: () {
                  _controller!.seekTo(Duration.zero);
                  _controller!.play();
                },
              ),
            ],
          )
        ],
      ),
    );
  }
}
