import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/audio_providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_fonts.dart';
import '../../../core/constants/app_layout.dart';
import '../../../core/haptics/kenos_haptics.dart';
import '../../../core/utils/motion_preferences.dart';
import '../../../core/utils/parallax_math.dart';
import '../../../core/voice/kenos_voice.dart';
import '../../../core/widgets/hud.dart';
import '../../constellations/data/constellation_repository.dart';
import '../../constellations/data/salon_anchor_store.dart';
import '../../constellations/domain/constellation_figure.dart';
import '../../constellations/presentation/constellation_sheets.dart';
import '../../constellations/presentation/salon_share_sheet.dart';
import '../../echo/data/echo_providers.dart';
import '../../echo/domain/echo.dart';
import '../../echo/domain/read_scar.dart';
import '../application/accretion.dart';
import '../application/celestial_bodies.dart';
import '../application/kenos_system.dart';
import '../application/map_controller.dart';
import '../application/motion_service.dart';
import '../application/poem_breath.dart';
import '../application/read_scar_controller.dart';
import '../application/reception_controller.dart';
import '../application/travel_camera.dart';
import '../application/void_territories.dart';
import '../data/artifact_memory.dart';
import 'widgets/accretion_painter.dart';
import 'widgets/awakening_sas.dart';
import 'widgets/background_painters.dart';
import 'widgets/celestial_plaque.dart';
import 'widgets/deep_field_painter.dart';
import 'widgets/mindful_hold_star.dart';
import 'widgets/origin_node.dart';
import 'widgets/scar_field_painter.dart';
import 'widgets/sky_map_sheet.dart';
import 'widgets/star_shift.dart';
import 'widgets/system_painter.dart';
import 'widgets/vestige.dart';
import 'widgets/vestige_library_sheet.dart';

