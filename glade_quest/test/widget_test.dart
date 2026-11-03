import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glade_quest/game.dart';
import 'package:glade_quest/main.dart';

void main() {
  test('player walks with the stick and cannot leave the world', () {
    final g = GameState(seed: 1)..enemies.clear();
    final startY = g.y;
    for (int i = 0; i < 10; i++) {
      g.update(0.016, const Offset(0, -1));
    }
    expect(g.y, lessThan(startY));
    for (int i = 0; i < 600; i++) {
      g.update(0.016, const Offset(0, -1));
    }
    expect(g.y, greaterThanOrEqualTo(GameState.playerRadius));
  });

  test('player cannot walk through the cottage', () {
    final g = GameState(seed: 1)..enemies.clear();
    g.x = 200;
    g.y = 200;
    for (int i = 0; i < 200; i++) {
      g.update(0.016, const Offset(-1, 0));
    }
    expect(g.x, greaterThanOrEqualTo(GameState.house.right + GameState.playerRadius - 0.01));
  });

  test('each sword press deals exactly one hit, three hits defeat a beetle', () {
    final g = GameState(seed: 1);
    g.enemies
      ..clear()
      ..add(Enemy(g.x, g.y + 25));
    g.facing = const Offset(0, 1);
    final e = g.enemies.first;
    g.attack();
    for (int i = 0; i < 20; i++) {
      g.update(0.016, Offset.zero);
    }
    expect(e.hp, 2);
    for (int n = 0; n < 2; n++) {
      e.x = g.x;
      e.y = g.y + 25;
      e.vx = e.vy = 0;
      g.attack();
      for (int i = 0; i < 25; i++) {
        g.update(0.016, Offset.zero);
      }
    }
    expect(e.alive, isFalse);
  });

  test('contact damage has invulnerability frames', () {
    final g = GameState(seed: 1);
    g.enemies
      ..clear()
      ..add(Enemy(g.x + 5, g.y));
    g.update(0.016, Offset.zero);
    expect(g.hearts, maxHearts - 1);
    g.enemies.first
      ..x = g.x + 5
      ..y = g.y;
    g.update(0.016, Offset.zero);
    expect(g.hearts, maxHearts - 1);
  });

  test('collecting all gems and defeating all enemies wins; restart resets', () {
    final g = GameState(seed: 1);
    for (final e in g.enemies) {
      e.hp = 0;
    }
    for (final gem in g.gems) {
      g.x = gem.x;
      g.y = gem.y;
      g.update(0.016, Offset.zero);
    }
    expect(g.win, isTrue);
    g.restart();
    expect(g.win, isFalse);
    expect(g.gemsCollected, 0);
    expect(g.enemiesLeft, 4);
  });

  test('every gem and spawn is reachable (not inside an obstacle)', () {
    final g = GameState(seed: 1);
    final points = [
      ...g.gems.map((e) => Offset(e.x, e.y)),
      ...g.enemies.map((e) => Offset(e.x, e.y)),
      Offset(g.x, g.y),
    ];
    for (final p in points) {
      for (final r in g.rects) {
        expect(r.rect.inflate(10).contains(p), isFalse, reason: '$p in ${r.rect}');
      }
      for (final t in g.trees) {
        expect((p - t.center).distance, greaterThan(t.radius + 10), reason: '$p near tree');
      }
    }
  });

  for (final size in [const Size(390, 844), const Size(844, 390), const Size(1024, 768), const Size(600, 600)]) {
    testWidgets('app renders without overflow at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const GladeApp());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(Joystick), findsOneWidget);
      expect(find.byType(AttackButton), findsOneWidget);
      await tester.tap(find.byType(AttackButton));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });
  }
}
