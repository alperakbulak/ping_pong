import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const PingPongApp());
}

class PingPongApp extends StatelessWidget {
  const PingPongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ping Pong',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  static const double _initialSpeedX = 560;
  static const double _initialSpeedY = 360;
  static const double _maxBounceVy = 640;
  static const double _playerPaddleSpeed = 420;
  static const double _cpuPaddleSpeed = 480;

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  Size _gameSize = Size.zero;

  Offset _ballPosition = Offset.zero;
  Offset _ballVelocity = const Offset(_initialSpeedX, _initialSpeedY);

  double _leftPaddleY = 0;
  double _rightPaddleY = 0;
  int _leftScore = 0;
  int _rightScore = 0;
  bool _initialized = false;

  final Set<LogicalKeyboardKey> _pressedKeys = {};

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!_initialized) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0) return;

    setState(() {
      _updatePaddles(dt);
      _updateBall(dt);
    });
  }

  void _updatePaddles(double dt) {
    if (_pressedKeys.contains(LogicalKeyboardKey.keyW) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowUp)) {
      _leftPaddleY -= _playerPaddleSpeed * dt;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyS) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowDown)) {
      _leftPaddleY += _playerPaddleSpeed * dt;
    }
    _leftPaddleY = _leftPaddleY.clamp(
      0,
      _gameSize.height - GamePainter.paddleHeight,
    );

    final paddleCenter = _rightPaddleY + GamePainter.paddleHeight / 2;
    final delta = _ballPosition.dy - paddleCenter;
    final maxStep = _cpuPaddleSpeed * dt;
    final move = delta.clamp(-maxStep, maxStep);
    _rightPaddleY = (_rightPaddleY + move).clamp(
      0,
      _gameSize.height - GamePainter.paddleHeight,
    );
  }

  void _updateBall(double dt) {
    var x = _ballPosition.dx + _ballVelocity.dx * dt;
    var y = _ballPosition.dy + _ballVelocity.dy * dt;
    var vx = _ballVelocity.dx;
    var vy = _ballVelocity.dy;

    if (y - GamePainter.ballRadius < 0) {
      y = GamePainter.ballRadius;
      vy = -vy;
    }
    if (y + GamePainter.ballRadius > _gameSize.height) {
      y = _gameSize.height - GamePainter.ballRadius;
      vy = -vy;
    }

    final leftRect = Rect.fromLTWH(
      GamePainter.paddleMargin,
      _leftPaddleY,
      GamePainter.paddleWidth,
      GamePainter.paddleHeight,
    );
    final rightRect = Rect.fromLTWH(
      _gameSize.width - GamePainter.paddleMargin - GamePainter.paddleWidth,
      _rightPaddleY,
      GamePainter.paddleWidth,
      GamePainter.paddleHeight,
    );
    final ballRect = Rect.fromCircle(
      center: Offset(x, y),
      radius: GamePainter.ballRadius,
    );

    if (vx < 0 && ballRect.overlaps(leftRect)) {
      x = leftRect.right + GamePainter.ballRadius;
      vx = -vx;
      vy = _bounceVy(y, leftRect);
    } else if (vx > 0 && ballRect.overlaps(rightRect)) {
      x = rightRect.left - GamePainter.ballRadius;
      vx = -vx;
      vy = _bounceVy(y, rightRect);
    }

    if (x + GamePainter.ballRadius < 0) {
      _rightScore++;
      _resetBall(towardRight: false);
      return;
    }
    if (x - GamePainter.ballRadius > _gameSize.width) {
      _leftScore++;
      _resetBall(towardRight: true);
      return;
    }

    _ballPosition = Offset(x, y);
    _ballVelocity = Offset(vx, vy);
  }

  double _bounceVy(double ballY, Rect paddle) {
    final relative = (ballY - paddle.center.dy) / (paddle.height / 2);
    return relative.clamp(-1.0, 1.0) * _maxBounceVy;
  }

  void _resetBall({required bool towardRight}) {
    _ballPosition = Offset(_gameSize.width / 2, _gameSize.height / 2);
    _ballVelocity = Offset(
      towardRight ? _initialSpeedX : -_initialSpeedX,
      _initialSpeedY,
    );
  }

  void _ensureInitialized(Size size) {
    if (_initialized && _gameSize == size) return;
    _gameSize = size;
    if (!_initialized) {
      _ballPosition = Offset(size.width / 2, size.height / 2);
      _leftPaddleY = (size.height - GamePainter.paddleHeight) / 2;
      _rightPaddleY = (size.height - GamePainter.paddleHeight) / 2;
      _initialized = true;
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _pressedKeys.add(event.logicalKey);
    } else if (event is KeyUpEvent) {
      _pressedKeys.remove(event.logicalKey);
    }
    return KeyEventResult.handled;
  }

  void _onPointerMove(PointerEvent event) {
    if (!_initialized) return;
    setState(() {
      _leftPaddleY = (event.localPosition.dy - GamePainter.paddleHeight / 2)
          .clamp(0.0, _gameSize.height - GamePainter.paddleHeight);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            _ensureInitialized(size);
            return Listener(
              onPointerDown: _onPointerMove,
              onPointerMove: _onPointerMove,
              child: CustomPaint(
                painter: GamePainter(
                  ballPosition: _ballPosition,
                  leftPaddleY: _leftPaddleY,
                  rightPaddleY: _rightPaddleY,
                  leftScore: _leftScore,
                  rightScore: _rightScore,
                ),
                size: size,
              ),
            );
          },
        ),
      ),
    );
  }
}

