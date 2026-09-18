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
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../data/models/payment_mode_model.dart';
import '../../data/repositories/payment_mode_repository.dart';

final paymentModeRepositoryProvider = Provider<PaymentModeRepository>((ref) {
  return const PaymentModeRepository();
});

final paymentModesListProvider = FutureProvider<List<PaymentMode>>((ref) async {
  return ref.watch(paymentModeRepositoryProvider).getPaymentModes();
});

class PaymentModesScreen extends ConsumerStatefulWidget {
  const PaymentModesScreen({super.key});

  @override
  ConsumerState<PaymentModesScreen> createState() => _PaymentModesScreenState();
}

class _PaymentModesScreenState extends ConsumerState<PaymentModesScreen> {
  void _openAddModeDialog() {
    final nameCtrl = TextEditingController();
    String selectedIcon = '💳';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusXl.r)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl.w),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add Custom Payment Mode', style: AppTextStyles.h3),
                    SizedBox(height: AppSpacing.lg.h),
                    AppTextField(
                      label: 'Payment Mode Name',
                      hint: 'e.g. Google Pay, Hawala, Barter',
                      controller: nameCtrl,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                    ),
                    SizedBox(height: AppSpacing.lg.h),
                    Text('Icon / Symbol', style: AppTextStyles.caption),
                    SizedBox(height: AppSpacing.xs.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: ['💳', '📱', '🏦', '📝', '🤝', '💎', '💵', '🪙'].map((icon) {
                        final isSel = selectedIcon == icon;
                        return InkWell(
                          onTap: () => setDialogState(() => selectedIcon = icon),
                          borderRadius: BorderRadius.circular(8.r),
                          child: Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: isSel ? AppColors.primaryLight.withValues(alpha: 0.3) : Theme.of(ctx).cardColor,
                              border: Border.all(
                                color: isSel ? AppColors.primary : AppColors.outline,
                                width: isSel ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(icon, style: TextStyle(fontSize: 22.sp)),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: AppSpacing.xl.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Cancel', style: AppTextStyles.button.copyWith(color: AppColors.textSecondary)),
                        ),
                        SizedBox(width: AppSpacing.sm.w),
                        AppButton(
                          label: 'Add Mode',
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              await ref.read(paymentModeRepositoryProvider).addPaymentMode(
                                    nameCtrl.text.trim(),
                                    selectedIcon,
                                  );
                              ref.invalidate(paymentModesListProvider);
                              if (ctx.mounted) Navigator.pop(ctx);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modesAsync = ref.watch(paymentModesListProvider);
    final isWide = MediaQuery.sizeOf(context).width >= AppConstants.tabletBreakpoint;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Payment Modes Configuration',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Payment Mode',
            onPressed: _openAddModeDialog,
          ),
        ],
      ),
      body: modesAsync.when(
        loading: () => const AppLoader(message: 'Loading payment modes...'),
        error: (e, _) => AppErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(paymentModesListProvider),
        ),
        data: (modes) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 800 : double.infinity),
              child: ListView(
                padding: EdgeInsets.all(AppSpacing.lg.w),
                children: [
                  Text(
                    'Configure enabled payment modes for cash loans, Jama repayments, and family transactions.',
                    style: AppTextStyles.caption,
                  ),
                  SizedBox(height: AppSpacing.md.h),
                  AppCard(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: modes.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final mode = modes[index];
                        return SwitchListTile(
                          value: mode.isActive,
                          activeThumbColor: AppColors.primary,
                          title: Row(
                            children: [
                              Text(mode.iconKey, style: TextStyle(fontSize: 20.sp)),
                              SizedBox(width: 8.w),
                              Flexible(
                                child: Text(
                                  mode.name,
                                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (mode.isSystemPreset) ...[
                                SizedBox(width: 8.w),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                  child: Text(
                                    'SYSTEM',
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(mode.code, style: AppTextStyles.caption),
                          onChanged: (active) async {
                            await ref.read(paymentModeRepositoryProvider).toggleModeActive(mode.id, active);
                            ref.invalidate(paymentModesListProvider);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Payment Mode'),
        onPressed: _openAddModeDialog,
      ),
    );
  }
}
