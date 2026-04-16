import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/signalr_service.dart';
import '../providers/game_provider.dart';

class GameOverScreen extends ConsumerStatefulWidget {
  const GameOverScreen({super.key});

  @override
  ConsumerState<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends ConsumerState<GameOverScreen>
    with TickerProviderStateMixin {

  // ── Titre ────────────────────────────────────────────────────────────────
  late AnimationController _titleController;
  late Animation<double> _titleScale;
  late Animation<double> _titleOpacity;

  // ── Colonnes podium (montée depuis le bas) ───────────────────────────────
  late AnimationController _podiumController;

  // ── Noms au-dessus des colonnes ──────────────────────────────────────────
  late AnimationController _namesController;

  // ── Classement complet ───────────────────────────────────────────────────
  late AnimationController _listController;

  // ── Bouton retour ────────────────────────────────────────────────────────
  late AnimationController _buttonController;
  late Animation<double> _buttonOpacity;

  @override
  void initState() {
    super.initState();

    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _titleScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.elasticOut),
    );
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _titleController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _podiumController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _namesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _buttonOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeIn),
    );

    _startSequence();
  }

  void _startSequence() async {
    // 1. Titre
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _titleController.forward();

    // 2. Colonnes du podium montent
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _podiumController.forward();

    // 3. Noms apparaissent
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    _namesController.forward();

    // 4. Classement complet
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _listController.forward();

    // 5. Bouton
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _buttonController.forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _podiumController.dispose();
    _namesController.dispose();
    _listController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameProvider);
    if (state is! GameOverState) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scores = state.scores;

    // Groupes par score pour détecter les égalités
    final grouped = _groupByScore(scores);
    final hasTopTie = grouped.isNotEmpty && grouped.first.length > 1;

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

              // ── Titre animé ──────────────────────────────────────────
              AnimatedBuilder(
                animation: _titleController,
                builder: (_, __) => Opacity(
                  opacity: _titleOpacity.value,
                  child: Transform.scale(
                    scale: _titleScale.value,
                    child: Column(
                      children: [
                        Text(
                          hasTopTie ? '🤝 Égalité !' : '🏆 Podium',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (hasTopTie) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Même score au sommet !',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Podium ────────────────────────────────────────────────
              if (scores.isNotEmpty)
                _AnimatedPodium(
                  scores: scores,
                  myPseudo: state.pseudo,
                  podiumController: _podiumController,
                  namesController: _namesController,
                  grouped: grouped,
                ),

              const SizedBox(height: 24),

              // ── Classement complet (si > 3 joueurs) ──────────────────
              if (scores.length > 3) ...[
                AnimatedBuilder(
                  animation: _listController,
                  builder: (_, __) => Opacity(
                    opacity: _listController.value,
                    child: Text(
                      'Classement complet',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _listController,
                    builder: (_, __) {
                      return ListView.separated(
                        itemCount: scores.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final player = scores[index];
                          final isMe = player.pseudo == state.pseudo;
                          final rank = _getRank(grouped, player.pseudo);

                          final itemDelay =
                              index / scores.length;
                          final itemProgress =
                              (_listController.value - itemDelay)
                                  .clamp(0.0, 1.0 - itemDelay) /
                                  (1.0 - itemDelay).clamp(0.01, 1.0);

                          return Opacity(
                            opacity: itemProgress.clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: Offset(
                                  0, 30 * (1 - itemProgress.clamp(0.0, 1.0))),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      theme.colorScheme.surfaceVariant,
                                  child: Text(
                                    '$rank',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(
                                  player.pseudo,
                                  style: TextStyle(
                                    fontWeight: isMe
                                        ? FontWeight.bold
                                        : FontWeight.normal,
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
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ] else
                const Spacer(),

              // ── Bouton retour ─────────────────────────────────────────
              AnimatedBuilder(
                animation: _buttonController,
                builder: (_, __) => Opacity(
                  opacity: _buttonOpacity.value,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        ref.read(gameProvider.notifier).reset(),
                    icon: const Icon(Icons.home_rounded),
                    label: const Text(
                      "Retour à l'accueil",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Regroupe les scores par valeur, triés du plus haut au plus bas.
  List<List<FinalScore>> _groupByScore(List<FinalScore> scores) {
    final groups = <int, List<FinalScore>>{};
    for (final s in scores) {
      groups.putIfAbsent(s.score, () => []).add(s);
    }
    final sorted = groups.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return sorted.map((e) => e.value).toList();
  }

  /// Retourne le rang affiché (ex : égalité → même numéro).
  int _getRank(List<List<FinalScore>> grouped, String pseudo) {
    int rank = 1;
    for (final group in grouped) {
      if (group.any((s) => s.pseudo == pseudo)) return rank;
      rank += group.length;
    }
    return rank;
  }
}

// ─── Podium animé ─────────────────────────────────────────────────────────────

class _AnimatedPodium extends StatelessWidget {
  final List<FinalScore> scores;
  final String myPseudo;
  final AnimationController podiumController;
  final AnimationController namesController;
  final List<List<FinalScore>> grouped;

  const _AnimatedPodium({
    required this.scores,
    required this.myPseudo,
    required this.podiumController,
    required this.namesController,
    required this.grouped,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Construit les entrées podium en tenant compte des égalités
    final entries = _buildPodiumEntries();

    return AnimatedBuilder(
      animation: Listenable.merge([podiumController, namesController]),
      builder: (_, __) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: entries.map((entry) {
            // Chaque colonne monte depuis 0 avec un léger décalage
            final colDelay = entry.podiumPosition == 1
                ? 0.0
                : entry.podiumPosition == 2
                    ? 0.15
                    : 0.3;
            final colProgress =
                ((podiumController.value - colDelay) / (1.0 - colDelay))
                    .clamp(0.0, 1.0);
            final colHeight = entry.barHeight * colProgress;
            final nameOpacity = namesController.value.clamp(0.0, 1.0);
            final isMe = entry.pseudos.contains(myPseudo);

            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Noms (fade in)
                  Opacity(
                    opacity: nameOpacity,
                    child: Column(
                      children: entry.pseudos.map((p) {
                        final isMeThis = p == myPseudo;
                        return Text(
                          p,
                          style: TextStyle(
                            fontWeight: isMeThis
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isMeThis
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Score
                  Opacity(
                    opacity: nameOpacity,
                    child: Text(
                      '${entry.score} pts',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  // Badge égalité si plusieurs pseudos sur la même marche
                  if (entry.pseudos.length > 1)
                    Opacity(
                      opacity: nameOpacity,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Chip(
                          label: const Text('Ex æquo',
                              style: TextStyle(fontSize: 10)),
                          padding: EdgeInsets.zero,
                          backgroundColor:
                              theme.colorScheme.tertiaryContainer,
                          labelStyle: TextStyle(
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Colonne qui monte
                  Container(
                    height: colHeight,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: entry.color,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                      boxShadow: isMe
                          ? [
                              BoxShadow(
                                color: entry.color.withOpacity(0.5),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        entry.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  List<_PodiumEntry> _buildPodiumEntries() {
    // On prend les 3 premières marches (groupes de score)
    final top = grouped.take(3).toList();

    // Définition visuelle : ordre d'affichage 2ème | 1er | 3ème
    const podiumOrder = [2, 1, 3]; // positions visuelles de gauche à droite
    const heights = {1: 110.0, 2: 80.0, 3: 60.0};
    const colors = {
      1: Colors.amber,
      2: Colors.grey,
      3: Colors.brown,
    };
    const labels = {1: '🥇', 2: '🥈', 3: '🥉'};

    final entries = <int, _PodiumEntry>{};

    for (var i = 0; i < top.length; i++) {
      final rank = i + 1;
      entries[rank] = _PodiumEntry(
        podiumPosition: rank,
        pseudos: top[i].map((s) => s.pseudo).toList(),
        score: top[i].first.score,
        barHeight: heights[rank]!,
        color: colors[rank]!,
        label: labels[rank]!,
      );
    }

    // Affichage : 2ème à gauche, 1er au centre, 3ème à droite
    return podiumOrder
        .where((r) => entries.containsKey(r))
        .map((r) => entries[r]!)
        .toList();
  }
}

class _PodiumEntry {
  final int podiumPosition;
  final List<String> pseudos;
  final int score;
  final double barHeight;
  final Color color;
  final String label;

  const _PodiumEntry({
    required this.podiumPosition,
    required this.pseudos,
    required this.score,
    required this.barHeight,
    required this.color,
    required this.label,
  });
}