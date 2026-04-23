import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/sales_storage.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          top: false,
          child: ValueListenableBuilder(
            valueListenable: HiveDatabase.salesBox.listenable(),
            builder: (context, box, _) {
              final snapshot = SalesStorage.buildSnapshot(
                HiveDatabase.salesBox.values,
              );

              return BlocBuilder<ShopBloc, ShopState>(
                builder: (context, state) {
                  final shopName =
                      state is ShopLoaded && state.shop.name.trim().isNotEmpty
                          ? state.shop.name.trim()
                          : 'Company';

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DashboardHeader(shopName: shopName),
                        Transform.translate(
                          offset: const Offset(0, -34),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Column(
                              children: [
                                _StatsPanel(snapshot: snapshot),
                                const SizedBox(height: 18),
                                _QuickActionsPanel(
                                  onBilling: () => context.push('/billing'),
                                  onPaymentQr: () =>
                                      context.push('/payment-qr'),
                                  onExpenses: () => context.push('/expenses'),
                                  onProducts: () => context.push('/products'),
                                  onSales: () => context.push('/sales'),
                                  onCustomers: () => context.push('/customers'),
                                  onSettings: () => context.push('/settings'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final String shopName;

  const _DashboardHeader({required this.shopName});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, topInset + 18, 22, 54),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            Color(0xFF0B2F2E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  final SalesSnapshot snapshot;

  const _StatsPanel({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E8E1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14123F3D),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatCell(
              title: 'Total Sales',
              value: '₹ ${snapshot.todaySales.toStringAsFixed(2)}',
              subtitle: '${snapshot.todayBills} bills today',
            ),
          ),
          Container(width: 1, height: 62, color: const Color(0xFFE4E8E1)),
          Expanded(
            child: _StatCell(
              title: 'Invoices',
              value: snapshot.monthBills.toString(),
              subtitle: 'This month',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _StatCell({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF4B5F5B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1F2937),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF82908D),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsPanel extends StatelessWidget {
  final VoidCallback onBilling;
  final VoidCallback onPaymentQr;
  final VoidCallback onExpenses;
  final VoidCallback onProducts;
  final VoidCallback onSales;
  final VoidCallback onCustomers;
  final VoidCallback onSettings;

  const _QuickActionsPanel({
    required this.onBilling,
    required this.onPaymentQr,
    required this.onExpenses,
    required this.onProducts,
    required this.onSales,
    required this.onCustomers,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE4E8E1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _ActionShortcut(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Expenses',
                  onTap: onExpenses,
                ),
              ),
              Expanded(
                child: _ActionShortcut(
                  icon: Icons.person_rounded,
                  label: 'Customers',
                  onTap: onCustomers,
                ),
              ),
              Expanded(
                child: _ActionShortcut(
                  icon: Icons.qr_code_2_rounded,
                  label: 'Payment QR',
                  onTap: onPaymentQr,
                ),
              ),
              Expanded(
                child: _ActionShortcut(
                  icon: Icons.cloud_upload_rounded,
                  label: 'Sales Backup',
                  onTap: onSettings,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Manage',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1F2937),
          ),
        ),
      //  const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _DashboardTile(
              icon: Icons.point_of_sale_rounded,
              title: 'Create Bill',
              subtitle: 'Start billing',
              onTap: onBilling,
            ),
            _DashboardTile(
              icon: Icons.inventory_2_rounded,
              title: 'Products',
              subtitle: 'Manage stocks',
              onTap: onProducts,
            ),
            _DashboardTile(
              icon: Icons.bar_chart_rounded,
              title: 'Sales',
              subtitle: 'Bill history',
              onTap: onSales,
            ),
            _DashboardTile(
              icon: Icons.settings_rounded,
              title: 'Settings',
              subtitle: 'Shop settings',
              onTap: onSettings,
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionShortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionShortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 25),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF455855),
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DashboardTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE4E8E1)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D123F3D),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.15,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
