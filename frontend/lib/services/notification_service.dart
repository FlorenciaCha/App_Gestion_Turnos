import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import '../config/api.dart'; // ApiConfig.baseUrl

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Llamar una vez al inicio de la app (en main),
  /// después de Firebase.initializeApp(...)
  static Future<void> initAndRegisterToken() async {
    // 1. Pedir permiso de notificaciones (Android 13+, iOS)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied ||
        settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      print('❌ Notificaciones NO autorizadas');
      return;
    }

    print('✅ Notificaciones autorizadas (${settings.authorizationStatus})');

    // 2. Obtener token FCM del dispositivo
    final token = await _messaging.getToken();
    print('📲 Token FCM inicial: $token');

    // 3. Guardar el token en backend si hay usuario logueado
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && token != null) {
      await _enviarTokenAlBackend(token);
    }

    // 4. Si Firebase cambia el token (por reinstalar app, etc), lo volvemos a subir al backend
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print('♻️ Token FCM actualizado: $newToken');
      final u = FirebaseAuth.instance.currentUser;
      if (u != null) {
        await _enviarTokenAlBackend(newToken);
      }
    });

    // 5. Escuchar mensajes cuando la app está en primer plano (foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 Push en foreground: ${message.notification?.title}');
      // Acá más adelante podés disparar un banner local con flutter_local_notifications
      // si querés que aparezca visualmente incluso en foreground.
    });
  }

  /// Llamar DESPUÉS del login exitoso
  static Future<void> registrarTokenDespuesDeLogin() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _enviarTokenAlBackend(token);
    }
  }

  static Future<void> _enviarTokenAlBackend(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('⚠️ No hay usuario autenticado, no guardo token todavía');
      return;
    }

    // Este es el JWT de Firebase Auth; tu backend lo verifica con get_current_firebase_user
    final idToken = await user.getIdToken();

    final url = Uri.parse('${ApiConfig.baseUrl}/fcm/register-device');

    final body = jsonEncode({
      "token_fcm": token, // tiene que matchear lo que espera tu endpoint FastAPI
    });

    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: body,
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      print('✅ Token FCM guardado en backend');
    } else {
      print('❌ Error guardando token en backend: '
            '${res.statusCode} ${res.body}');
    }
  }
}