class GamePainter extends CustomPainter {
  GamePainter({
    required this.ballPosition,
    required this.leftPaddleY,
    required this.rightPaddleY,
    required this.leftScore,
    required this.rightScore,
  });

  static const double paddleWidth = 12;
  static const double paddleHeight = 80;
  static const double paddleMargin = 20;
  static const double ballRadius = 8;

  final Offset ballPosition;
  final double leftPaddleY;
  final double rightPaddleY;
  final int leftScore;
  final int rightScore;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;

    _drawCenterLine(canvas, size, paint);
    _drawScores(canvas, size);

    canvas.drawRect(
      Rect.fromLTWH(paddleMargin, leftPaddleY, paddleWidth, paddleHeight),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width - paddleMargin - paddleWidth,
        rightPaddleY,
        paddleWidth,
        paddleHeight,
      ),
      paint,
    );

    canvas.drawCircle(ballPosition, ballRadius, paint);
  }

  void _drawCenterLine(Canvas canvas, Size size, Paint paint) {
    const dashHeight = 14.0;
    const dashGap = 10.0;
    const dashWidth = 3.0;
    final x = (size.width - dashWidth) / 2;
    double y = 0;
    while (y < size.height) {
      canvas.drawRect(Rect.fromLTWH(x, y, dashWidth, dashHeight), paint);
      y += dashHeight + dashGap;
    }
  }

  void _drawScores(Canvas canvas, Size size) {
    const style = TextStyle(
      color: Colors.white,
      fontSize: 64,
      fontWeight: FontWeight.bold,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    _paintText(canvas, '$leftScore', style, Offset(size.width * 0.25, 40));
    _paintText(canvas, '$rightScore', style, Offset(size.width * 0.75, 40));
  }

  void _paintText(Canvas canvas, String text, TextStyle style, Offset center) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(center.dx - painter.width / 2, center.dy));
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) =>
      oldDelegate.ballPosition != ballPosition ||
      oldDelegate.leftPaddleY != leftPaddleY ||
      oldDelegate.rightPaddleY != rightPaddleY ||
      oldDelegate.leftScore != leftScore ||
      oldDelegate.rightScore != rightScore;
}
