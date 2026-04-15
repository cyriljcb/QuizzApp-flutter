import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vibration/vibration.dart';
import '../providers/game_provider.dart';

class QuestionScreen extends ConsumerStatefulWidget {
  const QuestionScreen({super.key, required bool isSuddenDeath});

  @override
  ConsumerState<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends ConsumerState<QuestionScreen>
    with TickerProviderStateMixin {
  final _answerController = TextEditingController();

  // ── Timer principal ───────────────────────────────────────────────────────
  late AnimationController _timerController;
  int _remainingSeconds = 0;
  int _lastTrackedRound = -1;

  // ── Pulse (accélère sous 5s) ──────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Pop du chiffre à chaque seconde ──────────────────────────────────────
  late AnimationController _digitController;
  late Animation<double> _digitScale;

  // ── Flash rouge à la fin ─────────────────────────────────────────────────
  late AnimationController _flashController;
  late Animation<double> _flashOpacity;

  @override
  void initState() {
    super.initState();

    // Pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Pop chiffre
    _digitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _digitScale = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.35)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.35, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_digitController);

    // Flash rouge
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flashOpacity = Tween<double>(begin: 0.0, end: 0.35).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeInOut),
    );

    // Timer
    _timerController = AnimationController(vsync: this);
    _timerController.addListener(_onTimerTick);

    _initTimer();
  }

  void _initTimer() {
    final state = ref.read(gameProvider);
    if (state is! QuestionState) return;

    _remainingSeconds = state.question.durationSeconds;
    _lastTrackedRound = state.question.roundNumber;
    _timerController.duration =
        Duration(seconds: state.question.durationSeconds);
    _timerController.forward(from: 0);
  }

  void _resetForNewQuestion(QuestionState state) {
    _answerController.clear();
    _timerController.stop();
    _timerController.reset();
    _flashController.reset();

    // Repasse le pulse en mode normal
    _pulseController.duration = const Duration(milliseconds: 800);
    if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);

    setState(() {
      _remainingSeconds = state.question.durationSeconds;
      _lastTrackedRound = state.question.roundNumber;
    });

    _timerController.duration =
        Duration(seconds: state.question.durationSeconds);
    _timerController.forward(from: 0);
  }

  void _onTimerTick() async {
    final state = ref.read(gameProvider);
    if (state is! QuestionState) return;

    final elapsed =
        (_timerController.value * state.question.durationSeconds).round();
    final remaining = state.question.durationSeconds - elapsed;

    if (remaining == _remainingSeconds) return;

    setState(() => _remainingSeconds = remaining);

    // Pop du chiffre à chaque seconde
    _digitController.forward(from: 0);

    // Accélération du pulse sous 5s
    if (remaining <= 5) {
      _pulseController.duration = const Duration(milliseconds: 350);
      if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
    }

    // Vibrations courtes sous 3s
    if (remaining <= 3 && remaining > 0) {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 80);
      }
    }

    // Temps écoulé
    if (remaining <= 0) {
      _flashController.forward();
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 400);
      }
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    _timerController.removeListener(_onTimerTick);
    _timerController.dispose();
    _pulseController.dispose();
    _digitController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  Future<void> _submitAnswer() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) return;
    await ref.read(gameProvider.notifier).submitAnswer(answer);
  }

  Color _timerColor(double progress) {
    if (progress > 0.6) return Colors.green;
    if (progress > 0.3) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    // Reset propre lors d'une nouvelle question
    ref.listen<GameState>(gameProvider, (previous, next) {
      if (next is QuestionState &&
          next.question.roundNumber != _lastTrackedRound) {
        _resetForNewQuestion(next);
      }
    });

    final state = ref.watch(gameProvider);
    if (state is! QuestionState) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final question = state.question;
    final progress = 1 - _timerController.value;
    final isSuddenDeath = state.isSuddenDeath;
    final timerColor = _timerColor(progress);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: isSuddenDeath
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sudden Death',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Question décisive',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimary.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Text(
                    'Question ${question.roundNumber} / ${question.totalRounds}'),
            centerTitle: true,
            backgroundColor: isSuddenDeath
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Countdown ───────────────────────────────────────────
                  AnimatedBuilder(
                    animation: Listenable.merge(
                        [_timerController, _pulseController, _digitController]),
                    builder: (_, __) {
                      return Column(
                        children: [
                          Text(
                            'Temps restant',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Transform.scale(
                            scale: _remainingSeconds <= 5
                                ? _pulseAnimation.value
                                : 1.0,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Cercle de fond (track)
                                SizedBox(
                                  width: 110,
                                  height: 110,
                                  child: CircularProgressIndicator(
                                    value: progress,
                                    strokeWidth: 10,
                                    backgroundColor:
                                        theme.colorScheme.surfaceVariant,
                                    valueColor: AlwaysStoppedAnimation(
                                        timerColor),
                                  ),
                                ),
                                // Chiffre animé
                                Transform.scale(
                                  scale: _digitScale.value,
                                  child: Text(
                                    _remainingSeconds > 0
                                        ? '$_remainingSeconds'
                                        : '⏱',
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: timerColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  if (isSuddenDeath) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.error,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.flash_on_rounded,
                              size: 18, color: theme.colorScheme.error),
                          const SizedBox(width: 8),
                          Text(
                            'Premier correct gagne',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ── Image optionnelle ───────────────────────────────────
                  if (question.imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: question.imageUrl!,
                        height: 180,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          height: 180,
                          color: theme.colorScheme.surfaceVariant,
                          child:
                              const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          height: 180,
                          color: theme.colorScheme.errorContainer,
                          child: const Icon(Icons.broken_image_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Texte de la question ────────────────────────────────
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          question.questionText,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Compteur de joueurs ayant répondu ───────────────────
                  if (state.answeredPlayers.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            '${state.answeredPlayers.length} joueur(s) ont répondu',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── Champ réponse ou confirmation ───────────────────────
                  if (!state.hasAnswered) ...[
                    TextField(
                      controller: _answerController,
                      decoration: const InputDecoration(
                        labelText: 'Ta réponse',
                        prefixIcon: Icon(Icons.edit_rounded),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _submitAnswer(),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _submitAnswer,
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Valider',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ] else
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Réponse envoyée !',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // ── Flash rouge plein écran quand temps écoulé ────────────────────
        AnimatedBuilder(
          animation: _flashController,
          builder: (_, __) => IgnorePointer(
            child: Container(
              color: Colors.red.withOpacity(_flashOpacity.value),
            ),
          ),
        ),
      ],
    );
  }
}