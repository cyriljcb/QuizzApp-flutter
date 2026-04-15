import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:quiz/core/constants.dart';
import '../core/signalr_service.dart';
import '../models/question_payload.dart';
import '../models/round_result.dart';

// ─── États ────────────────────────────────────────────────────────────────────

sealed class GameState {}

class IdleState extends GameState {}

class ConnectingState extends GameState {}

class LobbyState extends GameState {
  final String roomCode;
  final String pseudo;
  final List<String> players;
  final bool isHost;

  LobbyState({
    required this.roomCode,
    required this.pseudo,
    required this.players,
    this.isHost = false,
  });

  LobbyState copyWith({List<String>? players}) => LobbyState(
        roomCode: roomCode,
        pseudo: pseudo,
        players: players ?? this.players,
        isHost: isHost,
      );
}

class QuestionState extends GameState {
  final String roomCode;
  final String pseudo;
  final QuestionPayload question;
  final bool hasAnswered;
  final List<String> answeredPlayers;
  final bool isSuddenDeath;

  QuestionState({
    required this.roomCode,
    required this.pseudo,
    required this.question,
    this.hasAnswered = false,
    this.answeredPlayers = const [],
    this.isSuddenDeath = false,
  });

  QuestionState copyWith({
    bool? hasAnswered,
    List<String>? answeredPlayers,
  }) =>
      QuestionState(
        roomCode: roomCode,
        pseudo: pseudo,
        question: question,
        hasAnswered: hasAnswered ?? this.hasAnswered,
        answeredPlayers: answeredPlayers ?? this.answeredPlayers,
        isSuddenDeath: isSuddenDeath,
      );
}

class RoundResultState extends GameState {
  final String roomCode;
  final String pseudo;
  final RoundResult result;

  RoundResultState({
    required this.roomCode,
    required this.pseudo,
    required this.result,
  });
}

class GameOverState extends GameState {
  final String pseudo;
  final List<FinalScore> scores;

  GameOverState({required this.pseudo, required this.scores});
}

class ErrorState extends GameState {
  final String message;
  final GameState? previousState;

  ErrorState({required this.message, this.previousState});
}

class SuddenDeathState extends GameState {
  final String roomCode;
  final String pseudo;
  final List<String> tiedPlayers;

  SuddenDeathState({
    required this.roomCode,
    required this.pseudo,
    required this.tiedPlayers,
  });
}

// ─── Providers ────────────────────────────────────────────────────────────────

final signalRServiceProvider = Provider<SignalRService>((ref) {
  ref.keepAlive();
  final service = SignalRService();
  ref.onDispose(service.disconnect);
  return service;
});

final gameProvider = NotifierProvider<GameNotifier, GameState>(GameNotifier.new);

// ─── Notifier ─────────────────────────────────────────────────────────────────

class GameNotifier extends Notifier<GameState> {
  late SignalRService _signalR;

  @override
  GameState build() {
    _signalR = ref.read(signalRServiceProvider);
    return IdleState();
  }

  // ─── Connexion + callbacks partagés ───────────────────────────────────────

