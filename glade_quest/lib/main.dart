import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'game.dart';
import 'painter.dart';

const gold = Color(0xffffd66b);
const panel = Color(0xff17251f);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const GladeApp());
}

class GladeApp extends StatelessWidget {
  const GladeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Glade Quest',
        theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xff101820)),
        home: const GameScreen(),
      );
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  final game = GameState();
  final frame = ValueNotifier<int>(0); // bumps every tick -> repaints
  Offset stick = Offset.zero;
  final Set<LogicalKeyboardKey> _keys = {};
  bool _wasFinished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero ? 0.0 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    game.update(dt.clamp(0, 0.05).toDouble(), _input());
    if (game.hurtEvent) HapticFeedback.heavyImpact();
    if (game.hitEnemyEvent) HapticFeedback.lightImpact();
    if (game.pickupEvent) HapticFeedback.selectionClick();
    frame.value++;
    if (game.finished != _wasFinished) {
      _wasFinished = game.finished;
      setState(() {});
    }
  }

  /// Joystick input, or WASD/arrow keys when a keyboard is attached.
  Offset _input() {
    double kx = 0, ky = 0;
    if (_keys.contains(LogicalKeyboardKey.arrowLeft) || _keys.contains(LogicalKeyboardKey.keyA)) kx -= 1;
    if (_keys.contains(LogicalKeyboardKey.arrowRight) || _keys.contains(LogicalKeyboardKey.keyD)) kx += 1;
    if (_keys.contains(LogicalKeyboardKey.arrowUp) || _keys.contains(LogicalKeyboardKey.keyW)) ky -= 1;
    if (_keys.contains(LogicalKeyboardKey.arrowDown) || _keys.contains(LogicalKeyboardKey.keyS)) ky += 1;
    if (kx != 0 || ky != 0) {
      final k = Offset(kx, ky);
      return k / k.distance;
    }
    return stick;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !game.finished) {
      setState(() => game.paused = true);
    }
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    _last = Duration.zero;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    frame.dispose();
    super.dispose();
  }

  void _restart() => setState(() {
        game.restart();
        _wasFinished = false;
      });

  void _togglePause() => setState(() => game.paused = !game.paused);

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyDownEvent) {
      _keys.add(e.logicalKey);
      if (e.logicalKey == LogicalKeyboardKey.space || e.logicalKey == LogicalKeyboardKey.keyJ) game.attack();
      if (e.logicalKey == LogicalKeyboardKey.escape || e.logicalKey == LogicalKeyboardKey.keyP) _togglePause();
    } else if (e is KeyUpEvent) {
      _keys.remove(e.logicalKey);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final view = Stack(children: [
      Positioned.fill(child: CustomPaint(painter: GamePainter(game, frame))),
      if (game.paused && !game.finished)
        _Overlay(title: 'PAUSED', button: 'RESUME', onPressed: _togglePause),
      if (game.win) _Overlay(title: 'THE GLADE IS SAFE!', button: 'PLAY AGAIN', onPressed: _restart),
      if (game.over) _Overlay(title: 'GAME OVER', titleColor: Colors.redAccent, button: 'TRY AGAIN', onPressed: _restart),
    ]);
    final gameView = AspectRatio(
      aspectRatio: worldW / worldH,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: gold.withValues(alpha: .6), width: 2)),
        child: ClipRect(child: view),
      ),
    );
    final hud = _Hud(game: game, frame: frame, onPause: _togglePause);
    final joystick = Joystick(onChanged: (v) => stick = v);
    final attack = AttackButton(onPressed: game.attack);

    return Scaffold(
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: SafeArea(
          child: LayoutBuilder(builder: (context, c) {
            final portrait = c.maxHeight >= c.maxWidth;
            if (portrait) {
              // Phone held upright: game on top, thumbs-zone controls below.
              return Column(children: [
                hud,
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: c.maxHeight * .55),
                  child: Center(heightFactor: 1, child: gameView),
                ),
                Expanded(
                  child: Row(children: [
                    Expanded(child: joystick),
                    SizedBox(width: math.min(180, c.maxWidth * .42), child: Center(child: attack)),
                  ]),
                ),
                const _Hint(),
              ]);
            }
            // Landscape: controls flank the game, under each thumb.
            final gw = math.max(0.0, math.min((c.maxHeight - 56) * worldW / worldH, c.maxWidth - 340));
            return Row(children: [
              Expanded(child: joystick),
              SizedBox(
                width: gw,
                child: Column(children: [
                  hud,
                  Expanded(child: Center(child: gameView)),
                ]),
              ),
              Expanded(child: Center(child: attack)),
            ]);
          }),
        ),
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.game, required this.frame, required this.onPause});
  final GameState game;
  final ValueNotifier<int> frame;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 56,
        child: ValueListenableBuilder<int>(
          valueListenable: frame,
          builder: (context, _, __) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              for (int i = 0; i < maxHearts; i++)
                Icon(i < game.hearts ? Icons.favorite : Icons.favorite_border,
                    color: const Color(0xffff5b5b), size: 22),
              const Spacer(),
              const Icon(Icons.diamond, color: Color(0xff3ddc97), size: 20),
              Text(' ${game.gemsCollected}/${game.gems.length}',
                  style: const TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 14),
              const Icon(Icons.pest_control, color: Color(0xffc58cff), size: 20),
              Text(' ${game.enemiesLeft}',
                  style: const TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(
                onPressed: onPause,
                icon: Icon(game.paused ? Icons.play_arrow : Icons.pause, color: gold),
                tooltip: 'Pause',
              ),
            ]),
          ),
        ),
      );
}

