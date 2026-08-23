import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/formatted_number_field.dart';
import '../../../../core/widgets/confirm_delete_dialog.dart';
import '../../data/pret_a_porter_repository.dart';

/// Screen "Mon Album" : Dedicated Showcase & Upload for Tailoring Models.
/// Allows uploading model photos & videos directly into the shop's album catalog.
class ModelsShowcaseScreen extends StatefulWidget {
  const ModelsShowcaseScreen({super.key});

  @override
  State<ModelsShowcaseScreen> createState() => _ModelsShowcaseScreenState();
}

class _ModelsShowcaseScreenState extends State<ModelsShowcaseScreen> {
  final PretAPorterRepository _repo = PretAPorterRepository();
  final TextEditingController _searchCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<PretAPorterModel> _allModels = [];
  List<PretAPorterModel> _filteredModels = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.list(limit: 100);
      setState(() {
        _allModels = items;
        _applySearch();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySearch() {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredModels = List.from(_allModels);
    } else {
      _filteredModels = _allModels.where((m) {
        return m.name.toLowerCase().contains(query) ||
            m.fabricType.toLowerCase().contains(query) ||
            (m.description ?? '').toLowerCase().contains(query);
      }).toList();
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Opens the Add Model modal sheet to upload media and save a new album model.
  Future<void> _showAddModelSheet() async {
    final nameCtrl = TextEditingController();
    final fabricCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final List<Map<String, String>> uploadedMedia = [];
    bool uploading = false;
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> pickAndUpload(String kind, ImageSource source) async {
              try {
                XFile? file;
                if (kind == 'image') {
                  file = await _picker.pickImage(
                    source: source,
                    maxWidth: 1200,
                    maxHeight: 1200,
                    imageQuality: 85,
                  );
                } else {
                  file = await _picker.pickVideo(
                    source: source,
                    maxDuration: const Duration(minutes: 3),
                  );
                }
                if (file == null) return;

                setSheetState(() => uploading = true);
                final res = await _repo.uploadMedia(file);
                setSheetState(() {
                  uploadedMedia.add({
                    'url': res['url']!,
                    'kind': kind,
                    'thumb_url': res['thumb_url'] ?? '',
                  });
                  uploading = false;
                });
                _toast('Média ajouté avec succès !');
              } catch (e) {
                setSheetState(() => uploading = false);
                _toast('Erreur d\'envoi du fichier: $e', error: true);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.collections_rounded, color: AppColors.primary, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          'Nouveau modèle (Mon Album)',
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom du modèle *',
                        hintText: 'ex: Robe Bazin Deluxe',
                        prefixIcon: Icon(Icons.checkroom_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: fabricCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Type de tissu',
                        hintText: 'ex: Bazin Getzner / Soie',
                        prefixIcon: Icon(Icons.texture_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FormattedNumberField(
                      controller: priceCtrl,
                      label: 'Prix estimé / Confection (FCFA)',
                      hint: '0',
                      prefixIcon: Icons.payments_rounded,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description / Notes',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Photos et Vidéos du modèle',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (uploadedMedia.isNotEmpty)
                      SizedBox(
                        height: 90,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: uploadedMedia.length,
                          itemBuilder: (_, idx) {
                            final item = uploadedMedia[idx];
                            final isVid = item['kind'] == 'video';
                            final rawUrl = item['url'] ?? '';
                            final url = rawUrl.startsWith('http') ? rawUrl : '${ApiClient.baseUrl}$rawUrl';

                            return Stack(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  margin: const EdgeInsets.only(right: 8, top: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: isVid
                                        ? Container(
                                            color: Colors.black87,
                                            child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
                                          )
                                        : CachedNetworkImage(
                                            imageUrl: url,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                                          ),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      setSheetState(() => uploadedMedia.removeAt(idx));
                                    },
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(3),
                                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: uploading ? null : () => pickAndUpload('image', ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_rounded),
                            label: const Text('Galerie'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: uploading ? null : () => pickAndUpload('image', ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_rounded),
                            label: const Text('Photo'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: uploading ? null : () => pickAndUpload('video', ImageSource.gallery),
                            icon: const Icon(Icons.videocam_rounded),
                            label: const Text('Vidéo'),
                          ),
                        ),
                      ],
                    ),
                    if (uploading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: (saving || uploading)
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                if (name.isEmpty) {
                                  _toast('Écrivez le nom du modèle.', error: true);
                                  return;
                                }
                                setSheetState(() => saving = true);
                                try {
                                  final price = parseThousands(priceCtrl.text) ?? 0;
                                  await _repo.create(
                                    name: name,
                                    fabricType: fabricCtrl.text.trim(),
                                    price: price.toDouble(),
                                    description: descCtrl.text.trim(),
                                    media: uploadedMedia,
                                  );
                                  if (mounted && ctx.mounted) {
                                    Navigator.pop(ctx);
                                    _toast('Modèle ajouté à Mon Album !');
                                    _loadModels();
                                  }
                                } catch (e) {
                                  setSheetState(() => saving = false);
                                  _toast('Erreur de création: $e', error: true);
                                }
                              },
                        icon: saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.save_rounded),
                        label: const Text('Enregistrer dans Mon Album', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _viewModelShowcase(PretAPorterModel m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final hasImg = m.media.any((x) => x.kind == 'image');
        final imgUrl = hasImg ? m.media.firstWhere((x) => x.kind == 'image').url : '';
        final resolvedImg = imgUrl.isNotEmpty
            ? (imgUrl.startsWith('http') ? imgUrl : '${ApiClient.baseUrl}$imgUrl')
            : '';

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          builder: (ctx, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              if (resolvedImg.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: CachedNetworkImage(
                      imageUrl: resolvedImg,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.collections_rounded, size: 64, color: AppColors.primary),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      m.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      formatFcfa(m.price.toInt()),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              // Deliberately nothing else here. The shop owner holds this open
              // in front of a customer, so the garment, its name and its price
              // are the whole message; the fabric chip and the description
              // paragraph only pushed the photos down the screen.
              const SizedBox(height: 18),

              // Showcase All Photos & Videos
              if (m.media.isNotEmpty) ...[
                Text('Photos et vidéos (${m.media.length})', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: m.media.length,
                    itemBuilder: (_, idx) {
                      final item = m.media[idx];
                      final isVid = item.kind == 'video';
                      final raw = item.url;
                      final url = raw.startsWith('http') ? raw : '${ApiClient.baseUrl}$raw';

                      return GestureDetector(
                        onTap: () async {
                          if (isVid) {
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          } else {
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                backgroundColor: Colors.transparent,
                                child: Stack(
                                  alignment: Alignment.topRight,
                                  children: [
                                    InteractiveViewer(child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain)),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: isVid
                                ? Container(
                                    color: Colors.black87,
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.play_circle_fill, color: Colors.white, size: 36),
                                        SizedBox(height: 4),
                                        Text('Vidéo', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  )
                                : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Delete button for managers
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  final confirm = await confirmDeleteByTyping(
                    context,
                    itemName: m.name,
                    itemLabel: 'ce modèle',
                    historyNote: 'Les commandes créées avec ce modèle restent enregistrées.',
                  );
                  if (confirm == true) {
                    try {
                      await _repo.delete(m.id);
                      if (mounted && ctx.mounted) {
                        Navigator.pop(ctx);
                        _toast('Modèle supprimé.');
                        _loadModels();
                      }
                    } catch (e) {
                      _toast('Erreur de suppression: $e', error: true);
                    }
                  }
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Supprimer ce modèle'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mon Album'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddModelSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo_rounded),
        label: const Text('Ajouter un modèle', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadModels,
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(_applySearch),
                decoration: InputDecoration(
                  hintText: 'Rechercher un modèle, tissu...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(_applySearch);
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).cardTheme.color,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                              const SizedBox(height: 12),
                              Text('Erreur: $_error', style: const TextStyle(color: AppColors.error)),
                              const SizedBox(height: 16),
                              ElevatedButton(onPressed: _loadModels, child: const Text('Réessayer')),
                            ],
                          ),
                        )
                      : _filteredModels.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.collections_outlined, size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Aucun modèle dans Mon Album',
                                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Cliquez sur "+ Ajouter un modèle" pour ajouter des photos et vidéos.',
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 260,
                                childAspectRatio: 0.70,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                              ),
                              itemCount: _filteredModels.length,
                              itemBuilder: (ctx, idx) =>
                                  _AlbumTile(
                                model: _filteredModels[idx],
                                onTap: () =>
                                    _viewModelShowcase(_filteredModels[idx]),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One model in the album.
///
/// This page is held up to a customer standing in the shop, so the garment is
/// the whole point: the photo fills the tile edge to edge and the only words on
/// it are the model's name and its price, sitting quietly on a dark fade at the
/// bottom. Everything else the screen used to print here — the fabric type, the
/// "Modèle sur mesure" filler — was noise competing with the picture.
class _AlbumTile extends StatelessWidget {
  const _AlbumTile({required this.model, required this.onTap});

  final PretAPorterModel model;
  final VoidCallback onTap;

  ModelMedia? get _cover {
    for (final ModelMedia m in model.media) {
      if (m.kind == 'image') return m;
    }
    return model.media.isNotEmpty ? model.media.first : null;
  }

  bool get _hasVideo => model.media.any((ModelMedia m) => m.kind == 'video');

  @override
  Widget build(BuildContext context) {
    final ModelMedia? cover = _cover;
    final String raw = cover?.thumbUrl ?? cover?.url ?? '';
    final String url = raw.isEmpty
        ? ''
        : (raw.startsWith('http') ? raw : '${ApiClient.baseUrl}$raw');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AppColors.primary.withValues(alpha: 0.06),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (url.isNotEmpty)
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, __) => const ColoredBox(
                  color: Color(0x11000000),
                ),
                errorWidget: (_, __, ___) => const Icon(
                    Icons.checkroom_rounded,
                    size: 48,
                    color: AppColors.primary),
              )
            else
              const Center(
                child: Icon(Icons.checkroom_rounded,
                    size: 52, color: AppColors.primary),
              ),

            // A soft fade so the caption stays readable over a bright fabric
            // without putting a solid bar across the garment.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                  colors: <Color>[Color(0xCC000000), Color(0x00000000)],
                ),
              ),
            ),

            if (_hasVideo)
              const Positioned(
                top: 10,
                right: 10,
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: Color(0x66000000),
                  child: Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 20),
                ),
              ),

            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    model.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatFcfa(model.price.toInt()),
                    style: const TextStyle(
                      color: Color(0xFFE8C766),
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
