import 'package:go_router/go_router.dart';
import '../../core/auth/shop_access_controller.dart';
import '../../features/auth/presentation/pages/shop_activation_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/billing/presentation/pages/home_page.dart';
import '../../features/product/presentation/pages/products_page.dart';
import '../../features/product/presentation/pages/product_list_page.dart';
import '../../features/product/presentation/pages/add_product_page.dart';
import '../../features/product/presentation/pages/add_product_using_qr_page.dart';
import '../../features/product/presentation/pages/edit_product_page.dart';
import '../../features/shop/presentation/pages/shop_details_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/billing/presentation/pages/scanner_page.dart';
import '../../features/billing/presentation/pages/checkout_page.dart';
import '../../features/sales/presentation/pages/sales_page.dart';
import '../../features/customer/presentation/pages/customer_page.dart';
import '../../features/expense/presentation/pages/expense_page.dart';
import '../../features/payment_qr/presentation/pages/payment_qr_page.dart';
import '../../features/product/domain/entities/product.dart';

final router = GoRouter(
  initialLocation: '/',
  refreshListenable: ShopAccessController.instance,
  redirect: (context, state) {
    final isAuthenticated = ShopAccessController.instance.isAuthenticated;
    final isActivationRoute = state.matchedLocation == '/activate';

    if (!isAuthenticated && !isActivationRoute) {
      return '/activate';
    }

    if (isAuthenticated && isActivationRoute) {
      return '/';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/activate',
      builder: (context, state) => const ShopActivationPage(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardPage(),
    ),
    GoRoute(
      path: '/billing',
      builder: (context, state) => const HomePage(),
      routes: [
        GoRoute(
          path: 'scanner',
          builder: (context, state) => const ScannerPage(),
        ),
        GoRoute(
          path: 'checkout',
          builder: (context, state) => const CheckoutPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/sales',
      builder: (context, state) => const SalesPage(),
    ),
    GoRoute(
      path: '/customers',
      builder: (context, state) => const CustomerPage(),
    ),
    GoRoute(
      path: '/payment-qr',
      builder: (context, state) => const PaymentQrPage(),
    ),
    GoRoute(
      path: '/expenses',
      builder: (context, state) => const ExpensePage(),
    ),
    GoRoute(
      path: '/products',
      builder: (context, state) => const ProductsPage(),
      routes: [
        GoRoute(
          path: 'list',
          builder: (context, state) => const ProductListPage(),
        ),
        GoRoute(
          path: 'add',
          builder: (context, state) => const AddProductPage(),
        ),
        GoRoute(
          path: 'add-with-qr',
          builder: (context, state) => const AddProductUsingQrPage(),
        ),
        GoRoute(
          path: 'edit/:id',
          builder: (context, state) {
            final product = state.extra as Product?;
            if (product == null) {
              return const ProductsPage();
            }
            return EditProductPage(product: product);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/shop',
      builder: (context, state) => const ShopDetailsPage(),
    ),
  ],
);