class _Hint extends StatelessWidget {
  const _Hint();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Text('Drag left side to move • Tap ⚔ to strike\nCollect every gem • Defeat every beetle',
            textAlign: TextAlign.center, style: TextStyle(color: Color(0xffc7d7c7), fontSize: 12)),
      );
}

class _Overlay extends StatelessWidget {
  const _Overlay({required this.title, required this.button, required this.onPressed, this.titleColor = gold});
  final String title, button;
  final Color titleColor;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: ColoredBox(
          color: const Color(0xaa000000),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(color: panel, border: Border.all(color: gold, width: 2)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                FittedBox(
                  child: Text(title,
                      style: TextStyle(color: titleColor, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: panel,
                      minimumSize: const Size(160, 48)),
                  onPressed: onPressed,
                  child: Text(button, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
          ),
        ),
      );
}

/// Floating analog joystick: touch anywhere in its area and the stick centres
/// under your thumb. Uses raw pointer events so it never waits on the gesture
/// arena and works alongside the attack button (multi-touch).
class Joystick extends StatefulWidget {
  const Joystick({super.key, required this.onChanged});
  final ValueChanged<Offset> onChanged;
  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  static const double radius = 56;
  int? _pointer;
  Offset? _origin;
  Offset _knob = Offset.zero;

  void _update(Offset pos) {
    var d = pos - _origin!;
    if (d.distance > radius) d = d / d.distance * radius;
    setState(() => _knob = d);
    widget.onChanged(d / radius);
  }

  void _release() {
    setState(() {
      _pointer = null;
      _origin = null;
      _knob = Offset.zero;
    });
    widget.onChanged(Offset.zero);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final rest = Offset(c.maxWidth / 2, c.maxHeight / 2);
        final origin = _origin ?? rest;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) {
            if (_pointer != null) return;
            _pointer = e.pointer;
            // Clamp so the base stays fully on screen.
            _origin = Offset(e.localPosition.dx.clamp(radius, math.max(radius, c.maxWidth - radius)),
                e.localPosition.dy.clamp(radius, math.max(radius, c.maxHeight - radius)));
            _update(e.localPosition);
          },
          onPointerMove: (e) {
            if (e.pointer == _pointer) _update(e.localPosition);
          },
          onPointerUp: (e) {
            if (e.pointer == _pointer) _release();
          },
          onPointerCancel: (e) {
            if (e.pointer == _pointer) _release();
          },
          child: Stack(children: [
            Positioned(
              left: origin.dx - radius,
              top: origin.dy - radius,
              child: Opacity(
                opacity: _pointer == null ? .45 : 1,
                child: Container(
                  width: radius * 2,
                  height: radius * 2,
                  decoration: BoxDecoration(
                    color: const Color(0xaa26383c),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xffd8c16b), width: 2),
                  ),
                ),
              ),
            ),
            Positioned(
              left: origin.dx + _knob.dx - 24,
              top: origin.dy + _knob.dy - 24,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(color: Color(0xffa9b9bb), shape: BoxShape.circle),
              ),
            ),
          ]),
        );
      });
}

/// Big thumb-sized attack button. Fires on finger-down for instant response.
class AttackButton extends StatefulWidget {
  const AttackButton({super.key, required this.onPressed});
  final VoidCallback onPressed;
  @override
  State<AttackButton> createState() => _AttackButtonState();
}

class _AttackButtonState extends State<AttackButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) {
          widget.onPressed();
          setState(() => _down = true);
        },
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: AnimatedScale(
          scale: _down ? .9 : 1,
          duration: const Duration(milliseconds: 60),
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: _down ? const Color(0xff3c5458) : const Color(0xaa26383c),
              border: Border.all(color: gold, width: 3),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('⚔', style: TextStyle(fontSize: 44, color: Colors.white))),
          ),
        ),
      );
}
