class SecurityModule {
  final String target;

  SecurityModule({required this.target});

  /// Initialise le module en mémoire vive
  void initModule() {
    // Session temporaire amorcée (aucune persistance sur disque ou BDD)
  }
}