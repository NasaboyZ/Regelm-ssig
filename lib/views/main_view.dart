import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../dependencies.dart';
import '../repositories/tracking_repository.dart';
import '../services/appointment_reminders.dart';
import '../viewmodels/record_view_model.dart';
import 'record/record_view.dart';
import '../viewmodels/home_state.dart';
import '../viewmodels/home_view_model.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../viewmodels/cycle_history_view_model.dart';
import 'cycle/cycle_history_view.dart';
import '../widgets/cycle/cycle_summary_card.dart';
import 'home/home_view.dart';

class MainView extends StatefulWidget {
  const MainView({super.key, this.trackingRepository, this.reminders});
  final TrackingRepository? trackingRepository;
  final AppointmentReminders? reminders;
  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  int _selectedIndex = 0;
  final _homeViewModel = HomeViewModel();
  final _cycleHistoryViewModel = CycleHistoryViewModel();
  late final TrackingRepository _tracking;
  late final AppointmentReminders _reminders;
  @override
  void initState() {
    super.initState();
    configureDependencies();
    _tracking =
        widget.trackingRepository ?? GetIt.instance<TrackingRepository>();
    _reminders = widget.reminders ?? GetIt.instance<AppointmentReminders>();
    _tracking.addListener(_syncTracking);
    _syncTracking();
    // The record screen presents load failures with a retry action.
    _tracking.load().catchError((Object _) {});
  }

  void _syncTracking() {
    _homeViewModel.setEntryDays(_tracking.snapshot.entryDays);
    _cycleHistoryViewModel.setEntryDays(_tracking.snapshot.entryDays);
  }

  @override
  void dispose() {
    _tracking.removeListener(_syncTracking);
    _homeViewModel.dispose();
    _cycleHistoryViewModel.dispose();
    super.dispose();
  }

  Future<void> _record([DateTime? date]) async {
    final viewModel = RecordViewModel(
      repository: _tracking,
      reminders: _reminders,
      date: date,
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => RecordView(viewModel: viewModel)),
    );
    // Route animations can still read the notifier until the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => viewModel.dispose());
  }

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
            onRecordDay: _record,
            onDetails: _details,
          ),
          CycleHistoryView(
            viewModel: _cycleHistoryViewModel,
            onRecordDay: _record,
          ),
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
