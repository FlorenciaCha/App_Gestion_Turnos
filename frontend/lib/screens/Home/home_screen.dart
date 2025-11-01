import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/config/api.dart';
import 'package:flutter_application_1/config/paleta_colores.dart' as pal;
import 'package:flutter_application_1/navigation.dart';
import 'package:flutter_application_1/widgets/barra_nav_inferior.dart';
import 'package:flutter_application_1/widgets/barra_nav_superior.dart';
import 'package:http/http.dart' as http;

import '../Especialidades/especialidades.dart';
import '../Login/login_screen.dart';
import '../Perfil/perfil.dart';
import '../Profesionales/profesionales.dart';
import '../Turnos/gestion_turnos.dart';
import '../Turnos/misTurnos.dart';
import '../Turnos/reservar_turno.dart';

// Paleta
/*const fondo = Color(0xFFF8FAFC);
const colorPrimario = Color(0xFF86B6F6);
const colorSecundario = Color(0xFFEEF5FF);
const colorAcento = Color(0xFF2C6E7B);
const colorAcento2 = Color(0xFF3A8FA0);
const kFondo = Color(0xFFF8FAFC);
const colorAtencion = Color.fromRGBO(246, 122, 122, 100);*/

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;
  int _notifCount = 3; // demo

  // Próximos turnos (cargados desde el backend)
  List<Appointment> _nextAppointments = [];

  int _bottomIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadNextAppointments();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes so we can refresh when returning to this screen
    final modal = ModalRoute.of(context);
    if (modal != null) {
      routeObserver.subscribe(this, modal);
    }
  }

  @override
  void dispose() {
    // Unsubscribe from route observer
    routeObserver.unsubscribe(this);
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when the top route has been popped and this route shows up again.
    _loadNextAppointments();
  }

  /// Cargar próximos turnos desde el backend (máx 3)
  Future<void> _loadNextAppointments() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/turnos/usuario'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<Appointment> items = data
            .map((json) => Appointment.fromJson(json))
            .toList();

        // Filtrar solo turnos en estado 'activo' y con fechaHora >= ahora
        final ahora = DateTime.now();
        final activos = items
            .where(
              (t) => t.estado == 'activo' && t.fechaHora.compareTo(ahora) >= 0,
            )
            .toList();

        // ordenar de forma descendente (más próximos primero según la instrucción)
        activos.sort((a, b) => a.fechaHora.compareTo(b.fechaHora));

        setState(() {
          _nextAppointments = activos.take(3).toList();
          if (_nextAppointments.isNotEmpty) _currentPage = 0;
        });
      }
    } catch (e) {
      // Silencioso; se puede mejorar mostrando un SnackBar
    }
  }

  // dispose removed since we now override it above

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: pal.fondo,
      /*appBar: AppBar(
        backgroundColor: pal.colorPrimario,
        elevation: 0,
        foregroundColor: pal.fondo,
        titleSpacing: 0,
        leading: PopupMenuButton<String>(
          icon: const Icon(Icons.menu),
          position: PopupMenuPosition.under,           // aparece debajo del botón
          offset: const Offset(0, 8),                  // separacion
          color: pal.colorPrimario,                        // fondo azul como la barra
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          onSelected: (value) async {
            switch (value) {
              case 'mis_turnos':
                // Navigator.push(context, MaterialPageRoute(builder: (_) => const MisTurnosScreen()));
                break;
              case 'historial':
                break;
              case 'especialidades':
                break;
              case 'profesionales':
                break;
              case 'perfil':
                break;
              case 'logout':
        
                await FirebaseAuth.instance.signOut();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: 'mis_turnos',      child: const Text('Mis turnos',        style: TextStyle(color: Colors.white))),
            PopupMenuItem(value: 'historial',       child: const Text('Historial turnos',  style: TextStyle(color: Colors.white))),
            PopupMenuItem(value: 'especialidades',  child: const Text('Especialidades',    style: TextStyle(color: Colors.white))),
            PopupMenuItem(value: 'profesionales',   child: const Text('Profesionales',     style: TextStyle(color: Colors.white))),
            PopupMenuItem(value: 'perfil',          child: const Text('Mi perfil',         style: TextStyle(color: Colors.white))),
            const PopupMenuDivider(),
            PopupMenuItem(value: 'logout',          child: const Text('Cerrar sesión',     style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          ],
        ),
        title: const Text(''),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () {
                  setState(() => _notifCount = 0);
                },
              ),
              if (_notifCount > 0)
                const Positioned(
                  right: 10,
                  top: 10,
                  child: _Badge(count: 3),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),*/
      appBar: CustomTopBar.home(
        title: '',
        notifCount: _notifCount,
        onNotificationsPressed: () => setState(() => _notifCount = 0),

        onMenuSelected: (value) async {
          switch (value) {
            case 'mis_turnos':
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MisTurnosScreen()),
              );
              break;

            case 'historial':
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GestionTurnosScreen()),
              );
              break;

            case 'especialidades':
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EspecialidadesScreen()),
              );
              break;

            case 'profesionales':
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfesionaleScreen()),
              );
              break;

            case 'perfil':
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MiPerfilScreen()),
              );
              break;

            case 'logout':
              // Cerrar sesión  y llevar a Login
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
              break;
          }
        },

        menuBuilder: (context) => const [
          PopupMenuItem(
            value: 'mis_turnos',
            child: Text('Mis turnos', style: TextStyle(color: Colors.white)),
          ),
          PopupMenuItem(
            value: 'historial',
            child: Text(
              'Historial turnos',
              style: TextStyle(color: Colors.white),
            ),
          ),
          PopupMenuItem(
            value: 'especialidades',
            child: Text(
              'Especialidades',
              style: TextStyle(color: Colors.white),
            ),
          ),
          PopupMenuItem(
            value: 'profesionales',
            child: Text('Profesionales', style: TextStyle(color: Colors.white)),
          ),
          PopupMenuItem(
            value: 'perfil',
            child: Text('Mi perfil', style: TextStyle(color: Colors.white)),
          ),
          PopupMenuDivider(),
          PopupMenuItem(
            value: 'logout',
            child: Text(
              'Cerrar sesión',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Image.asset(
                  'assets/logo.png',
                  height: 110,
                  fit: BoxFit.contain,
                ),
              ),

              // Contenedor celeste con carrusel
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                decoration: BoxDecoration(
                  color: pal.colorSecundario,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Próximos turnos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      height: 110,
                      child: Builder(
                        builder: (_) {
                          final upcomingCount = _nextAppointments.length > 3
                              ? 3
                              : _nextAppointments.length;

                          if (upcomingCount == 0) {
                            return const Center(
                              child: Text('No hay turnos próximos'),
                            );
                          }

                          return PageView.builder(
                            controller: _pageCtrl,
                            itemCount: upcomingCount,
                            onPageChanged: (i) =>
                                setState(() => _currentPage = i),
                            itemBuilder: (_, i) =>
                                _AppointmentCard(app: _nextAppointments[i]),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),
                    // Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        (_nextAppointments.length > 3
                            ? 3
                            : _nextAppointments.length),
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == i ? 10 : 8,
                          height: _currentPage == i ? 10 : 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentPage == i
                                ? pal.colorAcento2.withValues(alpha: 0.9)
                                : pal.colorPrimario.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Accesos rápidos (grid 2x2)
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.18,
                ),
                children: [
                  _QuickButton(
                    icon: Icons.person,
                    label: 'Mi Perfil',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MiPerfilScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickButton(
                    icon: Icons.event_note,
                    label: 'Mis Turnos',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MisTurnosScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickButton(
                    icon: Icons.local_hospital,
                    label: 'Especialidades',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EspecialidadesScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickButton(
                    icon: Icons.groups,
                    label: 'Profesionales',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfesionaleScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              SizedBox(height: media.size.height * 0.08),
            ],
          ),
        ),
      ),

      // Bottom nav
      /*bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colorPrimario,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            height: 68,
            backgroundColor: colorPrimario,
            indicatorColor: Colors.white.withValues(alpha: 0.08),
            selectedIndex: _bottomIndex,
            onDestinationSelected: (i) => setState(() => _bottomIndex = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined, color: Colors.white), label: ''),
              NavigationDestination(icon: Icon(Icons.arrow_back_ios_new, color: Colors.white), label: ''),
            ],
          ),
        ),
      ),*/
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _bottomIndex,
        onDestinationSelected: (i) => setState(() => _bottomIndex = i),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: pal.colorAcento,
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReservarTurnoWizard()),
          );
        },
        child: const Icon(Icons.calendar_month),
      ),
    );
  }
}

