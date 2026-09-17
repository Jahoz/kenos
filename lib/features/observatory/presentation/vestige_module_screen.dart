import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_fonts.dart';
import '../data/admin_providers.dart';
import '../data/admin_repository.dart';
import '../domain/admin_metrics.dart';

/// V3.57 — LE SEMEUR D'ÉCLATS, the Observatory's vestige module.
///
/// The pipeline became a screen: the guardian re-reads what the AI
/// sowed (verified twice, server-side), discards or publishes each
/// shard, retires and restores the library, and asks for another
/// harvest — all behind the same threshold, the same session, the
/// same voice. The gate stays human; the road is no longer a
/// pilgrimage of local files.
class VestigeModuleScreen extends ConsumerStatefulWidget {
  const VestigeModuleScreen({super.key});

  @override
  ConsumerState<VestigeModuleScreen> createState() =>
      _VestigeModuleScreenState();
}

enum _Phase { loading, ready, error }

class _VestigeModuleScreenState extends ConsumerState<VestigeModuleScreen> {
  _Phase _phase = _Phase.loading;
  List<VestigeProposal> _proposals = const [];
  List<VestigeLibraryEntry> _library = const [];
  bool _busy = false;
  String? _sowWord;

  // The sowing form: how many, on what theme.
  int _count = 6;
  final _theme = TextEditingController();

