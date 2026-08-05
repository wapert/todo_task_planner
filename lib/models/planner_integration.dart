import 'package:flutter/material.dart';

enum IntegrationStatus { notConnected, ready, needsSetup }

class PlannerIntegration {
  const PlannerIntegration({
    required this.name,
    required this.displayName,
    required this.description,
    required this.icon,
    required this.status,
  });

  /// Stable English identifier used for equality checks in code — not shown
  /// to the user. Use [displayName] for UI text.
  final String name;
  final String displayName;
  final String description;
  final IconData icon;
  final IntegrationStatus status;
}
