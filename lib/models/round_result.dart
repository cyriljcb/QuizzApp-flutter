import 'player_result.dart';
import '../core/signalr_service.dart';

class RoundResult {
  final String correctAnswer;
  final String explanation;
  final bool isLastRound;
  final List<PlayerResult> playerResults;

  const RoundResult({
    required this.correctAnswer,
    required this.explanation,
    required this.isLastRound,
    required this.playerResults,
  });

  factory RoundResult.fromData(RoundResultData data) => RoundResult(
        correctAnswer: data.correctAnswer,
        explanation: data.explanation,
        isLastRound: data.isLastRound,
        playerResults: data.playerResults
            .map(PlayerResult.fromData)
            .toList(),
      );

  PlayerResult? resultForPlayer(String pseudo) {
    try {
      return playerResults.firstWhere((p) => p.pseudo == pseudo);
    } catch (_) {
      return null;
    }
  }
}