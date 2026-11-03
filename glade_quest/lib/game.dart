import 'dart:math' as math;
import 'dart:ui';

/// Size of the game world in logical units. The painter scales this to fit
/// whatever screen the game runs on.
const double worldW = 640;
const double worldH = 480;

const int maxHearts = 5;

class Enemy {
  Enemy(this.x, this.y) : homeX = x, homeY = y;
  double x, y;
  final double homeX, homeY;
  int hp = 3;
  double vx = 0, vy = 0; // knockback velocity
  double flash = 0; // hit flash timer
  double wanderTimer = 0;
  Offset wanderDir = Offset.zero;
  bool get alive => hp > 0;
  static const double radius = 11;
}

class Gem {
  Gem(this.x, this.y);
  final double x, y;
  bool got = false;
}

class HeartPickup {
  HeartPickup(this.x, this.y);
  final double x, y;
  double life = 8;
}

class RectObstacle {
  const RectObstacle(this.rect);
  final Rect rect;
}

class CircleObstacle {
  const CircleObstacle(this.center, this.radius);
  final Offset center;
  final double radius;
}

/// All of the game rules live here, separate from rendering and input.
class GameState {
  GameState({int? seed}) : _rng = math.Random(seed) {
    restart();
  }

  final math.Random _rng;

  // Player
  double x = 320, y = 260;
  static const double playerRadius = 10;
  static const double playerSpeed = 135;
  Offset facing = const Offset(0, 1);
  int hearts = maxHearts;
  double invuln = 0;
  double kvx = 0, kvy = 0;

  // Sword
  static const double swingTime = 0.22;
  static const double swingCooldown = 0.32;
  static const double swordReach = 30;
  double swing = 0;
  double cooldown = 0;
  final Set<Enemy> _hitThisSwing = {};

  // World
  final List<Enemy> enemies = [];
  final List<Gem> gems = [];
  final List<HeartPickup> heartPickups = [];
  double time = 0;
  bool paused = false;

  /// Events since the last frame, so the UI can trigger haptics/sounds.
  bool hitEnemyEvent = false, hurtEvent = false, pickupEvent = false;

  static const treePositions = [
    Offset(45, 55), Offset(100, 45), Offset(605, 235), Offset(600, 300),
    Offset(60, 330), Offset(540, 420), Offset(145, 420), Offset(390, 65),
    Offset(220, 180),
  ];
  static const house = Rect.fromLTWH(28, 155, 124, 85);
  static const castle = Rect.fromLTWH(430, 20, 150, 130);
  static const water = Rect.fromLTWH(0, 430, 170, 50);

  final List<CircleObstacle> trees =
      treePositions.map((o) => CircleObstacle(o, 20)).toList();
  final List<RectObstacle> rects = const [
    RectObstacle(house),
    RectObstacle(castle),
    RectObstacle(water),
  ];

  int get gemsCollected => gems.where((g) => g.got).length;
  int get enemiesLeft => enemies.where((e) => e.alive).length;
  bool get win => gemsCollected == gems.length && enemiesLeft == 0;
  bool get over => hearts <= 0;
  bool get finished => win || over;

  void restart() {
    x = 320;
    y = 260;
    facing = const Offset(0, 1);
    hearts = maxHearts;
    invuln = 0;
    kvx = kvy = 0;
    swing = cooldown = 0;
    time = 0;
    paused = false;
    _hitThisSwing.clear();
    enemies
      ..clear()
      ..addAll([Enemy(160, 120), Enemy(490, 200), Enemy(440, 350), Enemy(230, 390)]);
    gems
      ..clear()
      ..addAll([Gem(95, 105), Gem(545, 300), Gem(300, 400), Gem(205, 340), Gem(615, 160)]);
    heartPickups.clear();
  }

  /// Called once per button press (not while held), so every swing is a
  /// deliberate action with a short cooldown.
  void attack() {
    if (finished || paused || cooldown > 0) return;
    swing = swingTime;
    cooldown = swingCooldown;
    _hitThisSwing.clear();
  }

  Offset get swordTip => Offset(x + facing.dx * swordReach, y + facing.dy * swordReach);

