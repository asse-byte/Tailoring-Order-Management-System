import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final String finalCancel = cancelLabel ?? context.loc.cancel;
  final String finalConfirm =
      confirmLabel ?? (destructive ? context.loc.yes : context.loc.save);

  final bool? result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(finalCancel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                )
              : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(finalConfirm),
        ),
      ],
    ),
  );
  return result ?? false;
}
