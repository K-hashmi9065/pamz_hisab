import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/db/sqlite/app_database.dart';
import '../../../../core/db/sqlite/database_helper.dart';
import '../../../../core/db/storage_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_bar_widgets.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../data/repositories/audit_log_repository.dart';

typedef AuditLogItem = AuditLogEntry;

final auditLogDatabaseHelperProvider = Provider<DatabaseHelper>(
  (ref) => DatabaseHelper(AppDatabase.instance),
);

final auditLogRepositoryProvider = Provider<AuditLogRepository>((ref) {
  return AuditLogRepositoryImpl(
    AppStorageConfig.isSqlite
        ? ref.watch(auditLogDatabaseHelperProvider)
        : null,
  );
});

final auditLogsProvider = FutureProvider<List<AuditLogItem>>((ref) async {
  final repo = ref.watch(auditLogRepositoryProvider);
  return repo.getAuditLogs();
});

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String _searchQuery = '';
  String _selectedEntity = 'all';
  String _selectedAction = 'all';

  final _entities = const [
    ('all', 'All Entities'),
    ('contacts', 'Contacts'),
    ('direct_udhar_loans', 'Udhar Loans'),
    ('repayments', 'Repayments'),
    ('family_transactions', 'Family Txns'),
    ('budgets', 'Budgets'),
    ('categories', 'Categories'),
  ];

  final _actions = const [
    ('all', 'All Actions'),
    ('create', 'Create'),
    ('update', 'Update'),
    ('delete', 'Delete'),
  ];

  void _showDetailDialog(AuditLogItem item) {
    Map<String, dynamic>? parsedJson;
    if (item.changedFieldsJson != null) {
      try {
        parsedJson = jsonDecode(item.changedFieldsJson!) as Map<String, dynamic>?;
      } catch (_) {}
    }

    final dateFmt = DateFormat('dd MMMM yyyy, hh:mm:ss a');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            _buildActionBadge(item.action),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'Audit: ${item.entityType}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Timestamp', dateFmt.format(item.performedAt)),
              _detailRow('Entity Type', item.entityType),
              _detailRow('Record ID', item.entityId),
              _detailRow('Audit ID', item.id),
              const Divider(),
              const Text('Changed Fields / Metadata:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6.h),
              if (parsedJson != null) ...[
                Container(
                  padding: EdgeInsets.all(AppSpacing.sm.w),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: parsedJson.entries.map((e) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 2.h),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${e.key}: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                            Expanded(child: Text('${e.value}')),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ] else ...[
                Text(
                  item.changedFieldsJson ?? 'No detailed payload recorded for this action.',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90.w, child: Text('$label:', style: const TextStyle(color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildActionBadge(String action) {
    final (label, color, bg) = switch (action.toLowerCase()) {
      'create' => ('CREATE', AppColors.credit, AppColors.creditLight.withValues(alpha: 0.3)),
      'update' => ('UPDATE', AppColors.primary, AppColors.primaryLight.withValues(alpha: 0.3)),
      'delete' => ('DELETE', AppColors.debit, AppColors.debitLight.withValues(alpha: 0.3)),
      _ => (action.toUpperCase(), AppColors.textSecondary, AppColors.cardBackground),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(auditLogsProvider);
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');
    final isWide = MediaQuery.of(context).size.width >= AppConstants.tabletBreakpoint;

    final content = Column(
        children: [
          // Filter & Search Controls
          Container(
            color: Theme.of(context).cardColor,
            padding: EdgeInsets.all(AppSpacing.md.w),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by record ID, payload, or entity...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                ),
                SizedBox(height: AppSpacing.sm.h),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ..._entities.map((e) {
                        final isSel = _selectedEntity == e.$1;
                        return Padding(
                          padding: EdgeInsets.only(right: 6.w),
                          child: FilterChip(
                            label: Text(
                              e.$2,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                                color: isSel ? Colors.white : AppColors.primary,
                              ),
                            ),
                            selected: isSel,
                            showCheckmark: isSel,
                            checkmarkColor: Colors.white,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                            selectedColor: AppColors.primary,
                            side: BorderSide(
                              color: isSel ? AppColors.primary : AppColors.primary.withValues(alpha: 0.25),
                              width: isSel ? 1.5 : 1.0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                            onSelected: (_) => setState(() => _selectedEntity = e.$1),
                          ),
                        );
                      }),
                      Container(
                        height: 24.h,
                        width: 1,
                        margin: EdgeInsets.symmetric(horizontal: 6.w),
                        color: Theme.of(context).dividerColor,
                      ),
                      ..._actions.map((a) {
                        final isSel = _selectedAction == a.$1;
                        final actionColor = switch (a.$1) {
                          'create' => AppColors.credit,
                          'update' => AppColors.primary,
                          'delete' => AppColors.debit,
                          _ => AppColors.primary,
                        };

                        return Padding(
                          padding: EdgeInsets.only(right: 6.w),
                          child: FilterChip(
                            label: Text(
                              a.$2,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                                color: isSel ? Colors.white : actionColor,
                              ),
                            ),
                            selected: isSel,
                            showCheckmark: isSel,
                            checkmarkColor: Colors.white,
                            backgroundColor: actionColor.withValues(alpha: 0.08),
                            selectedColor: actionColor,
                            side: BorderSide(
                              color: isSel ? actionColor : actionColor.withValues(alpha: 0.25),
                              width: isSel ? 1.5 : 1.0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                            onSelected: (_) => setState(() => _selectedAction = a.$1),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: logsAsync.when(
              loading: () => const AppLoader(message: 'Loading audit history...'),
              error: (e, _) => AppErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(auditLogsProvider),
              ),
              data: (logs) {
                final filtered = logs.where((item) {
                  if (_selectedEntity != 'all' && item.entityType != _selectedEntity) {
                    return false;
                  }
                  if (_selectedAction != 'all' && item.action.toLowerCase() != _selectedAction) {
                    return false;
                  }
                  if (_searchQuery.isNotEmpty) {
                    final fullText = '${item.entityType} ${item.entityId} ${item.changedFieldsJson ?? ''}'.toLowerCase();
                    if (!fullText.contains(_searchQuery)) return false;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: AppEmptyState(
                      title: 'No audit records found',
                      subtitle: 'Mutations and financial actions will appear here with timestamps.',
                      icon: Icons.history_rounded,
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.all(AppSpacing.md.w),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return ListTile(
                      onTap: () => _showDetailDialog(item),
                      leading: _buildActionBadge(item.action),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.entityType,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            dateFmt.format(item.performedAt),
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        'ID: ${item.entityId} ${item.changedFieldsJson != null ? '• ${item.changedFieldsJson}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                    );
                  },
                );
              },
            ),
          ),
        ],
      );

    return Scaffold(
      appBar: CustomAppBar(
        title: 'System Audit Logs',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Logs',
            onPressed: () => ref.invalidate(auditLogsProvider),
          ),
        ],
      ),
      body: isWide
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: content,
              ),
            )
          : content,
    );
  }
}
