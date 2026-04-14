import 'package:signalr_netcore/signalr_client.dart';
import 'constants.dart';

/// Callbacks vers le GameProvider
class SignalRCallbacks {
  final void Function(String roomCode, String pseudo, List<String> players) onRoomJoined;
  final void Function(String pseudo) onPlayerJoined;
  final void Function(String pseudo) onPlayerLeft;
  final void Function(int totalRounds, String? theme) onGameStarted;
  final void Function(NewQuestionData question) onNewQuestion;
  final void Function(String answer) onAnswerReceived;
  final void Function(String pseudo) onPlayerAnswered;
  final void Function(RoundResultData result) onRoundResult;
  final void Function(List<FinalScore> scores) onGameOver;
  final void Function(String message) onHostLeft;
  final void Function(String message) onError;
  final void Function() onReconnected;
  final void Function(List<String> tiedPlayers) onSuddenDeath;

  const SignalRCallbacks({
    required this.onRoomJoined,
    required this.onPlayerJoined,
    required this.onPlayerLeft,
    required this.onGameStarted,
    required this.onNewQuestion,
    required this.onAnswerReceived,
    required this.onPlayerAnswered,
    required this.onRoundResult,
    required this.onGameOver,
    required this.onHostLeft,
    required this.onError,
    required this.onReconnected,
    required this.onSuddenDeath,
  });
}

// ─── DTOs ─────────────────────────────────────────────────────────────────────

class NewQuestionData {
  final int roundNumber;
  final int totalRounds;
  final String questionText;
  final String? imageUrl;
  final String type;
  final int durationSeconds;

  NewQuestionData.fromMap(Map<String, dynamic> map)
      : roundNumber = map['roundNumber'] as int,
        totalRounds = map['totalRounds'] as int,
        questionText = map['questionText'] as String,
        imageUrl = map['imageUrl'] as String?,
        type = map['type'] as String,
        durationSeconds = map['durationSeconds'] as int;
}

class PlayerResultData {
  final String pseudo;
  final bool isCorrect;
  final int score;
  final int scoreGained;

  PlayerResultData.fromMap(Map<String, dynamic> map)
      : pseudo = map['pseudo'] as String,
        isCorrect = map['isCorrect'] as bool,
        score = map['score'] as int,
        scoreGained = map['scoreGained'] as int;
}

class RoundResultData {
  final String correctAnswer;
  final String explanation;
  final bool isLastRound;
  final List<PlayerResultData> playerResults;

  RoundResultData.fromMap(Map<String, dynamic> map)
      : correctAnswer = map['correctAnswer'] as String,
        explanation = map['explanation'] as String,
        isLastRound = map['isLastRound'] as bool,
        playerResults = (map['playerResults'] as List)
            .map((e) => PlayerResultData.fromMap(e as Map<String, dynamic>))
            .toList();
}

class FinalScore {
  final String pseudo;
  final int score;

  FinalScore.fromMap(Map<String, dynamic> map)
      : pseudo = map['pseudo'] as String,
        score = map['score'] as int;
}


// ─── Service ──────────────────────────────────────────────────────────────────

class SignalRService {
  late HubConnection _hub;
  bool _isConnected = false;
  SignalRCallbacks? _callbacks;
  bool _isRejoining = false;

  bool get isConnected => _isConnected;

