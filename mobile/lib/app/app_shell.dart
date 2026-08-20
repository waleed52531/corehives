import 'package:flutter/material.dart';
import '../features/transactions/presentation/add_action_sheet.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const AppShell({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddActionSheet(context),
        child: const Icon(Icons.add, size: 28),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home_outlined, 'Home', 0),
            _navItem(Icons.receipt_long_outlined, 'Transactions', 1),
            const SizedBox(width: 48), // space for FAB notch
            _navItem(Icons.payments_outlined, 'Payroll', 2),
            _navItem(Icons.person_outline, 'Profile', 3),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final selected = widget.currentIndex == index;
    return InkWell(
      onTap: () => widget.onTabSelected(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? Theme.of(context).colorScheme.primary : Colors.grey),
            Text(label, style: TextStyle(
              fontSize: 11,
              color: selected ? Theme.of(context).colorScheme.primary : Colors.grey,
            )),
          ],
        ),
      ),
    );
  }
}
