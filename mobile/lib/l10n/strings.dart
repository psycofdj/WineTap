/// Centralized French UI strings. Reference as `S.consumeButton` etc.
/// Replace with AppLocalizations when i18n is needed.
class S {
  S._();

  static const appTitle = 'WineTap';
  static const appSubtitle = 'WineTap Mobile';

  // Scan actions
  static const consumeButton = 'Consommer une bouteille';
  static const identifyButton = 'Identifier une bouteille';
  static const waitingForScan = 'En attente du scan…';
  static const tagRead = 'Tag lu ✓';

  // Consume flow
  static const cancel = 'Annuler';
  static const done = 'Terminé';
  static const markedAsConsumed = 'Marquée comme consommée ✓';

  // Errors
  static const unknownTag = 'Tag inconnu';
  static const tagInUse = 'Tag déjà utilisé';
  static const serverUnreachable = 'Serveur injoignable';
  static const serverUnreachableWithHint =
      'Serveur injoignable\nVérifiez votre connexion WiFi';
  static const timeout = 'Délai dépassé';
  static const noTagDetected = 'Aucun tag détecté';
  static const noTagDetectedWithHint = 'Aucun tag détecté — réessayez';
  static const retryPrompt = 'Réessayez';
  static const alreadyConsumed = 'Bouteille déjà consommée';
  static const databaseError = 'Erreur de base de données';
  static const checkWifi = 'Vérifiez votre connexion WiFi';

  // Intake
  static const intake = 'Prise en charge';
  static const intakeInProgress = 'Ajout en cours — Scannez le tag pour le manager';
  static const waitingForRequest = 'En attente…';
  static const scanRequestReceived = 'En attente du scan…';
  static const tagSentSuccess = 'Tag lu ✓';
  static const scanCancelledRetry = 'Scan annulé — réessayez';

  // Wine colors
  static const colorRouge = 'Rouge';
  static const colorBlanc = 'Blanc';
  static const colorRose = 'Rosé';
  static const colorEffervescent = 'Effervescent';
  static const colorAutre = 'Autre';

  // Settings / server
  static const settings = 'Paramètres';
  static const serverAddress = 'Adresse du serveur';
  static const serverRunning = 'Serveur actif';
  static const intakeUnavailable = 'Prise en charge\nnon disponible';

  // Backup / restore
  static const dataManagement = 'Gestion des données';
  static const exportDatabase = 'Exporter la base';
  static const restoreDatabase = 'Restaurer la base';
  static const restoreConfirmTitle = 'Restaurer la base ?';
  static const restoreConfirmBody =
      'Cela remplacera toutes les données actuelles';
  static const backupSuccess = 'Base exportée avec succès';
  static const restoreSuccess = "Base restaurée — redémarrez l'application";
  static const backupError = "Erreur lors de l'export";
  static const restoreError = 'Erreur lors de la restauration';
}