  AdminRepository get _repo => ref.read(adminRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _theme.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _phase = _Phase.loading);
    try {
      final answers = await Future.wait([
        _repo.fetchVestigeProposals(),
        _repo.fetchVestigeLibrary(),
      ]);
      if (!mounted) return;
      setState(() {
        _proposals = answers[0] as List<VestigeProposal>;
        _library = answers[1] as List<VestigeLibraryEntry>;
        _phase = _Phase.ready;
      });
    } on GuardianForbiddenException {
      await _repo.signOut();
      if (mounted) setState(() => _phase = _Phase.error);
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _decide(VestigeProposal proposal, bool approve) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _repo.decideVestigeProposal(proposal.id, approve);
      await _load();
    } on GuardianForbiddenException {
      await _repo.signOut();
      if (mounted) setState(() => _phase = _Phase.error);
    } catch (_) {
      if (mounted) {
        _say('LE CIEL SE DÉROBE — L\'ÉCLAT ATTEND ENCORE.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sow() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _sowWord = 'LE SEMEUR PASSE…';
    });
    try {
      final result = await _repo.sowVestiges(
        count: _count,
        theme: _theme.text.trim().isEmpty
            ? 'astronomie, étymologies, micro-histoires'
            : _theme.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _sowWord = switch (result.reason) {
          null => '${result.sown} ÉCLATS ATTENDENT TA LECTURE.',
          'unconfigured' =>
            'LA CLÉ N\'EST PAS SÉMÉE — AJOUTE VESTIGE_AI_KEY AUX SECRETS.',
          'forbidden' => 'LE SEUIL N\'Y VOIT PAS DE GARDIEN.',
          'empty' => 'LE SEMEUR N\'A RIEN TROUVÉ — CHANGE LE THÈME.',
          'demo' => 'DÉMO : UN ÉCLAT EN CONSERVE ATTEND TA LECTURE.',
          _ => 'LE CIEL A REFUSÉ LA MOISSON.',
        };
      });
      if (result.sown > 0) await _load();
    } catch (_) {
      if (mounted) setState(() => _sowWord = 'LE CIEL SE DÉROBE.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleLive(VestigeLibraryEntry entry) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _repo.setVestigeLive(entry.id, !entry.live);
      await _load();
    } on GuardianForbiddenException {
      await _repo.signOut();
      if (mounted) setState(() => _phase = _Phase.error);
    } catch (_) {
      if (mounted) _say('LE CIEL SE DÉROBE.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publishAll() async {
    if (_busy || _proposals.isEmpty) return;
    setState(() => _busy = true);
    try {
      for (final p in List.of(_proposals)) {
        await _repo.decideVestigeProposal(p.id, true);
      }
      await _load();
    } catch (_) {
      if (mounted) _say('LE CIEL SE DÉROBE.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String word) {
    setState(() => _sowWord = word);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      appBar: AppBar(
        backgroundColor: AppColors.voidBlack,
        foregroundColor: AppColors.pureLight,
        title: Text(
          'LE SEMEUR D\'ÉCLATS',
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 11,
            letterSpacing: 3,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _busy ? null : _load,
            child: Text(
              'RAFRAÎCHIR',
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 9,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
      body: switch (_phase) {
        _Phase.loading => _centered('CHARGEMENT…'),
        _Phase.error => _centered('LE CIEL SE DÉROBE'),
        _Phase.ready => _module(),
      },
    );
  }

  Widget _centered(String text) => Center(
    child: Text(
      text,
      style: TextStyle(
        fontFamily: AppFonts.mono,
        fontSize: 9,
        letterSpacing: 3,
        color: AppColors.fade(AppColors.pureLight, 0.4),
      ),
    ),
  );

  Widget _module() {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label('À RELIRE — ${_proposals.length}'),
                const SizedBox(height: 6),
                Text(
                  'Vérifiés deux fois par le semeur. Rien n\'est public '
                  'avant ton geste — publier fait entrer l\'éclat dans le '
                  'ciel français, pour toujours.',
                  style: TextStyle(
                    fontFamily: AppFonts.serifItalic,
                    fontSize: 12.5,
                    height: 1.6,
                    color: AppColors.fade(AppColors.pureLight, 0.5),
                  ),
                ),
                const SizedBox(height: 14),
                if (_proposals.isEmpty)
                  _quiet('Aucun éclat en attente — le ciel attend une moisson.')
                else ...[
                  for (final p in _proposals)
                    _ProposalCard(
                      proposal: p,
                      busy: _busy,
                      onDecide: (approve) => _decide(p, approve),
                    ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _busy ? null : _publishAll,
                    child: const Text(
                      'TOUT PUBLIER',
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 9,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 38),
                _label('SEMER — DEMANDER UNE MOISSON'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final n in const [4, 8, 12])
                      _countPill(n),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _theme,
                  cursorColor: AppColors.teal,
                  style: TextStyle(
                    fontFamily: AppFonts.serifItalic,
                    fontSize: 15,
                    color: AppColors.pureLight,
                  ),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText:
                        'thème — ex. étymologies grecques, l\'océan de nuit',
                    hintStyle: TextStyle(
                      fontFamily: AppFonts.serifItalic,
                      fontSize: 13,
                      color: AppColors.fade(AppColors.pureLight, 0.35),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: _busy ? null : _sow,
                  child: Text(
                    _busy ? '…' : 'SEMER $_count ÉCLATS',
                    style: const TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 10,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                if (_sowWord != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _sowWord!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 8.5,
                      letterSpacing: 1.5,
                      height: 1.7,
                      color: AppColors.fade(AppColors.teal, 0.8),
                    ),
                  ),
                ],
                const SizedBox(height: 38),
                _label('LA BIBLIOTHÈQUE — ${_library.length}'),
                const SizedBox(height: 6),
                Text(
                  'Ce que le ciel sert aux voyageurs. Retirer ne détruit '
                  'pas : l\'éclat quitte le ciel, la culture reste.',
                  style: TextStyle(
                    fontFamily: AppFonts.serifItalic,
                    fontSize: 12.5,
                    height: 1.6,
                    color: AppColors.fade(AppColors.pureLight, 0.5),
                  ),
                ),
                const SizedBox(height: 14),
                if (_library.isEmpty)
                  _quiet('La bibliothèque est vide — publie un premier éclat.')
                else
                  for (final entry in _library)
                    _LibraryRow(
                      entry: entry,
                      busy: _busy,
                      onToggle: () => _toggleLive(entry),
                    ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _countPill(int n) {
    final selected = n == _count;
    final ink = selected ? AppColors.teal : AppColors.pureLight;
    return TextButton(
      onPressed: () => setState(() => _count = n),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: AppColors.fade(ink, selected ? 0.8 : 0.25),
            width: selected ? 1.2 : 1,
          ),
        ),
        backgroundColor: selected
            ? Color.alphaBlend(
                AppColors.fade(AppColors.teal, 0.10),
                AppColors.voidBlack,
              )
            : AppColors.voidBlack,
      ),
      child: Text(
        '$n',
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 10,
          color: AppColors.fade(ink, selected ? 0.95 : 0.6),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: TextStyle(
      fontFamily: AppFonts.mono,
      fontSize: 9,
      letterSpacing: 2,
      color: AppColors.fade(AppColors.pureLight, 0.5),
    ),
  );

  Widget _quiet(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: AppFonts.serifItalic,
        fontSize: 12,
        height: 1.6,
        color: AppColors.fade(AppColors.pureLight, 0.5),
      ),
    ),
  );
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.busy,
    required this.onDecide,
  });

  final VestigeProposal proposal;
  final bool busy;
  final void Function(bool approve) onDecide;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.fade(AppColors.teal, 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${proposal.kindLabel} · ${proposal.theme}',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 8.5,
                    letterSpacing: 1.5,
                    color: AppColors.fade(AppColors.cyan, 0.8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            proposal.text,
            style: TextStyle(
              fontFamily: AppFonts.serifItalic,
              fontSize: 15.5,
              height: 1.7,
              color: AppColors.fade(AppColors.pureLight, 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '— ${proposal.source}',
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 8.5,
              letterSpacing: 1,
              color: AppColors.fade(AppColors.teal, 0.6),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: busy ? null : () => onDecide(true),
                child: Text(
                  'PUBLIER DANS LE CIEL',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 9,
                    letterSpacing: 2,
                    color: AppColors.fade(AppColors.teal, 0.9),
                  ),
                ),
              ),
              TextButton(
                onPressed: busy ? null : () => onDecide(false),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.fade(AppColors.pureLight, 0.45),
                ),
                child: const Text(
                  'ÉCARTER',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 9,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({
    required this.entry,
    required this.busy,
    required this.onToggle,
  });

  final VestigeLibraryEntry entry;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final ink = entry.live ? AppColors.teal : AppColors.pureLight;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.fade(ink, entry.live ? 0.25 : 0.12),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${entry.kindLabel}${entry.live ? '' : ' · RETIRÉ'}'
                  '${entry.createdOn.isEmpty ? '' : ' · ${entry.createdOn}'}',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 8,
                    letterSpacing: 1.5,
                    color: AppColors.fade(
                      ink,
                      entry.live ? 0.7 : 0.35,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.text,
            style: TextStyle(
              fontFamily: AppFonts.serifItalic,
              fontSize: 13.5,
              height: 1.6,
              color: AppColors.fade(
                AppColors.pureLight,
                entry.live ? 0.75 : 0.35,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: busy ? null : onToggle,
                child: Text(
                  entry.live ? 'RETIRER DU CIEL' : 'REMETTRE AU CIEL',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 8.5,
                    letterSpacing: 1.5,
                    // Retire is reversible curation, never destruction —
                    // ROSE keeps its law, teal carries both levers.
                    color: AppColors.fade(AppColors.teal, 0.75),
                  ),
                ),
              ),
          ),
        ],
      ),
    );
  }
}
