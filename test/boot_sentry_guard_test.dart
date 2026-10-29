import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// CCC-04 — la loi du boot sans DSN (voir main()).
///
/// PWW-04 avait promis « absent = no-op propre » ; sentry 9.30 n'a
/// jamais été un no-op : init() jette « DSN is required. » dès que le
/// DSN est null (throw inconditionnel). Tout build sans
/// --dart-define=SENTRY_DSN mourait donc AVANT le premier cadre — la
/// PWA démo locale était morte au boot depuis le 20/10 ; seul le
/// déployé vivait, son .env.cloud portant un DSN. Ce test épingle la
/// preuve : si la garde de main() disparaît, voici ce qui revient.
void main() {
  test(
    'sentry 9.30 sur DSN null jette — la garde du boot n\'est pas décorative',
    () async {
      await expectLater(
        SentryFlutter.init((options) {
          options.dsn = null;
        }),
        throwsArgumentError,
        reason: '« DSN is required. » — le crash qui tuait le boot démo',
      );
    },
  );
}
