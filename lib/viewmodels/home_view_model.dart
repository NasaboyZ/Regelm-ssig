import 'cycle_view_model.dart';
import 'home_state.dart';

class HomeViewModel extends CycleViewModel {
  HomeViewModel({required super.repository, super.calculator, super.clock});
  HomeState get state => isLoading
      ? const HomeLoading()
      : error != null
      ? HomeError(error!)
      : HomeSuccess(summary);
  Set<DateTime> get entryDays => summary.entryDays;
}
