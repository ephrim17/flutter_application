import 'package:flutter_application/church_app/models/app_config_model.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/screens/side_drawer/pastor/pastor_model.dart';
import 'package:flutter_application/church_app/screens/side_drawer/pastor/pastor_providers.dart';
import 'package:flutter_application/church_app/screens/side_drawer/pastor/pastor_view_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final pastorViewModelProvider = Provider<PastorViewModel>((ref) {
  return const PastorViewModel();
});

final pastorViewStateProvider = Provider<AsyncValue<PastorViewState>>((ref) {
  final pastorsAsync = ref.watch(pastorsProvider);
  final appConfig = ref.watch(appConfigProvider).value;
  final viewModel = ref.read(pastorViewModelProvider);

  if (pastorsAsync.isLoading) {
    return const AsyncLoading();
  }

  if (pastorsAsync.hasError) {
    return AsyncError(
      pastorsAsync.error!,
      pastorsAsync.stackTrace ?? StackTrace.current,
    );
  }

  return pastorsAsync.whenData((pastors) {
    return viewModel.toViewState(
      pastors: pastors,
      appConfig: appConfig,
    );  
  });
});

class PastorViewModel {
  const PastorViewModel();

  PastorViewState toViewState({
    required List<Pastor> pastors,
    AppConfig? appConfig,
  }) {
    return PastorViewState.fromModels(
      pastors: pastors,
      appConfig: appConfig,
    );
  }
}