  void update(double dt, Offset stick) {
    hitEnemyEvent = hurtEvent = pickupEvent = false;
    if (paused || finished || dt <= 0) return;
    time += dt;

    // --- Player movement (analog stick, with dead zone) ---
    final mag = stick.distance;
    if (mag > 0.15) {
      final m = math.min(1.0, mag);
      final dir = stick / mag;
      facing = dir;
      x += dir.dx * playerSpeed * m * dt;
      y += dir.dy * playerSpeed * m * dt;
    }
    x += kvx * dt;
    y += kvy * dt;
    final decay = math.pow(0.0005, dt).toDouble();
    kvx *= decay;
    kvy *= decay;
    final p = _resolve(x, y, playerRadius);
    x = p.dx;
    y = p.dy;

    invuln = math.max(0, invuln - dt);
    cooldown = math.max(0, cooldown - dt);
    swing = math.max(0, swing - dt);

    // --- Pickups ---
    for (final g in gems) {
      if (!g.got && _dist(x, y, g.x, g.y) < playerRadius + 10) {
        g.got = true;
        pickupEvent = true;
      }
    }
    for (final h in heartPickups) {
      h.life -= dt;
      if (h.life > 0 && _dist(x, y, h.x, h.y) < playerRadius + 9) {
        h.life = 0;
        hearts = math.min(maxHearts, hearts + 1);
        pickupEvent = true;
      }
    }
    heartPickups.removeWhere((h) => h.life <= 0);

    // --- Enemies ---
    for (final e in enemies) {
      if (!e.alive) continue;
      e.flash = math.max(0, e.flash - dt);
      final dx = x - e.x, dy = y - e.y;
      final d = math.sqrt(dx * dx + dy * dy);

      Offset move;
      if (d < 130 && d > 0) {
        move = Offset(dx / d, dy / d) * 55; // chase
      } else {
        e.wanderTimer -= dt;
        if (e.wanderTimer <= 0) {
          e.wanderTimer = 1 + _rng.nextDouble() * 2;
          // Drift back towards home if strayed too far.
          final hx = e.homeX - e.x, hy = e.homeY - e.y;
          final hd = math.sqrt(hx * hx + hy * hy);
          if (hd > 80) {
            e.wanderDir = Offset(hx / hd, hy / hd);
          } else if (_rng.nextDouble() < 0.3) {
            e.wanderDir = Offset.zero;
          } else {
            final a = _rng.nextDouble() * math.pi * 2;
            e.wanderDir = Offset(math.cos(a), math.sin(a));
          }
        }
        move = e.wanderDir * 28;
      }
      // Stunned while flashing from a hit.
      if (e.flash > 0) move = Offset.zero;
      e.x += (move.dx + e.vx) * dt;
      e.y += (move.dy + e.vy) * dt;
      e.vx *= decay;
      e.vy *= decay;
      final r = _resolve(e.x, e.y, Enemy.radius);
      e.x = r.dx;
      e.y = r.dy;

      // Sword hit: one hit per enemy per swing.
      if (swing > 0 && !_hitThisSwing.contains(e)) {
        final tip = swordTip;
        final mid = Offset(x + facing.dx * swordReach / 2, y + facing.dy * swordReach / 2);
        if (_dist(tip.dx, tip.dy, e.x, e.y) < Enemy.radius + 12 ||
            _dist(mid.dx, mid.dy, e.x, e.y) < Enemy.radius + 12) {
          _hitThisSwing.add(e);
          e.hp--;
          e.flash = 0.25;
          e.vx = facing.dx * 260;
          e.vy = facing.dy * 260;
          hitEnemyEvent = true;
          if (!e.alive && hearts < maxHearts && _rng.nextDouble() < 0.5) {
            heartPickups.add(HeartPickup(e.x, e.y));
          }
          continue;
        }
      }

      // Contact damage with invulnerability frames + knockback.
      final nd = _dist(x, y, e.x, e.y);
      if (nd < playerRadius + Enemy.radius && invuln <= 0 && e.flash <= 0) {
        hearts = math.max(0, hearts - 1);
        invuln = 1.0;
        hurtEvent = true;
        final kx = nd > 0 ? (x - e.x) / nd : -facing.dx;
        final ky = nd > 0 ? (y - e.y) / nd : -facing.dy;
        kvx = kx * 300;
        kvy = ky * 300;
      }
    }
  }

  /// Pushes a circle out of every obstacle and keeps it inside the world.
  Offset _resolve(double cx, double cy, double r) {
    for (int pass = 0; pass < 2; pass++) {
      for (final t in trees) {
        final dx = cx - t.center.dx, dy = cy - t.center.dy;
        final d = math.sqrt(dx * dx + dy * dy);
        final min = r + t.radius;
        if (d < min) {
          if (d == 0) {
            cy += min;
          } else {
            cx = t.center.dx + dx / d * min;
            cy = t.center.dy + dy / d * min;
          }
        }
      }
      for (final o in rects) {
        final rc = o.rect;
        final nx = cx.clamp(rc.left, rc.right).toDouble();
        final ny = cy.clamp(rc.top, rc.bottom).toDouble();
        final dx = cx - nx, dy = cy - ny;
        final d2 = dx * dx + dy * dy;
        if (d2 < r * r) {
          if (d2 > 0) {
            final d = math.sqrt(d2);
            cx = nx + dx / d * r;
            cy = ny + dy / d * r;
          } else {
            // Centre is inside the rect: push out along the shortest side.
            final l = cx - rc.left, ri = rc.right - cx, t = cy - rc.top, b = rc.bottom - cy;
            final m = [l, ri, t, b].reduce(math.min);
            if (m == l) {
              cx = rc.left - r;
            } else if (m == ri) {
              cx = rc.right + r;
            } else if (m == t) {
              cy = rc.top - r;
            } else {
              cy = rc.bottom + r;
            }
          }
        }
      }
      cx = cx.clamp(r, worldW - r).toDouble();
      cy = cy.clamp(r, worldH - r).toDouble();
    }
    return Offset(cx, cy);
  }

  static double _dist(double ax, double ay, double bx, double by) {
    final dx = ax - bx, dy = ay - by;
    return math.sqrt(dx * dx + dy * dy);
  }
}
