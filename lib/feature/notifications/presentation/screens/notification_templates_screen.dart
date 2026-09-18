import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_bar_widgets.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../data/models/notification_template_model.dart';
import '../../data/repositories/notification_template_repository.dart';
import '../providers/template_providers.dart';

class NotificationTemplatesScreen extends ConsumerStatefulWidget {
  const NotificationTemplatesScreen({super.key});

  @override
  ConsumerState<NotificationTemplatesScreen> createState() => _NotificationTemplatesScreenState();
}

class _NotificationTemplatesScreenState extends ConsumerState<NotificationTemplatesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _langTabCtrl;
  String _selectedTemplateId = 'loan_voucher';
  final _textController = TextEditingController();
  NotificationTemplate? _currentTemplate;
  bool _isSaving = false;

  int _lastSyncedIndex = 0;

  @override
  void initState() {
    super.initState();
    _langTabCtrl = TabController(length: 3, vsync: this);
    _langTabCtrl.addListener(() {
      if (mounted && _langTabCtrl.index != _lastSyncedIndex) {
        _lastSyncedIndex = _langTabCtrl.index;
        _syncTextWithLanguage();
      }
    });
  }

  @override
  void dispose() {
    _langTabCtrl.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _syncTextWithLanguage() {
    if (_currentTemplate == null) return;
    final text = switch (_langTabCtrl.index) {
      0 => _currentTemplate!.templateEnglish,
      1 => _currentTemplate!.templateHindi,
      2 => _currentTemplate!.templateHinglish,
      _ => _currentTemplate!.templateEnglish,
    };
    _textController.text = text;
    setState(() {});
  }

  void _updateCurrentLanguageText(String val) {
    if (_currentTemplate == null) return;
    switch (_langTabCtrl.index) {
      case 0:
        _currentTemplate = _currentTemplate!.copyWith(templateEnglish: val);
        break;
      case 1:
        _currentTemplate = _currentTemplate!.copyWith(templateHindi: val);
        break;
      case 2:
        _currentTemplate = _currentTemplate!.copyWith(templateHinglish: val);
        break;
    }
  }

  void _insertPlaceholder(String placeholder) {
    final text = _textController.text;
    final selection = _textController.selection;
    final newText = selection.isValid
        ? text.replaceRange(selection.start, selection.end, placeholder)
        : text + placeholder;
    _textController.text = newText;
    _updateCurrentLanguageText(newText);
  }

  Future<void> _saveTemplate() async {
    if (_currentTemplate == null) return;
    setState(() => _isSaving = true);
    _updateCurrentLanguageText(_textController.text);

    await ref.read(notificationTemplateRepositoryProvider).saveTemplate(_currentTemplate!);
    ref.invalidate(notificationTemplatesProvider);

    if (mounted) {
      setState(() => _isSaving = false);
      AppSnackbar.showSuccess(context, 'Template saved successfully!');
    }
  }

  Future<void> _resetDefaults() async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Reset All Templates',
      message: 'Are you sure you want to reset all WhatsApp and SMS message templates to factory defaults?',
      confirmLabel: 'Reset',
      isDestructive: true,
    );

    if (confirmed == true) {
      setState(() => _isSaving = true);
      await ref.read(notificationTemplateRepositoryProvider).resetToDefaults();
      ref.invalidate(notificationTemplatesProvider);
      if (mounted) {
        setState(() => _isSaving = false);
        AppSnackbar.showSuccess(context, 'All templates reset to defaults.');
      }
    }
  }

  String _getPreviewText() {
    final raw = _textController.text;
    return NotificationTemplateRepository.render(raw, {
      '{title}': 'Udhar Entry',
      '{contact_name}': 'Mohammad Tariq',
      '{amount}': '₹25,000',
      '{direction}': 'Lent (Receivable)',
      '{interest_info}': 'Simple Interest (2%/mo)',
      '{date}': '15-Mar-2026',
      '{due_date}': '15-Jun-2026',
      '{total_balance}': '₹26,500',
      '{memo_line}': '• Memo: Shop inventory credit',
      '{total_debit}': '₹40,000',
      '{total_credit}': '₹13,500',
      '{net_balance}': '₹26,500',
      '{balance_type}': 'Baki / Receivable',
      '{payment_mode}': 'Cash',
      '{remaining_balance}': '₹1,500',
    });
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(notificationTemplatesProvider);
    final isWide = MediaQuery.sizeOf(context).width >= AppConstants.tabletBreakpoint;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Message & Share Templates',
        actions: [
          IconButton(
            icon: const Icon(Icons.restore_rounded),
            tooltip: 'Reset All to Defaults',
            onPressed: _isSaving ? null : _resetDefaults,
          ),
        ],
      ),
      body: templatesAsync.when(
        loading: () => const AppLoader(message: 'Loading message templates...'),
        error: (e, _) => AppErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(notificationTemplatesProvider),
        ),
        data: (templates) {
          if (_currentTemplate == null || _currentTemplate!.id != _selectedTemplateId) {
            _currentTemplate = templates.firstWhere(
              (t) => t.id == _selectedTemplateId,
              orElse: () => templates.first,
            );
            WidgetsBinding.instance.addPostFrameCallback((_) => _syncTextWithLanguage());
          }

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 960 : double.infinity),
              child: ListView(
                padding: EdgeInsets.all(AppSpacing.lg.w),
                children: [
                  // Template Selector
                  Text('Select Message Template', style: AppTextStyles.h3),
                  SizedBox(height: AppSpacing.sm.h),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedTemplateId,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    ),
                    items: templates.map((t) {
                      return DropdownMenuItem(
                        value: t.id,
                        child: Text(t.name, style: AppTextStyles.bodyMedium),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedTemplateId = val;
                          _currentTemplate = templates.firstWhere((t) => t.id == val);
                        });
                        _syncTextWithLanguage();
                      }
                    },
                  ),
                  SizedBox(height: AppSpacing.lg.h),

                  // Language Tabs
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: TabBar(
                      controller: _langTabCtrl,
                      tabs: const [
                        Tab(text: 'English'),
                        Tab(text: 'हिंदी (Hindi)'),
                        Tab(text: 'Hinglish'),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSpacing.md.h),

                  // Placeholder Chips
                  Text('Available Placeholders (Tap to insert)', style: AppTextStyles.caption),
                  SizedBox(height: AppSpacing.xs.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 6.h,
                    children: (_currentTemplate?.supportedPlaceholders ?? []).map((ph) {
                      return ActionChip(
                        label: Text(ph, style: TextStyle(fontSize: 12.sp, color: AppColors.primaryDark)),
                        backgroundColor: AppColors.primaryLight.withValues(alpha: 0.3),
                        onPressed: () => _insertPlaceholder(ph),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: AppSpacing.md.h),

                  // Editor Card
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Template Editor', style: AppTextStyles.h3),
                        SizedBox(height: AppSpacing.sm.h),
                        TextField(
                          controller: _textController,
                          maxLines: 8,
                          style: AppTextStyles.bodyMedium,
                          decoration: const InputDecoration(
                            hintText: 'Enter template text with placeholders...',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) {
                            _updateCurrentLanguageText(v);
                            setState(() {});
                          },
                        ),
                        SizedBox(height: AppSpacing.md.h),
                        Align(
                          alignment: Alignment.centerRight,
                          child: AppButton(
                            label: 'Save Template',
                            icon: Icons.save_rounded,
                            isLoading: _isSaving,
                            onPressed: _saveTemplate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSpacing.xl.h),

                  // Live Preview Card
                  Text('Live Formatted Preview', style: AppTextStyles.h3),
                  SizedBox(height: AppSpacing.sm.h),
                  Container(
                    padding: EdgeInsets.all(AppSpacing.md.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCF8C6).withValues(alpha: 0.3), // subtle WhatsApp green tint
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF075E54)),
                            SizedBox(width: 8.w),
                            Text(
                              'WhatsApp & SMS Preview',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.sp,
                                color: const Color(0xFF075E54),
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        Text(
                          _getPreviewText(),
                          style: TextStyle(fontSize: 14.sp, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