  Future<void> _connectWithCallbacks() async {
    await _signalR.connect(SignalRCallbacks(
      onRoomCreated: (code, pseudo) {
        // L'hôte arrive en lobby avec isHost = true et est seul pour l'instant
        state = LobbyState(
          roomCode: code,
          pseudo: pseudo,
          players: [pseudo],
          isHost: true,
        );
      },
      onRoomJoined: (code, pseudo, players) {
        state = LobbyState(
          roomCode: code,
          pseudo: pseudo,
          players: players,
          isHost: false,
        );
      },
      onPlayerJoined: (p) {
        final current = state;
        if (current is LobbyState) {
          state = current.copyWith(players: [...current.players, p]);
        }
      },
      onPlayerLeft: (p) {
        final current = state;
        if (current is LobbyState) {
          state = current.copyWith(
            players: current.players.where((pl) => pl != p).toList(),
          );
        }
      },
      onGameStarted: (_, __) {},
      onNewQuestion: (data) {
        final roomCode = _extractRoomCode(state);
        final pseudo = _extractPseudo(state);
        if (roomCode == null || pseudo == null) return;

        final isSuddenDeath = state is SuddenDeathState;

        state = QuestionState(
          roomCode: roomCode,
          pseudo: pseudo,
          question: QuestionPayload.fromData(data),
          isSuddenDeath: isSuddenDeath,
        );
      },
      onAnswerReceived: (_) {},
      onPlayerAnswered: (p) {
        final current = state;
        if (current is QuestionState) {
          state = current.copyWith(
            answeredPlayers: [...current.answeredPlayers, p],
          );
        }
      },
      onRoundResult: (data) {
        final roomCode = _extractRoomCode(state);
        final pseudo = _extractPseudo(state);
        if (roomCode == null || pseudo == null) return;
        state = RoundResultState(
          roomCode: roomCode,
          pseudo: pseudo,
          result: RoundResult.fromData(data),
        );
      },
      onGameOver: (scores) {
        state = GameOverState(
          pseudo: _extractPseudo(state) ?? '',
          scores: scores,
        );
      },
      onHostLeft: (message) {
        state = ErrorState(message: message, previousState: state);
      },
      onError: (message) {
        state = ErrorState(message: message, previousState: state);
      },
      onReconnected: () {
        final current = state;
        final roomCode = _extractRoomCode(current);
        final pseudo = _extractPseudo(current);
        if (roomCode == null || pseudo == null) return;
        print('🔄 Reconnexion — rejoin room $roomCode');
        _signalR.rejoinRoom(roomCode, pseudo);
      },
      onSuddenDeath: (tiedPlayers) {
        final roomCode = _extractRoomCode(state);
        final pseudo = _extractPseudo(state);
        if (roomCode == null || pseudo == null) return;
        state = SuddenDeathState(
          roomCode: roomCode,
          pseudo: pseudo,
          tiedPlayers: tiedPlayers,
        );
      },
    ));
  }

  // ─── Actions publiques ────────────────────────────────────────────────────

  /// Crée une room — l'appelant devient l'hôte
  Future<void> createRoom(String pseudo) async {
    state = ConnectingState();
    try {
      await _connectWithCallbacks();
      await _signalR.createRoom(pseudo);
    } catch (e) {
      state = ErrorState(message: 'Connexion impossible : $e');
    }
  }

  /// Rejoint une room existante en tant que joueur
  Future<void> joinRoom(String roomCode, String pseudo) async {
    state = ConnectingState();
    try {
      await _connectWithCallbacks();
      await _signalR.joinRoom(roomCode, pseudo);
    } catch (e) {
      state = ErrorState(message: 'Connexion impossible : $e');
    }
  }
  Future<List<String>> fetchThemes() async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/question/themes')
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.cast<String>();
    } else {
      throw Exception('Erreur chargement thèmes');
    }
  }

  /// Lance la partie (hôte seulement)
  Future<void> startGame({String? theme}) async {
    final current = state;
    if (current is! LobbyState || !current.isHost) return;
    try {
      await _signalR.startGame(current.roomCode, theme: theme);
    } catch (e) {
      print('❌ startGame échoué: $e');
    }
  }

  Future<void> submitAnswer(String answer) async {
    final current = state;
    if (current is! QuestionState || current.hasAnswered) return;

    state = current.copyWith(hasAnswered: true);

    try {
      await _signalR.submitAnswer(current.roomCode, answer);
    } catch (e) {
      print('❌ submitAnswer échoué: $e');
      final currentState = state;
      if (currentState is QuestionState) {
        state = currentState.copyWith(hasAnswered: false);
      }
    }
  }

  Future<void> reset() async {
    await _signalR.disconnect();
    state = IdleState();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String? _extractRoomCode(GameState s) => switch (s) {
        LobbyState s => s.roomCode,
        QuestionState s => s.roomCode,
        RoundResultState s => s.roomCode,
        SuddenDeathState s => s.roomCode,
        _ => null,
      };

  String? _extractPseudo(GameState s) => switch (s) {
        LobbyState s => s.pseudo,
        QuestionState s => s.pseudo,
        RoundResultState s => s.pseudo,
        GameOverState s => s.pseudo,
        SuddenDeathState s => s.pseudo,
        _ => null,
      };
}