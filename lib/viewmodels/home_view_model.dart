import 'package:flutter/foundation.dart';
import '../models/cycle_data.dart';
import 'home_state.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({required CycleData initialData})
    : _state = HomeSuccess(initialData);
  HomeState _state;
  HomeState get state => _state;
}
