import '../models/cycle_data.dart';

sealed class HomeState {
  const HomeState();
}

class HomeInitial extends HomeState {
  const HomeInitial();
}

class HomeLoading extends HomeState {
  const HomeLoading();
}

class HomeSuccess extends HomeState {
  const HomeSuccess(this.cycle);
  final CycleData cycle;
}

class HomeError extends HomeState {
  const HomeError(this.message);
  final String message;
}
