import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/features/echo/domain/echo_excerpt.dart';

/// V3.10 — the Excerpts: strict link parsing, sealed wire form and the
/// canonical door URL. The raw reference is NEVER launched: a forged
/// input must not survive the parse.
void main() {
  group('parseLink — Spotify', () {
    test('share URL with tracking tail', () {
      final e = EchoExcerpt.parseLink(
        'https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT?si=abc123',
      );
      expect(e?.kind, EchoExcerptKind.song);
      expect(e?.id, '4cOdK2wGLETKBW3PvgPWqT');
    });

    test('localized path', () {
      final e = EchoExcerpt.parseLink(
        'https://open.spotify.com/intl-fr/track/4cOdK2wGLETKBW3PvgPWqT',
      );
      expect(e?.id, '4cOdK2wGLETKBW3PvgPWqT');
    });

    test('URI scheme', () {
      final e = EchoExcerpt.parseLink('spotify:track:4cOdK2wGLETKBW3PvgPWqT');
      expect(e?.kind, EchoExcerptKind.song);
    });

    test('a malformed id is not a door', () {
      expect(EchoExcerpt.parseLink('https://open.spotify.com/track/short'), isNull);
    });
  });

  group('parseLink — YouTube', () {
    test('short link with plain timestamp', () {
      final e = EchoExcerpt.parseLink(
        'https://youtu.be/jfKfPfyJRdk?t=90',
      );
      expect(e?.kind, EchoExcerptKind.video);
      expect(e?.id, 'jfKfPfyJRdk');
      expect(e?.startSeconds, 90);
    });

    test('watch URL with 1m30s timestamp', () {
      final e = EchoExcerpt.parseLink(
        'https://www.youtube.com/watch?v=jfKfPfyJRdk&t=1m30s',
      );
      expect(e?.startSeconds, 90);
    });

    test('mobile watch URL without timestamp starts at zero', () {
      final e = EchoExcerpt.parseLink(
        'https://m.youtube.com/watch?v=jfKfPfyJRdk&list=x',
      );
      expect(e?.startSeconds, 0);
    });

    test('timestamp is clamped to one day', () {
      final e = EchoExcerpt.parseLink('https://youtu.be/jfKfPfyJRdk?t=99999999');
      expect(e?.startSeconds, 86400);
    });

    test('an id that is too long is rejected', () {
      expect(
        EchoExcerpt.parseLink('https://youtu.be/jfKfPfyJRdkk'),
        isNull,
      );
    });
  });

  group('parseLink — refus', () {
    test('other domains and garbage are not doors', () {
      expect(EchoExcerpt.parseLink('https://example.com/track/abc'), isNull);
      expect(EchoExcerpt.parseLink('https://open.spotify.com/album/xyz'), isNull);
      expect(EchoExcerpt.parseLink('javascript:alert(1)'), isNull);
      expect(EchoExcerpt.parseLink(''), isNull);
      expect(EchoExcerpt.parseLink('   '), isNull);
    });

    test('whitespace is trimmed around a real link', () {
      final e = EchoExcerpt.parseLink(
        '  https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT\n',
      );
      expect(e, isNotNull);
    });
  });

  group('ref — wire form round-trip', () {
    test('song ref survives fromRef', () {
      const e = EchoExcerpt(kind: EchoExcerptKind.song, id: '4cOdK2wGLETKBW3PvgPWqT');
      final back = EchoExcerpt.fromRef(e.ref);
      expect(back, isNotNull);
      expect(back!.kind, e.kind);
      expect(back.id, e.id);
      expect(back.startSeconds, e.startSeconds);
    });

    test('video ref with timestamp survives fromRef', () {
      const e = EchoExcerpt(
        kind: EchoExcerptKind.video,
        id: 'jfKfPfyJRdk',
        startSeconds: 95,
      );
      final back = EchoExcerpt.fromRef(e.ref);
      expect(back, isNotNull);
      expect(back!.kind, e.kind);
      expect(back.id, e.id);
      expect(back.startSeconds, e.startSeconds);
    });

    test('fromRef is strict: forged refs die here', () {
      expect(EchoExcerpt.fromRef('spotify:track:short'), isNull);
      expect(EchoExcerpt.fromRef('youtube:jfKfPfyJRdk'), isNull);
      expect(EchoExcerpt.fromRef('youtube:jfKfPfyJRdk:999999'), isNull);
      expect(
        EchoExcerpt.fromRef('https://evil.example.com/whatever'),
        isNull,
      );
      expect(EchoExcerpt.fromRef(''), isNull);
    });
  });

  group('doorUrl — canonical, never the raw string', () {
    test('song door', () {
      const e = EchoExcerpt(kind: EchoExcerptKind.song, id: '4cOdK2wGLETKBW3PvgPWqT');
      expect(
        e.doorUrl.toString(),
        'https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT',
      );
    });

    test('video door with timestamp', () {
      const e = EchoExcerpt(
        kind: EchoExcerptKind.video,
        id: 'jfKfPfyJRdk',
        startSeconds: 95,
      );
      expect(
        e.doorUrl.toString(),
        'https://www.youtube.com/watch?v=jfKfPfyJRdk&t=95s',
      );
    });

    test('video door without timestamp', () {
      const e = EchoExcerpt(kind: EchoExcerptKind.video, id: 'jfKfPfyJRdk');
      expect(
        e.doorUrl.toString(),
        'https://www.youtube.com/watch?v=jfKfPfyJRdk',
      );
    });
  });
}
