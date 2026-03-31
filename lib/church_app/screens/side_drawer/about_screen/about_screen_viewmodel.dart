import 'package:flutter_application/church_app/models/side_drawer_models/about_model.dart';
import 'package:flutter_application/church_app/providers/side_drawer/about_providers.dart';
import 'package:flutter_application/church_app/screens/side_drawer/about_screen/about_screen_view_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final aboutScreenViewModelProvider = Provider<AboutScreenViewModel>((ref) {
  return const AboutScreenViewModel();
});

final aboutScreenStateProvider =
    Provider<AsyncValue<AboutScreenViewState?>>((ref) {
  final aboutAsync = ref.watch(aboutProvider);
  final viewModel = ref.watch(aboutScreenViewModelProvider);
  return aboutAsync.whenData(viewModel.toViewState);
});

class AboutScreenViewModel {
  const AboutScreenViewModel();

  AboutScreenViewState? toViewState(AboutModel? about) {
    if (about == null) {
      return null;
    }
    return AboutScreenViewState.fromModel(about);
  }
}
