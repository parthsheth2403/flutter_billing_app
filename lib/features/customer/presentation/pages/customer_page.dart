import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/utils/customer_storage.dart';

class CustomerPage extends StatefulWidget {
  const CustomerPage({super.key});

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ValueListenableBuilder(
          valueListenable: HiveDatabase.customerBox.listenable(),
          builder: (context, box, _) {
            final customers = CustomerStorage.getCustomers();
            final filteredCustomers = customers.where((customer) {
              final query = _searchQuery.toLowerCase().trim();
              if (query.isEmpty) return true;

              final haystack = [
                customer['name']?.toString() ?? '',
                customer['mobile']?.toString() ?? '',
                customer['address']?.toString() ?? '',
              ].join(' ').toLowerCase();

              return haystack.contains(query);
            }).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                FilledButton.icon(
                  onPressed: () => _showCustomerForm(context),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Add Customer'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search by name, mobile, or address',
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                if (customers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Center(child: Text('No customers added yet.')),
                  )
                else if (filteredCustomers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child:
                        Center(child: Text('No customers match your search.')),
                  )
                else
                  ...filteredCustomers.map(
                    (customer) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        title: Text(
                          customer['name']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          [
                            customer['mobile']?.toString() ?? '',
                            customer['address']?.toString() ?? '',
                          ].where((value) => value.isNotEmpty).join('\n'),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              await _showCustomerForm(
                                context,
                                customer: Map<String, dynamic>.from(customer),
                              );
                              return;
                            }

                            if (value == 'delete') {
                              await _deleteCustomer(
                                context,
                                customer['id']?.toString() ?? '',
                                customer['name']?.toString() ?? 'this customer',
                              );
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showCustomerForm(
    BuildContext context, {
    Map<String, dynamic>? customer,
  }) async {
    final isEditing = customer != null;
    final nameController =
        TextEditingController(text: customer?['name']?.toString() ?? '');
    final mobileController =
        TextEditingController(text: customer?['mobile']?.toString() ?? '');
    final addressController =
        TextEditingController(text: customer?['address']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isEditing ? 'Edit Customer' : 'Add Customer',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration:
                        const InputDecoration(labelText: 'Customer Name'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter customer name'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: mobileController,
                    keyboardType: TextInputType.phone,
                    decoration:
                        const InputDecoration(labelText: 'Mobile Number'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter mobile number'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addressController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;

                        if (isEditing) {
                          await CustomerStorage.updateCustomer(
                            id: customer['id'].toString(),
                            name: nameController.text,
                            mobile: mobileController.text,
                            address: addressController.text,
                          );
                        } else {
                          await CustomerStorage.saveCustomer(
                            name: nameController.text,
                            mobile: mobileController.text,
                            address: addressController.text,
                          );
                        }

                        if (context.mounted) Navigator.of(context).pop();
                      },
                      child: Text(
                        isEditing ? 'Update Customer' : 'Save Customer',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteCustomer(
    BuildContext context,
    String customerId,
    String customerName,
  ) async {
    if (customerId.isEmpty) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Delete $customerName from your customer list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    await CustomerStorage.deleteCustomer(customerId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$customerName deleted')),
    );
  }
}
