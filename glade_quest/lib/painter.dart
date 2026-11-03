import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game.dart';

class GamePainter extends CustomPainter {
  GamePainter(this.g, Listenable repaint) : super(repaint: repaint);
  final GameState g;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / worldW, size.height / worldH);
    final p = Paint();
    void rect(double x, double y, double w, double h, Color c) {
      p.color = c;
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), p);
    }

    // Grass tiles
    for (int yy = 0; yy < 15; yy++) {
      for (int xx = 0; xx < 20; xx++) {
        rect(xx * 32, yy * 32, 32, 32,
            Color.fromRGBO(55 + (xx * yy) % 12, 130 + (xx + yy) % 18, 65, 1));
        if ((xx * 7 + yy * 11) % 4 == 0) {
          rect(xx * 32 + 8, yy * 32 + 9, 3, 3, const Color(0xff7ab65e));
        }
      }
    }
    // Dirt path
    final path = Path()
      ..moveTo(280, 480)
      ..lineTo(350, 480)
      ..lineTo(350, 340)
      ..lineTo(310, 265)
      ..lineTo(355, 180)
      ..lineTo(325, 0)
      ..lineTo(285, 0)
      ..lineTo(310, 180)
      ..lineTo(275, 265)
      ..lineTo(315, 340)
      ..close();
    p.color = const Color(0xffb99a59);
    canvas.drawPath(path, p);

    // Water (animated ripples)
    const w = GameState.water;
    rect(w.left, w.top, w.width, w.height, const Color(0xff2868b2));
    for (double xx = 5; xx < w.width; xx += 25) {
      final off = math.sin(g.time * 2 + xx) * 4;
      rect(xx + off, w.top + 10 + (xx % 3) * 5, 15, 2, const Color(0xff5da5e5));
    }

    // Cottage
    const h = GameState.house;
    rect(h.left + 7, h.top + 10, h.width - 14, h.height - 10, const Color(0xffd4b17a));
    rect(h.left, h.top, h.width, 48, const Color(0xff8b463d));
    rect(h.left + 50, h.bottom - 35, 25, 35, const Color(0xff392b26));

    // Keep
    rect(430, 35, 150, 115, const Color(0xff7b8790));
    rect(450, 20, 35, 130, const Color(0xff65717c));
    rect(525, 20, 35, 130, const Color(0xff65717c));
    rect(470, 65, 70, 85, const Color(0xff4a5660));
    rect(487, 88, 36, 62, const Color(0xff171f27));

    // Gems (bobbing + sparkle)
    for (final c in g.gems) {
      if (c.got) continue;
      final bob = math.sin(g.time * 4 + c.x) * 2;
      final gem = Path()
        ..moveTo(c.x, c.y - 12 + bob)
        ..lineTo(c.x + 8, c.y + bob)
        ..lineTo(c.x, c.y + 12 + bob)
        ..lineTo(c.x - 8, c.y + bob)
        ..close();
      p.color = const Color(0xff1f9e6e);
      canvas.drawPath(gem, p);
      rect(c.x - 3, c.y - 6 + bob, 4, 7, const Color(0xffb6ffdd));
      p.color = const Color(0x3300ffaa);
      canvas.drawCircle(Offset(c.x, c.y + 15), 7, p);
    }

    // Heart drops (blink before vanishing)
    for (final hp in g.heartPickups) {
      if (hp.life < 2 && (hp.life * 8).floor().isEven) continue;
      _heart(canvas, Offset(hp.x, hp.y), 7, const Color(0xffff5b5b));
    }

    // Draw trees, enemies and the player sorted by y so things overlap nicely.
    final drawables = <(double, void Function())>[];
    for (final t in g.trees) {
      drawables.add((t.center.dy + 14, () => _tree(canvas, t.center)));
    }
    for (final e in g.enemies) {
      if (e.alive) drawables.add((e.y, () => _enemy(canvas, e)));
    }
    drawables.add((g.y, () => _player(canvas)));
    drawables.sort((a, b) => a.$1.compareTo(b.$1));
    for (final d in drawables) {
      d.$2();
    }

    canvas.restore();
  }

  void _tree(Canvas canvas, Offset o) {
    final p = Paint()..color = const Color(0xff67462c);
    canvas.drawRect(Rect.fromLTWH(o.dx - 6, o.dy + 8, 12, 18), p);
    canvas.drawCircle(o, 22, p..color = const Color(0xff1d5c36));
    canvas.drawCircle(o.translate(-3, -5), 17, p..color = const Color(0xff287443));
  }

  void _enemy(Canvas canvas, Enemy e) {
    final p = Paint();
    void r(double x, double y, double w, double h, Color c) {
      p.color = e.flash > 0 ? Colors.white : c;
      canvas.drawRect(Rect.fromLTWH(e.x + x, e.y + y, w, h), p);
    }

    p.color = const Color(0x55000000);
    canvas.drawOval(Rect.fromCenter(center: Offset(e.x, e.y + 11), width: 22, height: 6), p);
    r(-8, -6, 16, 15, const Color(0xff9d4938));
    r(-9, -10, 18, 8, const Color(0xff6b3b9b));
    r(-4, -4, 3, 3, const Color(0xffffe066));
    r(2, -4, 3, 3, const Color(0xffffe066));
    // HP pips
    for (int i = 0; i < e.hp; i++) {
      p.color = const Color(0xffff6b6b);
      canvas.drawRect(Rect.fromLTWH(e.x - 7 + i * 5, e.y - 16, 4, 2), p);
    }
  }

  void _player(Canvas canvas) {
    // Blink while invulnerable after taking damage.
    if (g.invuln > 0 && (g.invuln * 12).floor().isEven) return;
    final p = Paint();
    final x = g.x - 10, y = g.y - 12;
    void r(double dx, double dy, double w, double h, Color c) {
      p.color = c;
      canvas.drawRect(Rect.fromLTWH(x + dx, y + dy, w, h), p);
    }

    p.color = const Color(0x55000000);
    canvas.drawOval(Rect.fromCenter(center: Offset(g.x, g.y + 12), width: 22, height: 6), p);
    r(3, 13, 5, 9, const Color(0xff65452b));
    r(12, 13, 5, 9, const Color(0xff65452b));
    r(2, 4, 15, 12, const Color(0xffc0392b));
    r(1, 0, 17, 6, const Color(0xff3b2a1e));
    r(5, 5, 10, 8, const Color(0xfff0bd83));
    final lookX = g.facing.dx.sign * 1.5;
    r(7 + lookX, 8, 2, 2, Colors.black);
    r(12 + lookX, 8, 2, 2, Colors.black);

    // Sword sweep: arc from -70° to +70° around the facing direction.
    if (g.swing > 0) {
      final t = 1 - g.swing / GameState.swingTime;
      final base = math.atan2(g.facing.dy, g.facing.dx);
      final a = base - 1.2 + 2.4 * t;
      final dir = Offset(math.cos(a), math.sin(a));
      final hilt = Offset(g.x, g.y) + dir * 8;
      final tip = Offset(g.x, g.y) + dir * GameState.swordReach;
      final arc = Paint()
        ..color = const Color(0x55ffffff)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10;
      canvas.drawArc(Rect.fromCircle(center: Offset(g.x, g.y), radius: GameState.swordReach - 6),
          base - 1.2, 2.4 * t, false, arc);
      canvas.drawLine(hilt, tip,
          Paint()
            ..color = const Color(0xffeeeeea)
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round);
      canvas.drawCircle(hilt, 3, Paint()..color = const Color(0xffd4a72c));
    }
  }

  static void _heart(Canvas canvas, Offset c, double s, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy + s)
      ..cubicTo(c.dx - s * 1.6, c.dy - s * 0.2, c.dx - s * 0.6, c.dy - s * 1.4, c.dx, c.dy - s * 0.4)
      ..cubicTo(c.dx + s * 0.6, c.dy - s * 1.4, c.dx + s * 1.6, c.dy - s * 0.2, c.dx, c.dy + s)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => false;
}
