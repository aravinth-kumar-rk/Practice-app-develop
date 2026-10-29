import 'dart:math' as math;

import 'package:flutter/material.dart';

void main() => runApp(const TodoApp());

const kBlue = Color(0xFF1E90FF);
const kCyan = Color(0xFF00E5FF);

// ───────────────────────── APP ROOT ─────────────────────────
class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Orbit Tasks',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(primary: kBlue, secondary: kCyan),
      ),
      home: const Shell(),
    );
  }
}

// ───────────────────────── MODEL ─────────────────────────
class Task {
  final String title;
  bool done;
  Task(this.title, {this.done = false});
}

// ───────────────────────── SHELL (state lives here) ─────────────────────────
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with SingleTickerProviderStateMixin {
  // Drives the globe rotation forever
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  final _listKey = GlobalKey<AnimatedListState>();
  final _input = TextEditingController();
  final List<Task> _tasks = [];
  int _created = 0; // lifetime counter, doesn't drop when you delete
  int _page = 0;

  int get _completed => _tasks.where((t) => t.done).length;
  int get _pending => _tasks.where((t) => !t.done).length;

  @override
  void dispose() {
    _spin.dispose();
    _input.dispose();
    super.dispose();
  }

  void _add() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _tasks.insert(0, Task(text));
    _created++;
    _listKey.currentState?.insertItem(
      0,
      duration: const Duration(milliseconds: 450),
    );
    _input.clear();
    setState(() {});
  }

  void _toggle(Task t) => setState(() => t.done = !t.done);

  void _delete(Task t) {
    final i = _tasks.indexOf(t);
    if (i < 0) return;
    final removed = _tasks.removeAt(i);
    _listKey.currentState?.removeItem(
      i,
      (ctx, anim) => _TaskTile(task: removed, animation: anim),
      duration: const Duration(milliseconds: 350),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Golden hologram background (rings, spokes, circuits, bokeh)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _spin,
                  builder: (_, __) => CustomPaint(
                    painter: HoloBackgroundPainter(
                      _spin.value,
                      topPad + 16 + 150,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 3D globe lives behind every page
          Positioned(
            top: topPad + 16,
            left: 0,
            right: 0,
            height: 300,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: _page == 0 ? 1 : 0.25,
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _spin,
                    builder: (_, __) => CustomPaint(
                      painter: GlobePainter(_spin.value * 2 * math.pi),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: IndexedStack(
              index: _page,
              children: [_tasksPage(), _profilePage()],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.black,
        indicatorColor: kBlue.withOpacity(0.25),
        selectedIndex: _page,
        onDestinationSelected: (i) => setState(() => _page = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.checklist_rounded),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ───────────── PAGE 1: TASKS ─────────────
  Widget _tasksPage() {
    return Column(
      children: [
        const SizedBox(height: 16),
        // Same 300px height as the globe, input sits in its center
        SizedBox(
          height: 300,
          child: Center(
            child: Container(
              width: 270,
              padding: const EdgeInsets.only(left: 18, right: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: kCyan.withOpacity(0.7)),
                boxShadow: [
                  BoxShadow(color: kBlue.withOpacity(0.6), blurRadius: 24),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      onSubmitted: (_) => _add(),
                      decoration: const InputDecoration(
                        hintText: 'What needs doing?',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _add,
                    icon: const Icon(
                      Icons.add_circle_rounded,
                      color: kCyan,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              AnimatedList(
                key: _listKey,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                initialItemCount: _tasks.length,
                itemBuilder: (ctx, i, anim) {
                  final t = _tasks[i];
                  return _TaskTile(
                    task: t,
                    animation: anim,
                    onToggle: () => _toggle(t),
                    onDelete: () => _delete(t),
                  );
                },
              ),
              if (_tasks.isEmpty)
                const Center(
                  child: Text(
                    'No tasks yet. Add your first one ✨',
                    style: TextStyle(color: Colors.white38),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────── PAGE 2: PROFILE ─────────────
  Widget _profilePage() {
    final total = _tasks.length;
    final progress = total == 0 ? 0.0 : _completed / total;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
              border: Border.all(color: kCyan, width: 2),
              boxShadow: [
                BoxShadow(color: kBlue.withOpacity(0.7), blurRadius: 30),
              ],
            ),
            child: const Icon(Icons.person_rounded, size: 52, color: kCyan),
          ),
          const SizedBox(height: 12),
          const Text(
            'My Profile',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 150),
          Row(
            children: [
              _stat('Created', _created, Icons.add_task_rounded, kBlue),
              const SizedBox(width: 12),
              _stat(
                'Completed',
                _completed,
                Icons.check_circle_rounded,
                Colors.greenAccent,
              ),
              const SizedBox(width: 12),
              _stat(
                'Pending',
                _pending,
                Icons.hourglass_bottom_rounded,
                Colors.orangeAccent,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(kBlue),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Progress  ${(progress * 100).round()}%'),
                const SizedBox(height: 10),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 600),
                  builder: (_, v, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: v,
                      minHeight: 10,
                      backgroundColor: Colors.white12,
                      color: kCyan,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, int value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: _cardDecoration(color),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Text(
                '$value',
                key: ValueKey(value),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration(Color color) => BoxDecoration(
  color: Colors.black.withOpacity(0.65),
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: color.withOpacity(0.6)),
  boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 14)],
);

// ───────────────────────── TASK TILE (animated in/out) ─────────────────────────
class _TaskTile extends StatelessWidget {
  final Task task;
  final Animation<double> animation;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;

  const _TaskTile({
    required this.task,
    required this.animation,
    this.onToggle,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return SizeTransition(
      sizeFactor: curved,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0.3, 0),
            end: Offset.zero,
          ).animate(curved),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: _cardDecoration(task.done ? Colors.greenAccent : kBlue),
            child: ListTile(
              leading: Checkbox(
                value: task.done,
                activeColor: kCyan,
                onChanged: onToggle == null ? null : (_) => onToggle!(),
              ),
              title: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  fontSize: 16,
                  color: task.done ? Colors.white38 : Colors.white,
                  decoration: task.done ? TextDecoration.lineThrough : null,
                ),
                child: Text(task.title),
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                ),
                onPressed: onDelete,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 3D GLOBE (pure Dart, no packages) ─────────────────────────
class GlobePainter extends CustomPainter {
  final double angle; // rotation around the vertical axis
  GlobePainter(this.angle);

  static const double _tilt = 0.4; // axis tilt, like a real globe

  // Random "land dots", generated once
  static final List<List<double>> _dots = () {
    final r = math.Random(42);
    return List.generate(260, (_) {
      final lat = math.asin(2 * r.nextDouble() - 1);
      final lon = r.nextDouble() * 2 * math.pi;
      return [lat, lon];
    });
  }();

  // lat/lon -> rotated 3D point [x, y, z]; z > 0 means facing the viewer
  List<double> _p(double lat, double lon) {
    lon += angle;
    final x = math.cos(lat) * math.sin(lon);
    final y = math.sin(lat);
    final z = math.cos(lat) * math.cos(lon);
    final y2 = y * math.cos(_tilt) - z * math.sin(_tilt);
    final z2 = y * math.sin(_tilt) + z * math.cos(_tilt);
    return [x, y2, z2];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.34;

    // 1. Outer glow
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = kBlue.withOpacity(0.65)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 45),
    );

    // 2. Sphere body with light from top-left
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.4),
          radius: 1.0,
          colors: [Color(0xFF2E9BFF), Color(0xFF05285A), Color(0xFF00060F)],
          stops: [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // 3. Grid lines (depth-faded: front bright, back dim)
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    void seg(List<double> a, List<double> b) {
      final depth = (a[2] + b[2]) / 2; // -1 back … +1 front
      line.color = kCyan.withOpacity(
        (0.08 + 0.55 * (depth + 1) / 2).clamp(0.0, 1.0),
      );
      canvas.drawLine(
        Offset(c.dx + a[0] * r, c.dy - a[1] * r),
        Offset(c.dx + b[0] * r, c.dy - b[1] * r),
        line,
      );
    }

    // meridians
    for (int i = 0; i < 12; i++) {
      final lon = i * math.pi / 6;
      List<double>? prev;
      for (
        double lat = -math.pi / 2;
        lat <= math.pi / 2 + 0.01;
        lat += math.pi / 36
      ) {
        final p = _p(lat, lon);
        if (prev != null) seg(prev, p);
        prev = p;
      }
    }
    // parallels
    for (final deg in [-60, -30, 0, 30, 60]) {
      final lat = deg * math.pi / 180;
      List<double>? prev;
      for (double lon = 0; lon <= 2 * math.pi + 0.01; lon += math.pi / 36) {
        final p = _p(lat, lon);
        if (prev != null) seg(prev, p);
        prev = p;
      }
    }

    // 4. Glowing dots on the front side
    final dot = Paint();
    for (final d in _dots) {
      final p = _p(d[0], d[1]);
      if (p[2] <= 0) continue;
      dot.color = Colors.white.withOpacity(0.25 + 0.65 * p[2]);
      canvas.drawCircle(
        Offset(c.dx + p[0] * r, c.dy - p[1] * r),
        1.2 + 1.2 * p[2],
        dot,
      );
    }

    // 5. Rim light for the glowing edge
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = kCyan.withOpacity(0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(GlobePainter old) => old.angle != angle;
}

// ───────────────────────── GOLDEN HOLOGRAM BACKGROUND ─────────────────────────
class _Bokeh {
  final double x, y, r, phase, alpha;
  final int k;
  final Color color;
  _Bokeh(this.x, this.y, this.r, this.phase, this.alpha, this.k, this.color);
}

class HoloBackgroundPainter extends CustomPainter {
  final double t; // 0..1, loops seamlessly
  final double centerY; // hologram is centered on the globe
  HoloBackgroundPainter(this.t, this.centerY);

  static const _gold = Color(0xFFFFB300);
  static const _amber = Color(0xFFFF8F00);
  static const _pale = Color(0xFFFFE082);

  static final math.Random _rnd = math.Random(11);

  // Floating glowing dots (bokeh)
  static final List<_Bokeh> _bokeh = List.generate(80, (_) {
    return _Bokeh(
      _rnd.nextDouble(),
      _rnd.nextDouble(),
      0.8 + math.pow(_rnd.nextDouble(), 2.5) * 8,
      _rnd.nextDouble() * 2 * math.pi,
      0.35 + _rnd.nextDouble() * 0.6,
      1 + _rnd.nextInt(2),
      [_gold, _amber, _pale][_rnd.nextInt(3)],
    );
  });

  // Thin lines shooting out from the center: [angle, length, phase, startOffset]
  static final List<List<double>> _spokes = List.generate(
    34,
    (_) => [
      _rnd.nextDouble() * 2 * math.pi,
      0.45 + _rnd.nextDouble() * 0.9,
      _rnd.nextDouble() * 2 * math.pi,
      _rnd.nextDouble() * 0.3,
    ],
  );

  // Little circuit-board style zig-zag paths
  static final List<List<Offset>> _circuits = List.generate(16, (_) {
    final ang = _rnd.nextDouble() * 2 * math.pi;
    final dist = 130 + _rnd.nextDouble() * 330;
    var p = Offset(math.cos(ang) * dist, math.sin(ang) * dist);
    final pts = <Offset>[p];
    bool horiz = _rnd.nextBool();
    for (int i = 0; i < 6; i++) {
      final len = 8 + _rnd.nextDouble() * 36;
      final s = _rnd.nextBool() ? 1 : -1;
      p = horiz ? p + Offset(len * s, 0) : p + Offset(0, len * s);
      pts.add(p);
      horiz = !horiz;
    }
    return pts;
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, centerY);
    final tau = 2 * math.pi * t;
    final maxR = size.height * 0.75;

    // 1. Dark warm base
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF3D2000), Color(0xFF130900), Colors.black],
          stops: [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: size.height * 0.85)),
    );

    // 2. Soft amber glow in the middle
    canvas.drawCircle(
      c,
      size.width * 0.45,
      Paint()
        ..color = _amber.withOpacity(0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70),
    );

    canvas.save();
    canvas.translate(c.dx, c.dy);

    // 3. Tilted rotating rings with bright arc segments
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final bright = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 6; i++) {
      final rx = size.width * (0.34 + 0.13 * i);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: rx * 2,
        height: rx * 2 * (0.5 + 0.06 * i),
      );
      canvas.save();
      canvas.rotate((i.isEven ? -1 : 1) * tau + i * 0.6);
      glow.color = _gold.withOpacity(0.18);
      thin.color = _gold.withOpacity(0.45);
      bright.color = _pale.withOpacity(0.85);
      canvas.drawOval(rect, glow);
      canvas.drawOval(rect, thin);
      canvas.drawArc(rect, i * 1.1, 1.0 + 0.2 * i, false, bright);
      canvas.restore();
    }

    // 4. Spokes + circuit paths, slowly rotating together
    canvas.rotate(tau);
    final spoke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final s in _spokes) {
      final shimmer = 0.5 + 0.5 * math.sin(tau * 2 + s[2]);
      spoke.color = _gold.withOpacity(0.12 + 0.4 * shimmer);
      final a = s[0];
      final r0 = 30 + s[3] * 100;
      final r1 = maxR * s[1];
      canvas.drawLine(
        Offset(math.cos(a) * r0, math.sin(a) * r0),
        Offset(math.cos(a) * r1, math.sin(a) * r1),
        spoke,
      );
    }
    final circ = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _amber.withOpacity(0.55);
    for (final pts in _circuits) {
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, circ);
    }
    canvas.restore();

    // 5. Floating, twinkling bokeh dots (big ones are blurred)
    final dot = Paint();
    for (final b in _bokeh) {
      final px = b.x * size.width + 14 * math.sin(tau * b.k + b.phase);
      final py = b.y * size.height + 14 * math.cos(tau * b.k + b.phase * 1.3);
      final twinkle = 0.55 + 0.45 * math.sin(tau * (b.k + 1) + b.phase);
      dot.color = b.color.withOpacity((b.alpha * twinkle).clamp(0.0, 1.0));
      dot.maskFilter = b.r > 3.5
          ? MaskFilter.blur(BlurStyle.normal, b.r * 0.45)
          : null;
      canvas.drawCircle(Offset(px, py), b.r, dot);
    }

    // 6. Darken the lower area so the task list stays readable
    final top = (centerY + 120).clamp(0.0, size.height);
    final fade = Rect.fromLTRB(0, top, size.width, size.height);
    canvas.drawRect(
      fade,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.82)],
        ).createShader(fade),
    );
  }

  @override
  bool shouldRepaint(HoloBackgroundPainter old) => old.t != t;
}
