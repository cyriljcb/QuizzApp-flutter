import 'package:quiz/core/signalr_service.dart';

class QuestionPayload {
  final int roundNumber;
  final int totalRounds;
  final String questionText;
  final String? imageUrl;
  final String type;
  final int durationSeconds;

  const QuestionPayload({
    required this.roundNumber,
    required this.totalRounds,
    required this.questionText,
    this.imageUrl,
    required this.type,
    required this.durationSeconds,
  });

  factory QuestionPayload.fromData(NewQuestionData data) => QuestionPayload(
        roundNumber: data.roundNumber,
        totalRounds: data.totalRounds,
        questionText: data.questionText,
        imageUrl: data.imageUrl,
        type: data.type,
        durationSeconds: data.durationSeconds,
      );
}