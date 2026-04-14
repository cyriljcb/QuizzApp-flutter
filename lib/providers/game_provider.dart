import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/signalr_service.dart';
import '../models/player_result.dart';
import '../models/question_payload.dart';
import '../models/round_result.dart';

sealed class GameState {}

class IdleState extends GameState {}

class ConnectingState extends GameState {}

class LobbyState extends GameState {
  final String roomCode;
  final String pseudo;
  final List<String> players;
  final bool isHost;
  final String? selectedTheme;
  final int questionCount;

  LobbyState({
    required this.roomCode,
    required this.pseudo,
    required this.players,
    this.isHost = false,
    this.selectedTheme,
    this.questionCount = 10,
  });

  LobbyState copyWith({
    List<String>? players,
    bool? isHost,
    String? selectedTheme,
    bool clearTheme = false,
    int? questionCount,
  }) =>
      LobbyState(
        roomCode: roomCode,
        pseudo: pseudo,
        players: players ?? this.players,
        isHost: isHost ?? this.isHost,
        selectedTheme: clearTheme ? null : selectedTheme ?? this.selectedTheme,
        questionCount: questionCount ?? this.questionCount,
      );
}

class QuestionState extends GameState {
  final String roomCode;
  final String pseudo;
  final QuestionPayload question;
  final bool hasAnswered;
  final List<String> answeredPlayers;
  final bool isSuddenDeath;
  final bool isHost;

  QuestionState({
    required this.roomCode,
    required this.pseudo,
    required this.question,
    this.hasAnswered = false,
    this.answeredPlayers = const [],
    this.isSuddenDeath = false,
    this.isHost = false,
  });

  QuestionState copyWith({
    bool? hasAnswered,
    List<String>? answeredPlayers,
    bool? isSuddenDeath,
  }) =>
      QuestionState(
        roomCode: roomCode,
        pseudo: pseudo,
        question: question,
        hasAnswered: hasAnswered ?? this.hasAnswered,
        answeredPlayers: answeredPlayers ?? this.answeredPlayers,
        isSuddenDeath: isSuddenDeath ?? this.isSuddenDeath,
        isHost: isHost,
      );
}

class RoundResultState extends GameState {
  final String roomCode;
  final String pseudo;
  final RoundResult result;
  final bool isHost;

  RoundResultState({
    required this.roomCode,
    required this.pseudo,
    required this.result,
    this.isHost = false,
  });
}

class GameOverState extends GameState {
  final String pseudo;
  final List<FinalScore> scores;
  final bool isHost;

  GameOverState({
    required this.pseudo,
    required this.scores,
    this.isHost = false,
  });
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
  final bool isHost;

  SuddenDeathState({
    required this.roomCode,
    required this.pseudo,
    required this.tiedPlayers,
    this.isHost = false,
  });
}

final signalRServiceProvider = Provider<SignalRService>((ref) {
  ref.keepAlive();
  final service = SignalRService();
  ref.onDispose(service.disconnect);
  return service;
});

final gameProvider = NotifierProvider<GameNotifier, GameState>(GameNotifier.new);

class GameNotifier extends Notifier<GameState> {
  late SignalRService _signalR;
  bool _isHostSession = false;
  String? _selectedTheme;
  int _questionCount = 10;

  @override
  GameState build() {
    _signalR = ref.read(signalRServiceProvider);
    return IdleState();
  }

  Future<void> joinRoom(String roomCode, String pseudo) async {
    _isHostSession = false;
    state = ConnectingState();

    try {
      await _ensureConnected();
      await _signalR.joinRoom(roomCode, pseudo);
    } catch (e) {
      state = ErrorState(message: 'Connexion impossible : $e');
    }
  }

  Future<void> createRoom(String pseudo) async {
    _isHostSession = true;
    state = ConnectingState();

    try {
      await _ensureConnected();
      await _signalR.createRoom(pseudo);
    } catch (e) {
      state = ErrorState(message: 'Creation impossible : $e');
    }
  }

  void updateHostSettings({
    String? theme,
    int? questionCount,
    bool clearTheme = false,
  }) {
    if (clearTheme) {
      _selectedTheme = null;
    } else if (theme != null) {
      _selectedTheme = theme;
    }

    if (questionCount != null) {
      _questionCount = questionCount;
    }

    final current = state;
    if (current is LobbyState && current.isHost) {
      state = current.copyWith(
        selectedTheme: _selectedTheme,
        clearTheme: clearTheme,
        questionCount: _questionCount,
      );
    }
  }

  Future<void> startGame() async {
    final current = state;
    if (current is! LobbyState || !current.isHost) return;

    try {
      await _signalR.startGame(
        current.roomCode,
        theme: current.selectedTheme,
        questionCount: current.questionCount,
      );
    } catch (e) {
      state = ErrorState(message: 'Impossible de demarrer la partie : $e');
    }
  }

  Future<void> submitAnswer(String answer) async {
    final current = state;
    if (current is! QuestionState || current.hasAnswered) return;

    state = current.copyWith(hasAnswered: true);

    try {
      await _signalR.submitAnswer(current.roomCode, answer);
    } catch (e) {
      final liveState = state;
      if (liveState is QuestionState) {
        state = liveState.copyWith(hasAnswered: false);
      }
    }
  }

  Future<void> reset() async {
    await _signalR.disconnect();
    _isHostSession = false;
    _selectedTheme = null;
    _questionCount = 10;
    state = IdleState();
  }

  Future<void> _ensureConnected() async {
    await _signalR.connect(
      SignalRCallbacks(
        onRoomJoined: (code, p, players) {
          state = LobbyState(
            roomCode: code,
            pseudo: p,
            players: players,
            isHost: _isHostSession,
            selectedTheme: _selectedTheme,
            questionCount: _questionCount,
          );
        },
        onPlayerJoined: (p) {
          final current = state;
          if (current is LobbyState && !current.players.contains(p)) {
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
            isHost: _extractIsHost(state),
          );
        },
        onAnswerReceived: (_) {},
        onPlayerAnswered: (p) {
          final current = state;
          if (current is QuestionState && !current.answeredPlayers.contains(p)) {
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
            isHost: _extractIsHost(state),
          );
        },
        onGameOver: (scores) {
          state = GameOverState(
            pseudo: _extractPseudo(state) ?? '',
            scores: scores,
            isHost: _extractIsHost(state),
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
          if (roomCode == null || pseudo == null || _extractIsHost(current)) {
            return;
          }

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
            isHost: _extractIsHost(state),
          );
        },
      ),
    );
  }

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

  bool _extractIsHost(GameState s) => switch (s) {
        LobbyState s => s.isHost,
        QuestionState s => s.isHost,
        RoundResultState s => s.isHost,
        GameOverState s => s.isHost,
        SuddenDeathState s => s.isHost,
        _ => _isHostSession,
      };
}
