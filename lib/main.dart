import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/game_provider.dart';
import 'screens/create_room_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/question_screen.dart';
import 'screens/round_result_screen.dart';
import 'screens/game_over_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: QuizApp(),
    ),
  );
}

// ─── Router ───────────────────────────────────────────────────────────────────

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: _GameStateListenable(ref),
    redirect: (context, routerState) {
      final gameState = ref.read(gameProvider);
      return switch (gameState) {
        IdleState()        => '/home',
        ConnectingState()  => '/home',
        LobbyState()       => '/lobby',
        QuestionState()    => '/question',
        RoundResultState() => '/round-result',
        GameOverState()    => '/game-over',
        ErrorState()       => null,
        SuddenDeathState() => null,
      };
    },
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/create-room',
        builder: (context, state) => const CreateRoomScreen(),
      ),
      GoRoute(
        path: '/lobby',
        builder: (context, state) => const LobbyScreen(),
      ),
      GoRoute(
        path: '/question',
        builder: (context, state) {
          final gameState = ref.read(gameProvider);
          final round = gameState is QuestionState
              ? gameState.question.roundNumber
              : 0;
          return QuestionScreen(
            key: ValueKey('question_$round'),
          );
        },
      ),
      GoRoute(
        path: '/round-result',
        builder: (context, state) => const RoundResultScreen(),
      ),
      GoRoute(
        path: '/game-over',
        builder: (context, state) => const GameOverScreen(),
      ),
    ],
  );
});

// ─── Listenable qui notifie go_router quand GameState change ─────────────────

class _GameStateListenable extends ChangeNotifier {
  _GameStateListenable(Ref ref) {
    ref.listen(gameProvider, (_, __) => notifyListeners());
  }
}

// ─── App ──────────────────────────────────────────────────────────────────────

class QuizApp extends ConsumerWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    ref.listen(gameProvider, (previous, next) {
      if (next is ErrorState) {
        final ctx = _rootNavigatorKey.currentContext;
        if (ctx == null) return;
        _showErrorDialog(ctx, next.message, ref);
      }

      if (next is SuddenDeathState) {
        final ctx = _rootNavigatorKey.currentContext;
        if (ctx == null) return;
        _showSuddenDeathDialog(ctx, next.tiedPlayers);
      }

      if (previous is SuddenDeathState && next is QuestionState) {
        final ctx = _rootNavigatorKey.currentContext;
        if (ctx == null) return;
        Navigator.of(ctx, rootNavigator: true).popUntil(
          (route) => route is! DialogRoute,
        );
      }
    });

    return MaterialApp.router(
      title: '100% Logique',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      routerConfig: router,
    );
  }

  void _showErrorDialog(BuildContext context, String message, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Partie terminée'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(gameProvider.notifier).reset();
            },
            child: const Text("Retour à l'accueil"),
          ),
        ],
      ),
    );
  }
  void _showSuddenDeathDialog(BuildContext context, List<String> tiedPlayers) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('⚡ Sudden Death !'),
        content: Text(
          'Égalité entre ${tiedPlayers.join(', ')} !\n\nUne question décisive — le premier à répondre correctement gagne !',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Prêt !'),
          ),
        ],
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1565C0),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      fontFamily: 'Roboto',
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
