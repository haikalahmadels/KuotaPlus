import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Ekspresi Kuo untuk momen emosional saja (docs/UI-KuotaPlus.md, Maskot).
enum MascotMood {
  /// Menyapa: login, onboarding.
  wave,

  /// Agak khawatir: kuota berisiko.
  worried,

  /// Mengantuk: kuota habis. Tenang, tidak memarahi.
  sleepy,

  /// Merayakan sekali: pembayaran berhasil.
  celebrate,

  /// Istirahat: daftar kosong.
  rest,
}

/// Maskot Kuota+, digambar dengan kode (tanpa aset). Selalu dekoratif: makna ada di teks di sebelahnya.
/// Gerak idle (napas, kedip, lambaian) mati saat "kurangi animasi" aktif.
class Mascot extends StatefulWidget {
  const Mascot({super.key, required this.mood, this.size = 96});

  final MascotMood mood;
  final double size;

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _controller.stop();
      // Pose akhir yang diam: tangan terangkat untuk celebrate, netral untuk lainnya.
      _controller.value = widget.mood == MascotMood.celebrate ? 1 : 0;
      _started = false;
    } else if (!_started) {
      _started = true;
      _start();
    }
  }

  void _start() {
    if (widget.mood == MascotMood.celebrate) {
      // Merayakan sekali (± 1,5 detik), lalu diam.
      _controller
        ..duration = const Duration(milliseconds: 1500)
        ..forward(from: 0);
    } else {
      _controller
        ..duration = const Duration(seconds: 4)
        ..repeat();
    }
  }

  @override
  void didUpdateWidget(Mascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood && _started) _start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) =>
              CustomPaint(size: Size.square(widget.size), painter: _MascotPainter(widget.mood, _controller.value)),
        ),
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  _MascotPainter(this.mood, this.t);

  final MascotMood mood;

  /// Fase animasi 0..1.
  final double t;

  static const _strokeWidth = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Semua koordinat di kotak 100 × 100.
    canvas.scale(size.width / 100, size.height / 100);

    final celebrating = mood == MascotMood.celebrate;
    final hop = celebrating ? -(math.sin(t * math.pi * 3).abs()) * 8 * (1 - t) : math.sin(t * math.pi * 2) * 1.5;
    canvas.translate(0, hop);

    _shadow(canvas, hop);
    _antenna(canvas);
    _arms(canvas);
    _body(canvas);
    _cheeks(canvas);
    _eyes(canvas);
    _mouth(canvas);
    if (mood == MascotMood.sleepy) _zz(canvas);
  }

  Paint get _fill => Paint()..color = MascotColors.body;
  Paint _stroke(Color color, [double width = _strokeWidth]) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;

  void _shadow(Canvas canvas, double hop) {
    // Bayangan tetap di tanah walau badan melompat.
    canvas.save();
    canvas.translate(0, -hop);
    final shrink = 1 + hop / 40;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 96), width: 52 * shrink, height: 6),
      Paint()..color = MascotColors.ink.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  void _antenna(Canvas canvas) {
    final sway = math.sin(t * math.pi * 4) * 2;
    canvas.drawPath(
      Path()
        ..moveTo(50, 28)
        ..quadraticBezierTo(52, 18, 56 + sway, 12),
      _stroke(MascotColors.body),
    );
    canvas.drawCircle(Offset(56 + sway, 10), 6, Paint()..color = MascotColors.light);
    // Gelombang sinyal kecil di samping bola antena.
    canvas.drawArc(
      Rect.fromCircle(center: Offset(56 + sway, 10), radius: 11),
      -0.9,
      1.2,
      false,
      _stroke(MascotColors.light, 2.5),
    );
  }

  void _body(Canvas canvas) {
    final squash = mood == MascotMood.sleepy ? 3.0 : 0.0;
    canvas.drawRRect(RRect.fromLTRBR(16, 28 + squash, 84, 92, const Radius.circular(30)), _fill);
    // Kilau di dahi supaya badan terasa membulat.
    canvas.drawRRect(
      RRect.fromLTRBR(28, 34 + squash, 44, 39 + squash, const Radius.circular(3)),
      Paint()..color = MascotColors.white.withValues(alpha: 0.35),
    );
  }

  void _arms(Canvas canvas) {
    final paint = _stroke(MascotColors.body, 9);
    // Sudut lengan dari bahu: 0 = menggantung ke bawah, π = ke atas.
    final (double left, double right) = switch (mood) {
      MascotMood.wave => (0.35, 2.4 + math.sin(t * math.pi * 6) * 0.35),
      MascotMood.celebrate => (math.pi - 0.5 + math.sin(t * math.pi * 6) * 0.2 * (1 - t), math.pi - 0.5),
      MascotMood.worried => (0.9, 0.9),
      _ => (0.3, 0.3),
    };
    void arm(Offset shoulder, double angle, double side) {
      final end = shoulder + Offset(side * math.sin(angle) * 14, math.cos(angle) * 14);
      canvas.drawLine(shoulder, end, paint);
    }

    arm(const Offset(18, 64), left, -1);
    arm(const Offset(82, 64), right, 1);
  }

  void _cheeks(Canvas canvas) {
    final paint = Paint()..color = MascotColors.light.withValues(alpha: 0.7);
    canvas.drawOval(Rect.fromCenter(center: const Offset(29, 70), width: 10, height: 6), paint);
    canvas.drawOval(Rect.fromCenter(center: const Offset(71, 70), width: 10, height: 6), paint);
  }

  void _eyes(Canvas canvas) {
    const left = Offset(38, 56);
    const right = Offset(62, 56);
    final line = _stroke(MascotColors.white);

    switch (mood) {
      case MascotMood.wave || MascotMood.celebrate:
        // Mata senang: lengkung ke atas.
        for (final c in [left, right]) {
          canvas.drawArc(Rect.fromCircle(center: c + const Offset(0, 3), radius: 6), math.pi, math.pi, false, line);
        }
      case MascotMood.sleepy || MascotMood.rest:
        // Mata terpejam: lengkung ke bawah.
        for (final c in [left, right]) {
          canvas.drawArc(Rect.fromCircle(center: c - const Offset(0, 3), radius: 6), 0.2, math.pi - 0.4, false, line);
        }
      case MascotMood.worried:
        _openEyes(canvas, [left, right], lookUp: true);
        // Alis naik di tengah.
        canvas.drawLine(const Offset(31, 44), const Offset(42, 41), _stroke(MascotColors.white, 3));
        canvas.drawLine(const Offset(69, 44), const Offset(58, 41), _stroke(MascotColors.white, 3));
    }
  }

  void _openEyes(Canvas canvas, List<Offset> centers, {bool lookUp = false}) {
    // Kedip singkat menjelang akhir setiap putaran.
    final blink = t > 0.9 && t < 0.96 ? 0.15 : 1.0;
    for (final c in centers) {
      canvas.drawOval(Rect.fromCenter(center: c, width: 15, height: 17 * blink), Paint()..color = MascotColors.white);
      if (blink == 1) {
        canvas.drawCircle(c + Offset(1, lookUp ? -2 : 1), 4.5, Paint()..color = MascotColors.ink);
      }
    }
  }

  void _mouth(Canvas canvas) {
    const c = Offset(50, 74);
    switch (mood) {
      case MascotMood.celebrate:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 9, c.dy - 3)
            ..quadraticBezierTo(c.dx, c.dy + 14, c.dx + 9, c.dy - 3)
            ..close(),
          Paint()..color = MascotColors.white,
        );
      case MascotMood.wave || MascotMood.rest:
        canvas.drawArc(
          Rect.fromCircle(center: c - const Offset(0, 4), radius: 7),
          0.4,
          math.pi - 0.8,
          false,
          _stroke(MascotColors.white),
        );
      case MascotMood.worried:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 7, c.dy + 1)
            ..quadraticBezierTo(c.dx - 3.5, c.dy - 3, c.dx, c.dy + 1)
            ..quadraticBezierTo(c.dx + 3.5, c.dy + 5, c.dx + 7, c.dy + 1),
          _stroke(MascotColors.white, 3),
        );
      case MascotMood.sleepy:
        canvas.drawCircle(c, 3.5, _stroke(MascotColors.white, 2.5));
    }
  }

  void _zz(Canvas canvas) {
    // "z" melayang naik pelan.
    final rise = t * 6;
    final paint = _stroke(MascotColors.ink.withValues(alpha: 0.55), 2.5);
    void z(Offset o, double s) {
      canvas.drawPath(
        Path()
          ..moveTo(o.dx, o.dy)
          ..lineTo(o.dx + s, o.dy)
          ..lineTo(o.dx, o.dy + s)
          ..lineTo(o.dx + s, o.dy + s),
        paint,
      );
    }

    z(Offset(80, 24 - rise), 7);
    z(Offset(90, 12 - rise), 5);
  }

  @override
  bool shouldRepaint(_MascotPainter old) => old.mood != mood || old.t != t;
}
