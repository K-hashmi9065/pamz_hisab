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
import '../../../direct_udhar/presentation/widgets/opening_balance_form_sheet.dart';
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
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Set Opening Balance',
            onPressed: () => _openOpeningBalanceForm(),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'New Contact',
            onPressed: _openNewContactForm,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(130.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSegmentedControl(),
              _buildSearchBar(),
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

  Widget _buildDetailView(BuildContext context) {
    if (_selectedContactId != null) {
      return ContactDetailScreen(
        key: ValueKey(_selectedContactId),
        contactId: _selectedContactId!,
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

  Widget _buildSegmentedControl() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w, vertical: AppSpacing.sm.h),
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('Buyers'), icon: Icon(Icons.people_rounded)),
          ButtonSegment(value: 1, label: Text('Suppliers'), icon: Icon(Icons.store_rounded)),
          ButtonSegment(value: 2, label: Text('Direct Cash'), icon: Icon(Icons.monetization_on_rounded)),
        ],
        selected: {_selectedTab},
        onSelectionChanged: (selection) =>
            setState(() {
              _selectedTab = selection.first;
              _selectedContactId = null;
            }),
        style: const ButtonStyle(
          visualDensity: VisualDensity.comfortable,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg.w, 0, AppSpacing.lg.w, AppSpacing.sm.h),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search name or mobile...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
        style: AppTextStyles.body,
      ),
    );
  }

  Widget _buildBody({required bool isWide}) {
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
        final filtered = _searchQuery.isEmpty
            ? contacts
            : contacts
                .where((c) =>
                    c.name.toLowerCase().contains(_searchQuery) ||
                    c.mobileNumber.contains(_searchQuery))
                .toList();

        if (filtered.isEmpty) {
          return AppEmptyState(
            title: _selectedTab == 0 ? 'No buyers yet' : 'No suppliers yet',
            subtitle: 'Tap + to add your first contact',
            icon: Icons.people_outline_rounded,
            actionLabel: 'Add Contact',
            onAction: _openNewContactForm,
          );
        }

        return ListView.separated(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            indent: AppSpacing.lg.w + 48.w, // align with avatar
          ),
          itemBuilder: (_, i) {
            final contact = filtered[i];
            final isSelected = isWide && contact.id == _selectedContactId;
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const OpeningBalanceFormSheet(),
    );
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
  });

  final Contact contact;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync =
        ref.watch(contactTotalBalanceProvider(contact.id));

    final tile = balanceAsync.when(
      loading: () => LedgerListTile(
        name: contact.name,
        amount: 0,
        isCredit: true,
        mobile: contact.mobileNumber,
        onTap: onTap,
      ),
      error: (_, __) => LedgerListTile(
        name: contact.name,
        amount: 0,
        isCredit: true,
        mobile: contact.mobileNumber,
        onTap: onTap,
      ),
      data: (balance) => LedgerListTile(
        name: contact.name,
        amount: balance.abs(),
        isCredit: balance >= 0,
        mobile: contact.mobileNumber,
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
