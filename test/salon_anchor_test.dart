import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/constellations/data/salon_anchor_store.dart';

/// L'ANCRE DU SALON — the door holder's local memory: the key lives
/// on this device (sower at the drop, guest at their first line), the
/// anchor dies with the door (seven days, or the ring closing into
/// its public artifact), and it never carries a line of the poem.
void main() {
  SalonAnchor anchor(
    String id, {
    String token = 'cafe',
    int heldSince = 0,
  }) =>
      SalonAnchor(
        id: id,
        token: token,
        seedX: 0.4,
        seedY: 0.6,
        kind: 'POEM',
        target: 4,
        heldSince: heldSince,
      );

  group('la mémoire des portes', () {
    test('semer une porte la retient — elle survit au redémarrage',
        () async {
      final io = _MemIO();
      final now = DateTime.now().millisecondsSinceEpoch;
      final first = SalonAnchorStore(io: io);
      await first.load();
      await first.remember(anchor('c1', heldSince: now));

      final second = SalonAnchorStore(io: io);
      await second.load();
      expect(second.open().map((a) => a.id), ['c1'],
          reason: 'l\'ancre ne meurt pas avec la session');
      expect(second.byId('c1')!.token, 'cafe');
    });

    test('retenir deux fois la même porte rafraîchit, ne duplique pas',
        () async {
      final store = SalonAnchorStore(io: _MemIO());
      await store.load();
      await store.remember(anchor('c1', token: 'old', heldSince: 1));
      await store.remember(anchor('c1', token: 'new', heldSince: 2));

      expect(store.open().length, 1);
      expect(store.byId('c1')!.token, 'new');
    });

    test('la plus ancienne porte s\'ouvre en premier', () async {
      final store = SalonAnchorStore(io: _MemIO());
      await store.load();
      await store.remember(anchor('late', heldSince: 2000));
      await store.remember(anchor('early', heldSince: 1000));

      expect(store.open().map((a) => a.id), ['early', 'late']);
    });

    test('oublier dissout l\'ancre — la porte fermée ne laisse rien',
        () async {
      final io = _MemIO();
      final first = SalonAnchorStore(io: io);
      await first.load();
      await first.remember(anchor('c1', heldSince: 1000));
      await first.forget('c1');

      final second = SalonAnchorStore(io: io);
      await second.load();
      expect(second.open(), isEmpty,
          reason: 'refermé, l\'artefact est public et indiscernable');
    });
  });

  group('la loi des sept jours', () {
    test('une ancre de plus de sept jours se taille seule', () async {
      final io = _MemIO();
      final day = 86400000;
      final now = DateTime.now().millisecondsSinceEpoch;
      io.data['kenos.salon_anchors'] = '''
        {"anchors": [
          {"id": "living", "token": "a", "seedX": 0.1, "seedY": 0.1,
           "kind": "MELODY", "target": 5, "heldSince": ${now - 6 * day}},
          {"id": "reaped", "token": "b", "seedX": 0.2, "seedY": 0.2,
           "kind": "POEM", "target": 4, "heldSince": ${now - 8 * day}}
        ]}''';

      final store = SalonAnchorStore(io: io);
      await store.load();
      expect(store.open().map((a) => a.id), ['living'],
          reason: 'l\'anneau ouvert meurt à sept jours — sa clé avec lui');
    });

    test('un JSON corrompu repart de zéro, sans rien casser', () async {
      final io = _MemIO();
      io.data['kenos.salon_anchors'] = 'not json at all';

      final store = SalonAnchorStore(io: io);
      await store.load();
      expect(store.open(), isEmpty);
      await store.remember(anchor('c1', heldSince: 1000));
      expect(store.open().map((a) => a.id), ['c1']);
    });

    test('une ancre ne porte AUCUN contenu — ni ligne ni poème',
        () async {
      final io = _MemIO();
      final store = SalonAnchorStore(io: io);
      await store.load();
      await store.remember(anchor('c1', heldSince: 1000));

      expect(io.data['kenos.salon_anchors']!.contains('text'), isFalse,
          reason: 'la porte dit où, jamais quoi');
    });
  });
}

class _MemIO implements SalonAnchorIO {
  final data = <String, String>{};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;
}