  Future<void> connect(SignalRCallbacks callbacks) async {
    _callbacks = callbacks;

    _hub = HubConnectionBuilder()
        .withUrl(AppConstants.hubUrl)
        .withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 30000])
        .build();

    _hub.serverTimeoutInMilliseconds = 30000;
    _hub.keepAliveIntervalInMilliseconds = 10000;

    _registerHandlers();

    _hub.onclose(({Exception? error}) {
      _isConnected = false;
      print('🔴 SignalR fermé — erreur: $error');
    });

    _hub.onreconnecting(({Exception? error}) {
      _isConnected = false;
      print('🟡 SignalR reconnexion en cours...');
    });

    _hub.onreconnected(({String? connectionId}) {
      if (_isRejoining) return;
      _isRejoining = true;
      _isConnected = true;
      print('🟢 SignalR reconnecté : $connectionId');
      _callbacks?.onReconnected();
      
      Future.delayed(const Duration(seconds: 3), () {
        _isRejoining = false;
      });
    });

    await _hub.start();
    _isConnected = true;
    print('🟢 SignalR connecté');
  }

  Future<void> disconnect() async {
    await _hub.stop();
    _isConnected = false;
  }

  // ─── CLIENT → SERVEUR ─────────────────────────────────────────────────────

  Future<void> joinRoom(String roomCode, String pseudo) async {
    await _hub.invoke('JoinRoom', args: [roomCode, pseudo]);
  }

  Future<void> submitAnswer(String roomCode, String answer) async {
    await _hub.invoke('SubmitAnswer', args: [roomCode, answer]);
  }
  Future<void> rejoinRoom(String roomCode, String pseudo) async {
    await _hub.invoke('RejoinRoom', args: [roomCode, pseudo]);
  }

  // ─── SERVEUR → CLIENT ─────────────────────────────────────────────────────

  void _registerHandlers() {
    _hub.on('RoomJoined', (args) {
      try {
        if (args == null || _callbacks == null) return;
        final payload = args[0] as Map<String, dynamic>;
        final roomCode = payload['roomCode'] as String;
        final pseudo = payload['pseudo'] as String;
        final players = (payload['players'] as List)
            .map((e) => e as String)
            .toList();
        _callbacks!.onRoomJoined(roomCode, pseudo, players);
      } catch (e) {
        print('❌ RoomJoined error: $e');
      }
    });

    _hub.on('PlayerJoined', (args) {
      try {
        if (args == null || _callbacks == null) return;
        _callbacks!.onPlayerJoined(args[0] as String);
      } catch (e) {
        print('❌ PlayerJoined error: $e');
      }
    });

    _hub.on('PlayerLeft', (args) {
      try {
        if (args == null || _callbacks == null) return;
        _callbacks!.onPlayerLeft(args[0] as String);
      } catch (e) {
        print('❌ PlayerLeft error: $e');
      }
    });

    _hub.on('GameStarted', (args) {
      try {
        if (args == null || _callbacks == null) return;
        final payload = args[0] as Map<String, dynamic>;
        _callbacks!.onGameStarted(
          payload['totalRounds'] as int,
          payload['theme'] as String?,
        );
      } catch (e) {
        print('❌ GameStarted error: $e');
      }
    });

    _hub.on('NewQuestion', (args) {
      try {
        if (args == null || _callbacks == null) return;
        print('📥 NewQuestion reçu: ${args[0]}');
        _callbacks!.onNewQuestion(
          NewQuestionData.fromMap(args[0] as Map<String, dynamic>),
        );
      } catch (e) {
        print('❌ NewQuestion error: $e');
      }
    });

    _hub.on('AnswerReceived', (args) {
      try {
        if (args == null || _callbacks == null) return;
        print('📥 AnswerReceived reçu: ${args[0]}');
        final payload = args[0] as Map<String, dynamic>;
        _callbacks!.onAnswerReceived(payload['answer'] as String);
      } catch (e) {
        print('❌ AnswerReceived error: $e');
      }
    });

    _hub.on('PlayerAnswered', (args) {
      try {
        if (args == null || _callbacks == null) return;
        print('📥 PlayerAnswered reçu: ${args[0]}');
        _callbacks!.onPlayerAnswered(args[0] as String);
      } catch (e) {
        print('❌ PlayerAnswered error: $e');
      }
    });

    _hub.on('RoundResult', (args) {
      try {
        if (args == null || _callbacks == null) return;
        print('📥 RoundResult reçu: ${args[0]}');
        _callbacks!.onRoundResult(
          RoundResultData.fromMap(args[0] as Map<String, dynamic>),
        );
      } catch (e) {
        print('❌ RoundResult error: $e');
      }
    });

    _hub.on('GameOver', (args) {
      try {
        if (args == null || _callbacks == null) return;
        print('📥 GameOver reçu: ${args[0]}');
        final list = (args[0] as List)
            .map((e) => FinalScore.fromMap(e as Map<String, dynamic>))
            .toList();
        _callbacks!.onGameOver(list);
      } catch (e) {
        print('❌ GameOver error: $e');
      }
    });

    _hub.on('HostLeft', (args) {
      try {
        if (args == null || _callbacks == null) return;
        print('📥 HostLeft reçu: ${args[0]}');
        _callbacks!.onHostLeft(args[0] as String);
      } catch (e) {
        print('❌ HostLeft error: $e');
      }
    });

    _hub.on('Error', (args) {
      try {
        if (args == null || _callbacks == null) return;
        print('📥 Error reçu: ${args[0]}');
        _callbacks!.onError(args[0] as String);
      } catch (e) {
        print('❌ Error handler error: $e');
      }
    });

    _hub.onreconnected(({String? connectionId}) {
      _isConnected = true;
      print('🟢 SignalR reconnecté : $connectionId');
      _callbacks?.onReconnected();
    });
    _hub.on('SuddenDeath', (args) {
      try {
        if (args == null || _callbacks == null) return;
        final payload = args[0] as Map<String, dynamic>;
        final tied = (payload['tiedPlayers'] as List)
            .map((e) => e as String)
            .toList();
        _callbacks!.onSuddenDeath(tied);
      } catch (e) {
        print('❌ SuddenDeath error: $e');
      }
    });
  }
}
