import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/whatsapp.dart';
import '../../../settings/presentation/providers/shop_settings_provider.dart';
import '../../data/receipt_invoice_service.dart';
import '../../data/sales_repository.dart';

/// What the seller sees the moment the money is taken: the sale is done, here
/// is the invoice, here is how to send it.
///
/// Both roles reach it — it shows only the price the customer just paid.
class SaleReceiptScreen extends StatelessWidget {
  const SaleReceiptScreen({super.key, required this.receipt});

  final SaleReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopSettingsProvider>();
    final live = receipt.lines.where((l) => !l.voided).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vente terminée'),
        automaticallyImplyLeading: false,
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: <Widget>[
          Center(
            child: Column(
              children: <Widget>[
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 42),
                ),
                const SizedBox(height: 14),
                Text(formatFcfa(receipt.total),
                    style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
                const SizedBox(height: 4),
                Text('${receipt.itemsCount} article(s) vendu(s)',
                    style: const TextStyle(color: AppColors.textSecondary)),
                if ((receipt.clientName ?? '').isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text('Pour ${receipt.clientName}',
                      style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: <Widget>[
                for (final l in live)
                  ListTile(
                    dense: true,
                    title: Text(l.itemName),
                    subtitle: Text('${l.qty} × ${formatFcfa(l.unitPrice)}'),
                    trailing: Text(formatFcfa(l.total),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.primary,
            ),
            icon: const Icon(Icons.share_rounded),
            label: const Text('Envoyer la facture'),
            onPressed: () => _share(context, shop),
          ),
          const SizedBox(height: 10),
          if (canWhatsApp(receipt.clientPhone ?? ''))
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
              icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
              label: const Text('Écrire au client sur WhatsApp'),
              onPressed: () => _whatsAppText(context, shop),
            ),
          const SizedBox(height: 12),
          const Text(
            'Choisissez WhatsApp dans la liste de partage pour envoyer la '
            'facture au client.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Future<void> _share(BuildContext context, ShopSettingsProvider shop) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await const ReceiptInvoiceService().shareInvoice(
        receipt,
        shopName: shop.shopName,
        logoUrl: shop.logoUrl,
        promoLink: shop.promoGroupLink,
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Facture impossible : $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _whatsAppText(
      BuildContext context, ShopSettingsProvider shop) async {
    final messenger = ScaffoldMessenger.of(context);
    final buffer = StringBuffer()
      ..writeln('Bonjour${(receipt.clientName ?? '').isEmpty ? '' : ' ${receipt.clientName}'},')
      ..writeln('Merci pour votre achat chez ${shop.shopName}.')
      ..writeln();
    for (final l in receipt.lines.where((l) => !l.voided)) {
      buffer.writeln('- ${l.itemName} x${l.qty} = ${formatFcfa(l.total)}');
    }
    buffer
      ..writeln()
      ..writeln('Total: ${formatFcfa(receipt.total)}');

    final bool opened =
        await openWhatsApp(receipt.clientPhone ?? '', text: buffer.toString());
    if (!opened) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Numéro WhatsApp introuvable pour ce client.'),
        backgroundColor: AppColors.error,
      ));
    }
  }
}
