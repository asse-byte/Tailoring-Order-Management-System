import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Irreversible-delete confirmation for Type-A master data (client, tailor,
/// monthly staff, product, ready-to-wear model). Unlike a plain yes/no, the
/// manager must TYPE the exact name — a deliberate speed bump because this
/// really deletes the profile (financial history is preserved separately on
/// the server via name snapshots).
///
/// Returns true only if the typed text matches [itemName] and the manager
/// confirmed. [historyNote] (optional) explains, in French, what historical
/// data is kept despite the deletion.
Future<bool> confirmDeleteByTyping(
  BuildContext context, {
  required String itemName,
  required String itemLabel, // e.g. "ce client", "ce couturier", "ce produit"
  String? historyNote,
}) async {
  final TextEditingController controller = TextEditingController();
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) {
      return StatefulBuilder(
        builder: (BuildContext ctx, void Function(void Function()) setDlg) {
          final bool matches = controller.text.trim() == itemName.trim();
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: <Widget>[
                const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(child: Text('Supprimer $itemLabel')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Cette action est DÉFINITIVE et irréversible. Le profil de '
                  '« $itemName » sera supprimé pour toujours.',
                ),
                const SizedBox(height: 10),
                Text(
                  historyNote ??
                      'Les données historiques déjà enregistrées restent '
                          'conservées dans les rapports.',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pour confirmer, tapez le nom exact ci-dessous :',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (_) => setDlg(() {}),
                  decoration: InputDecoration(
                    hintText: itemName,
                    border: const OutlineInputBorder(),
                    suffixIcon: matches
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppColors.success)
                        : null,
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                // Disabled until the typed name matches exactly.
                onPressed: matches ? () => Navigator.of(ctx).pop(true) : null,
                child: const Text('Supprimer définitivement'),
              ),
            ],
          );
        },
      );
    },
  );
  return result ?? false;
}
