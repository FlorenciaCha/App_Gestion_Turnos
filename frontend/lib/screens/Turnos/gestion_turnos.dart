import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/config/paleta_colores.dart' as pal;
import 'package:flutter_application_1/widgets/barra_nav_inferior.dart';
import 'package:http/http.dart' as http;

import '../../config/api.dart';
import '../Turnos/reservar_turno.dart';

class Turno {
  final int id;
  final String especialidad;
  final String profesional;
  final String fecha;
  final String horario;
  final String estado;
  final String? observaciones;
  final DateTime fechaHora; // Para ordenamiento

  Turno({
    required this.id,
    required this.especialidad,
    required this.profesional,
    required this.fecha,
    required this.horario,
    required this.estado,
    required this.fechaHora,
    this.observaciones,
  });

  factory Turno.fromJson(Map<String, dynamic> json) {
    // Parsear fecha y horario originales para ordenamiento
    final fechaOriginal = json['fecha']; // YYYY-MM-DD
    final horarioOriginal = json['horario']; // HH:MM:SS

    DateTime fechaHoraCompleta = DateTime.parse(
      '$fechaOriginal $horarioOriginal',
    );

    // Formatear fecha y horario:

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

    return Turno(
      id: json['id'],
      especialidad:
          json['profesional']?['especialidad']?['nombre'] ?? 'Sin especialidad',
      profesional: json['profesional']?['nombre'] ?? 'Sin asignar',
      fecha: fechaFormateada,
      horario: horarioFormateado,
      estado: json['estado'],
      fechaHora: fechaHoraCompleta,
      observaciones: json['observaciones'],
    );
  }
}

class GestionTurnosScreen extends StatefulWidget {
  const GestionTurnosScreen({super.key});

  @override
  State<GestionTurnosScreen> createState() => _GestionTurnosScreen();
}

