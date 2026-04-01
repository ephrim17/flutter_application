import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/app_config_model.dart';
import 'package:flutter_application/church_app/screens/side_drawer/pastor/pastor_model.dart';

class PastorViewState {
  const PastorViewState({
    required this.pastors,
    required this.primaryColor,
    required this.secondaryColor,
  });

  factory PastorViewState.fromModels({
    required List<Pastor> pastors,
    AppConfig? appConfig,
  }) {
    return PastorViewState(
      pastors: List<Pastor>.unmodifiable(pastors),
      primaryColor: (appConfig?.primaryColorHex ?? '#1C1C1C').toColor(),
      secondaryColor: (appConfig?.secondaryColorHex ?? '#5E5E5E').toColor(),
    );
  }

  final List<Pastor> pastors;
  final Color primaryColor;
  final Color secondaryColor;

  bool get isEmpty => pastors.isEmpty;
}
