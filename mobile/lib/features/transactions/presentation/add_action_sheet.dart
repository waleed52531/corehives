import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void showAddActionSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (context) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.remove_circle_outline, color: Colors.red),
            title: const Text('Add Expense'),
            onTap: () {
              Navigator.pop(context);
              context.push('/add-expense');
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: Colors.green),
            title: const Text('Add Cash In'),
            onTap: () {
              Navigator.pop(context);
              context.push('/add-cash-in');
            },
          ),
        ],
      ),
    ),
  );
}