class _GestionTurnosScreen extends State<GestionTurnosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  List<Turno> _proximos = [];
  List<Turno> _pasados = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _cargarTurnos();
  }

  /// Cargar turnos desde la base de datos
  Future<void> _cargarTurnos() async {
    setState(() => _loading = true);

    try {
      // Obtener usuario actual de Firebase
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No hay sesión activa')));
        }
        setState(() => _loading = false);
        return;
      }

      final idToken = await user.getIdToken();

      // Consultar turnos del usuario
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/turnos/usuario'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<Turno> todosTurnos = data
            .map((json) => Turno.fromJson(json))
            .toList();

        // Separar en próximos y pasados usando fecha/hora además del estado
        final ahora = DateTime.now();

        // Próximos: estado 'activo' y fechaHora >= ahora
        final proximos = todosTurnos
            .where(
              (t) => t.estado == 'activo' && t.fechaHora.compareTo(ahora) >= 0,
            )
            .toList();

        // Pasados: estado distinto de 'cancelado' y fechaHora < ahora
        final pasados = todosTurnos
            .where(
              (t) =>
                  t.estado != 'cancelado' && t.fechaHora.compareTo(ahora) < 0,
            )
            .toList();

        proximos.sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
        pasados.sort((a, b) => b.fechaHora.compareTo(a.fechaHora));

        setState(() {
          _proximos = proximos;
          _pasados = pasados;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar turnos: ${response.statusCode}'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Cancelar turno en el backend
  Future<bool> _cancelarTurno(int idTurno) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No hay sesión activa')));
        }
        return false;
      }

      final idToken = await user.getIdToken();

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/turnos/$idTurno/cancelar'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cancelar turno: ${response.statusCode}'),
            ),
          );
        }
        return false;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
      }
      return false;
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  int _bottomIndex = 1; // marcar Atrás como activo en esta pantalla

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pal.fondo,

      // AppBar con tabs
      appBar: AppBar(
        backgroundColor: pal.colorPrimario,
        elevation: 0,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Turnos'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: pal.colorSecundario,
            child: TabBar(
              controller: _tabCtrl,
              indicatorColor: pal.colorIndicador,
              labelColor: pal.colorIndicador,
              unselectedLabelColor: pal.colorFuente,
              tabs: const [
                Tab(text: 'Próximos'),
                Tab(text: 'Pasados'),
              ],
            ),
          ),
        ),
      ),

      // Contenido de cada pestaña
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                RefreshIndicator(
                  onRefresh: _cargarTurnos,
                  child: _ListaTurnos(
                    items: _proximos,
                    onTapItem: (t) => _mostrarDetalleProximo(context, t),
                  ),
                ),
                RefreshIndicator(
                  onRefresh: _cargarTurnos,
                  child: _ListaTurnos(
                    items: _pasados,
                    onTapItem: (t) => _mostrarDetallePasado(context, t),
                  ),
                ),
              ],
            ),

      // Bottom nav igual al Home
      /*bottomNavigationBar: Container(
      decoration: BoxDecoration(
        color: pal.colorPrimario,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          height: 68,
          backgroundColor: pal.colorPrimario,
          indicatorColor: Colors.white.withOpacity(0.08),
          selectedIndex: _bottomIndex,
          onDestinationSelected: (i) {
            setState(() => _bottomIndex = i);
            if (i == 0) {
              Navigator.of(context).popUntil((route) => route.isFirst); // Home
            } else {
              Navigator.of(context).maybePop(); // Atrás
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: Colors.white),
              label: '',
            ),
            NavigationDestination(
              icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
              label: '',
            ),
          ],
        ),
      ),
    ),*/
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _bottomIndex,
        onDestinationSelected: (i) {
          setState(() => _bottomIndex = i);
          if (i == 0) {
            // Ir a Home (raíz de la app)
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else {
            // Atrás
            Navigator.of(context).maybePop();
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: pal.colorAcento,
        foregroundColor: Colors.white,
        onPressed: () {
          // Acceso rápido a "Reservar Turno"
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ReservarTurnoWizard()),
          );
        },
        child: const Icon(Icons.calendar_month),
      ),
    );
  }

  // ---------- POPUPS Próximos ----------
  void _mostrarDetalleProximo(BuildContext context, Turno t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: pal.colorSecundario,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header con icono + cerrar
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.calendar_today, color: pal.colorAcento, size: 36),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Datos del turno',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            _DatoLinea(label: 'Especialidad', value: t.especialidad),
            _DatoLinea(label: 'Profesional', value: t.profesional),
            _DatoLinea(label: 'Fecha', value: t.fecha),
            _DatoLinea(label: 'Horario', value: t.horario),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: pal.colorAtencion, // botón rojo suave
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // cierra detalle
                  _confirmarCancelacion(context, t);
                },
                child: const Text('Cancelar turno'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarCancelacion(BuildContext context, Turno t) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: pal.colorSecundario,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        title: Row(
          children: const [
            Icon(Icons.error_outline, color: pal.colorAtencion),
            SizedBox(width: 8),
            Expanded(
              child: Text('¿Deseás cancelar este turno?', softWrap: true),
            ),
          ],
        ),
        content: const Text(
          'Si lo cancelás, perderás la reserva de la fecha y el horario seleccionados.',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: pal.colorAcento,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.of(context).pop();

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) =>
                    const Center(child: CircularProgressIndicator()),
              );

              // Cancelar turno en el backend
              final exitoso = await _cancelarTurno(t.id);

              if (mounted) Navigator.of(context).pop();

              if (exitoso) {
                // Recargar turnos
                await _cargarTurnos();
                if (mounted) {
                  _exitoCancelacion(context);
                }
              }
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  void _exitoCancelacion(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: pal.colorSecundario,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Icon(Icons.check_circle_outline, color: pal.colorAcento),
            SizedBox(width: 8),
            Expanded(
              child: Text('Turno cancelado correctamente', softWrap: true),
            ),
          ],
        ),
        content: const Text('Tu turno ha sido cancelado correctamente.'),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: pal.colorAcento,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- POPUP Pasados ----------
  void _mostrarDetallePasado(BuildContext context, Turno t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: pal.colorSecundario,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, color: pal.colorAcento, size: 36),
            const SizedBox(height: 10),
            const Text(
              'Datos del turno',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            _DatoLinea(label: 'Especialidad', value: t.especialidad),
            _DatoLinea(label: 'Profesional', value: t.profesional),
            _DatoLinea(label: 'Fecha', value: t.fecha),
            _DatoLinea(label: 'Horario', value: t.horario),
            if (t.observaciones != null) ...[
              const SizedBox(height: 8),
              _DatoLinea(
                label: 'Observaciones médicas',
                value: t.observaciones!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ====== Lista y Card reutilizable ======
class _ListaTurnos extends StatelessWidget {
  final List<Turno> items;
  final void Function(Turno) onTapItem;

  const _ListaTurnos({required this.items, required this.onTapItem});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No hay turnos para mostrar',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final t = items[i];
        return Material(
          color: pal.colorSecundario,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onTapItem(t),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.event_available,
                      color: pal.colorAcento,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.especialidad,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${t.profesional}  •  ${t.fecha}  •  ${t.horario}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.black45),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ====== Fila de dato  ======
class _DatoLinea extends StatelessWidget {
  final String label;
  final String value;

  const _DatoLinea({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}
