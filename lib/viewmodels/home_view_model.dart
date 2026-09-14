import 'package:flutter/foundation.dart';
import '../models/cycle_data.dart';
import 'home_state.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({CycleData? initialData})
    : _state = initialData == null
          ? const HomeEmpty()
          : HomeSuccess(initialData);

  void setCycle(CycleData? cycle) {
    _state = cycle == null ? const HomeEmpty() : HomeSuccess(cycle);
    notifyListeners();
  }

  HomeState _state;
  HomeState get state => _state;
}