/// The stellar map: KENOS public space.
/// No lists, no scrolling — a three-dimensional Stack where the void dominates.
///
/// Performance contract: only the leaf layers ([_AmbientBackground],
/// [_ParallaxStarLayer]) watch the tilt stream — the HUD and the screen
/// itself never rebuild at sensor rate.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.eye});

  /// V3.49 — where a deep link lands the eye (`/#/ciel/x/y`): the
  /// sky opens already standing where a stranger stood, and murmurs
  /// it once. Null: the heart, as always.
  final Offset? eye;

  /// V3.35 — the landscapes already whispered this session (silence
  /// is the default state): resettable by tests, like the star's own
  /// once-per-session whisper.
  static final Set<VoidTerritory> territoriesAnnounced = {};

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with WidgetsBindingObserver {
  /// The Awakening sas speaks once per session, after the first
  /// receptions sync — never again (silence is the default state).
  static bool _aubeSpokenThisSession = false;

  /// The Vestiges: curated culture drifting in the void (V3.9).
  List<Vestige> _vestiges = const [];

  /// The traveller's artifact memory: seven-day read markers and the
  /// reliquaire (kept objects stay in THIS sky, local forever).
  late final ArtifactMemory _artifacts = ref.read(artifactMemoryProvider);

  /// L'ANCRE DU SALON: the doors this device holds (sower or claimed
  /// guest) — ember seeds on the sky, the key that reopens them, all
  /// strictly local. An open salon stays invisible to the ether; this
  /// is the one place it shows, to its holder only.
  late final SalonAnchorStore _salonDoors = ref.read(salonAnchorStoreProvider);
  List<SalonAnchor> _salonAnchors = const [];

  /// The one line that matters: signals first (they pulse), then the
  /// readable ether, then the mode.
  String _hudHeadline({required int readable, required int signals}) {
    if (signals > 0) {
      return signals == 1 ? '1 SIGNAL — KENOS' : '$signals SIGNAUX — KENOS';
    }
    return '$readable ÉCHOS — $_bootLabel';
  }

  String get _bootLabel =>
      ref.read(bootstrapProvider).supabaseConfigured ? 'LIAISON' : 'DÉMO';

  /// The quiet second line: drift + territory + sealed + vestiges,
  /// joined by breath marks — presence, never urgency. V3.35: the
  /// territory label makes distance a PLACE, not just a number (the
  /// line lives in the camera's builder — the label follows the eye
  /// without waking the screen). V3.44: on a narrow phone the COUNTS
  /// fold away — drift, place and the souffle stay (the way home and
  /// the where-am-I), the inventory waits for a wider sky.
  String _readableSilent({required bool compact}) {
    final parts = <String>[
      'DÉRIVE ${_camera.driftLabel}',
      VoidTerritories.hudLabel(VoidTerritories.territoryAt(_camera.center)),
    ];
    if (!compact) {
      final sealedCount =
          (ref.read(mapControllerProvider).valueOrNull ?? const <Echo>[])
              .where((e) => e.isMine)
              .length;
      if (sealedCount > 0) parts.add('$sealedCount SCELLÉES');
      if (_constellations.isNotEmpty) {
        parts.add('${_constellations.length} CONSTELLATIONS');
      }
      final unreadVestiges = _vestiges
          .where((v) => !_artifacts.isRead(v.id))
          .length;
      if (unreadVestiges > 0) parts.add('$unreadVestiges VESTIGES');
    }
    // V3.30 — the breath: when no readable light drifts within the
    // eye's field, the sky whispers where to travel.
    final breath = _breathLine;
    if (breath != null) parts.add(breath);
    return parts.join(' · ');
  }

  /// V3.30 — the breath toward the ether. The client only knows what
  /// it has fetched (the bottle is searched for, never delivered):
  /// the whisper points at the nearest LOADED light, else at the
  /// nearest world — the lights gravitate around them by law. A
  /// direction told, never a GPS.
  ///
  /// V3.45 — the poem outranks everything: a corpse these hands
  /// helped write, closed and unread, takes the breath until read —
  /// the participant can FIND their own artifact in the immensity.
  String? get _breathLine {
    final poem = PoemBreath.line(_constellations, _artifacts, _camera.center);
    if (poem != null) return poem;
    final echoes =
        ref.read(mapControllerProvider).valueOrNull ?? const <Echo>[];
    final now = DateTime.now();
    final eye = _camera.center;
    Echo? nearestEcho;
    var bestEcho = double.infinity;
    for (final e in echoes) {
      if (e.isMine) continue;
      final d = (KenosSystem.echoPosition(e, now) - eye).distance;
      if (d <= ParallaxMath.receptionRadius + ParallaxMath.receptionFade) {
        return null; // a light drifts here — no whisper needed
      }
      if (d < bestEcho) {
        bestEcho = d;
        nearestEcho = e;
      }
    }
    if (nearestEcho != null) {
      final h = ParallaxMath.clockDirection(
        KenosSystem.echoPosition(nearestEcho, now) - eye,
      );
      // The distance rides the whisper (V3.36): the direction told,
      // and what it costs to reach — the map's own A.L. currency.
      return 'SOUFFLE VERS $h H — ${bestEcho.toStringAsFixed(2)} A.L.';
    }
    // Nothing loaded nearby: the worlds carry the lights.
    var nearestWorld = 0;
    var bestWorld = double.infinity;
    for (var i = 0; i < 2; i++) {
      final d = (KenosSystem.planetPosition(i, now) - eye).distance;
      if (d < bestWorld) {
        bestWorld = d;
        nearestWorld = i;
      }
    }
    final h = ParallaxMath.clockDirection(
      KenosSystem.planetPosition(nearestWorld, now) - eye,
    );
    return 'LES LUMIÈRES GRAVITENT — SOUFFLE VERS $h H';
  }

  /// V3.12/V3.38 — the hovered named body (desktop): its name floats
  /// beside it, the cursor says « this is a world ». The state holds
  /// the TARGET, never a position — the label derives its place live
  /// on the heavens' beat (bodies orbit while hovered) and the
  /// camera's pulse (the sky pans under the pointer). The old code
  /// froze the label's coordinates at the first hover: a drifting
  /// body left its name behind, and the fixed pixel offset printed it
  /// ON the world at deep zoom.
  ({bool wanderer, int index})? _hoverTarget;

  /// The Constellations: exquisite corpses drifting in the void (V3.8).
  List<ConstellationMeta> _constellations = const [];

  /// V3.7a — Le Voyage: the traveller's eye. Fixed zoom, the void
  /// follows the finger, drift accumulates in Années-Lumière.
  final TravelCamera _camera = TravelCamera();
  Timer? _glide;
  Size _viewport = Size.zero;

  /// Gesture bookkeeping: where it began, how far it carried, how
  /// much it pinched. A release with neither travel nor zoom is an
  /// intention (a tap); a pinch that stays put still zooms.
  Offset _lastPointerDown = Offset.zero;
  Offset _dragTotal = Offset.zero;
  double _pinchFactor = 1.0;

  /// The sky's quiet breath (see initState).
  Timer? _skyBreath;

  /// V3.35 — the landscape the eye rides: the territory it left (null
  /// until the first reading), the one being whispered, and the
  /// whisper's own timer. Crossing a territory speaks ONCE per
  /// session; the born territory is ridden, never announced — the sky
  /// does not greet itself.
  VoidTerritory? _territory;
  VoidTerritory? _territoryWhispering;
  Timer? _territoryTimer;

  /// V3.49 — the eye arrived by a place link: one murmured welcome,
  /// then the sky keeps quiet about it.
  bool _landedByLink = false;

  /// V3.45 — the one-time closure whisper (a poem of these hands,
  /// closed and unread): its constellation id while it shows.
  String? _closureWhisper;
  Timer? _closureTimer;

  /// The camera's own pulse (V3.35): territories crossed, drone depth.
  void _onEyeTravels() {
    final territory = VoidTerritories.territoryAt(_camera.center);
    if (territory != _territory) {
      final wasBorn = _territory == null;
      _territory = territory;
      if (wasBorn) return;
      if (!MapScreen.territoriesAnnounced.contains(territory)) {
        MapScreen.territoriesAnnounced.add(territory);
        _territoryTimer?.cancel();
        setState(() => _territoryWhispering = territory);
        _territoryTimer = Timer(const Duration(seconds: 7), () {
          if (mounted) setState(() => _territoryWhispering = null);
        });
      }
    }
    unawaited(
      ref
          .read(audioControllerProvider)
          .setDroneDepth(
            VoidTerritories.droneFactor(
              (_camera.center - VoidTerritories.heart).distance,
            ),
          ),
    );
  }

  /// A fresh corpse comes back from its door: reload the sky, then
  /// offer the seeder to give the FIRST line — to their own poem they
  /// are just another stranger, as blind as the rest. A salon never
  /// shows on the sky while it is written: the first line is given
  /// behind the door, then the link — once.
  Future<void> _corpseSeeded(SeededConstellation seeded) async {
    if (seeded.isSalon) {
      // The door is held from the very drop — even a seeder who
      // closes both sheets without copying the link keeps their
      // ember anchor, and the door with it.
      unawaited(
        _salonDoors.remember(
          SalonAnchor(
            id: seeded.meta.id,
            token: seeded.inviteToken!,
            seedX: seeded.meta.seedX,
            seedY: seeded.meta.seedY,
            kind: seeded.meta.kind == ConstellationKind.melody
                ? 'MELODY'
                : 'POEM',
            target: seeded.meta.target,
            heldSince: DateTime.now().millisecondsSinceEpoch,
          ),
        ),
      );
      await showContributeSheet(
        context,
        ref: ref,
        constellation: seeded.meta,
        inviteToken: seeded.inviteToken,
      );
      if (!mounted) return;
      await showSalonShareSheet(
        context,
        meta: seeded.meta,
        inviteToken: seeded.inviteToken!,
      );
      return;
    }
    await _loadConstellations();
    if (!mounted) return;
    ConstellationMeta? fresh;
    for (final c in _constellations) {
      if (c.id == seeded.meta.id) {
        fresh = c;
        break;
      }
    }
    if (fresh == null) return;
    await showContributeSheet(context, ref: ref, constellation: fresh);
    if (mounted) unawaited(_loadConstellations());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // V3.49 — a place link stands its ground BEFORE the first frame:
    // the sky opens where the stranger stood, then loads its own
    // rect (the default first gaze is skipped by the dedup union).
    final landed = widget.eye;
    if (landed != null && landed != const Offset(0.5, 0.5)) {
      _camera.panByWorld(landed - _camera.center);
      _landedByLink = true;
    }
    _loadVestiges();
    _loadConstellations();
    _loadArtifactMemory();
    _loadSalonDoors();
    _readCorpseGuide();
    _readEyeGuide();
    // The sky breathes: a quiet pull every 90 s — strangers' lines
    // appear on an OPEN map, states settle to the ether's truth. Pull
    // only, never a push; the cadence stays invisible.
    _skyBreath = Timer.periodic(const Duration(seconds: 90), (_) {
      if (mounted) _loadConstellations();
    });
    // V3.35 — the landscapes ride the camera's own pulse (no timers of
    // their own), and the drone learns the birth radius once it lives.
    _camera.addListener(_onEyeTravels);
    _onEyeTravels();
    if (_landedByLink) {
      // The first gaze at the landed rect (the default heart rect is
      // already covered by the union dedup).
      _refreshAfterTravel();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_landedByLink) showHud(context, 'UN ŒIL T\'A CONDUIT ICI.');
      final audio = ref.read(audioControllerProvider);
      unawaited(() async {
        await audio.ensureStarted();
        await audio.setDroneDepth(
          VoidTerritories.droneFactor(
            (_camera.center - VoidTerritories.heart).distance,
          ),
        );
      }());
    });
  }

  /// The corpses explain themselves once (like the waves' guide) —
  /// then the sky stays quiet about them forever.
  Future<void> _readCorpseGuide() async {
    final seen = await ref.read(localEchoStoreProvider).hasCorpseGuideSeen();
    if (mounted && !seen) setState(() => _showingCorpseGuide = true);
  }

  bool _showingCorpseGuide = false;

  void _dismissCorpseGuide() {
    setState(() => _showingCorpseGuide = false);
    unawaited(ref.read(localEchoStoreProvider).markCorpseGuideSeen());
  }

  /// Coalesced wheel zoom (V3.22): pending factor + anchor + the
  /// 32 ms apply timer — see the Listener's onPointerSignal.
  double _wheelFactor = 1.0;
  Offset _wheelAnchor = Offset.zero;
  Timer? _wheelDue;

  /// V3.17 — the wheel whisper: desktop eyes have no pinch to teach
  /// them the zoom. One quiet breath above the gates, once, never
  /// blocking the map (IgnorePointer), gone on its own.
  bool _showingEyeWhisper = false;
  Timer? _eyeWhisperTimer;

  /// The PWA on a desktop OS: the only place a wheel exists. Mobile
  /// eyes learn the pinch by hand — they never see this whisper.
  static bool get _isDesktopEye =>
      kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  Future<void> _readEyeGuide() async {
    if (!_isDesktopEye) return;
    final seen = await ref.read(localEchoStoreProvider).hasEyeGuideSeen();
    if (mounted && !seen) {
      setState(() => _showingEyeWhisper = true);
      _eyeWhisperTimer = Timer(const Duration(seconds: 8), _dismissEyeWhisper);
    }
  }

  void _dismissEyeWhisper() {
    _eyeWhisperTimer?.cancel();
    _eyeWhisperTimer = null;
    // The wheel moved: the whisper taught, it disappears — seen
    // either way, it never speaks twice.
    if (_showingEyeWhisper) {
      setState(() => _showingEyeWhisper = false);
    }
    unawaited(ref.read(localEchoStoreProvider).markEyeGuideSeen());
  }

  Future<void> _loadVestiges() async {
    final vestiges = await loadVestiges();
    if (mounted) setState(() => _vestiges = vestiges);
  }

  Future<void> _loadArtifactMemory() async {
    await _artifacts.load();
    if (mounted) setState(() {});
  }

  Future<void> _loadConstellations() async {
    try {
      final repo = ref.read(constellationRepositoryProvider);
      final visible = await repo.fetchVisible();
      if (mounted) setState(() => _constellations = visible);
      _tellClosedPoems(visible);
    } catch (e) {
      debugPrint('[kenos.constellations] unreachable: $e');
    }
  }

  /// V3.45 — the closure whisper: a corpse these hands helped write,
  /// CLOSED and not yet read, is told ONCE — then the ember orbit and
  /// the souffle carry it. The sky does not nag: told closures are
  /// remembered, read ones need no telling at all.
  void _tellClosedPoems(List<ConstellationMeta> visible) {
    if (!mounted || _closureWhisper != null) return;
    for (final cst in visible) {
      if (!cst.isClosed) continue;
      if (!_artifacts.contributedTo(cst.id)) continue;
      if (_artifacts.closureTold(cst.id)) continue;
      if (_artifacts.isRead(cst.id) || _artifacts.isKept(cst.id)) {
        // Already lived with: no telling, just remembered.
        unawaited(_artifacts.markClosureTold(cst.id));
        continue;
      }
      unawaited(_artifacts.markClosureTold(cst.id));
      setState(() => _closureWhisper = cst.id);
      _closureTimer = Timer(const Duration(seconds: 7), () {
        if (mounted) setState(() => _closureWhisper = null);
      });
      return; // one poem at a time; the next visit tells the next
    }
  }

  /// The doors this device holds, re-read from local memory — then
  /// each asked the ether's truth in the background: a ring closed
  /// into its artifact drops its anchor (the artifact is public now,
  /// and indistinguishable); a reaped one goes too, quietly.
  Future<void> _loadSalonDoors() async {
    await _salonDoors.load();
    if (!mounted) return;
    setState(() => _salonAnchors = _salonDoors.open());
    for (final anchor in _salonAnchors) {
      unawaited(_refreshSalonDoor(anchor));
    }
  }

  Future<void> _refreshSalonDoor(SalonAnchor anchor) async {
    try {
      final meta = await ref
          .read(constellationRepositoryProvider)
          .fetchInvited(anchor.token);
      if (!meta.isClosed) return;
      await _salonDoors.forget(anchor.id);
      if (!mounted) return;
      setState(() => _salonAnchors = _salonDoors.open());
      unawaited(_loadConstellations()); // the artifact joins the public sky
    } catch (e) {
      if (e.toString().contains('KENOS_INVITE_UNKNOWN')) {
        // The door died with its ring (reaped at seven days): the
        // anchor was a memory of a dead key — it goes too.
        await _salonDoors.forget(anchor.id);
        if (mounted) setState(() => _salonAnchors = _salonDoors.open());
        return;
      }
      // The sky being far is not the door being dead: the anchor
      // stays until the ether says otherwise (or day seven).
    }
  }

  /// A door held on this device: the tap knocks. Open and these
  /// hands gave → the honest state; open and empty-handed → the
  /// contribution offer (to their own poem the seeder is just
  /// another stranger); closed → the anchor dissolves into its
  /// public artifact, read whole, right away; dead → it goes.
  Future<void> _onSalonDoorTap(SalonAnchor anchor) async {
    KenosHaptics.pulse(KenosPulse.themePick);
    final ConstellationMeta meta;
    try {
      meta = await ref
          .read(constellationRepositoryProvider)
          .fetchInvited(anchor.token);
    } catch (e) {
      if (!e.toString().contains('KENOS_INVITE_UNKNOWN')) {
        if (mounted) showHud(context, 'L\'ÉTHER EST INJOIGNABLE.');
        return;
      }
      await _salonDoors.forget(anchor.id);
      if (!mounted) return;
      setState(() => _salonAnchors = _salonDoors.open());
      showHud(context, 'LE SALON S\'EST TU.');
      return;
    }
    if (!mounted) return;
    if (meta.isClosed) {
      await _salonDoors.forget(anchor.id);
      setState(() => _salonAnchors = _salonDoors.open());
      unawaited(_loadConstellations());
      final lines = await ref
          .read(constellationRepositoryProvider)
          .read(meta.id);
      if (!mounted) return;
      if (lines != null && lines.isNotEmpty) {
        await showConstellationReading(
          context,
          lines: lines,
          figureId: meta.id,
          curatedBy: meta.curatedBy,
          memory: _artifacts,
          keepPosition: Offset(meta.seedX, meta.seedY),
          reportable: true,
        );
      }
      return;
    }
    if (_artifacts.contributedTo(anchor.id)) {
      showHud(context, 'TA LIGNE EST DÉJÀ DANS CE CORPS.');
      return;
    }
    // V3.53 — an UNTOUCHED door offers the seeder a second key: a
    // silent guest's seat is not a condemnation anymore. Nobody
    // wrote — nobody is replaced.
    if (meta.lineCount == 0) {
      final choice = await showUntouchedDoorChoice(
        context,
        song: meta.kind == ConstellationKind.melody,
      );
      if (!mounted || choice == null) return;
      if (choice == UntouchedDoorChoice.reseed) {
        await _reseedSalonKey(anchor, meta);
        return;
      }
    }
    await showContributeSheet(
      context,
      ref: ref,
      constellation: meta,
      inviteToken: anchor.token,
    );
    if (mounted) unawaited(_loadSalonDoors());
  }

  /// V3.53 — the seeder cuts a fresh key: the old one dies with the
  /// cut, the anchor forgets it, the new link is shown ONCE (the
  /// V3.19 grammar) and remembered on this device alone.
  Future<void> _reseedSalonKey(
    SalonAnchor anchor,
    ConstellationMeta meta,
  ) async {
    try {
      final token = await ref
          .read(constellationRepositoryProvider)
          .reseedKey(meta.id);
      await _salonDoors.remember(
        SalonAnchor(
          id: anchor.id,
          token: token,
          seedX: anchor.seedX,
          seedY: anchor.seedY,
          kind: anchor.kind,
          target: anchor.target,
          heldSince: anchor.heldSince,
        ),
      );
      if (!mounted) return;
      setState(() => _salonAnchors = _salonDoors.open());
      await showSalonShareSheet(context, meta: meta, inviteToken: token);
    } catch (e) {
      if (mounted) showHud(context, reseedRefusalMessage(e));
    }
  }

  void _maybeSpeakAube() {
    if (_aubeSpokenThisSession || !mounted) return;
    final receptions = ref.read(receptionControllerProvider).valueOrNull;
    if (receptions == null) return; // still syncing: wait.
    _aubeSpokenThisSession = true;
    unawaited(maybeShowAwakening(context, ref));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _skyBreath?.cancel();
    _glide?.cancel();
    _eyeWhisperTimer?.cancel();
    _wheelDue?.cancel();
    _territoryTimer?.cancel();
    _closureTimer?.cancel();
    _camera.removeListener(_onEyeTravels);
    _camera.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // V3.49 — a place link arriving at a LIVING map (the router
    // reuses the page element when the pages carry no keys): stand
    // the eye where the stranger stood, load that rect, murmur it.
    final landed = widget.eye;
    if (landed != null && landed != oldWidget.eye) {
      _glide?.cancel();
      _camera.panByWorld(landed - _camera.center);
      _landedByLink = true;
      _refreshAfterTravel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showHud(context, 'UN ŒIL T\'A CONDUIT ICI.');
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back to the sky: the ether has written meanwhile — the
    // corpses' truth (lines, states) and the shards' daily rotation
    // are pulled the moment the traveller returns.
    if (state == AppLifecycleState.resumed) {
      _loadConstellations();
      _loadVestiges();
      _loadSalonDoors();
    }
  }

  /// The sky follows the fingers: one finger travels, two fingers
  /// also zoom (the point between them stays anchored under the
  /// pinch — clustered stars can be separated to be held).
  void _onScaleStart(ScaleStartDetails details) {
    _glide?.cancel();
    _lastPointerDown = details.focalPoint;
    _dragTotal = Offset.zero;
    _pinchFactor = 1.0;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // No setState: the camera notifies, only the layers that look
    // through it rebuild (the screen and the HUD stay untouched).
    if (details.pointerCount >= 2 && details.scale != 1.0) {
      _camera.zoomBy(
        details.scale / _pinchFactor,
        _screenToWorld(details.focalPoint),
      );
      _pinchFactor = details.scale;
    }
    _dragTotal += details.focalPointDelta;
    _camera.panByScreen(details.focalPointDelta, _viewport);
  }

  void _onScaleEnd(ScaleEndDetails details) {
    // Neither travelled nor zoomed: an intention — a planet glides the
    // eye toward its gravity. (One detector, one grammar.)
    if (_dragTotal.distance < 8 && (_pinchFactor - 1.0).abs() < 0.03) {
      _onVoidTap();
      return;
    }
    if (context.wantsReducedMotion) {
      _refreshAfterTravel();
      return;
    }
    final velocity = details.velocity.pixelsPerSecond;
    final worldPerSecond = Offset(
      velocity.dx / (_viewport.width) * _camera.viewExtent,
      velocity.dy / (_viewport.height) * _camera.viewExtent,
    );
    final path = DriftGlide().path(-worldPerSecond).toList();
    if (path.isEmpty) {
      _refreshAfterTravel();
      return;
    }
    var i = 0;
    _glide?.cancel();
    _glide = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (i >= path.length) {
        _glide?.cancel();
        _glide = null;
        _refreshAfterTravel();
        return;
      }
      _camera.panByWorld(path[i++]);
    });
  }

  /// Screen point → world point (for anchoring the pinch).
  Offset _screenToWorld(Offset screen) => Offset(
    (screen.dx - _viewport.width / 2) / _viewport.width * _camera.viewExtent +
        _camera.center.dx,
    (screen.dy - _viewport.height / 2) / _viewport.height * _camera.viewExtent +
        _camera.center.dy,
  );

  /// Publish where the eye rests (music of the spheres listens there).
  void _publishPosition() {
    ref.read(travelPositionProvider.notifier).state = _camera.center;
  }

  /// What the eye sees changed: ask the ether for this window.
  void _refreshAfterTravel() {
    final r = _camera.visibleRect;
    unawaited(
      ref
          .read(mapControllerProvider.notifier)
          .refreshViewport(
            minX: r.minX,
            minY: r.minY,
            maxX: r.maxX,
            maxY: r.maxY,
          ),
    );
  }

  /// Desktop hover: a named body whispers its name before the plaque.
  void _onFieldHover(PointerHoverEvent event) {
    final now = DateTime.now();
    ({bool wanderer, int index})? target;
    final w = wandererHitTest(
      screenPoint: event.position,
      camera: _camera,
      viewport: _viewport,
      now: now,
    );
    if (w >= 0) {
      target = (wanderer: true, index: w);
    } else {
      final p = planetHitTest(
        screenPoint: event.position,
        camera: _camera,
        viewport: _viewport,
        now: now,
      );
      if (p >= 0) target = (wanderer: false, index: p);
    }
    // Records compare by value: the setState fires only when the
    // pointer actually changes worlds — a move WITHIN the same body
    // costs nothing (the label follows by itself).
    if (target != _hoverTarget) {
      setState(() => _hoverTarget = target);
    }
  }

  /// A tap on the void: a named body explains itself (V3.12) — the
  /// plaque carries « voyager vers » for the anchors. Tapping empty
  /// space travels nowhere (the drag is the road, the tap is the
  /// intention).
  Future<void> _onVoidTap() async {
    _publishPosition();
    final now = DateTime.now();
    final wanderer = wandererHitTest(
      screenPoint: _lastPointerDown,
      camera: _camera,
      viewport: _viewport,
      now: now,
    );
    if (wanderer >= 0) {
      KenosHaptics.pulse(KenosPulse.themePick);
      await showCelestialPlaque(
        context,
        body: celestialWanderers[wanderer],
        sharePosition:
            CelestialMath.wandererPosition(wanderer, DateTime.now()),
      );
      return;
    }
    final hit = planetHitTest(
      screenPoint: _lastPointerDown,
      camera: _camera,
      viewport: _viewport,
      now: now,
    );
    if (hit < 0) return;
    KenosHaptics.pulse(KenosPulse.themePick);
    final echoes =
        ref.read(mapControllerProvider).valueOrNull ?? const <Echo>[];
    final orbitCount = echoes
        .where((e) => !e.isMine && KenosSystem.planetIndexOf(e) == hit)
        .length;
    await showCelestialPlaque(
      context,
      body: celestialBodies[hit],
      orbitCount: orbitCount,
      sharePosition: KenosSystem.planetPosition(hit, DateTime.now()),
      onTravel: () {
        final target = KenosSystem.planetPosition(hit, DateTime.now());
        _glide?.cancel();
        _camera.panByWorld(target - _camera.center);
        _refreshAfterTravel();
      },
    );
  }

  /// An OPEN corpse takes a line (continuing the preceding one); a
  /// CLOSED one is an ARTIFACT — readable by everyone, contributors
  /// included, again and again. Nothing is consumed anymore.
  Future<void> _onConstellationTap(ConstellationMeta cst) async {
    KenosHaptics.pulse(KenosPulse.themePick);
    if (cst.isClosed) {
      final lines = await ref
          .read(constellationRepositoryProvider)
          .read(cst.id);
      if (!mounted) return;
      if (lines == null || lines.isEmpty) {
        // Gone with the moon — unless THIS traveller kept it: the
        // reliquaire re-reads locally, ember-marked.
        final kept = _artifacts.keptById(cst.id);
        if (kept != null) {
          await showConstellationReading(
            context,
            lines: [
              for (var i = 0; i < kept.texts.length; i++)
                AssembledLine(number: i + 1, text: kept.texts[i]),
            ],
            figureId: kept.id,
            curatedBy: kept.curatedBy,
          );
          return;
        }
        // Open race (closed elsewhere is impossible here) or gone
        // with the moon: the sky tells the truth again.
        unawaited(_loadConstellations());
        return;
      }
      await showConstellationReading(
        context,
        lines: lines,
        figureId: cst.id,
        curatedBy: cst.curatedBy,
        memory: _artifacts,
        keepPosition: Offset(cst.seedX, cst.seedY),
        reportable: true,
      );
      // No reload: the artifact stays, refermé.
    } else {
      await _offerIfNewToMe(cst);
    }
  }

  /// One line per stranger per corpse — and the OFFER must never
  /// come for hands that already gave. Two truths, in order: the
  /// device's memory first (instant), then the ether itself (the
  /// only truth across devices and sessions). When the ether says
  /// yes-these-hands-gave, its answer becomes local memory — the
  /// question is never asked again for this corpse.
  Future<void> _offerIfNewToMe(ConstellationMeta cst) async {
    if (_artifacts.contributedTo(cst.id)) {
      showHud(context, 'TA LIGNE EST DÉJÀ DANS CE CORPS.');
      return;
    }
    final etherSays = await ref
        .read(constellationRepositoryProvider)
        .hasContributed(cst.id);
    if (!mounted) return;
    if (etherSays == true) {
      unawaited(_artifacts.markContributed(cst.id));
      showHud(context, 'TA LIGNE EST DÉJÀ DANS CE CORPS.');
      return;
    }
    await showContributeSheet(context, ref: ref, constellation: cst);
    if (mounted) unawaited(_loadConstellations());
  }

  /// RECALIBRER, travelled: return the eye to the heart of the ether.
  void _recenter() {
    _glide?.cancel();
    _camera.recenter();
    _refreshAfterTravel();
  }

  @override
  Widget build(BuildContext context) {
    final echoes = ref.watch(mapControllerProvider);
    final reduced = context.wantsReducedMotion;
    final all = echoes.valueOrNull ?? const <Echo>[];
    final readable = all.where((e) => !e.isMine).length;
    final signals =
        ref.watch(receptionControllerProvider).valueOrNull?.length ?? 0;
    // The reader's trail: faint hollow points where lights dissolved.
    final scars =
        ref.watch(readScarControllerProvider).valueOrNull ?? const <ReadScar>[];

    // L'Aube: once the first sync settles, the sas may speak.
    ref.listen(receptionControllerProvider, (previous, next) {
      if (previous == null || !previous.hasValue) _maybeSpeakAube();
    });

    // A new signal lands: the device feels it (single informative
    // pulse, kept even under reduce-motion).
    ref.listen<int>(
      receptionControllerProvider.select(
        (receptions) => receptions.valueOrNull?.length ?? 0,
      ),
      (previous, next) {
        if ((previous ?? 0) < next) {
          KenosHaptics.pulse(KenosPulse.signal, reduceMotion: reduced);
        }
      },
    );

    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      // First gesture anywhere = audio unlock (iOS autoplay policy).
      body: Listener(
        onPointerDown: (_) =>
            unawaited(ref.read(audioControllerProvider).ensureStarted()),
        // Desktop: the wheel zooms, anchored under the cursor — the
        // mouse's pinch. Up = closer, down = further; smooth enough
        // for trackpads (small deltas), strong enough for notches.
        onPointerSignal: (signal) {
          if (signal is PointerScrollEvent) {
            // The eye found the wheel: the whisper has nothing left
            // to teach (V3.17).
            if (_showingEyeWhisper) _dismissEyeWhisper();
            _glide?.cancel();
            // Coalesced at 32 ms (V3.22): a trackpad flick fires
            // dozens of signals a second, each one rebuilding the
            // whole sky — the zoom eases at 30 fps instead, factors
            // multiplied, anchor kept at the freshest cursor.
            _wheelFactor *= math.pow(1.0015, -signal.scrollDelta.dy).toDouble();
            _wheelAnchor = _screenToWorld(signal.position);
            _wheelDue ??= Timer(const Duration(milliseconds: 32), () {
              _wheelDue = null;
              _camera.zoomBy(_wheelFactor, _wheelAnchor);
              _wheelFactor = 1.0;
            });
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Spatial void + diffuse nebulae + dead star field (scenery).
            const _AmbientBackground(),
            // The matter: the echoes — and the travelling eye.
            LayoutBuilder(
              builder: (context, constraints) {
                _viewport = Size(constraints.maxWidth, constraints.maxHeight);
                return MouseRegion(
                  // Desktop: named bodies whisper their name on hover.
                  cursor: _hoverTarget != null
                      ? SystemMouseCursors.click
                      : MouseCursor.defer,
                  onHover: _onFieldHover,
                  onExit: (_) {
                    if (_hoverTarget != null) {
                      setState(() => _hoverTarget = null);
                    }
                  },
                  child: GestureDetector(
                    // The sky follows the finger; holding a star keeps
                    // its own friction (a >28px drift cancels the hold
                    // and hands the gesture to the void). Tapping a
                    // planet glides the eye toward its gravity.
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: _onScaleUpdate,
                    onScaleEnd: _onScaleEnd,
                    behavior: HitTestBehavior.translucent,
                    // The eye moves → only what looks through it
                    // rebuilds: heavens, vestiges, corpses, stars. The
                    // HUD, the gates and the scenery keep their frames.
                    child: ListenableBuilder(
                      listenable: _camera,
                      // epoch lives HERE, inside the camera builder: a
                      // stale captured epoch made shouldRepaint see two
                      // identical clocks — the heavens froze mid-gesture
                      // and jumped at the next screen rebuild.
                      builder: (context, _) {
                        final epoch = DateTime.now();
                        // V3.12c — serene real estate: every resting
                        // body (vestige, corpse) is resolved against
                        // the throat, the lanes, the beacon and every
                        // one placed before it, in stable order.
                        // The reliquaire: kept objects stay in this
                        // sky even when the moon (or the daily shard
                        // rotation) takes the original back — merged
                        // in, local forever, ember-marked.
                        final vestigesShown = [
                          ..._vestiges,
                          for (final k in _artifacts.kept())
                            if (k.kind == 'vestige' &&
                                !_vestiges.any((v) => v.id == k.id))
                              Vestige(
                                id: k.id,
                                kind: k.vestigeKind ?? 'quote',
                                text: k.texts.first,
                                source: k.source ?? 'kenos',
                                offsetX: k.x,
                                offsetY: k.y,
                              ),
                        ];
                        final constellationsShown = [
                          ..._constellations,
                          for (final k in _artifacts.kept())
                            if (k.kind == 'constellation' &&
                                !_constellations.any((c) => c.id == k.id))
                              ConstellationMeta(
                                id: k.id,
                                seedX: k.x,
                                seedY: k.y,
                                state: 'CLOSED',
                                lineCount: k.texts.length,
                                target: k.target,
                                kind: ConstellationKind.poem,
                                curatedBy: k.curatedBy,
                              ),
                        ];
                        final staticAnchors = <Offset>[];
                        final vestigeAt = <String, Offset>{};
                        for (final v in vestigesShown) {
                          final at = KenosSystem.resolveResting(
                            Offset(v.offsetX, v.offsetY),
                            occupied: staticAnchors,
                          );
                          vestigeAt[v.id] = at;
                          staticAnchors.add(at);
                        }
                        final corpseAt = <String, Offset>{};
                        for (final cst in constellationsShown) {
                          final at = KenosSystem.resolveResting(
                            Offset(cst.seedX, cst.seedY),
                            occupied: staticAnchors,
                          );
                          corpseAt[cst.id] = at;
                          staticAnchors.add(at);
                        }
                        final salonAt = <String, Offset>{};
                        for (final door in _salonAnchors) {
                          final at = KenosSystem.resolveResting(
                            Offset(door.seedX, door.seedY),
                            occupied: staticAnchors,
                          );
                          salonAt[door.id] = at;
                          staticAnchors.add(at);
                        }
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            // V3.34 — the deep field: the far universe
                            // behind the ether, riding slower layers than
                            // the world — the pan becomes a passage, not a
                            // scroll. Scenery, never matter (IgnorePointer:
                            // the V3.12b lesson — a childless full-screen
                            // CustomPaint would starve the holds above).
                            RepaintBoundary(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: DeepFieldPainter(camera: _camera),
                                ),
                              ),
                            ),
                            // The reader's trail: hollow points where lights
                            // dissolved — local, contentless, fading.
                            if (scars.isNotEmpty)
                              RepaintBoundary(
                                child: CustomPaint(
                                  painter: ScarFieldPainter(
                                    center: _camera.center,
                                    zoom: _camera.zoom,
                                    scars: scars,
                                  ),
                                ),
                              ),
                            // The lights first (V3.17b): echoes drift as
                            // the deepest living layer — the heavens
                            // above them eclipse what crosses a body.
                            echoes.when(
                              data: (list) => list.isEmpty
                                  ? const _CalmEther()
                                  : _ParallaxStarLayer(
                                      echoes: list,
                                      camera: _camera,
                                    ),
                              loading: () => const _Centered(
                                'CALIBRATION DE L\'ÉTHER…',
                                color: AppColors.teal,
                              ),
                              error: (e, _) => _UnreachableEther(
                                onRetry: () {
                                  ref.invalidate(sessionReadyProvider);
                                  ref.invalidate(mapControllerProvider);
                                },
                              ),
                            ),
                            // The heavens: black hole + planets + wanderers,
                            // ABOVE the lights (V3.17b — the eclipse fix):
                            // a body occludes a light, never the other way
                            // — an echo drifting over Polaris passes BEHIND
                            // her disc now, and the black hole truly
                            // swallows what crosses it (its oldest
                            // comment finally true). IgnorePointer: a
                            // childless full-screen CustomPaint claims
                            // hit-tests and would starve the stars'
                            // holds beneath it (the V3.12b lesson).
                            // The heavens' clock: the sky drifts on its
                            // OWN heartbeat, not only when the eye
                            // moves (V3.12c).
                            _HeavensClock(
                              builder: (context, heavensAt) => RepaintBoundary(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: SystemPainter(
                                      camera: _camera,
                                      viewport: _viewport,
                                      now: heavensAt,
                                      reducedMotion: context.wantsReducedMotion,
                                      echoes:
                                          echoes.valueOrNull ?? const <Echo>[],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // The Vestiges: carved shards of culture, static
                            // in the void, tappable for a re-readable reveal.
                            // Their tumble rides their own CALM clock
                            // (V3.17c: 64 shards repainting at the heavens'
                            // 12.5 Hz beat was a third of the wide view's
                            // paint bill) and the whole stack owns ONE
                            // RepaintBoundary — culture drifts even when
                            // the eye rests, cheaply.
                            if (vestigesShown.isNotEmpty)
                              RepaintBoundary(
                                child: _HeavensClock(
                                  period: const Duration(milliseconds: 250),
                                  builder: (context, vestigeBeat) => LayoutBuilder(
                                    builder: (context, c) => Stack(
                                      children: [
                                        for (final v in vestigesShown)
                                          Builder(
                                            builder: (context) {
                                              final sp = _camera.worldToScreen(
                                                vestigeAt[v.id] ??
                                                    Offset(
                                                      v.offsetX,
                                                      v.offsetY,
                                                    ),
                                                Size(c.maxWidth, c.maxHeight),
                                              );
                                              if (sp.dx < -30 ||
                                                  sp.dx > c.maxWidth + 30 ||
                                                  sp.dy < -30 ||
                                                  sp.dy > c.maxHeight + 30) {
                                                return const SizedBox.shrink();
                                              }
                                              // Shards grow with the eye
                                              // too (V3.17) — the painter
                                              // sizes itself to its box.
                                              final shardSide =
                                                  32 *
                                                  ParallaxMath.zoomScale(
                                                    _camera.zoom,
                                                  );
                                              return Positioned(
                                                left: sp.dx - shardSide / 2,
                                                top: sp.dy - shardSide / 2,
                                                width: shardSide,
                                                height: shardSide,
                                                child: GestureDetector(
                                                  behavior:
                                                      HitTestBehavior.opaque,
                                                  onTap: () async {
                                                    await showVestigeSheet(
                                                      context,
                                                      vestige: v,
                                                      memory: _artifacts,
                                                    );
                                                    if (mounted) {
                                                      setState(() {});
                                                    }
                                                  },
                                                  child: CustomPaint(
                                                    painter: VestigePainter(
                                                      rotation:
                                                          VestigeMath.rotationAt(
                                                            v.id,
                                                            context.wantsReducedMotion
                                                                ? epoch
                                                                : DateTime.now(),
                                                          ),
                                                      color:
                                                          _artifacts.isKept(
                                                            v.id,
                                                          )
                                                          ? AppColors.ember
                                                          : AppColors.pureLight,
                                                      pulse: 0,
                                                      read:
                                                          _artifacts.isRead(
                                                            v.id,
                                                          ) &&
                                                          !_artifacts.isKept(
                                                            v.id,
                                                          ),
                                                      kept: _artifacts.isKept(
                                                        v.id,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            // The Constellations: exquisite corpses. OPEN =
                            //    contribute a blind line; CLOSED = read it
                            //    whole, once. Never both for the same person.
                            if (constellationsShown.isNotEmpty)
                              LayoutBuilder(
                                builder: (context, c) => Stack(
                                  children: [
                                    for (final cst in constellationsShown)
                                      Builder(
                                        builder: (context) {
                                          final sp = _camera.worldToScreen(
                                            corpseAt[cst.id] ??
                                                Offset(cst.seedX, cst.seedY),
                                            Size(c.maxWidth, c.maxHeight),
                                          );
                                          if (sp.dx < -72 ||
                                              sp.dx > c.maxWidth + 72 ||
                                              sp.dy < -72 ||
                                              sp.dy > c.maxHeight + 72) {
                                            return const SizedBox.shrink();
                                          }
                                          // Gates grow with the eye
                                          // (V3.17): the ring painter
                                          // reads its box size. V3.29:
                                          // 46 → 68 and viewport-scaled —
                                          // the corpses were the smallest
                                          // things in their own sky.
                                          final gateSide =
                                              68 *
                                              ParallaxMath.zoomScale(
                                                _camera.zoom,
                                              ) *
                                              math.max(
                                                ParallaxMath.displayScale(
                                                  math.min(
                                                    c.maxWidth,
                                                    c.maxHeight,
                                                  ),
                                                ),
                                                0.8,
                                              );
                                          return Positioned(
                                            left: sp.dx - gateSide / 2,
                                            top: sp.dy - gateSide / 2,
                                            width: gateSide,
                                            height: gateSide,
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () =>
                                                  _onConstellationTap(cst),
                                              child: CustomPaint(
                                                painter: _ConstellationPainter(
                                                  id: cst.id,
                                                  closed: cst.isClosed,
                                                  lineCount: cst.lineCount,
                                                  target: cst.target,
                                                  read:
                                                      _artifacts.isRead(
                                                        cst.id,
                                                      ) &&
                                                      !_artifacts.isKept(
                                                        cst.id,
                                                      ),
                                                  kept: _artifacts.isKept(
                                                    cst.id,
                                                  ),
                                                  mine: _artifacts
                                                      .contributedTo(cst.id),
                                                  // Songs read cyan (the waves'
                                                  // instrument), poems white;
                                                  // closed = indigo artifact.
                                                  color: cst.isClosed
                                                      ? AppColors.indigo
                                                      : cst.kind ==
                                                            ConstellationKind
                                                                .melody
                                                      ? AppColors.cyan
                                                      : AppColors.pureLight,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            // L'ANCRE DU SALON: the doors this device
                            // holds — ember seeds where hidden rings
                            // sleep, visible to their holder alone.
                            if (_salonAnchors.isNotEmpty)
                              LayoutBuilder(
                                builder: (context, c) => Stack(
                                  children: [
                                    for (final door in _salonAnchors)
                                      Builder(
                                        builder: (context) {
                                          final sp = _camera.worldToScreen(
                                            salonAt[door.id] ??
                                                Offset(door.seedX, door.seedY),
                                            Size(c.maxWidth, c.maxHeight),
                                          );
                                          if (sp.dx < -72 ||
                                              sp.dx > c.maxWidth + 72 ||
                                              sp.dy < -72 ||
                                              sp.dy > c.maxHeight + 72) {
                                            return const SizedBox.shrink();
                                          }
                                          final gateSide =
                                              68 *
                                              ParallaxMath.zoomScale(
                                                _camera.zoom,
                                              ) *
                                              math.max(
                                                ParallaxMath.displayScale(
                                                  math.min(
                                                    c.maxWidth,
                                                    c.maxHeight,
                                                  ),
                                                ),
                                                0.8,
                                              );
                                          return Positioned(
                                            key: ValueKey(
                                              'salon_anchor_${door.id}',
                                            ),
                                            left: sp.dx - gateSide / 2,
                                            top: sp.dy - gateSide / 2,
                                            width: gateSide,
                                            height: gateSide,
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () =>
                                                  _onSalonDoorTap(door),
                                              child: CustomPaint(
                                                painter: _SalonAnchorPainter(
                                                  mine: _artifacts
                                                      .contributedTo(door.id),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            // V3.12b — the falls: what dies here spirals
                            // into the black hole, above the stars —
                            // and NEVER intercepts a pointer: a
                            // full-screen CustomPaint claims hit-tests
                            // by default (hitTestSelf → size.contains),
                            // which starved every widget beneath it
                            // (stars, vestiges, corpses: unclickable).
                            _HeavensClock(
                              builder: (context, fallAt) => IgnorePointer(
                                child: CustomPaint(
                                  painter: AccretionPainter(
                                    motes: ref.watch(accretionProvider),
                                    camera: _camera,
                                    viewport: _viewport,
                                    now: fallAt,
                                    reducedMotion: reduced,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            // V3.12 — the hovered body's name, floating beside it.
            // V3.38 — the label RIDES its body: the heavens' beat (a
            // hovered world keeps orbiting) and the camera's pulse (the
            // sky pans under a still pointer) each recompute its place,
            // and it anchors OUTSIDE the body's tap zone — at deep zoom
            // the old fixed offset printed the name ON the world, and
            // a drift left it floating mid-void. A static Positioned
            // at the origin carries a translated label: ParentData
            // must not live inside the ticking builders.
            if (_hoverTarget != null)
              Positioned(
                left: 0,
                top: 0,
                child: _HeavensClock(
                  builder: (context, _) => ListenableBuilder(
                    listenable: _camera,
                    builder: (context, _) {
                      final target = _hoverTarget;
                      if (target == null) return const SizedBox.shrink();
                      final now = DateTime.now();
                      final String name;
                      final Rect zone;
                      if (target.wanderer) {
                        name = celestialWanderers[target.index].name;
                        zone = wandererTapRect(
                          index: target.index,
                          camera: _camera,
                          viewport: _viewport,
                          now: now,
                        );
                      } else {
                        name = celestialBodies[target.index].name;
                        zone = planetTapRect(
                          index: target.index,
                          camera: _camera,
                          viewport: _viewport,
                          now: now,
                        );
                      }
                      final offset = Offset(
                        (zone.topRight.dx + 10).clamp(
                          8.0,
                          _viewport.width - 150,
                        ),
                        (zone.top - 34).clamp(8.0, _viewport.height - 40),
                      );
                      return IgnorePointer(
                        child: Transform.translate(
                          offset: offset,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.fade(AppColors.voidBlack, 0.8),
                              border: Border.all(
                                color: AppColors.hairlineStrong,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              name,
                              style: TextStyle(
                                fontFamily: AppFonts.mono,
                                fontSize: 9,
                                letterSpacing: 3,
                                color: AppColors.fade(
                                  AppColors.pureLight,
                                  0.75,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            // Top HUD — one thin line of machine whisper, one row of
            // quiet controls. The void dominates; the numbers breathe.
            SafeArea(
              child: Padding(
                padding: AppLayout.hudPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ONE line: the state that matters now.
                    Text(
                      _hudHeadline(readable: readable, signals: signals),
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontSize: 9,
                        letterSpacing: 3,
                        color: signals > 0
                            ? AppColors.teal
                            : AppColors.fade(AppColors.cyan, 0.55),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // The quiet second line — presence, not urgency.
                    // Listens to the eye: the drift label follows the
                    // travel without waking the whole screen.
                    ListenableBuilder(
                      listenable: _camera,
                      builder: (context, _) => Text(
                        _readableSilent(
                          compact: MediaQuery.sizeOf(context).width < 430,
                        ),
                        style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: 8,
                          letterSpacing: 3,
                          color: AppColors.fade(AppColors.pureLight, 0.28),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // V3.44 — on tablets and desktops the HUD's doors
                    // gain a breath of size (a finger of tablet
                    // deserves more than a phone's whisper); phones
                    // keep the tuned compact line.
                    Builder(
                      builder: (context) {
                        final wide = MediaQuery.sizeOf(context).width >= 700;
                        final hudDoor = TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: wide ? 11.0 : 10.0,
                          letterSpacing: 2.5,
                          color: AppColors.fade(AppColors.pureLight, 0.55),
                        );
                        Widget hudDoorButton(
                          String label,
                          VoidCallback? onPressed, {
                          VoidCallback? onLongPress,
                        }) => TextButton(
                          onPressed: onPressed,
                          onLongPress: onLongPress,
                          child: Text(label, style: hudDoor),
                        );
                        return Wrap(
                          spacing: 0,
                          runSpacing: 0,
                          children: [
                            const _SoundToggle(),
                            hudDoorButton(
                              'ONDES',
                              () => context.push('/frequencies'),
                            ),
                            hudDoorButton(
                              'IMPACT',
                              () => context.push('/impact'),
                            ),
                            hudDoorButton(
                              // V3.28 — the organization told at a
                              // glance. V3.30 — a LONG press opens the
                              // library: the vestiges, at leisure.
                              'CARTE',
                              () => showSkyMapSheet(
                                context,
                                eye: _camera.center,
                                onTravel: (target) {
                                  _glide?.cancel();
                                  _camera.panByWorld(target - _camera.center);
                                  _refreshAfterTravel();
                                },
                              ),
                              onLongPress: () => showVestigeLibrary(
                                context,
                                vestiges: _vestiges,
                                artifacts: _artifacts,
                                eye: _camera.center,
                              ),
                            ),
                            hudDoorButton('RECALIBRER', _recenter),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            // The origin node: one's warm ember anchor, stardust
            // riding around it. Quiet impact, one tap away. On narrow
            // portraits it sits above the mirror gate — never under it.
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: EdgeInsets.only(
                  left: AppLayout.originLeft,
                  bottom:
                      MediaQuery.sizeOf(context).width <
                          AppLayout.mirrorGateMaxWidth
                      ? AppLayout.originBottomNarrow
                      : AppLayout.originBottomWide,
                ),
                child: const OriginNode(),
              ),
            ),
            // Mirror gate + the corpse's own door: two acts of
            // different natures, two doors — one empties oneself
            // (the Mirror), one opens a space for strangers.
            // V3.41 — LES DEUX PORTES: one family, two intensities
            // (the hierarchy rides LIGHT, not noise), opaque fills
            // so the sky never prints through the words, targets the
            // thumb can't miss. The corpse's indigo stays on the map
            // — as a gate on the void it read as mud.
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                minimum: const EdgeInsets.only(
                  bottom: AppLayout.mirrorGateBottomInset,
                ),
                // V3.43 — wide windows: the two doors stand SIDE BY
                // SIDE (two doors, côte à côte); phones keep the
                // stack, where the thumb lives.
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide =
                        constraints.maxWidth >= AppLayout.gatesSideBySide;
                    return Flex(
                      direction: wide ? Axis.horizontal : Axis.vertical,
                      mainAxisSize: MainAxisSize.min,
                      // Both doors stand on the same floor (the first
                      // is a breath taller — the hierarchy, again).
                      crossAxisAlignment: wide
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.center,
                      children: [
                        _GateDoor(
                          key: const ValueKey('gate-constellation'),
                          label: ref.watch(voiceProvider).pick(
                            'SEMER UNE CONSTELLATION',
                            'SOW A CONSTELLATION',
                          ),
                          onPressed: () async {
                            final seeded = await context.push('/cadavre');
                            if (seeded is SeededConstellation) {
                              await _corpseSeeded(seeded);
                            }
                          },
                        ),
                        SizedBox(width: wide ? 14 : 0, height: wide ? 0 : 10),
                        _GateDoor.first(
                          key: const ValueKey('gate-echo'),
                          label: ref.watch(voiceProvider).pick(
                            'FORMULER UN ÉCHO',
                            'FORMULATE AN ECHO',
                          ),
                          onPressed: () => context.push('/mirror'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            // The corpses explain themselves, once.
            if (_showingCorpseGuide)
              Positioned.fill(
                child: _CorpseGuide(onUnderstood: _dismissCorpseGuide),
              ),
            // The wheel whisper (desktop eye, once): a breath above
            // the gates, never blocking — see _EyeWhisper.
            if (_showingEyeWhisper)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 200,
                child: IgnorePointer(child: _EyeWhisper()),
              ),
            // The territory's breath (V3.35, once per landscape per
            // session): the crossing is told, then the sky stays quiet
            // about it forever. Sits above the wheel whisper's spot —
            // the two never overlap.
            if (_territoryWhispering != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 264,
                child: IgnorePointer(
                  child: _TerritoryWhisper(territory: _territoryWhispering!),
                ),
              ),
            // The closure whisper (V3.45, once per poem): a corpse
            // these hands wrote in has closed — the artifact waits,
            // ember-orbited, and the souffle knows the way. Shares the
            // territory's slot: the sky speaks one thing at a time.
            if (_closureWhisper != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 264,
                child: const IgnorePointer(child: _ClosureWhisper()),
              ),
          ],
        ),
      ),
    );
  }
}

/// Scenery layer: nebulae + dead star field.
///
/// The twinkle ticks at ~8 fps through a plain timer — scenery must
/// breathe without repainting at display rate (a sanctuary app owes
/// the battery some silence). Frozen entirely under reduce-motion.
class _AmbientBackground extends ConsumerStatefulWidget {
  const _AmbientBackground();

  @override
  ConsumerState<_AmbientBackground> createState() => _AmbientBackgroundState();
}

/// Epsilon gate for the tilt stream: quantized to 0.02 (≤ ~1 px of
/// parallax at the strongest amplitude). Records compare BY VALUE, so
/// `select` skips the rebuild while the drift stays sub-pixel — the
/// eye sees the same sky, the frames stop bleeding.
({double x, double y}) _gateTilt(AsyncValue<Tilt> value) {
  final t = value.valueOrNull ?? Tilt.zero;
  return (x: (t.x * 50).round() / 50, y: (t.y * 50).round() / 50);
}

class _AmbientBackgroundState extends ConsumerState<_AmbientBackground> {
  static const _tick = Duration(milliseconds: 125);

  double _time = 0;
  Timer? _twinkle;

  @override
  void initState() {
    super.initState();
    if (!platformDisablesAnimations()) {
      _twinkle = Timer.periodic(_tick, (_) {
        if (mounted) setState(() => _time += _tick.inMilliseconds / 1000);
      });
    }
  }

  @override
  void dispose() {
    _twinkle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ambient parallax calms down (×0.15) but stays alive: the ether is
    // not a screenshot.
    final motionScale = context.wantsReducedMotion ? 0.15 : 1.0;
    final tilt = ref.watch(tiltProvider.select(_gateTilt));

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: NebulaPainter(
              tiltX: tilt.x * 0.5 * motionScale,
              tiltY: tilt.y * 0.5 * motionScale,
              time: _time,
            ),
          ),
          CustomPaint(
            painter: BackgroundStarFieldPainter(
              time: _time,
              tiltX: tilt.x * motionScale,
              tiltY: tilt.y * motionScale,
            ),
          ),
        ],
      ),
    );
  }
}

/// Positions echoes in space: normalized coordinates, parallax
/// proportional to depth, close buckets painted last.
///
/// Stars are grouped in depth buckets; the whole bucket translates with
/// the tilt (one Transform per bucket) instead of rewriting every star's
/// position at sensor rate. Distant buckets share one blur layer instead
/// of one saveLayer per star.
class _ParallaxStarLayer extends ConsumerStatefulWidget {
  const _ParallaxStarLayer({required this.echoes, required this.camera});

  final List<Echo> echoes;

  /// The traveller's eye: stars are placed in the WORLD, the camera
  /// decides which sky the screen holds.
  final TravelCamera camera;

  @override
  ConsumerState<_ParallaxStarLayer> createState() => _ParallaxStarLayerState();
}

class _ParallaxStarLayerState extends ConsumerState<_ParallaxStarLayer>
    with SingleTickerProviderStateMixin {
  /// Far → near. The last edge breathes past 1.0 so z = 1 lands inside.
  static const _bucketEdges = [0.05, 0.30, 0.55, 0.80, 1.001];

  /// One metabolism, two rhythms:
  ///  - the orbital ticker runs at frame rate and moves each star by a
  ///    RENDER-level shift (StarShift) — pure recomposition, the star
  ///    widgets never rebuild for drift (a 30 fps full-layer rebuild
  ///    once wedged the tab at 0.3 fps);
  ///  - V3.59: the breath no longer rebuilds the layer at all — each
  ///    alive star fades its own cached raster (MindfulHoldStar), so
  ///    nothing here stirs but the drift and the glimmer clock.
  late final Ticker _orbit = createTicker(_onOrbitTick);
  bool _reduced = false;

  /// When a star is caught, its orbit time freezes HERE: the layer
  /// keeps computing its position from this instant until release.
  DateTime? _frozenAt;
  String? _frozenFor;

  /// Sort order changes with the list (and slowly, with one's own
  /// drifting sealed stars): memoized for [_sortEpochMs].
  static const _sortEpochMs = 100;
  int _sortedAtMs = -1;
  List<Echo>? _sortSource;
  List<Echo> _sorted = const [];

  /// Live drift plumbing, keyed by echo id: the base screen position
  /// captured at the last layer build, and the render-level shifter.
  /// Bounded to the VISIBLE sky — the drift loop must never walk the
  /// whole accumulated list.
  final Map<String, Echo> _byId = {};
  final Map<String, Offset> _baseScreen = {};
  final Map<String, ValueNotifier<Offset>> _shifts = {};
  final Set<String> _visibleIds = {};
  Size? _viewportSize;

  /// The glimmer field's clock (V3.24): one notifier, one painter —
  /// the far sky repaints as a single canvas instead of a widget per
  /// star. Half the frame rate: glimmers drift, they do not race.
  final ValueNotifier<DateTime?> _glimmerClock = ValueNotifier(null);
  int _orbitTickCount = 0;

  void _onOrbitTick(Duration elapsed) {
    if (!mounted || _reduced) return;
    // 120 Hz displays double the work for nothing the eye can name:
    // the drift rides at most ~60 fps (V3.25).
    if (elapsed - _lastOrbitAt < const Duration(milliseconds: 12)) return;
    _lastOrbitAt = elapsed;
    final now = DateTime.now();
    _driftSkies(now);
    _orbitTickCount++;
    // The glimmer clock: calm half-rate at the resting eye (battery
    // is part of the sanctuary), EVERY tick on a deep watch (V3.37) —
    // past deepWatchZoom the far lights race, and 30 fps reads as
    // judder exactly where the traveller went to watch them move.
    // (V3.59: the BREATH no longer lives here — each alive star fades
    // its own cached raster; the map-wide 250 ms setState was the
    // max-zoom judder.)
    if (_orbitTickCount.isEven ||
        ParallaxMath.glimmerFullRate(widget.camera.zoom)) {
      _glimmerClock.value = now;
    }
  }

  Duration _lastOrbitAt = Duration.zero;

  /// Frame-rate orbital drift: each star's screen delta from its base
  /// position feeds its ValueNotifier — a layout-only update. The
  /// caught star never moves (its clock is frozen); bases refresh on
  /// every layer rebuild (breath, tilt, camera), which resets shifts.
  void _driftSkies(DateTime now) {
    final viewport = _viewportSize;
    if (viewport == null || _shifts.isEmpty) return;
    final frozenFor = _frozenFor;
    for (final entry in _byId.entries) {
      final id = entry.key;
      final base = _baseScreen[id];
      final shift = _shifts[id];
      if (base == null || shift == null) continue;
      Offset delta;
      if (id == frozenFor && _frozenAt != null) {
        delta = Offset.zero; // caught: it holds still under the finger
      } else {
        final world = KenosSystem.echoPosition(entry.value, now);
        delta = widget.camera.worldToScreen(world, viewport) - base;
      }
      if ((delta - shift.value).distance > 0.05) shift.value = delta;
    }
  }

  /// Two-phase retirement: a star culled by THIS build may still be
  /// unmounting (its render object disposes after the frame) — its
  /// notifier gets one cycle of grace before disposal, so the orbital
  /// ticker never writes into a dying tree. Only stars the LAST build
  /// actually painted stay live.
  final List<ValueNotifier<Offset>> _retired = [];

  void _forgetStaleShifts() {
    for (final notifier in _retired) {
      notifier.dispose();
    }
    _retired.clear();
    final stale = _shifts.keys
        .where((id) => !_visibleIds.contains(id))
        .toList();
    for (final id in stale) {
      _retired.add(_shifts.remove(id)!);
      _baseScreen.remove(id);
      _byId.remove(id);
    }
  }

  List<Echo> _sortedSkies(DateTime now) {
    if (identical(_sortSource, widget.echoes) &&
        now.millisecondsSinceEpoch - _sortedAtMs < _sortEpochMs) {
      return _sorted;
    }
    _sortSource = widget.echoes;
    _sortedAtMs = now.millisecondsSinceEpoch;
    _sorted = widget.echoes.toList()
      ..sort((a, b) => a.resolveZ(now).compareTo(b.resolveZ(now)));
    return _sorted;
  }

  @override
  void initState() {
    super.initState();
    _orbit.start();
  }

  @override
  void dispose() {
    _orbit.dispose();
    _glimmerClock.dispose();
    for (final notifier in _shifts.values) {
      notifier.dispose();
    }
    _shifts.clear();
    for (final notifier in _retired) {
      notifier.dispose();
    }
    _retired.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ambient parallax calms down (×0.15) under reduce-motion.
    final motionScale = context.wantsReducedMotion ? 0.15 : 1.0;
    _reduced = context.wantsReducedMotion;
    final tilt = ref.watch(tiltProvider.select(_gateTilt));
    final now = DateTime.now();
    final sorted = _sortedSkies(now);
    _forgetStaleShifts();

    // A caught star holds still: snapshot the instant the hold began,
    // compute ITS position from that frozen clock until release.
    final heldId = ref.watch(heldEchoIdProvider);
    if (heldId != _frozenFor) {
      _frozenFor = heldId;
      _frozenAt = heldId != null ? DateTime.now() : null;
    }
    final frozenFor = _frozenFor;
    final frozenAt = _frozenAt;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        _viewportSize = Size(w, h);
        _visibleIds.clear();

        final eyeScale = ParallaxMath.zoomScale(widget.camera.zoom);
        final eye = widget.camera.center;
        // One sky, every screen (V3.25): star lights scale with the
        // viewport like the planets do — on a phone's narrow window
        // raw-pixel stars swallowed the Moon whole.
        final dScale = ParallaxMath.displayScale(math.min(w, h).toDouble());

        // Pass 1 — every visible sight: position, depth, aliveness.
        final sights =
            <
              ({Echo echo, double z, Offset world, Offset sp, double reception})
            >[];
        for (final echo in sorted) {
          // A CAUGHT echo (under a finger) computes from its frozen
          // instant: catching a moving light is not a chase.
          final echoNow = (frozenFor == echo.id && frozenAt != null)
              ? frozenAt
              : null;
          final world = echoNow != null
              ? KenosSystem.echoPosition(echo, echoNow)
              : KenosSystem.echoPosition(echo, now);
          final sp = widget.camera.worldToScreen(world, Size(w, h));
          // Travel culling: only the visible sky is drawn.
          if (sp.dx < -60 || sp.dx > w + 60 || sp.dy < -60 || sp.dy > h + 60) {
            continue;
          }
          sights.add((
            echo: echo,
            z: echo.resolveZ(now),
            world: world,
            sp: sp,
            reception: ParallaxMath.receptionIntensity(eye: eye, star: world),
          ));
        }

        // Pass 2 — the ALIVE set (V3.24): the reception law made
        // literal. Only what the eye can truly reach carries a widget
        // — one's own sealed hearts, the caught light, and the
        // [aliveBudget] closest sights of the field (stable order).
        // The rest is the glimmer field: ONE canvas, no widgets, no
        // hit zones — far lights to approach, never to hold. 180
        // widget-stars were the wide view's floor; ~24 is its flight.
        const aliveBudget = 24;
        final ranked = sights.toList()
          ..sort((a, b) {
            final sa = a.echo.isMine
                ? 2.0
                : a.echo.id == frozenFor
                ? 1.9
                : a.reception;
            final sb = b.echo.isMine
                ? 2.0
                : b.echo.id == frozenFor
                ? 1.9
                : b.reception;
            if (sa != sb) return sb.compareTo(sa);
            return a.echo.id.compareTo(b.echo.id);
          });
        final alive = <String>{};
        var taken = 0;
        for (final s in ranked) {
          final score = s.echo.isMine
              ? 2.0
              : s.echo.id == frozenFor
              ? 1.9
              : s.reception;
          if (score <= 0) break;
          alive.add(s.echo.id);
          if (++taken >= aliveBudget) break;
        }

        // Pass 3 — the alive become holdable stars, four buckets deep.
        final buckets = List.generate(
          _bucketEdges.length - 1,
          (_) => <Widget>[],
        );
        final glimmers = <Echo>[];
        for (final s in sights) {
          final echo = s.echo;
          final z = s.z;
          if (!alive.contains(echo.id)) {
            glimmers.add(echo);
            continue;
          }
          var b = 0;
          while (b < _bucketEdges.length - 2 && z >= _bucketEdges[b + 1]) {
            b++;
          }
          final sp = s.sp;
          // The TOUCH target barely grows (V3.22): at depth the
          // whole screen was covered by 250 px boxes stealing each
          // other's holds — a star must stay catchable, not smother
          // its neighbours. 1.35 keeps the comfort, loses the plague.
          final hit =
              ParallaxMath.starDiameter(z) * dScale * math.min(eyeScale, 1.35) +
              26;
          final reception = s.reception;
          // Fresh base for this frame: the drift accumulates from HERE.
          final shift = _shifts.putIfAbsent(
            echo.id,
            () => ValueNotifier(Offset.zero),
          );
          shift.value = Offset.zero;
          _baseScreen[echo.id] = sp;
          _byId[echo.id] = echo;
          _visibleIds.add(echo.id);
          buckets[b].add(
            Positioned(
              key: ValueKey(echo.id),
              left: sp.dx - hit / 2,
              top: sp.dy - hit / 2,
              width: hit,
              height: hit,
              // The orbital drift rides the render-level shift; the
              // star's raster (RepaintBoundary below) survives both
              // the pan and the drift — recomposition only.
              child: Transform.scale(
                scale: eyeScale,
                child: StarShift(
                  shift: shift,
                  child: RepaintBoundary(
                    child: MindfulHoldStar(
                      key: ValueKey('star-${echo.id}'),
                      echo: echo,
                      z: z,
                      displayScale: dScale,
                      eyeDistanceAL:
                          (Offset(echo.coordX, echo.coordY) - eye).distance,
                      // The reception field: near = alive, far = a glimmer
                      // to approach. Sealed anchors ignore it (widget-side).
                      reception: reception,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final layers = <Widget>[];
        // The glimmer field first (V3.24): the whole far sky in ONE
        // painter riding the glimmer clock — the depth buckets and
        // the holdable stars paint above it.
        layers.add(
          RepaintBoundary(
            child: ListenableBuilder(
              listenable: _glimmerClock,
              builder: (context, _) => CustomPaint(
                painter: _GlimmerFieldPainter(
                  echoes: glimmers,
                  camera: widget.camera,
                  now: _glimmerClock.value ?? now,
                  reduced: _reduced,
                ),
              ),
            ),
          ),
        );
        for (var b = 0; b < buckets.length; b++) {
          final children = buckets[b];
          if (children.isEmpty) continue;

          final bucketZ =
              (_bucketEdges[b] + _bucketEdges[b + 1].clamp(0.0, 1.0)) / 2;
          // Depth haze now rides EACH star's cached glow (its own
          // RepaintBoundary): a bucket-level ImageFiltered had to
          // re-blur the whole viewport every frame once the orbits
          // came alive — 0.3 fps. The bucket keeps only its parallax
          // transform, isolated behind its own boundary.
          final layer = RepaintBoundary(child: Stack(children: children));
          layers.add(
            Transform.translate(
              offset: Offset(
                ParallaxMath.offsetPixels(
                  tilt: tilt.x * motionScale,
                  z: bucketZ,
                  amplitude: 46,
                ),
                ParallaxMath.offsetPixels(
                  tilt: tilt.y * motionScale,
                  z: bucketZ,
                  amplitude: 32,
                ),
              ),
              child: layer,
            ),
          );
        }

        return Stack(fit: StackFit.expand, children: layers);
      },
    );
  }
}

/// The corpses explain themselves once, in the waves' guide grammar:
/// what the pale rings are, how to give a line, how to launch one.
/// V3.17 — the wheel whisper: on a desktop eye, one breath to say
/// the wheel approaches the sky. Pure text, ignored by every pointer,
/// gone on its own timer or at the first turn of the wheel.
class _EyeWhisper extends StatelessWidget {
  const _EyeWhisper();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'L\'ŒIL DU VOYAGEUR',
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 9,
            letterSpacing: 4,
            color: AppColors.fade(AppColors.teal, 0.7),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Ici, la molette approche le ciel — comme le pincement des doigts.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.serifItalic,
            fontSize: 14,
            color: AppColors.fade(AppColors.pureLight, 0.55),
          ),
        ),
      ],
    );
  }
}

/// V3.45 — the closure whisper: a poem these hands helped write has
/// closed. The artifact is public and re-readable; the ember orbit
/// marks it, the souffle knows the way. One breath, once — then the
/// sky trusts the traveller's eye.
class _ClosureWhisper extends StatelessWidget {
  const _ClosureWhisper();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "UN POÈME DE TA MAIN S'EST REFERMÉ",
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 9,
            letterSpacing: 4,
            color: AppColors.fade(AppColors.indigo, 0.85),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Refermé, il t’attend — lisible autant de fois que tu voudras.\n'
          'L’orbite ember le garde, le souffle en connaît le chemin.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.serifItalic,
            fontSize: 14,
            height: 1.7,
            color: AppColors.fade(AppColors.pureLight, 0.6),
          ),
        ),
      ],
    );
  }
}

/// V3.35 — the crossing breath: a landscape's name, told once per
/// session. The machine-whisper grammar (mono caps) over one serif
/// breath — never a notification, never a counter, never a reward.
class _TerritoryWhisper extends StatelessWidget {
  const _TerritoryWhisper({required this.territory});

  final VoidTerritory territory;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          VoidTerritories.whisperTitle(territory),
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 9,
            letterSpacing: 4,
            color: AppColors.fade(AppColors.cyan, 0.7),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          VoidTerritories.whisperLine(territory),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.serifItalic,
            fontSize: 14,
            color: AppColors.fade(AppColors.pureLight, 0.55),
          ),
        ),
      ],
    );
  }
}

class _CorpseGuide extends StatelessWidget {
  const _CorpseGuide({required this.onUnderstood});

  final VoidCallback onUnderstood;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onUnderstood,
      child: Container(
        color: AppColors.fade(AppColors.voidBlack, 0.88),
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'LES CONSTELLATIONS',
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 10,
                letterSpacing: 5,
                color: AppColors.fade(AppColors.teal, 0.85),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Les anneaux pâles sont des poèmes à l\'aveugle.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.serifItalic,
                fontSize: 18,
                color: AppColors.fade(AppColors.pureLight, 0.92),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Touche-en un pour donner une ligne, à la suite\n'
              'de celle qui te précède — sans jamais\n'
              'voir le tout. Les tout vides sont des anneaux\n'
              'plantés : la première ligne est à toi.\n'
              'Les stations creuses disent ce qui reste —\n'
              'la dernière ligne referme le poème de lui-même,\n'
              'en artefact indigo lisible par tous.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.serifItalic,
                fontSize: 15,
                height: 1.9,
                color: AppColors.fade(AppColors.pureLight, 0.6),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Pour en semer une : SEMER UNE CONSTELLATION,\nau pied du miroir.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.serifItalic,
                fontSize: 15,
                color: AppColors.fade(AppColors.teal, 0.75),
              ),
            ),
            const SizedBox(height: 36),
            Text(
              'TOUCHE POUR ENTRER',
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 9,
                letterSpacing: 3,
                color: AppColors.fade(AppColors.pureLight, 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalmEther extends StatefulWidget {
  const _CalmEther();

  @override
  State<_CalmEther> createState() => _CalmEtherState();
}

class _CalmEtherState extends State<_CalmEther>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void initState() {
    super.initState();
    if (!platformDisablesAnimations()) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated breathing glow
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final opacity = 0.3 + (_controller.value * 0.3);
              final scale = 0.95 + (_controller.value * 0.1);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.fade(AppColors.cyan, opacity * 0.5),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 40),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final opacity = 0.5 + (_controller.value * 0.2);
              return Opacity(
                opacity: opacity,
                child: Text(
                  'L\'ÉTHER EST CALME.',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 10,
                    letterSpacing: 4,
                    color: AppColors.fade(AppColors.pureLight, 1.0),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'RESPIRE.',
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 9,
              letterSpacing: 3,
              color: AppColors.fade(AppColors.teal, 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnreachableEther extends StatelessWidget {
  const _UnreachableEther({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Centered('L\'ÉTHER EST INJOIGNABLE.', color: AppColors.rose),
          const SizedBox(height: 18),
          TextButton(onPressed: onRetry, child: const Text('RECALIBRER')),
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered(this.message, {required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 10,
          letterSpacing: 4,
          color: AppColors.fade(color, 0.6),
        ),
      ),
    );
  }
}

/// V3.41 — LES DEUX PORTES: the map's two acts of emptying oneself.
///
/// One family, two intensities — the hierarchy is carried by LIGHT,
/// not by noise: the FIRST door (the Mirror, the product's own
/// gesture) glows teal; the second (seeding a corpse) keeps a quiet
/// hairline. Opaque fills — the sky never prints through the words.
/// The glow BREATHES (a calm ~4 s swell); the text never scales, so
/// the space between the words stays stable and readable. The
/// corpse's indigo stays on the map (rings, closed artifacts), where
/// it has contrast — on the void floor it read as mud.
class _GateDoor extends StatefulWidget {
  const _GateDoor({super.key, required this.label, required this.onPressed})
    : first = false;

  const _GateDoor.first({
    super.key,
    required this.label,
    required this.onPressed,
  }) : first = true;

  final String label;
  final VoidCallback onPressed;

  /// The first door: the teal-lit one.
  final bool first;

  @override
  State<_GateDoor> createState() => _GateDoorState();
}

class _GateDoorState extends State<_GateDoor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void initState() {
    super.initState();
    if (widget.first && !platformDisablesAnimations()) {
      _breath.repeat(reverse: true);
    } else {
      _breath.value = 0.5; // a held, calm half-glow
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  bool _pressed = false;

  /// V3.44 — the desktop hover: the door LIVES under the cursor —
  /// border and wash brighten, so a pointer knows the way in.
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final dim = _pressed ? 0.72 : 1.0;
    final hover = _hovered && !_pressed ? 1.0 : 0.0;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: Semantics(
          button: true,
          child: AnimatedBuilder(
            animation: _breath,
            builder: (context, _) {
              final swell = Curves.easeInOut.transform(_breath.value);
              return Container(
                // No `alignment`: an alignment box EXPANDS to every
                // loose constraint it is given — in the wide Flex it
                // stretched each door to 770 px tall and the block
                // swallowed the lower sky's every touch (V3.43). The
                // symmetric padding centers the label already.
                constraints: BoxConstraints(minHeight: widget.first ? 46 : 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  // Opaque: the door is a surface, not a window —
                  // no star prints through the words.
                  color: widget.first
                      ? Color.alphaBlend(
                          AppColors.fade(
                            AppColors.teal,
                            (0.10 + 0.08 * hover) * dim,
                          ),
                          AppColors.voidBlack,
                        )
                      : Color.alphaBlend(
                          AppColors.fade(
                            AppColors.pureLight,
                            (0.05 + 0.05 * hover) * dim,
                          ),
                          AppColors.voidBlack,
                        ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: widget.first
                        ? AppColors.fade(
                            AppColors.teal,
                            (0.85 + 0.15 * hover) * dim,
                          )
                        : AppColors.fade(
                            AppColors.pureLight,
                            (0.38 + 0.30 * hover) * dim,
                          ),
                    width: widget.first ? 1.2 : 1,
                  ),
                  boxShadow: widget.first
                      ? [
                          // The breath: light, never geometry — the
                          // text holds still while the door glows.
                          BoxShadow(
                            color: AppColors.fade(
                              AppColors.teal,
                              (0.10 + 0.12 * swell) * dim,
                            ),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ]
                      : const <BoxShadow>[],
                ),
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: widget.first ? 10.5 : 10,
                    letterSpacing: widget.first ? 4 : 3,
                    color: AppColors.fade(
                      AppColors.pureLight,
                      (widget.first ? 0.95 : 0.82) * dim,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SoundToggle extends ConsumerStatefulWidget {
  const _SoundToggle();

  @override
  ConsumerState<_SoundToggle> createState() => _SoundToggleState();
}

class _SoundToggleState extends ConsumerState<_SoundToggle> {
  @override
  Widget build(BuildContext context) {
    final audio = ref.watch(audioControllerProvider);
    return TextButton(
      onPressed: () async {
        await audio.toggleMute();
        if (mounted) setState(() {});
      },
      child: Text(audio.isMuted ? 'SON ─ OFF' : 'SON ─ ON'),
    );
  }
}

/// V3.11b — the emergent figure: each contributed line is a star at the
/// next golden-angle station around the seed — the constellation draws
/// itself as strangers write. Drawn stars are bright and linked by
/// faint segments (what they wrote); the stations still hollow wait.
/// CLOSED = the figure complete, glowing indigo (readable whole, once).
class _ConstellationPainter extends CustomPainter {
  _ConstellationPainter({
    required this.id,
    required this.closed,
    required this.lineCount,
    required this.target,
    required this.color,
    this.read = false,
    this.kept = false,
    this.mine = false,
  });

  final String id;
  final bool closed;
  final int lineCount;
  final int target;
  final Color color;

  /// Read on this device within the week: the drawn stars open into
  /// hollow rings — the cicatrices grammar (visited is visible, the
  /// ether's promise stays: full lights are discoveries).
  final bool read;

  /// Kept in this traveller's sky: ember seed and links, never ghost.
  final bool kept;

  /// These hands gave a line to this corpse: a thin orbit rings the
  /// seed — 'ta main est dans ce corps', visible across the sky.
  final bool mine;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 3;
    final t = target.clamp(2, 7);

    // One arithmetic, one truth: the figure domain places the stations.
    Offset station(int k) {
      final unit = ConstellationFigure.starAt(k, target: t, id: id);
      return Offset(center.dx + radius * unit.dx, center.dy + radius * unit.dy);
    }

    // The seed: where the first stranger planted the corpse. Kept:
    // the reliquaire's ember burns at the heart.
    canvas.drawCircle(
      center,
      kept ? 2.1 : 1.5,
      Paint()
        ..color = AppColors.fade(
          kept ? AppColors.ember : color,
          closed ? 0.9 : 0.55,
        ),
    );
    if (mine) {
      // V3.45 — the hand's mark in EMBER (the salon grammar: hands
      // having given carry the warm orbit), not the ring's own color:
      // on a closed indigo artifact the old same-hue orbit was
      // invisible — the participant could not find their own poem.
      canvas.drawCircle(
        center,
        kept ? 6.5 : 5.5,
        Paint()
          ..color = AppColors.fade(AppColors.ember, kept ? 0.9 : 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
      );
    }

    // The strangers' segments: what has been drawn so far.
    final drawn = lineCount.clamp(0, t);
    if (drawn >= 2) {
      final link = Paint()
        ..color = AppColors.fade(
          kept ? AppColors.ember : color,
          closed ? (kept ? 0.6 : 0.5) : 0.28,
        )
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round;
      for (var k = 1; k < drawn; k++) {
        canvas.drawLine(station(k - 1), station(k), link);
      }
    }

    // The stations: filled stars for written lines, hollow for the
    // rest. A READ artifact opens its stars into rings (visited is a
    // memory, not a burn — full again after the week, or when kept).
    for (var k = 0; k < t; k++) {
      final isFilled = k < drawn && !(read && !kept);
      final pos = station(k);
      final paint = Paint()
        ..color = AppColors.fade(color, isFilled ? (closed ? 0.9 : 0.6) : 0.18);
      if (isFilled) {
        canvas.drawCircle(pos, closed ? 2.6 : 2.4, paint);
      } else {
        canvas.drawCircle(
          pos,
          1.8,
          Paint()
            ..color = AppColors.fade(color, 0.16)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ConstellationPainter old) =>
      old.id != id ||
      old.closed != closed ||
      old.lineCount != lineCount ||
      old.target != target ||
      old.read != read ||
      old.kept != kept ||
      old.mine != mine;
}

/// V3.12c — the heavens' own heartbeat: the sky (planets, wanderers,
/// the beacon's breath, the falls, the vestiges' tumble) drifts on a
/// gentle clock of its own — never waiting for the eye to move.
/// ~12 fps is imperceptibly fluid for celestial speeds and cheap
/// under the RepaintBoundary; « réduire les animations » stills it.
/// V3.24 — the glimmer field: every echo the eye cannot yet reach,
/// painted as one canvas. No widgets, no hit zones, no rasters — a
/// far light to approach (the reception law made literal: it becomes
/// a holdable star only when the eye comes close). Positions are
/// recomputed inside the paint from the deterministic system math, so
/// the far sky drifts on its own clock, half the frame rate.
class _GlimmerFieldPainter extends CustomPainter {
  _GlimmerFieldPainter({
    required this.echoes,
    required this.camera,
    required this.now,
    required this.reduced,
  }) : _center = camera.center,
       _zoom = camera.zoom;

  final List<Echo> echoes;
  final TravelCamera camera;
  final DateTime now;
  final bool reduced;

  // Camera VALUES captured at construction (the camera is a single
  // mutable instance — comparing it to itself never fires).
  final Offset _center;
  final double _zoom;

  @override
  void paint(Canvas canvas, Size size) {
    final eyeScale = ParallaxMath.zoomScale(_zoom);
    final dScale = ParallaxMath.displayScale(size.shortestSide);
    for (final echo in echoes) {
      final z = echo.resolveZ(now);
      final world = KenosSystem.echoPosition(echo, now);
      final sp = camera.worldToScreen(world, size);
      if (sp.dx < -24 ||
          sp.dx > size.width + 24 ||
          sp.dy < -24 ||
          sp.dy > size.height + 24) {
        continue;
      }
      final reception = ParallaxMath.receptionIntensity(
        eye: _center,
        star: world,
      );
      // The same light as a holdable star carries, at glimmer
      // distance: depth-dimmed, field-dimmed, never breathing.
      final alpha =
          ParallaxMath.opacityFor(z) * (0.30 + 0.70 * reception) * 0.85;
      final paint = Paint()..color = AppColors.fade(echo.theme.core, alpha);
      canvas.drawCircle(
        sp,
        ParallaxMath.coreRadius(z) * 0.8 * eyeScale * dScale,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GlimmerFieldPainter oldDelegate) =>
      oldDelegate.echoes != echoes ||
      oldDelegate.now != now ||
      oldDelegate._center != _center ||
      oldDelegate._zoom != _zoom;
}

class _HeavensClock extends StatefulWidget {
  const _HeavensClock({
    required this.builder,
    this.period = const Duration(milliseconds: 80),
  });

  final Widget Function(BuildContext, DateTime) builder;

  /// The beat. The heavens themselves need their 80 ms (orbits must
  /// glide); slow-decorating riders (the vestiges' tumble) pass a
  /// calmer one — a shard rotating at 4 Hz reads exactly like 12.5 Hz,
  /// at a third of the repaint price.
  final Duration period;

  @override
  State<_HeavensClock> createState() => _HeavensClockState();
}

class _HeavensClockState extends State<_HeavensClock> {
  DateTime _now = DateTime.now();
  Timer? _beat;

  @override
  void initState() {
    super.initState();
    if (!platformDisablesAnimations()) {
      _beat = Timer.periodic(widget.period, (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _beat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}

/// L'ANCRE DU SALON — a door held on this device: an ember seed (la
/// braise, la main tendue de l'invitation) inside a thin ember halo.
/// No stations, no segments — the ring is hidden while it is written:
/// the holder sees WHERE it sleeps, never WHAT it holds. These hands
/// already gave: a tighter second orbit (the 'mine' grammar, ember).
/// Parsimonious and still by law: ROSE stays reserved for destruction,
/// and nothing here moves on its own.
class _SalonAnchorPainter extends CustomPainter {
  _SalonAnchorPainter({required this.mine});

  final bool mine;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // The braise: a warm seed at the door's heart.
    canvas.drawCircle(
      center,
      2.1,
      Paint()..color = AppColors.fade(AppColors.ember, 0.9),
    );

    // The halo: a thin ember ring — the door's aura, nothing more.
    canvas.drawCircle(
      center,
      size.shortestSide / 2 - 14,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.fade(AppColors.ember, 0.35),
    );

    if (mine) {
      // 'Ta main est dans ce corps' — the shared orbit grammar.
      canvas.drawCircle(
        center,
        4.2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = AppColors.fade(AppColors.ember, 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(_SalonAnchorPainter old) => old.mine != mine;
}
