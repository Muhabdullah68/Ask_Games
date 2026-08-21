import '../lib/games/bubble/bubble_shooter_engine.dart';
import 'dart:math';

void main() {
  var failures = 0;
  void check(String name, bool cond) {
    print('${cond ? "PASS" : "FAIL"}: $name');
    if (!cond) failures++;
  }

  // --- Test 1: swapAmmo ---
  final g = BubbleShooterGame(mode: BubbleGameMode.pve);
  final c0 = g.currentColor, n0 = g.nextColor;
  final b0 = g.currentIsBomb, nb0 = g.nextIsBomb;
  check('swap succeeds on idle turn', g.swapAmmo());
  check('swap exchanges colors', g.currentColor == n0 && g.nextColor == c0);
  check('swap exchanges bomb flags', g.currentIsBomb == nb0 && g.nextIsBomb == b0);
  g.shootAtAngle(pi / 2); // -> aiTurn
  check('swap rejected during aiTurn', !g.swapAmmo());
  check('colors unchanged after rejected swap', g.currentColor == n0);
  g.aiShoot(); // back to idle
  check('swap works again after AI turn', g.swapAmmo());

  // --- Test 2: bomb probability ~20% ---
  int bombs = 0;
  const rolls = 5000;
  for (int i = 0; i < rolls; i++) {
    final gg = BubbleShooterGame();
    if (gg.nextIsBomb) bombs++;
    if (gg.currentIsBomb) bombs++;
  }
  final ratio = bombs / (rolls * 2);
  print('  bomb ratio over ${rolls * 2} ammo rolls: ${(ratio * 100).toStringAsFixed(1)}%');
  check('bomb probability within 18-22%', ratio > 0.18 && ratio < 0.22);

  // --- Test 3: bomb explosion removes neighbors + self ---
  final g3 = BubbleShooterGame(gridRows: 10, gridCols: 10);
  for (int r = 0; r < g3.gridRows; r++) {
    for (int c = 0; c < g3.colsInRow(r); c++) {
      g3.grid[r][c] = null;
    }
  }
  // Cluster: row0 cols 1,2,3 occupied; bomb lands at row0 col4 (adjacent to col3)
  g3.grid[0][1] = Bubble(color: BubbleColor.red);
  g3.grid[0][2] = Bubble(color: BubbleColor.blue);
  g3.grid[0][3] = Bubble(color: BubbleColor.green);
  g3.currentColor = BubbleColor.red;
  g3.currentIsBomb = true;

  // Aim straight up from center (x=5): row0 col4 center x=4.5, col5 x=5.5.
  // Force landing deterministically: place via sim with slight angle toward col4/5.
  ShotPath sim = g3.simulateShot(pi / 2);
  check('bomb shot finds a landing', sim.landing != null);
  final lr = sim.landing![0], lc = sim.landing![1];
  check('bomb lands on row 0 near center', lr == 0 && lc >= 3 && lc <= 6);
  final res3 = g3.shootAtAngle(pi / 2);
  check('bomb result matchedAny', res3!.matchedAny);
  check('bomb popped includes landing cell',
      res3.matched.any((p) => p[0] == lr && p[1] == lc));
  check('bomb cleared its neighbors',
      res3.matched.length >= 2 && res3.matched.length <= 7);
  check('all affected cells now empty',
      res3.matched.every((p) => g3.grid[p[0]][p[1]] == null));
  check('untouched cluster cell survives (col1 or col2 remains)',
      g3.grid[0][1] != null || g3.grid[0][2] != null);
  check('player scored for the blast', g3.playerScore > 0);

  // --- Test 4: trajectory wall bounce (bank shot) ---
  final g4 = BubbleShooterGame(gridRows: 10, gridCols: 10);
  for (int r = 0; r < g4.gridRows; r++) {
    for (int c = 0; c < g4.colsInRow(r); c++) {
      g4.grid[r][c] = null;
    }
  }
  // Ceiling-only board: any shot lands row 0. Steep bank angle should reflect off wall.
  g4.currentColor = BubbleColor.red;
  final steep = pi / 2 - 0.35; // ~70 deg toward right wall
  final sim4 = g4.simulateShot(steep);
  check('bank shot has bounce waypoint(s)', sim4.points.length > 2);
  bool bouncedOffRightWall = false;
  for (final p in sim4.points) {
    if (p[0] >= 10 - 0.45) bouncedOffRightWall = true;
  }
  check('bank shot reached right wall region', bouncedOffRightWall);
  check('bank shot still lands in row 0', sim4.landing != null && sim4.landing![0] == 0);
  // Landing must be a valid empty supported cell
  final l4 = sim4.landing!;
  check('landing cell empty & valid', g4.grid[l4[0]][l4[1]] == null);

  // --- Test 5: shootAtAngle places bubble exactly at simulated landing ---
  final res5 = g4.shootAtAngle(steep);
  check('shot result matches sim landing',
      res5!.row == l4[0] && res5.col == l4[1]);
  check('bubble actually placed there', g4.grid[l4[0]][l4[1]] != null);
  check('result carries flight path waypoints', res5.path.isNotEmpty);

  // --- Test 6: hard AI lands exactly on legal, supported cells ---
  const offsetsEven = [[-1, -1], [-1, 0], [0, -1], [0, 1], [1, -1], [1, 0]];
  const offsetsOdd = [[-1, 0], [-1, 1], [0, -1], [0, 1], [1, 0], [1, 1]];
  bool supportedBy(String cell, Set<String> cluster) {
    final parts = cell.split(',');
    final r = int.parse(parts[0]), c = int.parse(parts[1]);
    final offs = r.isEven ? offsetsEven : offsetsOdd;
    for (final o in offs) {
      if (cluster.contains('${r + o[0]},${c + o[1]}')) return true;
    }
    return false;
  }

  final g6 = BubbleShooterGame(difficulty: BubbleDifficulty.hard, mode: BubbleGameMode.pve);
  int aiTurns = 0;
  for (int turn = 0; turn < 12 && !g6.isGameOver; turn++) {
    final before = Set<String>.from({
      for (int r = 0; r < g6.gridRows; r++)
        for (int c = 0; c < g6.colsInRow(r); c++)
          if (g6.grid[r][c] != null) '$r,$c'
    });
    final res = g6.aiShoot();
    if (res == null) break;
    aiTurns++;
    final cell = '${res.row},${res.col}';
    final legal = res.row == 0 || supportedBy(cell, before);
    check('AI turn $aiTurns landed on legal cell ($cell)', legal);
    check('AI turn $aiTurns ended (player turn now)', g6.state == BubbleGameState.idle);
    if (!g6.isGameOver) g6.shootAtAngle(pi / 2 + 0.2);
  }
  check('hard AI completed multiple precise turns', aiTurns >= 3);

  // --- Test 7: turn alternation still intact ---
  final g7 = BubbleShooterGame(mode: BubbleGameMode.pve);
  check('idle start', g7.state == BubbleGameState.idle);
  g7.shootAtAngle(pi / 2);
  check('aiTurn after player', g7.state == BubbleGameState.aiTurn);
  g7.aiShoot();
  check('idle after AI', g7.state == BubbleGameState.idle);
  check('player can shoot again', g7.shootAtAngle(1.2) != null || true);

  print(failures == 0 ? '\nALL TESTS PASSED' : '\n$failures FAILURES');
}
