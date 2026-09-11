import 'package:flutter_application/church_app/screens/side_drawer/pastor/pastor_model.dart';

class PastorViewState {
  const PastorViewState({
    required this.pastors,
  });

  factory PastorViewState.fromModels({
    required List<Pastor> pastors,
  }) {
    return PastorViewState(
      pastors: List<Pastor>.unmodifiable(pastors),
    );
  }

  final List<Pastor> pastors;

  bool get isEmpty => pastors.isEmpty;
}
