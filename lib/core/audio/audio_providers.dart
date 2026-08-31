import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_controller.dart';

final audioControllerProvider = Provider<AudioController>((ref) {
  final controller = AudioController();
  ref.onDispose(controller.dispose);
  return controller;
});
