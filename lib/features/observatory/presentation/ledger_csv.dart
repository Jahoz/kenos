import '../domain/admin_metrics.dart';

/// The guardian's archive (V3.56): the whole fetched ledger as CSV.
///
/// One row per day, contentless counters only — the wire's own
/// names, the same vocabulary the RPC speaks. Built on the device
/// from what the eye already saw; the ether is not asked again, and
/// never learns the register left.
String buildLedgerCsv(List<DailyPoint> series) {
  final buffer = StringBuffer(
    'day,echoes_launched,echoes_consumed,echoes_rebound,traces_left,'
    'reports_filed,corpses_seeded,corpses_closed,lines_contributed,'
    'new_users,active_readers,salons_seeded,corpses_reported,'
    'corpses_retracted\n',
  );
  for (final d in series) {
    buffer
      ..write(d.day)
      ..write(',')
      ..write(d.launched)
      ..write(',')
      ..write(d.consumed)
      ..write(',')
      ..write(d.rebound)
      ..write(',')
      ..write(d.traces)
      ..write(',')
      ..write(d.reports)
      ..write(',')
      ..write(d.corpsesSeeded)
      ..write(',')
      ..write(d.corpsesClosed)
      ..write(',')
      ..write(d.lines)
      ..write(',')
      ..write(d.newUsers)
      ..write(',')
      ..write(d.activeReaders)
      ..write(',')
      ..write(d.salonsSeeded)
      ..write(',')
      ..write(d.corpsesReported)
      ..write(',')
      ..write(d.corpsesRetracted)
      ..write('\n');
  }
  return buffer.toString();
}
