import 'package:quiz/core/signalr_service.dart';

class PlayerResult {
  final String pseudo;
  final bool isCorrect;
  final int score;
  final int scoreGained;

  const PlayerResult({
    required this.pseudo,
    required this.isCorrect,
    required this.score,
    required this.scoreGained,
  });

  factory PlayerResult.fromData(PlayerResultData data) => PlayerResult(
        pseudo: data.pseudo,
        isCorrect: data.isCorrect,
        score: data.score,
        scoreGained: data.scoreGained,
      );
}