import 'package:flutter/material.dart';
import '../viewmodels/home_state.dart';
import '../viewmodels/home_view_model.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../viewmodels/cycle_history_view_model.dart';
import 'cycle/cycle_history_view.dart';
import '../widgets/cycle/cycle_summary_card.dart';
import 'home/home_view.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});
  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  int _selectedIndex = 0;
  final _homeViewModel = HomeViewModel();
  final _cycleHistoryViewModel = CycleHistoryViewModel();
  @override
  void dispose() {
    _homeViewModel.dispose();
    _cycleHistoryViewModel.dispose();
    super.dispose();
  }

  void _record() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Heute erfassen',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              'Hier kannst du künftig deine Periode, Symptome und Stimmung erfassen. Die Erfassung ist noch nicht verfügbar.',
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
  void _details() {
    final state = _homeViewModel.state;
    if (state is! HomeSuccess) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CycleSummaryCard(
                cycle: state.cycle,
                onDetails: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeView(
            viewModel: _homeViewModel,
            onOpenCalendar: () => setState(() => _selectedIndex = 1),
            onRecord: _record,
            onDetails: _details,
          ),
          CycleHistoryView(viewModel: _cycleHistoryViewModel),
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Einstellungen',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 12),
                  Text('Hier werden deine Einstellungen verfügbar sein.'),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: AppBottomNavigationBar(
      selectedIndex: _selectedIndex,
      onItemSelected: (index) => setState(() => _selectedIndex = index),
    ),
  );
}
