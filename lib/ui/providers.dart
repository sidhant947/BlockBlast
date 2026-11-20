import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:blockblast/data/repositories/progress_repository.dart';
import 'package:blockblast/data/services/hive_service.dart';
import 'package:blockblast/domain/use_cases/level_generator.dart';
import 'package:blockblast/ui/features/game/view_models/game_view_model.dart';
import 'package:blockblast/ui/features/home/view_models/home_view_model.dart';

final hiveServiceProvider = Provider<HiveService>((ref) {
  throw UnimplementedError('Must be overridden in main');
});

final progressRepositoryProvider = ChangeNotifierProvider<ProgressRepository>((ref) {
  final hiveService = ref.watch(hiveServiceProvider);
  return ProgressRepository(hiveService: hiveService);
});

final levelGeneratorProvider = Provider<LevelGenerator>((ref) {
  return LevelGenerator();
});

final homeViewModelProvider =
    StateNotifierProvider<HomeViewModel, HomeViewModelState>((ref) {
      final progressRepository = ref.read(progressRepositoryProvider);
      return HomeViewModel(progressRepository: progressRepository);
    });

final gameViewModelProvider =
    StateNotifierProvider.autoDispose<GameViewModel, GameViewModelState>((ref) {
      final progressRepository = ref.read(progressRepositoryProvider);
      final levelGenerator = ref.read(levelGeneratorProvider);
      return GameViewModel(
        progressRepository: progressRepository,
        levelGenerator: levelGenerator,
      );
    });

class SoundSettingsNotifier extends StateNotifier<bool> {
  SoundSettingsNotifier(this._hiveService)
      : super(_loadInitial(_hiveService));

  final HiveService _hiveService;

  static bool _loadInitial(HiveService hiveService) {
    try {
      if (Hive.isBoxOpen(HiveService.progressBoxName)) {
        return hiveService.progressBox.get('soundEnabled', defaultValue: true) as bool;
      }
    } catch (_) {}
    return true;
  }

  Future<void> toggle() async {
    await setSoundEnabled(!state);
  }

  Future<void> setSoundEnabled(bool value) async {
    state = value;
    try {
      if (Hive.isBoxOpen(HiveService.progressBoxName)) {
        await _hiveService.progressBox.put('soundEnabled', value);
      }
    } catch (_) {}
  }
}

final soundSettingsProvider =
    StateNotifierProvider<SoundSettingsNotifier, bool>((ref) {
  final hiveService = ref.watch(hiveServiceProvider);
  return SoundSettingsNotifier(hiveService);
});

class CompactLayoutSettingsNotifier extends StateNotifier<bool> {
  CompactLayoutSettingsNotifier(this._hiveService)
      : super(_loadInitial(_hiveService));

  final HiveService _hiveService;

  static bool _loadInitial(HiveService hiveService) {
    try {
      if (Hive.isBoxOpen(HiveService.progressBoxName)) {
        return hiveService.progressBox.get(
              'compactLayoutEnabled',
              defaultValue: false,
            )
            as bool;
      }
    } catch (_) {}
    return false;
  }

  Future<void> toggle() async {
    await setLayoutEnabled(!state);
  }

  Future<void> setLayoutEnabled(bool value) async {
    state = value;
    try {
      if (Hive.isBoxOpen(HiveService.progressBoxName)) {
        await _hiveService.progressBox.put('compactLayoutEnabled', value);
      }
    } catch (_) {}
  }
}

final compactLayoutSettingsProvider =
    StateNotifierProvider<CompactLayoutSettingsNotifier, bool>((ref) {
  final hiveService = ref.watch(hiveServiceProvider);
  return CompactLayoutSettingsNotifier(hiveService);
});


