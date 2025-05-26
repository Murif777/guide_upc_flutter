class Constants {
  // API endpoints
  static const String apiConsulta = '/api/ia-navegacion/consulta';
  static const String apiProcessImage = '/api/process-image';
  static const String apiTelegramSend = '/api/telegram/send';
  
  // SharedPreferences keys
  static const String userNameKey = 'userName';
  
  // Special phrases
  static const List<String> cameraKeywords = ['usar cámara', 'abrir cámara', 'tomar foto'];
  static const List<String> helpKeywords = ['ayuda', 'emergencia', 'socorro', 'auxilio'];
  static const List<String> changeNamePatterns = [
    'cambiar nombre', 
    'cambiar mi nombre', 
    'quiero cambiar mi nombre', 
    'modifica mi nombre', 
    'actualiza mi nombre'
  ];
  
  // Response keywords
  static const List<String> responseKeywords = ['}'];
  
  // Messages
  static const String welcomeMessage = 'Bienvenido a guide UPC';
  static const String askNameMessage = 'Bienvenido a guide UPC. ¿Cuál es tu nombre?';
  static const String emptyNameError = 'Por favor ingresa tu nombre';
  static const String emptyQueryError = 'Por favor ingresa tu consulta';
  static const String processingError = 'Error al procesar la consulta.';
  static const String cameraOpeningMessage = 'Abriendo la cámara...';
  static const String helpMessage = 'No te preocupes y manten la calma, la ayuda está en camino a tu ubicación.';
  static const String newNamePrompt = 'Por favor, dime tu nuevo nombre';
  
  // Button labels
  static const String saveButtonLabel = 'Guardar';
  static const String sendButtonLabel = 'Enviar';
  static const String takePictureButtonLabel = 'Tomar Foto';
  static const String openCameraButtonLabel = 'Abrir Cámara';
  
  // Placeholders
  static const String nameInputPlaceholder = 'Escribe tu nombre';
  static const String queryInputPlaceholder = 'Escribe tu consulta';
  
  // Status texts
  static const String listeningText = 'Escuchando...';
  static const String speakingText = 'Hablando...';
  static const String pressToStartText = 'Presiona para iniciar';
  static const String pressToSpeakText = 'Presiona para hablar';
}
