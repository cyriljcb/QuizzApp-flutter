import 'package:signalr_netcore/signalr_client.dart';
import 'constants.dart';

class SignalRCallbacks {
  final void Function(String roomCode, String pseudo, List<String> players)
      onRoomJoined;
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

class SignalRService {
  HubConnection? _hub;
  bool _isConnected = false;
  bool _isRejoining = false;
  SignalRCallbacks? _callbacks;

  bool get isConnected => _isConnected;

  Future<void> connect(SignalRCallbacks callbacks) async {
    if (_hub != null) {
      await disconnect();
    }

    _callbacks = callbacks;

    final hub = HubConnectionBuilder()
        .withUrl(AppConstants.hubUrl)
        .withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 30000])
        .build();

    hub.serverTimeoutInMilliseconds = 30000;
    hub.keepAliveIntervalInMilliseconds = 10000;

    _hub = hub;
    _registerHandlers(hub);

    hub.onclose(({Exception? error}) {
      _isConnected = false;
      print('SignalR closed: $error');
    });

    hub.onreconnecting(({Exception? error}) {
      _isConnected = false;
      print('SignalR reconnecting...');
    });

    hub.onreconnected(({String? connectionId}) {
      if (_isRejoining) return;

      _isRejoining = true;
      _isConnected = true;
      _callbacks?.onReconnected();

      Future.delayed(const Duration(seconds: 3), () {
        _isRejoining = false;
      });
    });

    await hub.start();
    _isConnected = true;
  }

  Future<void> disconnect() async {
    final hub = _hub;
    if (hub == null) return;

    await hub.stop();
    _hub = null;
    _isConnected = false;
    _isRejoining = false;
  }

  Future<void> joinRoom(String roomCode, String pseudo) async {
    await _hub!.invoke('JoinRoom', args: [roomCode, pseudo]);
  }

  Future<void> createRoom(String pseudo) async {
    await _hub!.invoke('CreateRoom', args: [pseudo]);
  }

  Future<void> startGame(
    String roomCode, {
    String? theme,
    required int questionCount,
  }) async {
    await _hub!.invoke('StartGame', args: [roomCode, theme ?? '', questionCount]);
  }

  Future<void> submitAnswer(String roomCode, String answer) async {
    await _hub!.invoke('SubmitAnswer', args: [roomCode, answer]);
  }

  Future<void> rejoinRoom(String roomCode, String pseudo) async {
    await _hub!.invoke('RejoinRoom', args: [roomCode, pseudo]);
  }

  void _registerHandlers(HubConnection hub) {
    hub.on('RoomJoined', (args) {
      try {
        if (args == null || _callbacks == null) return;
        final payload = args[0] as Map<String, dynamic>;
        final roomCode = payload['roomCode'] as String;
        final pseudo = payload['pseudo'] as String;
        final players = (payload['players'] as List).cast<String>();
        _callbacks!.onRoomJoined(roomCode, pseudo, players);
      } catch (e) {
        print('RoomJoined error: $e');
      }
    });

    hub.on('PlayerJoined', (args) {
      try {
        if (args == null || _callbacks == null) return;
        _callbacks!.onPlayerJoined(args[0] as String);
      } catch (e) {
        print('PlayerJoined error: $e');
      }
    });

    hub.on('PlayerLeft', (args) {
      try {
        if (args == null || _callbacks == null) return;
        _callbacks!.onPlayerLeft(args[0] as String);
      } catch (e) {
        print('PlayerLeft error: $e');
      }
    });

    hub.on('GameStarted', (args) {
      try {
        if (args == null || _callbacks == null) return;
        final payload = args[0] as Map<String, dynamic>;
        _callbacks!.onGameStarted(
          payload['totalRounds'] as int,
          payload['theme'] as String?,
        );
      } catch (e) {
        print('GameStarted error: $e');
      }
    });

    hub.on('NewQuestion', (args) {
      try {
        if (args == null || _callbacks == null) return;
        _callbacks!.onNewQuestion(
          NewQuestionData.fromMap(args[0] as Map<String, dynamic>),
        );
      } catch (e) {
        print('NewQuestion error: $e');
      }
    });

    hub.on('AnswerReceived', (args) {
      try {
        if (args == null || _callbacks == null) return;
        final payload = args[0] as Map<String, dynamic>;
        _callbacks!.onAnswerReceived(payload['answer'] as String);
      } catch (e) {
        print('AnswerReceived error: $e');
      }
    });

    hub.on('PlayerAnswered', (args) {
      try {
        if (args == null || _callbacks == null) return;
        _callbacks!.onPlayerAnswered(args[0] as String);
      } catch (e) {
        print('PlayerAnswered error: $e');
      }
    });

    hub.on('RoundResult', (args) {
      try {
        if (args == null || _callbacks == null) return;
        _callbacks!.onRoundResult(
          RoundResultData.fromMap(args[0] as Map<String, dynamic>),
        );
      } catch (e) {
        print('RoundResult error: $e');
      }
    });

    hub.on('GameOver', (args) {
      try {
        if (args == null || _callbacks == null) return;
        final scores = (args[0] as List)
            .map((e) => FinalScore.fromMap(e as Map<String, dynamic>))
            .toList();
        _callbacks!.onGameOver(scores);
      } catch (e) {
        print('GameOver error: $e');
      }
    });

    hub.on('HostLeft', (args) {
      try {
        if (args == null || _callbacks == null) return;
        _callbacks!.onHostLeft(args[0] as String);
      } catch (e) {
        print('HostLeft error: $e');
      }
    });

    hub.on('Error', (args) {
      try {
        if (args == null || _callbacks == null) return;
        _callbacks!.onError(args[0] as String);
      } catch (e) {
        print('Error handler error: $e');
      }
    });

    hub.on('SuddenDeath', (args) {
      try {
        if (args == null || _callbacks == null) return;
        final payload = args[0] as Map<String, dynamic>;
        final tiedPlayers = (payload['tiedPlayers'] as List).cast<String>();
        _callbacks!.onSuddenDeath(tiedPlayers);
      } catch (e) {
        print('SuddenDeath error: $e');
      }
    });
  }
}
