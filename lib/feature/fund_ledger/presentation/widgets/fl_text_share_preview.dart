import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/fl_share_service.dart';
import '../../domain/entities/fl_share_statement.dart';

Future<void> showFLTextSharePreview(
  BuildContext context, {
  required FLShareStatement statement,
  required FLShareService shareService,
}) async {
  final text = shareService.statementText(statement);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Share Statement Text'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: SingleChildScrollView(
          child: SelectableText(text),
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.copy_outlined, size: 18),
          label: const Text('Copy'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (dialogContext.mounted) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Statement text copied')),
              );
            }
          },
        ),
        FilledButton.icon(
          icon: const Icon(Icons.share_outlined, size: 18),
          label: const Text('Share'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          onPressed: () async {
            await showModalBottomSheet<void>(
              context: dialogContext,
              builder: (shareContext) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Share statement with',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        leading: const Icon(Icons.chat, color: Colors.green),
                        title: const Text('WhatsApp'),
                        onTap: () async {
                          Navigator.of(shareContext).pop();
                          final opened =
                              await shareService.shareToWhatsApp(statement);
                          if (!opened && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('WhatsApp is not available'),
                              ),
                            );
                          }
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.sms_outlined),
                        title: const Text('SMS'),
                        onTap: () async {
                          Navigator.of(shareContext).pop();
                          final opened =
                              await shareService.shareToSms(statement);
                          if (!opened && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('SMS is not available'),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}
