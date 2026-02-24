# Turismo Tarija — Guía de Configuración

## Archivos Firebase que debes configurar

### 1. `firestore.rules` → Aplica en Firebase Console
```
Firebase Console → Firestore Database → Reglas → Pegar contenido → Publicar
```

### 2. `firestore.indexes.json` → Aplica con CLI
```bash
firebase deploy --only firestore:indexes
```

## Pasos para ejecutar la app

### Paso 1 — Instalar FlutterFire CLI y configurar
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```
Esto genera automáticamente `lib/firebase_options.dart`.

### Paso 2 — Instalar dependencias
```bash
flutter pub get
```

### Paso 3 — Google Maps API Key

**Android** → `android/app/src/main/AndroidManifest.xml`
Dentro de `<application>`:
```xml
<meta-data
  android:name="com.google.android.geo.API_KEY"
  android:value="TU_GOOGLE_MAPS_API_KEY"/>
```

**iOS** → `ios/Runner/AppDelegate.swift`
```swift
import GoogleMaps
// En application(_:didFinishLaunchingWithOptions:)
GMSServices.provideAPIKey("TU_GOOGLE_MAPS_API_KEY")
```

### Paso 4 — Permisos de ubicación

**Android** → `android/app/src/main/AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

**iOS** → `ios/Runner/Info.plist`
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Necesitamos tu ubicación para mostrar el mapa del hotel.</string>
```

### Paso 5 — Configurar Service Account para FCM HTTP v1

1. Ir a Firebase Console → Configuración del proyecto → Cuentas de servicio
2. Hacer clic en "Generar nueva clave privada" → descarga el JSON
3. Abrir `lib/core/services/notification_service.dart`
4. Reemplazar el contenido de `_serviceAccountJson` con el JSON descargado
5. Reemplazar `TU_FIREBASE_PROJECT_ID` en `lib/core/constants/app_constants.dart`

⚠️ NUNCA subas el JSON del service account a un repositorio público.
   En producción considera cifrar el archivo o cargarlo desde un backend seguro.

### Paso 6 — Crear primer usuario Admin

1. Crear el usuario en Firebase Console → Authentication → Agregar usuario
2. Copiar el UID generado
3. Ir a Firestore → Colección `users` → Agregar documento con ese UID como ID:
```json
{
  "uid": "EL_UID_COPIADO",
  "email": "admin@turismotarija.com",
  "displayName": "Administrador",
  "role": "admin",
  "isActive": true,
  "fcmToken": null,
  "createdAt": (timestamp actual),
  "updatedAt": (timestamp actual),
  "totalReservations": 0
}
```

### Paso 7 — iOS: configurar APNs para notificaciones push

1. Firebase Console → Configuración del proyecto → Cloud Messaging
2. En "Configuración de la app de Apple" subir tu archivo `.p8` de APNs
3. En Xcode → Capabilities → habilitar "Push Notifications" y "Background Modes → Remote notifications"

## Archivos modificados respecto a la versión anterior

| Archivo | Cambio |
|---------|--------|
| `pubspec.yaml` | Eliminado `firebase_storage`, `image_picker`, `cached_network_image`, `flutter_svg`, `shimmer`. Agregado `googleapis_auth`. |
| `firestore.rules` | Eliminadas reglas de Storage. Ajustada escritura de notifications (cliente escribe). |
| `firestore.indexes.json` | Sin cambios estructurales, añadidos índices faltantes. |
| Todos los modelos | Eliminado campo `imageUrls` de `PackageModel`. |
| `notification_service.dart` | Nueva: envía FCM HTTP v1 con JWT de service account (sin Cloud Functions). |
| `firestore_service.dart` | Envío de notificaciones integrado directamente en las operaciones CRUD. |

## Estructura final del proyecto
```
lib/
├── main.dart
├── firebase_options.dart          ← generado por FlutterFire CLI
├── app/
│   ├── app_router.dart
│   └── app_theme.dart
├── core/
│   ├── constants/app_constants.dart
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── package_model.dart
│   │   ├── reservation_model.dart
│   │   └── message_model.dart
│   └── services/
│       ├── auth_service.dart
│       ├── firestore_service.dart
│       └── notification_service.dart
└── features/
    ├── auth/
    │   ├── providers/auth_provider.dart
    │   └── screens/
    │       ├── login_screen.dart
    │       └── register_screen.dart
    ├── public/
    │   ├── providers/public_provider.dart
    │   └── screens/
    │       ├── home_screen.dart
    │       ├── package_detail_screen.dart
    │       ├── create_reservation_screen.dart
    │       └── my_reservations_screen.dart
    ├── hotel/
    │   ├── providers/hotel_provider.dart
    │   └── screens/
    │       ├── hotel_home_screen.dart
    │       ├── create_package_screen.dart
    │       ├── reservation_requests_screen.dart
    │       └── inbox_screen.dart
    └── admin/
        ├── providers/admin_provider.dart
        └── screens/
            ├── admin_home_screen.dart
            └── hotel_detail_screen.dart
```
