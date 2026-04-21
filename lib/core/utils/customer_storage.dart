import '../data/hive_database.dart';

class CustomerStorage {
  static Future<String> saveCustomer({
    required String name,
    required String mobile,
    required String address,
  }) async {
    final customerId = 'CUS-${DateTime.now().microsecondsSinceEpoch}';
    final customer = <String, dynamic>{
      'id': customerId,
      'name': name.trim(),
      'mobile': mobile.trim(),
      'address': address.trim(),
      'createdAt': DateTime.now().toIso8601String(),
    };

    await HiveDatabase.customerBox.put(customerId, customer);
    return customerId;
  }

  static Future<void> updateCustomer({
    required String id,
    required String name,
    required String mobile,
    required String address,
  }) async {
    final existingCustomer =
        Map<String, dynamic>.from(HiveDatabase.customerBox.get(id) ?? {});
    if (existingCustomer.isEmpty) return;

    final updatedCustomer = <String, dynamic>{
      ...existingCustomer,
      'id': id,
      'name': name.trim(),
      'mobile': mobile.trim(),
      'address': address.trim(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    await HiveDatabase.customerBox.put(id, updatedCustomer);
  }

  static Future<void> deleteCustomer(String id) async {
    await HiveDatabase.customerBox.delete(id);
  }

  static List<Map> getCustomers() {
    final customers = HiveDatabase.customerBox.values.toList();
    customers.sort((a, b) {
      final aName = a['name']?.toString().toLowerCase() ?? '';
      final bName = b['name']?.toString().toLowerCase() ?? '';
      return aName.compareTo(bName);
    });
    return customers;
  }
}