// ---------------- Widgets de apoyo ----------------

class Appointment {
  final String especialidad;
  final String profesional;
  final String fecha; // presentación: e.g. 12/03/2025 • 09:00
  final DateTime fechaHora; // usado para ordenamiento
  final String estado;

  const Appointment({
    required this.especialidad,
    required this.profesional,
    required this.fecha,
    required this.fechaHora,
    required this.estado,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final fechaOriginal = json['fecha'] ?? '';
    final horarioOriginal = json['horario'] ?? '';

    DateTime fechaHoraCompleta;
    try {
      fechaHoraCompleta = DateTime.parse('$fechaOriginal $horarioOriginal');
    } catch (_) {
      fechaHoraCompleta = DateTime.now();
    }

    String fechaFormateada = fechaOriginal;
    if (fechaFormateada.contains('-')) {
      final partes = fechaFormateada.split('-');
      if (partes.length == 3) {
        fechaFormateada = '${partes[2]}/${partes[1]}/${partes[0]}';
      }
    }

    String horarioFormateado = horarioOriginal;
    if (horarioFormateado.length > 5) {
      horarioFormateado = horarioFormateado.substring(0, 5);
    }

    final especialidad =
        json['profesional']?['especialidad']?['nombre'] ?? 'Sin especialidad';
    final profesional = json['profesional']?['nombre'] ?? 'Sin asignar';

    return Appointment(
      especialidad: especialidad,
      profesional: profesional,
      fecha: '$fechaFormateada  •  $horarioFormateado',
      fechaHora: fechaHoraCompleta,
      estado: json['estado'] ?? 'cancelado',
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment app;
  const _AppointmentCard({required this.app});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: pal.fondo,
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${app.especialidad} • ${app.profesional}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(app.fecha, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: pal.colorSecundario,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: pal.colorAcento),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Badge widget removed (not referenced). If you want notifications badge, re-add it here.
