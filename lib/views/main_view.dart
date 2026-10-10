import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../dependencies.dart';
import '../repositories/tracking_repository.dart';
import '../services/appointment_reminders.dart';
import '../viewmodels/record_view_model.dart';
import 'record/record_view.dart';
import '../services/cycle_calculation_service.dart';
import '../widgets/cycle/forecast_settings.dart';
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

class _MainViewState extends State<MainView> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  late final HomeViewModel _homeViewModel;
  late final CycleHistoryViewModel _cycleHistoryViewModel;
  Timer? _dayTimer;
  late final TrackingRepository _tracking;
  late final AppointmentReminders _reminders;
  @override
  void initState() {
    super.initState();
    configureDependencies();
    _tracking =
        widget.trackingRepository ?? GetIt.instance<TrackingRepository>();
    _reminders = widget.reminders ?? GetIt.instance<AppointmentReminders>();
    final calculator = GetIt.instance<CycleCalculationService>();
    _homeViewModel = HomeViewModel(
      repository: _tracking,
      calculator: calculator,
    );
    _cycleHistoryViewModel = CycleHistoryViewModel(
      repository: _tracking,
      calculator: calculator,
    );
    _homeViewModel.load();
    _cycleHistoryViewModel.load();
    WidgetsBinding.instance.addObserver(this);
    _scheduleDayRefresh();
  }

  void _scheduleDayRefresh() {
    _dayTimer?.cancel();
    final now = DateTime.now();
    _dayTimer = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      () {
        _homeViewModel.refresh();
        _cycleHistoryViewModel.refresh();
        _scheduleDayRefresh();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _homeViewModel.refresh();
      _cycleHistoryViewModel.refresh();
      _scheduleDayRefresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayTimer?.cancel();
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
    final route = MaterialPageRoute<void>(
      builder: (_) => RecordView(viewModel: viewModel),
    );
    await Navigator.of(context).push(route);
    await route.completed;
    viewModel.dispose();
  }

  void _details() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ListenableBuilder(
            listenable: _homeViewModel,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CycleSummaryCard(
                  cycle: _homeViewModel.summary,
                  showCalculationDetails: true,
                ),
                const SizedBox(height: 16),
                ForecastSettings(viewModel: _homeViewModel),
              ],
            ),
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
