import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/game_provider.dart';

class QuestionScreen extends ConsumerStatefulWidget {
  const QuestionScreen({super.key, required bool isSuddenDeath});

  @override
  ConsumerState<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends ConsumerState<QuestionScreen>
    with SingleTickerProviderStateMixin {
  final _answerController = TextEditingController();
  late AnimationController _timerController;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(vsync: this);
    _initTimer();
  }

  void _initTimer() {
    final state = ref.read(gameProvider);
    if (state is! QuestionState) return;

    _remainingSeconds = state.question.durationSeconds;
    _timerController.duration =
        Duration(seconds: state.question.durationSeconds);
    _timerController.addListener(_onTimerTick);
    _timerController.forward(from: 0);
  }

  void _resetForNewQuestion(QuestionState state) {
    _answerController.clear();
    _timerController.removeListener(_onTimerTick);
    _timerController.stop();
    _timerController.reset();

    setState(() {
      _remainingSeconds = state.question.durationSeconds;
    });

    _timerController.duration =
        Duration(seconds: state.question.durationSeconds);
    _timerController.addListener(_onTimerTick);
    _timerController.forward(from: 0);
  }

  void _onTimerTick() {
    final state = ref.read(gameProvider);
    if (state is! QuestionState) return;

    final elapsed =
        (_timerController.value * state.question.durationSeconds).round();
    final remaining = state.question.durationSeconds - elapsed;

    if (remaining != _remainingSeconds) {
      setState(() => _remainingSeconds = remaining);
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    _timerController.removeListener(_onTimerTick);
    _timerController.dispose();
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
    // Détecte l'arrivée d'une nouvelle question
    // ref.listen<GameState>(gameProvider, (previous, next) {
    //   if (next is QuestionState &&
    //       next.question.roundNumber != _currentRound) {
    //     _resetForNewQuestion(next);
    //   }
    // });

    final state = ref.watch(gameProvider);
    if (state is! QuestionState) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final question = state.question;
    final progress = 1 - _timerController.value;

    final isSuddenDeath = state.isSuddenDeath;

    return Scaffold(
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
                    'Question decisive',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimary.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Text('Question ${question.roundNumber} / ${question.totalRounds}'),
        centerTitle: true,
        backgroundColor:
            isSuddenDeath ? theme.colorScheme.error : theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Timer
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Temps restant',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '$_remainingSeconds s',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _timerColor(progress),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AnimatedBuilder(
                    animation: _timerController,
                    builder: (_, __) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation(
                          _timerColor(progress),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (isSuddenDeath) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 14,
                  ),
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
                      Icon(
                        Icons.flash_on_rounded,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
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

              // Image optionnelle
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
                      child: const Center(child: CircularProgressIndicator()),
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

              // Question
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

              // Joueurs ayant répondu
              if (state.answeredPlayers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
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

              // Champ réponse ou confirmation
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
                  label: const Text(
                    'Valider',
                    style: TextStyle(fontSize: 16),
                  ),
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
                      Icon(
                        Icons.check_circle_rounded,
                        color: theme.colorScheme.primary,
                      ),
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
    );
  }
}
