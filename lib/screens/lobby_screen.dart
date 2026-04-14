import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_provider.dart';

class LobbyScreen extends ConsumerWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    if (state is! LobbyState) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salle d\'attente'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Code de la room
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'Code de la room',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.roomCode,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                        letterSpacing: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Liste des joueurs
              Row(
                children: [
                  Icon(Icons.group_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Joueurs (${state.players.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: state.players.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final player = state.players[index];
                    final isMe = player == state.pseudo;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isMe
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceVariant,
                        child: Text(
                          player[0].toUpperCase(),
                          style: TextStyle(
                            color: isMe
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        player,
                        style: TextStyle(
                          fontWeight:
                              isMe ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isMe
                          ? Chip(
                              label: const Text('Moi'),
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                            )
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Message d'attente
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'En attente du lancement par l\'hôte...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}