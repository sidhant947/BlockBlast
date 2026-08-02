import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blockblast/data/repositories/progress_repository.dart';
import 'package:blockblast/domain/models/user_progress.dart';

class HomeViewModelState {
  final UserProgress? progress;
  final bool isLoading;

  HomeViewModelState({
    this.progress,
    this.isLoading = false,
  });

  HomeViewModelState copyWith({
    UserProgress? progress,
    bool? isLoading,
  }) {
    return HomeViewModelState(
      progress: progress ?? this.progress,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class HomeViewModel extends StateNotifier<HomeViewModelState> {
  HomeViewModel({required this.progressRepository}) : super(HomeViewModelState());

  final ProgressRepository progressRepository;

  Future<void> loadProgress() async {
    state = state.copyWith(isLoading: true);
    final progress = await progressRepository.getProgress();
    state = state.copyWith(progress: progress, isLoading: false);
  }
}
