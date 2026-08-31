import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../echo/data/echo_providers.dart';

/// A wave heard from the ether: another stranger's emission.
class RemoteWave {
  const RemoteWave({
    required this.id,
    required this.offsetX,
    required this.offsetY,
    required this.noteIndex,
    required this.hueIndex,
    required this.createdAt,
  });

  final String id;
  final double offsetX;
  final double offsetY;
  final int noteIndex;
  final int hueIndex;
  final DateTime createdAt;
}

/// Ether access contract for the Symphonie Collective.
///
/// Two implementations:
///  - [SupabaseFrequencyRepository]: production (RPC emit + bbox hear);
///  - [LocalFrequencyRepository]:    demo mode, same semantics plus
///    ghost strangers so an offline field still feels inhabited.
abstract class FrequencyRepository {
  /// Emits a wave at the normalized position. Fire-and-forget semantics
  /// for the caller; implementations surface errors as exceptions.
  Future<void> emit({
    required double offsetX,
    required double offsetY,
    required int noteIndex,
    required int hueIndex,
  });

  /// Waves heard around the listening point, newest first, never the
  /// caller's own, none older than one minute.
  Future<List<RemoteWave>> fetchNearby({
    required double centerX,
    required double centerY,
    required double radius,
  });
}

/// Production: the hearing radius is a normalized-space bbox (see
/// ROADMAP_V3 T3) over a 60-second ether.
class SupabaseFrequencyRepository implements FrequencyRepository {
  SupabaseFrequencyRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> emit({
    required double offsetX,
    required double offsetY,
    required int noteIndex,
    required int hueIndex,
  }) async {
    await _client.rpc('emit_frequency', params: {
      'p_x': offsetX,
      'p_y': offsetY,
      'p_note_index': noteIndex,
      'p_hue_index': hueIndex,
    });
  }

  @override
  Future<List<RemoteWave>> fetchNearby({
    required double centerX,
    required double centerY,
    required double radius,
  }) async {
    final rows = await _client.rpc('fetch_nearby_frequencies', params: {
      'p_x': centerX,
      'p_y': centerY,
      'p_radius': radius,
    }) as List;
    return rows.map((row) {
      final map = (row as Map).cast<String, dynamic>();
      return RemoteWave(
        id: map['id'] as String,
        offsetX: (map['x_pos'] as num).toDouble(),
        offsetY: (map['y_pos'] as num).toDouble(),
        noteIndex: map['note_index'] as int,
        hueIndex: map['hue_index'] as int,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
    }).toList();
  }
}

/// Demo: keeps the user's waves in memory (never echoed back) and
/// sometimes materializes a ghost stranger nearby, so an offline field
/// stays inhabited — same contract as the backend.
class LocalFrequencyRepository implements FrequencyRepository {
  LocalFrequencyRepository({Random? random}) : _random = random ?? Random();

  final Random _random;
  final List<RemoteWave> _mine = [];
  final List<RemoteWave> _ghosts = [];

  @override
  Future<void> emit({
    required double offsetX,
    required double offsetY,
    required int noteIndex,
    required int hueIndex,
  }) async {
    _mine.add(RemoteWave(
      id: 'mine-${DateTime.now().microsecondsSinceEpoch}',
      offsetX: offsetX,
      offsetY: offsetY,
      noteIndex: noteIndex,
      hueIndex: hueIndex,
      createdAt: DateTime.now(),
    ));
  }

  @override
  Future<List<RemoteWave>> fetchNearby({
    required double centerX,
    required double centerY,
    required double radius,
  }) async {
    // A ghost stranger sings, now and then, somewhere near the ear.
    if (_random.nextDouble() < 0.45) {
      final angle = _random.nextDouble() * 2 * pi;
      final dist = _random.nextDouble() * radius;
      _ghosts.add(RemoteWave(
        id: 'ghost-${DateTime.now().microsecondsSinceEpoch}',
        offsetX: (centerX + dist * cos(angle)).clamp(0.0, 1.0),
        offsetY: (centerY + dist * sin(angle)).clamp(0.0, 1.0),
        noteIndex: _random.nextInt(20),
        hueIndex: _random.nextInt(4),
        createdAt: DateTime.now(),
      ));
    }
    final horizon = DateTime.now().subtract(const Duration(seconds: 60));
    return [
      ..._ghosts.where((w) => w.createdAt.isAfter(horizon)),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}

/// Supabase when configured, the inhabited demo ether otherwise.
final frequencyRepositoryProvider = Provider<FrequencyRepository>((ref) {
  final boot = ref.watch(bootstrapProvider);
  if (boot.supabaseConfigured) {
    return SupabaseFrequencyRepository(Supabase.instance.client);
  }
  return LocalFrequencyRepository();
});
