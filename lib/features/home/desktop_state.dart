import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;
import '../../models/episode.dart';
import '../../models/anime_models.dart';

class DesktopSelectedSeriesNotifier extends Notifier<AnimeSeries?> {
  @override
  AnimeSeries? build() => null;

  @override
  set state(AnimeSeries? series) {
    super.state = series;
  }
}

final desktopSelectedSeriesProvider = NotifierProvider<DesktopSelectedSeriesNotifier, AnimeSeries?>(DesktopSelectedSeriesNotifier.new);

class DesktopSelectedEpisodeNotifier extends Notifier<Episode?> {
  @override
  Episode? build() => null;

  @override
  set state(Episode? episode) {
    super.state = episode;
  }
}

final desktopSelectedEpisodeProvider = NotifierProvider<DesktopSelectedEpisodeNotifier, Episode?>(DesktopSelectedEpisodeNotifier.new);

class DesktopSelectedSeasonIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  @override
  set state(int index) {
    super.state = index;
  }
}

final desktopSelectedSeasonIndexProvider = NotifierProvider<DesktopSelectedSeasonIndexNotifier, int>(DesktopSelectedSeasonIndexNotifier.new);

class DesktopHighlightMessageIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  @override
  set state(int? id) {
    super.state = id;
  }
}

final desktopHighlightMessageIdProvider = NotifierProvider<DesktopHighlightMessageIdNotifier, int?>(DesktopHighlightMessageIdNotifier.new);
