import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/couture_icons.dart';
import '../../../../core/theme/couture_palette.dart';
import '../../../../core/widgets/couture/couture_bits.dart';
import '../../../../core/widgets/couture/couture_scaffold.dart';
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
        backgroundColor: error
            ? CouturePalette.terracottaDeep
            : CoutureScheme.of(context).goodInk,
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
                        Icon(CoutureIcons.images,
                            color: CoutureScheme.of(ctx).iconInk, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          'Nouveau modèle',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            color: CoutureScheme.of(ctx).ink,
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
                        prefixIcon: Icon(CoutureIcons.coatHanger),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: fabricCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Type de tissu',
                        hintText: 'ex: Bazin Getzner / Soie',
                        prefixIcon: Icon(CoutureIcons.stack),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FormattedNumberField(
                      controller: priceCtrl,
                      label: 'Prix estimé / Confection (FCFA)',
                      hint: '0',
                      prefixIcon: CoutureIcons.wallet,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description / Notes',
                        prefixIcon: Icon(CoutureIcons.clipboardText),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Photos et Vidéos du modèle',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
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
                            final url = rawUrl.startsWith('http')
                                ? rawUrl
                                : '${ApiClient.baseUrl}$rawUrl';

                            return Stack(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  margin:
                                      const EdgeInsets.only(right: 8, top: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: isVid
                                        ? Container(
                                            color: Colors.black87,
                                            child: const Icon(CoutureIcons.play,
                                                color: Colors.white, size: 30),
                                          )
                                        : CachedNetworkImage(
                                            imageUrl: url,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) =>
                                                const Icon(CoutureIcons.images),
                                          ),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      setSheetState(
                                          () => uploadedMedia.removeAt(idx));
                                    },
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(3),
                                      child: const Icon(CoutureIcons.close,
                                          color: Colors.white, size: 13),
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
                            onPressed: uploading
                                ? null
                                : () =>
                                    pickAndUpload('image', ImageSource.gallery),
                            icon: const Icon(CoutureIcons.images),
                            label: const Text('Galerie'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: uploading
                                ? null
                                : () =>
                                    pickAndUpload('image', ImageSource.camera),
                            icon: const Icon(CoutureIcons.camera),
                            label: const Text('Photo'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: uploading
                                ? null
                                : () =>
                                    pickAndUpload('video', ImageSource.gallery),
                            icon: const Icon(CoutureIcons.videoCamera),
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
                          backgroundColor: CoutureScheme.of(ctx).iconInk,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: (saving || uploading)
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                if (name.isEmpty) {
                                  _toast('Écrivez le nom du modèle.',
                                      error: true);
                                  return;
                                }
                                setSheetState(() => saving = true);
                                try {
                                  final price =
                                      parseThousands(priceCtrl.text) ?? 0;
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
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(CoutureIcons.checkCircle),
                        label: const Text('Enregistrer dans Mon Album',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
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
        final imgUrl =
            hasImg ? m.media.firstWhere((x) => x.kind == 'image').url : '';
        final resolvedImg = imgUrl.isNotEmpty
            ? (imgUrl.startsWith('http')
                ? imgUrl
                : '${ApiClient.baseUrl}$imgUrl')
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
                    color: CoutureScheme.of(context).quiet,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(CoutureIcons.images,
                      size: 56, color: CoutureScheme.of(context).inkFaint),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      m.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: CoutureScheme.of(context).ink,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: CoutureScheme.of(context).iconInk,
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
                Text('Photos et vidéos (${m.media.length})',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
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
                      final url = raw.startsWith('http')
                          ? raw
                          : '${ApiClient.baseUrl}$raw';

                      return GestureDetector(
                        onTap: () async {
                          if (isVid) {
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          } else {
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                backgroundColor: Colors.transparent,
                                child: Stack(
                                  alignment: Alignment.topRight,
                                  children: [
                                    InteractiveViewer(
                                        child: CachedNetworkImage(
                                            imageUrl: url,
                                            fit: BoxFit.contain)),
                                    IconButton(
                                      icon: const Icon(CoutureIcons.close,
                                          color: Colors.white, size: 26),
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(CoutureIcons.play,
                                            color: Colors.white, size: 34),
                                        SizedBox(height: 4),
                                        Text('Vidéo',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  )
                                : CachedNetworkImage(
                                    imageUrl: url, fit: BoxFit.cover),
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
                  foregroundColor: CouturePalette.terracottaDeep,
                  side: const BorderSide(color: CouturePalette.terracottaDeep),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  final confirm = await confirmDeleteByTyping(
                    context,
                    itemName: m.name,
                    itemLabel: 'ce modèle',
                    historyNote:
                        'Les commandes créées avec ce modèle restent enregistrées.',
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
                icon: const Icon(CoutureIcons.trash),
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
    final CoutureScheme c = CoutureScheme.of(context);
    return CoutureScaffold(
      title: 'Mon Album',
      subtitle: 'À montrer au client',
      actions: <Widget>[
        CoutureBandAction(
          icon: CoutureIcons.refresh,
          tooltip: 'Actualiser',
          onPressed: _loadModels,
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddModelSheet,
        backgroundColor: c.urgentInk,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(CoutureIcons.plus, size: 20),
        label: const Text('Ajouter un modèle',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      below: Padding(
        padding: const EdgeInsets.fromLTRB(CouturePalette.s4, CouturePalette.s3,
            CouturePalette.s4, CouturePalette.s3),
        child: CoutureSearchField(
          controller: _searchCtrl,
          hint: 'Nom du modèle, tissu',
          onChanged: (_) => setState(_applySearch),
          onClear: () {
            _searchCtrl.clear();
            setState(_applySearch);
          },
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _loadModels,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? const CoutureEmpty(
                    icon: CoutureIcons.warningCircle,
                    tone: CoutureTone.urgent,
                    title: 'L\'album ne s\'affiche pas',
                    message:
                        'Vérifiez la connexion, puis appuyez sur Actualiser.',
                  )
                : _filteredModels.isEmpty
                    ? const CoutureEmpty(
                        icon: CoutureIcons.images,
                        title: 'Album vide',
                        message:
                            'Appuyez sur « Ajouter un modèle » pour mettre vos photos et vos vidéos.',
                      )
                    : GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                            CouturePalette.s4, 0, CouturePalette.s4, 96),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 260,
                          childAspectRatio: 0.70,
                          crossAxisSpacing: CouturePalette.s3,
                          mainAxisSpacing: CouturePalette.s3,
                        ),
                        itemCount: _filteredModels.length,
                        itemBuilder: (BuildContext ctx, int idx) => _AlbumTile(
                          model: _filteredModels[idx],
                          onTap: () => _viewModelShowcase(_filteredModels[idx]),
                        ),
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
          color: CoutureScheme.of(context).quiet,
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
                errorWidget: (_, __, ___) => Icon(CoutureIcons.coatHanger,
                    size: 46, color: CoutureScheme.of(context).inkFaint),
              )
            else
              Center(
                child: Icon(CoutureIcons.coatHanger,
                    size: 50, color: CoutureScheme.of(context).inkFaint),
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
                  child: Icon(CoutureIcons.play, color: Colors.white, size: 16),
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
                      // On a photograph, over a dark fade: white reads at any
                      // brightness of fabric, and the palette's colours do not.
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
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
