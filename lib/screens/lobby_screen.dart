import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_provider.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  bool _isStarting = false;
  String? _selectedTheme;
  List<String> _themes = [];
  bool _isLoadingThemes = true;

  @override
  void initState() {
    super.initState();
    _loadThemes();
  }

  Future<void> _startGame() async {
    setState(() => _isStarting = true);

    await ref.read(gameProvider.notifier).startGame(
      theme: _selectedTheme,
    );

    if (mounted) setState(() => _isStarting = false);
  }
  Future<void> _loadThemes() async {
  try {
    final themes = await ref.read(gameProvider.notifier).fetchThemes();
    setState(() {
      _themes = themes;
      _selectedTheme = themes.isNotEmpty ? themes.first : null;
      _isLoadingThemes = false;
    });
  } catch (e) {
    setState(() => _isLoadingThemes = false);
  }
}

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameProvider);
    if (state is! LobbyState) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isHost = state.isHost;
    final canStart = state.players.length >= 2;

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
              // ── Code de la room ──────────────────────────────────────
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: state.roomCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Code copié !'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
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
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 14,
                            color: theme.colorScheme.onPrimaryContainer
                                .withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Appuie pour copier',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer
                                  .withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Liste des joueurs ────────────────────────────────────
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
                    // L'hôte est toujours le premier de la liste
                    final isPlayerHost = isHost && index == 0;

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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isPlayerHost)
                            Chip(
                              label: const Text('Hôte'),
                              avatar: const Icon(Icons.star_rounded, size: 16),
                              backgroundColor:
                                  theme.colorScheme.tertiaryContainer,
                              labelStyle: TextStyle(
                                color: theme.colorScheme.onTertiaryContainer,
                                fontSize: 12,
                              ),
                            ),
                          if (isPlayerHost && isMe)
                            const SizedBox(width: 8),
                          if (isMe)
                            Chip(
                              label: const Text('Moi'),
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                            ),
                        ],
                      ),
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

              // ── Bas de page : hôte ou joueur ─────────────────────────
              if (isHost) ...[
                // ── Sélection du thème ─────────────────────────
                if (_isLoadingThemes)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: CircularProgressIndicator(),
                  )
                else if (_themes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thème du quiz',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedTheme,
                          items: _themes
                              .map(
                                (theme) => DropdownMenuItem(
                                  value: theme,
                                  child: Text(theme),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() => _selectedTheme = value);
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!canStart)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Il faut au moins 2 joueurs pour lancer.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: _isStarting
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          onPressed: canStart ? _startGame : null,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text(
                            'Lancer la partie',
                            style: TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            disabledBackgroundColor:
                                theme.colorScheme.surfaceVariant,
                          ),
                        ),
                ),
              ] else ...[
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
            ],
          ),
        ),
      ),
    );
  }
}