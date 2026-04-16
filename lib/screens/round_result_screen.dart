import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_provider.dart';

class RoundResultScreen extends ConsumerStatefulWidget {
  const RoundResultScreen({super.key});

  @override
  ConsumerState<RoundResultScreen> createState() => _RoundResultScreenState();
}

class _RoundResultScreenState extends ConsumerState<RoundResultScreen>
    with TickerProviderStateMixin {

  // ── Reveal bonne réponse ─────────────────────────────────────────────────
  late AnimationController _revealController;
  late Animation<double> _revealScale;
  late Animation<double> _revealOpacity;

  // ── Slide résultat personnel ─────────────────────────────────────────────
  late AnimationController _personalController;
  late Animation<Offset> _personalSlide;
  late Animation<double> _personalOpacity;

  // ── Staggered classement ─────────────────────────────────────────────────
  late AnimationController _leaderboardController;

  // ── Compteur de score ────────────────────────────────────────────────────
  late AnimationController _scoreController;
  int _displayedScore = 0;
  int _targetScore = 0;

  static const _revealDelay = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();

    // Reveal
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _revealScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _revealController, curve: Curves.elasticOut),
    );
    _revealOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Résultat personnel
    _personalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _personalSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _personalController, curve: Curves.easeOutCubic),
    );
    _personalOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _personalController, curve: Curves.easeIn),
    );

    // Classement staggered
    _leaderboardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Compteur score
    _scoreController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scoreController.addListener(_onScoreTick);

    _startSequence();
  }

  void _startSequence() async {
    final state = ref.read(gameProvider);
    if (state is! RoundResultState) return;

    final myResult = state.result.resultForPlayer(state.pseudo);
    _targetScore = myResult?.scoreGained ?? 0;

    // 1. Délai puis reveal de la bonne réponse
    await Future.delayed(_revealDelay);
    if (!mounted) return;
    _revealController.forward();

    // 2. Résultat personnel juste après
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _personalController.forward();

    // 3. Compteur de score
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _scoreController.forward();

    // 4. Classement staggered
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _leaderboardController.forward();
  }

  void _onScoreTick() {
    final value = (_scoreController.value * _targetScore).round();
    if (value != _displayedScore) {
      setState(() => _displayedScore = value);
    }
  }

  @override
  void dispose() {
    _revealController.dispose();
    _personalController.dispose();
    _leaderboardController.dispose();
    _scoreController.removeListener(_onScoreTick);
    _scoreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameProvider);
    if (state is! RoundResultState) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final result = state.result;
    final myResult = result.resultForPlayer(state.pseudo);
    final isCorrect = myResult?.isCorrect ?? false;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Résultats du round'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Bonne réponse (reveal) ─────────────────────────────────
              AnimatedBuilder(
                animation: _revealController,
                builder: (_, __) => Opacity(
                  opacity: _revealOpacity.value,
                  child: Transform.scale(
                    scale: _revealScale.value,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Bonne réponse',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            result.correctAnswer,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Explication ────────────────────────────────────────────
              AnimatedBuilder(
                animation: _revealController,
                builder: (_, __) => Opacity(
                  opacity: _revealOpacity.value,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: theme.colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      result.explanation,
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Résultat personnel (slide) ─────────────────────────────
              if (myResult != null)
                AnimatedBuilder(
                  animation: _personalController,
                  builder: (_, __) => SlideTransition(
                    position: _personalSlide,
                    child: Opacity(
                      opacity: _personalOpacity.value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: isCorrect
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCorrect
                                ? Colors.green.shade200
                                : Colors.red.shade200,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isCorrect
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                                  color: isCorrect
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isCorrect
                                      ? 'Bonne réponse !'
                                      : 'Mauvaise réponse',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isCorrect
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                            // Compteur animé
                            AnimatedBuilder(
                              animation: _scoreController,
                              builder: (_, __) => Text(
                                isCorrect
                                    ? '+$_displayedScore pts'
                                    : '+0 pts',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isCorrect
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // ── Classement staggered ───────────────────────────────────
              Row(
                children: [
                  Icon(Icons.leaderboard_rounded,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Classement',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AnimatedBuilder(
                  animation: _leaderboardController,
                  builder: (_, __) {
                    return ListView.separated(
                      itemCount: result.playerResults.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final player = result.playerResults[index];
                        final isMe = player.pseudo == state.pseudo;

                        // Décalage par ligne
                        final itemDelay = index / result.playerResults.length;
                        final itemProgress = (_leaderboardController.value -
                                itemDelay)
                            .clamp(0.0, 1.0 - itemDelay) /
                            (1.0 - itemDelay).clamp(0.01, 1.0);

                        final opacity = itemProgress.clamp(0.0, 1.0);
                        final slide = Offset(0, 0.3 * (1 - itemProgress));

                        return Opacity(
                          opacity: opacity,
                          child: Transform.translate(
                            offset: Offset(0,
                                slide.dy * 50), // 50px de déplacement max
                            child: _LeaderboardTile(
                              index: index,
                              pseudo: player.pseudo,
                              score: player.score,
                              scoreGained: player.scoreGained,
                              isMe: isMe,
                              isCorrect: player.isCorrect,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // ── Message fin de partie ──────────────────────────────────
              if (result.isLastRound)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'Fin de la partie !',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tile classement ──────────────────────────────────────────────────────────

class _LeaderboardTile extends StatelessWidget {
  final int index;
  final String pseudo;
  final int score;
  final int scoreGained;
  final bool isMe;
  final bool isCorrect;

  const _LeaderboardTile({
    required this.index,
    required this.pseudo,
    required this.score,
    required this.scoreGained,
    required this.isMe,
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Médailles pour le top 3
    final medalColors = [Colors.amber, Colors.grey.shade400, Colors.brown.shade300];
    final isMedal = index < 3;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            isMedal ? medalColors[index] : theme.colorScheme.surfaceVariant,
        child: Text(
          '${index + 1}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isMedal ? Colors.white : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      title: Text(
        pseudo,
        style: TextStyle(
          fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: isCorrect
          ? Text(
              '+$scoreGained pts ce round',
              style: TextStyle(
                fontSize: 11,
                color: Colors.green.shade600,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
      trailing: Text(
        '$score pts',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isMe
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
        ),
      ),
    );
  }
}