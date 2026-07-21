import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;
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

class DesktopSelectedEpisodeNotifier extends Notifier<td.Message?> {
  @override
  td.Message? build() => null;

  @override
  set state(td.Message? episode) {
    super.state = episode;
  }
}

final desktopSelectedEpisodeProvider = NotifierProvider<DesktopSelectedEpisodeNotifier, td.Message?>(DesktopSelectedEpisodeNotifier.new);

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
