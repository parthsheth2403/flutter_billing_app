import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:app_settings/app_settings.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/shop_access_controller.dart';
import '../../../../core/utils/billing_settings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/data_backup_service.dart';
import '../../../billing/presentation/bloc/billing_bloc.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';
import '../bloc/printer_bloc.dart';
import '../bloc/printer_event.dart';
import '../bloc/printer_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ShopAccessController _accessController = ShopAccessController.instance;
  bool _isExportingBackup = false;
  bool _isImportingBackup = false;
  bool _gstEnabled = BillingSettings.isGstEnabled;
  late final TextEditingController _gstRateController;

  @override
  void initState() {
    super.initState();
    _gstRateController = TextEditingController(
      text: BillingSettings.gstRate.toStringAsFixed(
        BillingSettings.gstRate == BillingSettings.gstRate.roundToDouble()
            ? 0
            : 2,
      ),
    );
    // Re-initialize printer state whenever settings page opens
    context.read<PrinterBloc>().add(InitPrinterEvent());
  }

  @override
  void dispose() {
    _gstRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left,
              size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Profile Section
              Container(
                width: double.infinity,
                color: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                child: BlocBuilder<ShopBloc, ShopState>(
                  builder: (context, state) {
                    String shopName = 'Retail Billing App';
                    String initials = 'EG';
                    if (state is ShopLoaded && state.shop.name.isNotEmpty) {
                      shopName = state.shop.name;
                      final parts = shopName.split(' ');
                      initials = parts
                          .take(2)
                          .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
                          .join('');
                      if (initials.isEmpty) initials = 'S';
                    }

                    return Column(
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.2),
                                  blurRadius: 15,
                                  spreadRadius: 5,
                                )
                              ]),
                          alignment: Alignment.center,
                          child: Text(initials,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -1)),
                        ),
                        const SizedBox(height: 16),
                        Text(shopName.toUpperCase(),
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Management Section
              _buildSectionHeader('Management'),
              _buildListGroup(
                children: [
                  _buildListItem(
                    icon: Icons.qr_code_scanner,
                    title: 'Products',
                    subtitle: 'Manage stock and barcodes',
                    onTap: () => context.push('/products'),
                  ),
                  _buildDivider(),
                  _buildListItem(
                    icon: Icons.storefront,
                    title: 'Shop Details',
                    subtitle: 'Edit business info & address',
                    onTap: () => context.push('/shop'),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _buildSectionHeader('Billing'),
              _buildListGroup(
                children: [
                  SwitchListTile(
                    value: _gstEnabled,
                    onChanged: (value) => _saveGstSettings(enabled: value),
                    title: const Text(
                      'Enable GST',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'Apply GST in billing, saved sales, and printed receipts',
                      style: TextStyle(fontSize: 12),
                    ),
                    activeThumbColor: AppTheme.primaryColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                  ),
                  _buildDivider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'GST Rate (%)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _gstRateController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            hintText: '18',
                            suffixText: '%',
                          ),
                          onSubmitted: (_) => _saveGstSettings(),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton(
                            onPressed: _saveGstSettings,
                            child: const Text('Save GST'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _buildSectionHeader('Access'),
              AnimatedBuilder(
                animation: _accessController,
                builder: (context, _) {
                  final profile = _accessController.profile;
                  final accessSubtitle = profile == null
                      ? 'Shop activation required'
                      : '${profile.shopId} • Expires ${DateFormat('dd MMM yyyy').format(profile.expiryDate)}';

                  return _buildListGroup(
                    children: [
                      _buildListItem(
                        icon: Icons.verified_user_rounded,
                        title: 'Shop Access',
                        subtitle: accessSubtitle,
                        trailingIcon: null,
                      ),
                      _buildDivider(),
                      _buildListItem(
                        icon: Icons.logout_rounded,
                        title: 'Logout',
                        subtitle: 'Sign out without deleting local shop data',
                        trailingIcon: null,
                        onTap: _logout,
                        trailingWidget: Icon(
                          Icons.chevron_right,
                          color: Colors.grey[300],
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              _buildSectionHeader('Data'),
              _buildListGroup(
                children: [
                  _buildListItem(
                    icon: Icons.upload_file_rounded,
                    title: 'Export Backup',
                    subtitle:
                        'Create one file with products, customers, sales, expenses, shop, and settings',
                    trailingWidget: _isExportingBackup
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: _isExportingBackup ? null : _exportBackup,
                  ),
                  _buildDivider(),
                  _buildListItem(
                    icon: Icons.download_rounded,
                    title: 'Import Backup',
                    subtitle:
                        'Restore everything from a previously exported backup file',
                    trailingWidget: _isImportingBackup
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: _isImportingBackup ? null : _importBackup,
                  ),
                ],
              ),

              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text(
                  'Import will replace current local data on this device with the contents of the backup file.',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[500],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Hardware Section
              _buildSectionHeader('Hardware'),
              BlocConsumer<PrinterBloc, PrinterState>(
                listener: (context, state) {
                  if (state.errorMessage != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(state.errorMessage!),
                        backgroundColor: Colors.red));
                  } else if (state.status == PrinterStatus.connected) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Connected to printer'),
                        backgroundColor: Colors.green));
                  }
                },
                builder: (context, state) {
                  final devices = List.of(state.devices)
                    ..sort((a, b) => a.name.compareTo(b.name));

                  return _buildListGroup(
                    children: [
                      _buildListItem(
                        icon: Icons.print,
                        title: 'Print Device',
                        subtitleWidget: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              state.connectedMac != null
                                  ? (state.connectedName ?? 'Printer connected')
                                  : 'No printer connected',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500]),
                            ),
                            if (state.connectedMac != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.teal[100],
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: Colors.teal[200]!)),
                                child: Text(
                                  'CONNECTED',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal[700]),
                                ),
                              ),
                          ],
                        ),
                        trailingWidget: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (state.status == PrinterStatus.scanning ||
                                state.status == PrinterStatus.connecting)
                              const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                            else
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: () => context
                                    .read<PrinterBloc>()
                                    .add(RefreshPrinterEvent()),
                                color: AppTheme.primaryColor,
                              ),
                            IconButton(
                              icon: const Icon(Icons.settings),
                              onPressed: () {
                                AppSettings.openAppSettings(
                                    type: AppSettingsType.bluetooth);
                              },
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                      _buildDivider(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: state.connectedMac == null ||
                                    state.status == PrinterStatus.connecting ||
                                    state.status == PrinterStatus.testPrinting
                                ? null
                                : () {
                                    context.read<PrinterBloc>().add(
                                          TestPrintEvent(_currentShopName()),
                                        );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Sending test page to printer...',
                                        ),
                                      ),
                                    );
                                  },
                            icon: state.status == PrinterStatus.testPrinting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.receipt_long_rounded),
                            label: Text(
                              state.connectedMac == null
                                  ? 'Connect Printer To Test'
                                  : 'Print Test Page',
                            ),
                          ),
                        ),
                      ),
                      if (devices.isNotEmpty) ...[
                        _buildDivider(),
                        ...devices.asMap().entries.map((entry) {
                          final index = entry.key;
                          final device = entry.value;
                          final isConnected =
                              state.connectedMac == device.macAdress;

                          return Column(
                            children: [
                              _buildListItem(
                                icon: isConnected
                                    ? Icons.bluetooth_connected
                                    : Icons.print_outlined,
                                title: device.name,
                                subtitle: device.macAdress,
                                trailingWidget: isConnected
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.teal[50],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.teal[200]!),
                                        ),
                                        child: Text(
                                          'Connected',
                                          style: TextStyle(
                                            color: Colors.teal[700],
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      )
                                    : TextButton(
                                        onPressed: state.status ==
                                                PrinterStatus.connecting
                                            ? null
                                            : () =>
                                                context.read<PrinterBloc>().add(
                                                      ConnectPrinterEvent(
                                                        mac: device.macAdress,
                                                        name: device.name,
                                                      ),
                                                    ),
                                        child: const Text('Connect'),
                                      ),
                                trailingIcon: null,
                                onTap: state.status == PrinterStatus.connecting
                                    ? null
                                    : () => context.read<PrinterBloc>().add(
                                          ConnectPrinterEvent(
                                            mac: device.macAdress,
                                            name: device.name,
                                          ),
                                        ),
                              ),
                              if (index != devices.length - 1) _buildDivider(),
                            ],
                          );
                        }),
                      ],
                    ],
                  );
                },
              ),

              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text(
                  "To connect a new device, tap the Settings gear to pair it in your phone's Bluetooth settings, then return, hit Refresh, and tap the printer you want to connect.",
                  style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[500]),
                ),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportBackup() async {
    setState(() => _isExportingBackup = true);
    try {
      await DataBackupService.shareBackupFile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup file is ready to share.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExportingBackup = false);
      }
    }
  }

  Future<void> _saveGstSettings({bool? enabled}) async {
    final parsedRate = double.tryParse(_gstRateController.text.trim());
    if (parsedRate == null || parsedRate < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid GST rate'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final resolvedEnabled = enabled ?? _gstEnabled;
    await BillingSettings.saveGstSettings(
      enabled: resolvedEnabled,
      rate: parsedRate,
    );

    if (!mounted) return;

    setState(() {
      _gstEnabled = resolvedEnabled;
      _gstRateController.text = parsedRate.toStringAsFixed(
        parsedRate == parsedRate.roundToDouble() ? 0 : 2,
      );
    });

    context.read<BillingBloc>().add(RefreshBillingPreferencesEvent());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('GST settings saved'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _importBackup() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Import Backup'),
              content: const Text(
                'This will replace all current local products, customers, sales, expenses, shop details, and saved settings with the selected backup file. Continue?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Import'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    setState(() => _isImportingBackup = true);
    try {
      final snapshot = await DataBackupService.pickAndImportBackupForShop(
        expectedShopId: _accessController.cachedShopId,
      );
      if (snapshot == null || !mounted) return;

      await ShopAccessController.instance.init();

      if (!mounted) return;
      context.read<ProductBloc>().add(LoadProducts());
      context.read<ShopBloc>().add(LoadShopEvent());
      context.read<PrinterBloc>().add(InitPrinterEvent());
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backup imported for ${snapshot.shopId ?? 'this shop'}: ${snapshot.productCount} products, ${snapshot.customerCount} customers, ${snapshot.saleCount} sales, ${snapshot.expenseCount} expenses restored.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isImportingBackup = false);
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.2),
        ),
      ),
    );
  }

  Widget _buildListGroup({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 1, color: Colors.grey[50], indent: 64);
  }

  Widget _buildListItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? subtitleWidget,
    Widget? trailingWidget,
    IconData? trailingIcon = Icons.chevron_right,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                  if (subtitleWidget != null) ...[
                    const SizedBox(height: 4),
                    subtitleWidget,
                  ]
                ],
              ),
            ),
            if (trailingWidget != null)
              trailingWidget
            else if (trailingIcon != null)
              Icon(trailingIcon, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'This will sign you out of the shop access session, but all products, customers, bills, and sales data will remain on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    await _accessController.logout();
    if (!mounted) return;
    context.go('/activate');
  }

  String _currentShopName() {
    final state = context.read<ShopBloc>().state;
    if (state is ShopLoaded && state.shop.name.trim().isNotEmpty) {
      return state.shop.name.trim();
    }
    return 'Retail Billing App';
  }
}
