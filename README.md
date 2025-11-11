Aplicación de Gestión de Turnos Médicos
Aplicación que permite a los pacientes reservar turnos médicos , visualizar sus turnos próximos/pasados ​​y recibir recordatorios automáticos .
Incluye autenticación, gestión de horarios disponibles, filtrados por especialidad/profesional y notificaciones push.

Tecnologías principales
Frontend: Flutter
Backend: FastAPI (Python)
Base de datos: PostgreSQL
Autenticación: Firebase Auth
Notificaciones: Firebase Cloud Messaging
Infraestructura: Render + GitHub + GitHub Actions
Arquitectura
App_Gestion_Turnos 
├── .github/ 
      └── workflows/ 
          └── recordatorios.yml 
├── backend/ 
    └── app/ 
        ├── main.py  
        ├── database.py 
        ├── crud.py 
        ├── firebase.py  
        ├── deps.py 
        ├── models.py  
        ├── schemas.py  
      └──routers/
        ├── turnos.py 
        └── profesionales.py 
        ├── recordatorios.py 
        ├──notifications.py 
      ├── requirements.txt 
      └── .env 
└── frontend/ 
      ├── lib/ 
      ├── android/ 
      ├── ios/ 
      └── pubspec.yaml

Autenticación
Iniciar sesión / Registrarse mediante autenticación de Firebase
El frontend obtiene un idToken
Este token se envía al backend en cada solicitud: Autorización: Bearer
El backend lo valida confirebase_admin
Notificaciones push
Se registra un token FCM por usuario
El backend puede enviar notificaciones
Recordatorios 24 h antes del turno
Base de datos
Tablas principales:

usuarios
profesionales
especialidades
turnos
Flujo de uso
El usuario inicia sesión con Firebase
Se registra el token del dispositivo
Selecciona especialidades y profesionales
Consulta los horarios disponibles
Reservar turno
Recibe recordatorios/avisos
