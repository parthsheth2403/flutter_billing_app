import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/shop_access_controller.dart';
import '../../../../core/theme/app_theme.dart';

class ShopActivationPage extends StatefulWidget {
  const ShopActivationPage({super.key});

  @override
  State<ShopActivationPage> createState() => _ShopActivationPageState();
}

class _ShopActivationPageState extends State<ShopActivationPage> {
  final _formKey = GlobalKey<FormState>();
  final _shopIdController = TextEditingController();
  final _shopKeyController = TextEditingController();
  final ShopAccessController _accessController = ShopAccessController.instance;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _shopIdController.text = _accessController.cachedShopId ?? '';
  }

  @override
  void dispose() {
    _shopIdController.dispose();
    _shopKeyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final message = await _accessController.signIn(
      shopId: _shopIdController.text,
      shopKey: _shopKeyController.text,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (message == null) {
      context.go('/');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _accessController.profile;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mahavir Trading Company',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Activate this shop to continue billing. Your products, customers, and sales stay safely stored on this device.',
                    style: TextStyle(
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x110F172A),
                          blurRadius: 18,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (profile != null) ...[
                            _InfoChip(
                              label: profile.shopName.isEmpty
                                  ? profile.shopId
                                  : '${profile.shopName} • ${profile.shopId}',
                              helper: profile.isExpired
                                  ? 'Expired on ${profile.formattedExpiryDate}'
                                  : 'Valid until ${profile.formattedExpiryDate}',
                              color: profile.isExpired
                                  ? const Color(0xFFDC2626)
                                  : AppTheme.primaryColor,
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _shopIdController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Shop ID',
                              hintText: 'e.g. SH123',
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Enter shop ID'
                                    : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _shopKeyController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Shop Key',
                              hintText: 'Enter your shop key',
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Enter shop key'
                                    : null,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isSubmitting ? null : _submit,
                              icon: _isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.lock_open_rounded),
                              label: Text(
                                _isSubmitting
                                    ? 'Verifying...'
                                    : 'Activate Shop',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Local billing data is preserved even if the session expires or you log out.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String helper;
  final Color color;

  const _InfoChip({
    required this.label,
    required this.helper,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            helper,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
