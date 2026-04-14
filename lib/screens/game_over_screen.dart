import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz/core/signalr_service.dart';
import '../providers/game_provider.dart';

class GameOverScreen extends ConsumerWidget {
  const GameOverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    if (state is! GameOverState) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scores = state.scores;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Fin de partie'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                '🏆 Podium',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Top 3 podium visuel
              if (scores.isNotEmpty)
                _PodiumWidget(scores: scores, myPseudo: state.pseudo),

              const SizedBox(height: 32),

              // Classement complet
              if (scores.length > 3) ...[
                Text(
                  'Classement complet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: scores.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final player = scores[index];
                      final isMe = player.pseudo == state.pseudo;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.surfaceVariant,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          player.pseudo,
                          style: TextStyle(
                            fontWeight:
                                isMe ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: Text(
                          '${player.score} pts',
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
                    },
                  ),
                ),
              ] else
                const Spacer(),

              // Bouton retour
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(gameProvider.notifier).reset(),
                icon: const Icon(Icons.home_rounded),
                label: const Text(
                  "Retour à l'accueil",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PodiumWidget extends StatelessWidget {
  final List<FinalScore> scores;
  final String myPseudo;

  const _PodiumWidget({required this.scores, required this.myPseudo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Positions podium : 2ème | 1er | 3ème
    final podium = <({FinalScore score, int rank, double height, Color color})>[
      if (scores.length >= 2)
        (
          score: scores[1],
          rank: 2,
          height: 80,
          color: Colors.grey.shade400,
        ),
      (
        score: scores[0],
        rank: 1,
        height: 110,
        color: Colors.amber,
      ),
      if (scores.length >= 3)
        (
          score: scores[2],
          rank: 3,
          height: 60,
          color: Colors.brown.shade300,
        ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: podium.map((entry) {
        final isMe = entry.score.pseudo == myPseudo;
        return Expanded(
          child: Column(
            children: [
              Text(
                entry.score.pseudo,
                style: TextStyle(
                  fontWeight:
                      isMe ? FontWeight.bold : FontWeight.normal,
                  color: isMe
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${entry.score.score} pts',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: entry.height,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: entry.color,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
                child: Center(
                  child: Text(
                    '${entry.rank}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}