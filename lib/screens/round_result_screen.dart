import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_provider.dart';

class RoundResultScreen extends ConsumerWidget {
  const RoundResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              // Bonne réponse
              Container(
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
              const SizedBox(height: 16),

              // Explication
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  result.explanation,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),

              // Résultat personnel
              if (myResult != null)
                Container(
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
                            isCorrect ? 'Bonne réponse !' : 'Mauvaise réponse',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isCorrect
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        isCorrect
                            ? '+${myResult.scoreGained} pts'
                            : '+0 pts',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCorrect
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // Classement
              Row(
                children: [
                  Icon(
                    Icons.leaderboard_rounded,
                    color: theme.colorScheme.primary,
                  ),
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
                child: ListView.separated(
                  itemCount: result.playerResults.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final player = result.playerResults[index];
                    final isMe = player.pseudo == state.pseudo;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: index == 0
                            ? Colors.amber
                            : theme.colorScheme.surfaceVariant,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: index == 0
                                ? Colors.white
                                : theme.colorScheme.onSurfaceVariant,
                          ),
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

              // Message si dernier round
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