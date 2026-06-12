import 'package:tdlib/td_api.dart' as td;

class AnimeSeries {
  final String coreName;
  final List<AnimeSeason> seasons;

  AnimeSeries({required this.coreName, required this.seasons});
}

class AnimeSeason {
  final String fullTitle;
  final String seasonName;
  final td.Message posterMessage; // The Photo message
  final List<td.Message> episodes; // The Video/Document messages

  AnimeSeason({
    required this.fullTitle,
    required this.seasonName,
    required this.posterMessage,
    required this.episodes,
  });
}
