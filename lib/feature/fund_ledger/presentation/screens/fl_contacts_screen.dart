import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/app_bar_widgets.dart';
import '../providers/fl_contact_providers.dart';
import '../widgets/fl_contact_card.dart';
import 'fl_contact_form_screen.dart';

/// Primary Contacts screen in Fund Ledger displaying list of contacts, search,
/// real-time available fund balances, and creation flow.
class FLContactsScreen extends ConsumerStatefulWidget {
  const FLContactsScreen({super.key});

  @override
  ConsumerState<FLContactsScreen> createState() => _FLContactsScreenState();
}

class _FLContactsScreenState extends ConsumerState<FLContactsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(flFilteredContactListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Contacts'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        label: Text(
          'Add Contact',
          style: AppTextStyles.button.copyWith(color: Colors.white),
        ),
        onPressed: () {
          showFLContactFormBottomSheet(context);
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md.w,
                vertical: AppSpacing.sm.h,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  ref.read(flContactSearchQueryProvider.notifier).state = val;
                },
                decoration: InputDecoration(
                  hintText: 'Search contacts by name, mobile, or project...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(flContactSearchQueryProvider.notifier)
                                .state = '';
                          },
                        )
                      : null,
                ),
              ),
            ),

            // Contacts List
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(flContactListProvider);
                },
                child: contactsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.lg.r),
                      child: Text(
                        'Failed to load contacts: $error',
                        style:
                            AppTextStyles.body.copyWith(color: AppColors.error),
                      ),
                    ),
                  ),
                  data: (contacts) {
                    if (contacts.isEmpty) {
                      final hasQuery = _searchController.text.trim().isNotEmpty;
                      return Center(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.all(AppSpacing.xxl.r),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                hasQuery
                                    ? Icons.search_off
                                    : Icons.group_outlined,
                                size: 64.r,
                                color: AppColors.textDisabled,
                              ),
                              SizedBox(height: AppSpacing.md.h),
                              Text(
                                hasQuery
                                    ? 'No matching contacts found'
                                    : 'No contacts yet',
                                style: AppTextStyles.h3.copyWith(
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                hasQuery
                                    ? 'Try searching with a different name or number'
                                    : 'Add your first fund contributor or recipient contact.',
                                style: AppTextStyles.caption.copyWith(
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (!hasQuery) ...[
                                SizedBox(height: AppSpacing.lg.h),
                                FilledButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Contact'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                  ),
                                  onPressed: () {
                                    showFLContactFormBottomSheet(context);
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md.w,
                        vertical: AppSpacing.sm.h,
                      ),
                      itemCount: contacts.length,
                      itemBuilder: (context, index) {
                        final contact = contacts[index];
                        final summaryAsync =
                            ref.watch(flContactSummaryProvider(contact.id));

                        return summaryAsync.when(
                          loading: () => SizedBox(
                            height: 100.h,
                            child: const Center(
                                child: CircularProgressIndicator()),
                          ),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (summary) {
                            if (summary == null) return const SizedBox.shrink();
                            return Padding(
                              padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
                              child: FLContactCard(
                                summary: summary,
                                onTap: () {
                                  context.pushNamed(
                                    RouteNames.flContactDetail,
                                    pathParameters: {'id': contact.id},
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
