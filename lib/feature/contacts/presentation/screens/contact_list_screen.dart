import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../routes/route_names.dart';
import '../../../../shared/widgets/app_bar_widgets.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ledger_list_tile.dart';
import '../../domain/entities/contact.dart';

import '../providers/contact_providers.dart';
import 'contact_detail_screen.dart';
import 'contact_form_screen.dart';

/// Master pane: lists all Buyers, Suppliers, or Direct Cash contacts.
/// Segmented control at top selects the active tab.
/// On tablet/iPad landscape (>= tabletBreakpoint), provides a 2-pane master-detail view.
class ContactListScreen extends ConsumerStatefulWidget {
  const ContactListScreen({super.key});

  @override
  ConsumerState<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends ConsumerState<ContactListScreen> {
  int _selectedTab = 0; // 0=Buyers, 1=Suppliers, 2=Direct Cash
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedContactId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= AppConstants.tabletBreakpoint;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: 380,
              child: _buildMasterView(context, isWide: true),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: Theme.of(context).dividerColor,
            ),
            Expanded(
              child: _buildDetailView(context),
            ),
          ],
        ),
      );
    }

    return _buildMasterView(context, isWide: false);
  }

  Widget _buildMasterView(BuildContext context, {required bool isWide}) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Udhar Khata',
        actions: [
          IconButton(
            key: const Key('openingBalanceButton'),
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Set Opening Balance',
            onPressed: () => _openOpeningBalanceForm(),
          ),
          IconButton(
            key: const Key('newContactButton'),
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'New Contact',
            onPressed: _openNewContactForm,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            _searchQuery.isNotEmpty ? 62.h : 114.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSearchBar(isWide: isWide),
              if (_searchQuery.isEmpty)
                _buildTabSwitcher(context),
            ],
          ),
        ),
      ),
      body: _buildBody(isWide: isWide),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('newContactFab'),
        onPressed: _openNewContactForm,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('New Contact'),
        tooltip: 'Add new buyer or supplier',
      ),
    );
  }

  List<Contact> _getActiveContacts() {
    if (_searchQuery.trim().isNotEmpty) {
      return ref.watch(udharGlobalSearchProvider).valueOrNull ?? [];
    }
    if (_selectedTab == 2) {
      return [];
    }
    final provider = _selectedTab == 0 ? buyerListProvider : supplierListProvider;
    return ref.watch(provider).valueOrNull ?? [];
  }

  String? _getEffectiveContactId(List<Contact> activeContacts) {
    if (_selectedContactId != null && activeContacts.any((c) => c.id == _selectedContactId)) {
      return _selectedContactId;
    }
    return activeContacts.isNotEmpty ? activeContacts.first.id : null;
  }

  Widget _buildDetailView(BuildContext context) {
    final activeContacts = _getActiveContacts();
    final effectiveId = _getEffectiveContactId(activeContacts);

    if (effectiveId != null) {
      return ContactDetailScreen(
        key: ValueKey(effectiveId),
        contactId: effectiveId,
        isMasterDetail: true,
        onDeleted: () {
          setState(() => _selectedContactId = null);
        },
      );
    }

    return const Scaffold(
      appBar: CustomAppBar(
        title: 'Contact Details',
        leading: SizedBox.shrink(),
      ),
      body: Center(
        child: AppEmptyState(
          title: 'Select a Contact',
          subtitle: 'Choose a buyer or supplier from the list on the left to view their complete ledger history.',
          icon: Icons.person_search_outlined,
        ),
      ),
    );
  }

  Widget _buildTabSwitcher(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabs = [
      (
        index: 0,
        label: 'Buyers',
        icon: Icons.people_rounded,
        activeColor: AppColors.primary,
        inactiveColor: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
      ),
      (
        index: 1,
        label: 'Suppliers',
        icon: Icons.store_rounded,
        activeColor: const Color(0xFF5E35B1),
        inactiveColor: isDark ? const Color(0xFFB39DDB) : const Color(0xFF673AB7),
      ),
      (
        index: 2,
        label: 'Direct Cash',
        icon: Icons.monetization_on_rounded,
        activeColor: const Color(0xFFE65100),
        inactiveColor: isDark ? const Color(0xFFFFB74D) : const Color(0xFFEF6C00),
      ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.md.w, 0, AppSpacing.md.w, AppSpacing.sm.h),
      child: Container(
        height: 38.h,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
          border: Border.all(
            color: isDark ? AppColors.darkOutline : AppColors.outline,
          ),
        ),
        child: Row(
          children: tabs.map((tab) {
            final isSelected = _selectedTab == tab.index;
            final itemColor = isSelected ? Colors.white : tab.inactiveColor;
            final activeBgColor = tab.activeColor;

            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r - 2),
                onTap: () => setState(() {
                  _selectedTab = tab.index;
                  _selectedContactId = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: isSelected ? activeBgColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r - 2),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: activeBgColor.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tab.icon,
                          size: 15.r,
                          color: itemColor,
                        ),
                        SizedBox(width: 5.w),
                        Flexible(
                          child: Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: itemColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSearchBar({required bool isWide}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.md.w, AppSpacing.xs.h, AppSpacing.md.w, AppSpacing.xs.h),
      child: TextField(
        key: const Key('udharSearchBar'),
        controller: _searchController,
        onChanged: (v) {
          setState(() => _searchQuery = v);
          ref.read(udharGlobalSearchQueryProvider.notifier).state = v;
        },
        decoration: InputDecoration(
          hintText: 'Search name or mobile...',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    ref.read(udharGlobalSearchQueryProvider.notifier).state = '';
                  },
                )
              : null,
        ),
        style: AppTextStyles.bodyMedium,
      ),
    );
  }

  Widget _buildBody({required bool isWide}) {
    // When global search is active (non-empty query), show unified results across Buyers & Suppliers
    if (_searchQuery.trim().isNotEmpty) {
      return _buildSearchResults(isWide: isWide);
    }

    if (_selectedTab == 2) {
      return _buildDirectCashPlaceholder();
    }

    final provider =
        _selectedTab == 0 ? buyerListProvider : supplierListProvider;
    final asyncContacts = ref.watch(provider);

    return asyncContacts.when(
      loading: () => const AppLoader(message: 'Loading contacts...'),
      error: (e, _) => AppErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(provider),
      ),
      data: (contacts) {
        if (contacts.isEmpty) {
          return AppEmptyState(
            title: _selectedTab == 0 ? 'No buyers yet' : 'No suppliers yet',
            subtitle: 'Tap + to add your first contact',
            icon: Icons.people_outline_rounded,
            actionLabel: 'Add Contact',
            onAction: _openNewContactForm,
          );
        }

        final effectiveId = isWide ? _getEffectiveContactId(contacts) : null;

        return ListView.separated(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
          itemCount: contacts.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            indent: AppSpacing.lg.w + 48.w, // align with avatar
          ),
          itemBuilder: (_, i) {
            final contact = contacts[i];
            final isSelected = isWide && contact.id == effectiveId;
            return _ContactRow(
              contact: contact,
              isSelected: isSelected,
              onTap: () {
                if (isWide) {
                  setState(() => _selectedContactId = contact.id);
                } else {
                  context.goNamed(
                    RouteNames.contactLedger,
                    pathParameters: {'contactId': contact.id},
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResults({required bool isWide}) {
    final searchResultsAsync = ref.watch(udharGlobalSearchProvider);

    return searchResultsAsync.when(
      loading: () => const AppLoader(message: 'Searching contacts...'),
      error: (e, _) => AppErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(allContactListProvider),
      ),
      data: (results) {
        if (results.isEmpty) {
          return AppEmptyState(
            title: 'No matching records',
            subtitle: 'No contacts matched "$_searchQuery"',
            icon: Icons.person_search_rounded,
          );
        }

        final effectiveId = isWide ? _getEffectiveContactId(results) : null;

        return ListView.separated(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
          itemCount: results.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            indent: AppSpacing.lg.w + 48.w,
          ),
          itemBuilder: (_, i) {
            final contact = results[i];
            final isSelected = isWide && contact.id == effectiveId;
            return _ContactRow(
              contact: contact,
              isSelected: isSelected,
              showTypeBadge: true,
              onTap: () {
                if (isWide) {
                  setState(() => _selectedContactId = contact.id);
                } else {
                  context.goNamed(
                    RouteNames.contactLedger,
                    pathParameters: {'contactId': contact.id},
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDirectCashPlaceholder() {
    return AppEmptyState(
      title: 'Direct Cash & Opening Balances',
      subtitle: 'Record prior balances or new direct loans with simple interest',
      icon: Icons.account_balance_wallet_outlined,
      actionLabel: 'Set Opening Balance',
      onAction: _openOpeningBalanceForm,
    );
  }

  void _openOpeningBalanceForm() {
    // Opening Balance workflow has been retired.
    // This action is no longer available in the Contacts feature.
  }

  void _openNewContactForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ContactFormScreen(
        type: _selectedTab == 0 ? ContactType.buyer : ContactType.supplier,
      ),
    );
  }
}

class _ContactRow extends ConsumerWidget {
  const _ContactRow({
    required this.contact,
    required this.onTap,
    this.isSelected = false,
    this.showTypeBadge = false,
  });

  final Contact contact;
  final VoidCallback onTap;
  final bool isSelected;
  final bool showTypeBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync =
        ref.watch(contactTotalBalanceProvider(contact.id));

    final typeLabel = contact.isBuyer ? 'Buyer' : 'Supplier';
    final subtitleText = showTypeBadge
        ? '$typeLabel • ${contact.mobileNumber}'
        : contact.mobileNumber;

    final tile = balanceAsync.when(
      loading: () => LedgerListTile(
        name: contact.name,
        amount: 0,
        isCredit: true,
        mobile: subtitleText,
        onTap: onTap,
      ),
      error: (_, __) => LedgerListTile(
        name: contact.name,
        amount: 0,
        isCredit: true,
        mobile: subtitleText,
        onTap: onTap,
      ),
      data: (balance) => LedgerListTile(
        name: contact.name,
        amount: balance.abs(),
        isCredit: balance >= 0,
        mobile: subtitleText,
        onTap: onTap,
      ),
    );

    if (!isSelected) return tile;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primaryLight.withValues(alpha: 0.15)
            : AppColors.primaryLight.withValues(alpha: 0.1),
        border: const Border(
          left: BorderSide(
            color: AppColors.primary,
            width: 4,
          ),
        ),
      ),
      child: tile,
    );
  }
}
