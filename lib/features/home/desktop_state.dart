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
