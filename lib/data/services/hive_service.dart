import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static const String progressBoxName = 'user_progress_box';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(progressBoxName);
  }

  Box get progressBox => Hive.box(progressBoxName);
}
