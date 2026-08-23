import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:printing/printing.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/couture_icons.dart';
import '../../../../core/theme/couture_palette.dart';
import '../../../../core/widgets/couture/couture_bits.dart';
import '../../../../core/widgets/couture/couture_scaffold.dart';
import '../../../../core/widgets/confirm_delete_dialog.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/formatted_number_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/pret_a_porter_repository.dart';
import '../../../settings/presentation/providers/shop_settings_provider.dart';
import '../../../orders/data/invoice_service.dart';

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
    final priceCtrl =
        TextEditingController(text: formatThousands(model.price.toInt()));

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Vendre Modèle - ${model.name}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
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
              const SizedBox(height: 12),
              FormattedNumberField(
                controller: priceCtrl,
                label: 'Prix de vente unitaire (FCFA)',
                validator: (val) {
                  if (val == null || val < 0) return 'Prix invalide';
                  return null;
                },
              ),
            ],
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
                final customPrice =
                    parseThousands(priceCtrl.text) ?? model.price.toInt();
                Navigator.pop(ctx);
                try {
                  setState(() => _loading = true);
                  await _repo.sellModel(
                    modelId: model.id,
                    quantity: qty,
                    unitPrice: customPrice,
                  );
                  setState(() => _loading = false);
                  if (mounted) {
                    final settings = context.read<ShopSettingsProvider>();
                    final total = qty * customPrice;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                            'Vente de prêt-à-porter enregistrée avec succès !'),
                        backgroundColor: CoutureScheme.of(context).goodInk,
                        duration: const Duration(seconds: 8),
                        action: SnackBarAction(
                          label: 'Imprimer reçu',
                          textColor: Colors.white,
                          onPressed: () async {
                            final pdfBytes =
                                await InvoiceService.buildSaleReceiptPdf(
                              itemName: model.name,
                              itemKind: 'Modèle Prêt-à-porter',
                              qty: qty,
                              unitPrice: customPrice,
                              total: total,
                              shopName: settings.shopName,
                            );
                            await Printing.layoutPdf(
                              onLayout: (format) async => pdfBytes,
                              name: 'recu_modele_${model.name}.pdf',
                            );
                          },
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  setState(() => _loading = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Erreur: $e'),
                          backgroundColor: CouturePalette.terracottaDeep),
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
    final bool isManager = !context.read<AuthProvider>().isSecretary;
    final formKey = GlobalKey<FormState>();
    String name = existing?.name ?? '';
    String fabric = existing?.fabricType ?? '';
    double price = existing?.price ?? 45000.0;
    double costPrice = existing?.costPrice ?? 0.0;
    String description = existing?.description ?? '';
    final priceCtrl = TextEditingController(
        text: price > 0 ? formatThousands(price.toInt()) : '');
    final costCtrl = TextEditingController(
        text: costPrice > 0 ? formatThousands(costPrice.toInt()) : '');

    final List<Map<String, String>> currentMedia = existing != null
        ? existing.media
            .map((e) => {
                  'id': e.id,
                  'url': e.url,
                  'kind': e.kind,
                  'thumb_url': e.thumbUrl ?? ''
                })
            .toList()
        : [];

    bool uploading = false;
    final ImagePicker picker = ImagePicker();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      decoration:
                          const InputDecoration(labelText: 'Nom du modèle'),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Requis' : null,
                      onSaved: (v) => name = v ?? '',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: fabric,
                      decoration: const InputDecoration(labelText: 'Tissu'),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Requis' : null,
                      onSaved: (v) => fabric = v ?? '',
                    ),
                    const SizedBox(height: 12),
                    FormattedNumberField(
                      controller: priceCtrl,
                      label: 'Prix de vente (FCFA)',
                      validator: (v) => v == null ? 'Invalide' : null,
                      onChanged: (v) =>
                          setDlgState(() => price = (v ?? 0).toDouble()),
                    ),
                    // Prix d'achat + profit = financial data, manager only.
                    if (isManager) ...[
                      const SizedBox(height: 12),
                      FormattedNumberField(
                        controller: costCtrl,
                        label: 'Prix d\'achat (FCFA)',
                        validator: (v) => v == null ? 'Invalide' : null,
                        onChanged: (v) =>
                            setDlgState(() => costPrice = (v ?? 0).toDouble()),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Bénéfice unitaire: ${formatFcfa((price - costPrice).toInt())}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: (price - costPrice) >= 0
                                ? CoutureScheme.of(context).goodInk
                                : CouturePalette.terracottaDeep,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: description,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                      onSaved: (v) => description = v ?? '',
                    ),
                    const SizedBox(height: 16),

                    // Media preview list
                    if (currentMedia.isNotEmpty) ...[
                      const Text('Médias:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
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
                            final resolvedUrl = rawUrl.startsWith('http')
                                ? rawUrl
                                : '${ApiClient.baseUrl}$rawUrl';

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
                                            child: const Icon(
                                                CoutureIcons.videoCamera,
                                                color: Colors.white),
                                          )
                                        : CachedNetworkImage(
                                            imageUrl: resolvedUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => const Center(
                                                child:
                                                    CircularProgressIndicator()),
                                            errorWidget: (_, __, ___) =>
                                                const Icon(CoutureIcons.images),
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
                                      decoration: const BoxDecoration(
                                          color: CouturePalette.terracottaDeep,
                                          shape: BoxShape.circle),
                                      child: const Icon(CoutureIcons.close,
                                          color: Colors.white, size: 15),
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
                                    final XFile? file = await picker.pickImage(
                                        source: ImageSource.gallery,
                                        maxWidth: 800,
                                        maxHeight: 800);
                                    if (file != null) {
                                      setDlgState(() => uploading = true);
                                      try {
                                        final uploaded =
                                            await _repo.uploadMedia(file);
                                        setDlgState(() {
                                          currentMedia.add({
                                            'url': uploaded['url']!,
                                            'kind': 'image',
                                            'thumb_url':
                                                uploaded['thumb_url'] ?? '',
                                          });
                                        });
                                      } catch (e) {
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(ctx)
                                              .showSnackBar(SnackBar(
                                                  content: Text('Erreur: $e')));
                                        }
                                      } finally {
                                        setDlgState(() => uploading = false);
                                      }
                                    }
                                  },
                            icon: const Icon(CoutureIcons.images, size: 16),
                            label: const Text('Image'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: uploading
                                ? null
                                : () async {
                                    final XFile? file = await picker.pickVideo(
                                        source: ImageSource.gallery);
                                    if (file != null) {
                                      setDlgState(() => uploading = true);
                                      try {
                                        final uploaded =
                                            await _repo.uploadMedia(file);
                                        setDlgState(() {
                                          currentMedia.add({
                                            'url': uploaded['url']!,
                                            'kind': 'video',
                                            'thumb_url': '',
                                          });
                                        });
                                      } catch (e) {
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(ctx)
                                              .showSnackBar(SnackBar(
                                                  content: Text('Erreur: $e')));
                                        }
                                      } finally {
                                        setDlgState(() => uploading = false);
                                      }
                                    }
                                  },
                            icon:
                                const Icon(CoutureIcons.videoCamera, size: 16),
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
                            SnackBar(
                                content: Text('Erreur: $e'),
                                backgroundColor: CouturePalette.terracottaDeep),
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

        final imgUrl =
            hasImg ? m.media.firstWhere((x) => x.kind == 'image').url : '';
        final resolvedImg = imgUrl.isNotEmpty
            ? (imgUrl.startsWith('http')
                ? imgUrl
                : '${ApiClient.baseUrl}$imgUrl')
            : '';

        final videoUrl =
            hasVideo ? m.media.firstWhere((x) => x.kind == 'video').url : '';
        final resolvedVideo = videoUrl.isNotEmpty
            ? (videoUrl.startsWith('http')
                ? videoUrl
                : '${ApiClient.baseUrl}$videoUrl')
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
                    placeholder: (_, __) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (_, __, ___) => Container(
                      height: 250,
                      color: Colors.grey[200],
                      child: const Icon(CoutureIcons.images, size: 46),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    m.name,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    formatFcfa(m.price.toInt()),
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: CoutureScheme.of(context).ink),
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
                      color: m.profit >= 0
                          ? CoutureScheme.of(context).goodInk
                          : CouturePalette.terracottaDeep,
                    ),
                  ),
                ),
                _detailRow(
                    'Prix d\'achat unitaire', formatFcfa(m.costPrice.toInt())),
                const SizedBox(height: 16),
                const Text(
                  'Statistiques de vente',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                FutureBuilder<Map<String, dynamic>>(
                  future: _repo.getStats(m.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Text(
                        'Erreur: ${snapshot.error}',
                        style: const TextStyle(
                            color: CouturePalette.terracottaDeep),
                      );
                    }
                    final stats = snapshot.data!;
                    final int totalSold = stats['total_sold'] as int;
                    final int totalRevenue = stats['total_revenue'] as int;
                    final int totalProfit = stats['total_profit'] as int;

                    return Column(
                      children: [
                        _detailRow('Quantité vendue', '$totalSold unités'),
                        _detailRow('Ventes totales', formatFcfa(totalRevenue)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Gain total'),
                            Text(
                              formatFcfa(totalProfit),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: totalProfit >= 0
                                      ? CoutureScheme.of(context).goodInk
                                      : CouturePalette.terracottaDeep),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 8),
              Chip(
                avatar: const Icon(CoutureIcons.stack, size: 16),
                label: Text('Tissu: ${m.fabricType}'),
              ),
              const SizedBox(height: 12),
              Text(
                m.description ?? 'Aucune description fournie.',
                style: TextStyle(
                    fontSize: 16, color: Colors.grey[800], height: 1.4),
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
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(CoutureIcons.pencil),
                      label: const Text('Modifier'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _addOrEditModel(m);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: CouturePalette.terracottaDeep),
                      icon: const Icon(CoutureIcons.trash),
                      label: const Text('Supprimer'),
                      onPressed: () async {
                        final confirm = await confirmDeleteByTyping(
                          context,
                          itemName: m.name,
                          itemLabel: 'ce modèle',
                          historyNote:
                              'Les ventes de ce modèle resteront en mémoire dans les Finances.',
                        );
                        if (confirm && ctx.mounted) {
                          Navigator.pop(ctx);
                          try {
                            await _repo.delete(m.id);
                            if (mounted) _loadModels();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Erreur: $e'),
                                    backgroundColor:
                                        CouturePalette.terracottaDeep),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
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

    final CoutureScheme c = CoutureScheme.of(context);

    return CoutureScaffold(
      title: 'Prêt-à-porter',
      subtitle: shopName.isEmpty ? 'Les modèles déjà cousus' : shopName,
      actions: <Widget>[
        CoutureBandAction(
          icon: CoutureIcons.refresh,
          tooltip: 'Actualiser',
          onPressed: _loadModels,
        ),
      ],
      // Catalog management is open to both roles (cost_price/profit stay hidden).
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEditModel(),
        backgroundColor: c.urgentInk,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(CoutureIcons.plus, size: 20),
        label: const Text('Nouveau modèle',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? const CoutureEmpty(
                  icon: CoutureIcons.warningCircle,
                  tone: CoutureTone.urgent,
                  title: 'Les modèles ne s\'affichent pas',
                  message:
                      'Vérifiez la connexion, puis appuyez sur Actualiser.',
                )
              : _models.isEmpty
                  ? const CoutureEmpty(
                      icon: CoutureIcons.coatHanger,
                      title: 'Aucun modèle',
                      message:
                          'Appuyez sur « Nouveau modèle » pour en ajouter un.',
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(CouturePalette.s4,
                          CouturePalette.s4, CouturePalette.s4, 96),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: _models.length,
                      itemBuilder: (context, index) {
                        final m = _models[index];
                        final hasImg = m.media.any((x) => x.kind == 'image');
                        final imgUrl = hasImg
                            ? m.media.firstWhere((x) => x.kind == 'image').url
                            : '';
                        final resolvedImg = imgUrl.isNotEmpty
                            ? (imgUrl.startsWith('http')
                                ? imgUrl
                                : '${ApiClient.baseUrl}$imgUrl')
                            : '';

                        return CoutureCard(
                          padding: EdgeInsets.zero,
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
                                            placeholder: (_, __) => const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2)),
                                            errorWidget: (_, __, ___) =>
                                                Container(color: c.quiet),
                                          )
                                        : Container(
                                            color: c.quiet,
                                            child: Icon(CoutureIcons.images,
                                                color: c.inkFaint)),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.6),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          formatFcfa(m.price.toInt()),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold),
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
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14.5,
                                          color: c.ink),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      m.fabricType,
                                      style: TextStyle(
                                          color: c.inkFaint, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (!isSec)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          'Bénéfice ${formatFcfa(m.profit.toInt())}',
                                          style: TextStyle(
                                            color: m.profit >= 0
                                                ? c.goodInk
                                                : c.urgentText,
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
                                          icon: Icon(CoutureIcons.cashRegister,
                                              color: c.goodInk, size: 18),
                                          tooltip: 'Vendre',
                                          onPressed: () => _recordSale(m),
                                        ),
                                        // Catalog edits: both roles.
                                        IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(4),
                                          icon: Icon(CoutureIcons.pencil,
                                              color: c.inkSoft, size: 18),
                                          onPressed: () => _addOrEditModel(m),
                                        ),
                                        IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(4),
                                          icon: Icon(CoutureIcons.trash,
                                              color: c.urgentText, size: 18),
                                          onPressed: () async {
                                            final confirm =
                                                await confirmDeleteByTyping(
                                              context,
                                              itemName: m.name,
                                              itemLabel: 'ce modèle',
                                              historyNote: 'Les ventes déjà '
                                                  'enregistrées de ce modèle restent '
                                                  'conservées dans les Finances (au nom '
                                                  'et prix mémorisés).',
                                            );
                                            if (confirm) {
                                              await _repo.delete(m.id);
                                              _loadModels();
                                            }
                                          },
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: CoutureScheme.of(context).inkSoft)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
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
    final controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
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
          child: const Text('Échec de la lecture vidéo',
              style: TextStyle(color: Colors.white)),
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
                Icon(CoutureIcons.play, color: Colors.white, size: 52),
                SizedBox(height: 8),
                Text('Charger la vidéo / Load video',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
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
                  _controller!.value.isPlaying
                      ? CoutureIcons.pause
                      : CoutureIcons.play,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _controller!.value.isPlaying
                        ? _controller!.pause()
                        : _controller!.play();
                  });
                },
              ),
              IconButton(
                icon: const Icon(CoutureIcons.refresh, color: Colors.white),
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
