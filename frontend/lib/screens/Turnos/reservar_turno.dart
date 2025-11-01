import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'misTurnos.dart';
import '../Home/home_screen.dart';
import 'package:flutter_application_1/config/paleta_colores.dart' as pal;
import 'package:flutter_application_1/widgets/barra_nav_inferior.dart';
import '../../config/api.dart';

/*
const colorFondo = Color(0xFFF8FAFC);
const colorPrimario = Color(0xFF86B6F6);
const colorAcento = Color(0xFF2C6E7B);*/

// Horarios disponibles
const _horariosBase = <String>[
  '08:00','08:30','09:00','09:30','10:00','10:30','11:00','11:30',
  '12:00','14:00','14:30','15:00','15:30',
  '16:00','16:30','17:00','17:30'
];

// Modelos para especialidades y profesionales
class Especialidad {
  final int id;
  final String nombre;

  Especialidad({required this.id, required this.nombre});

  factory Especialidad.fromJson(Map<String, dynamic> json) {
    return Especialidad(
      id: json['id'],
      nombre: json['nombre'],
    );
  }
}

class Profesional {
  final int id;
  final String nombre;
  final int idEspecialidad;

  Profesional({required this.id, required this.nombre, required this.idEspecialidad});

  factory Profesional.fromJson(Map<String, dynamic> json) {
    return Profesional(
      id: json['id'],
      nombre: json['nombre'],
      idEspecialidad: json['id_especialidad'],
    );
  }
}

InputDecoration _inputDecoration({required String hint, required IconData prefix}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    prefixIcon: Icon(prefix, color: pal.colorAcento),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.black.withOpacity(.25)),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: pal.colorAcento, width: 1.4),
    ),
  );
}

class ReservarTurnoWizard extends StatefulWidget {
  const ReservarTurnoWizard({super.key});
  @override
  State<ReservarTurnoWizard> createState() => _ReservarTurnoWizardState();
}

class _ReservarTurnoWizardState extends State<ReservarTurnoWizard> {
  final _page = PageController();

  // Estado del flujo
  int? _idEspecialidad;
  int? _idProfesional; // null = "Cualquiera"
  DateTime? _fecha;
  String? _horario;
  bool _recordatorio24h = false;

  // Datos de la DB
  List<Especialidad> _especialidades = [];
  List<Profesional> _profesionales = [];
  List<String> _horariosDisponibles = [];
  bool _loadingEspecialidades = false;
  bool _loadingProfesionales = false;
  bool _loadingHorarios = false;

  // Habilitaciones
  bool get _okStep0 => _idEspecialidad != null && _profesionales.isNotEmpty; // Requiere especialidad Y que tenga profesionales
  bool get _okStep1 => _fecha != null && _horario != null;

  // Bottom nav (home / back)
  int _bottomIndex = 1;

  @override
  void initState() {
    super.initState();
    _cargarEspecialidades();
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  /// Cargar especialidades desde la base de datos
  Future<void> _cargarEspecialidades() async {
    setState(() => _loadingEspecialidades = true);

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/especialidades/'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _especialidades = data.map((json) => Especialidad.fromJson(json)).toList();
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al cargar especialidades')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de conexión: $e')),
        );
      }
    } finally {
      setState(() => _loadingEspecialidades = false);
    }
  }

  /// Cargar profesionales filtrados por especialidad
  Future<void> _cargarProfesionales(int idEspecialidad) async {
    setState(() => _loadingProfesionales = true);

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/profesionales/?id_especialidad=$idEspecialidad'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _profesionales = data.map((json) => Profesional.fromJson(json)).toList();
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al cargar profesionales')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de conexión: $e')),
        );
      }
    } finally {
      setState(() => _loadingProfesionales = false);
    }
  }

  /// Cargar horarios disponibles según fecha, especialidad y profesional
  Future<void> _cargarHorariosDisponibles() async {
    if (_fecha == null || _idEspecialidad == null) {
      setState(() => _horariosDisponibles = []);
      return;
    }

    setState(() {
      _loadingHorarios = true;
      _horario = null;
    });

    try {
      final fechaStr = '${_fecha!.year}-${_fecha!.month.toString().padLeft(2, '0')}-${_fecha!.day.toString().padLeft(2, '0')}';
      
      // Construir URL con parámetros
      final url = _idProfesional == null
          ? '${ApiConfig.baseUrl}/turnos/horarios-ocupados?fecha=$fechaStr&id_especialidad=$_idEspecialidad'
          : '${ApiConfig.baseUrl}/turnos/horarios-ocupados?fecha=$fechaStr&id_especialidad=$_idEspecialidad&id_profesional=$_idProfesional';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<String> horariosOcupados = List<String>.from(data['horarios_ocupados'] ?? []);
        
        // Filtrar horarios base para mostrar solo disponibles
        setState(() {
          _horariosDisponibles = _horariosBase
              .where((h) => !horariosOcupados.contains(h))
              .toList();
        });

        if (_horariosDisponibles.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay horarios disponibles para esta fecha')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al cargar horarios')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de conexión: $e')),
        );
      }
    } finally {
      setState(() => _loadingHorarios = false);
    }
  }

  /// Seleccionar un profesional disponible al azar para el horario elegido cuando el usuario seleccionó "Cualquiera"
  Future<int?> _seleccionarProfesionalDisponible() async {
    if (_fecha == null || _idEspecialidad == null || _horario == null) {
      return null;
    }

    try {
      final fechaStr = '${_fecha!.year}-${_fecha!.month.toString().padLeft(2, '0')}-${_fecha!.day.toString().padLeft(2, '0')}';
      
      if (_profesionales.isEmpty) {
        await _cargarProfesionales(_idEspecialidad!);
      }

      // Consultar cada profesional para ver quién está disponible en el horario seleccionado
      final List<Profesional> profesionalesDisponibles = [];
      
      for (final profesional in _profesionales) {
        // Consultar si este profesional específico tiene ocupado este horario
        final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/turnos/horarios-ocupados?fecha=$fechaStr&id_especialidad=$_idEspecialidad&id_profesional=${profesional.id}'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final List<String> horariosOcupados = List<String>.from(data['horarios_ocupados'] ?? []);
          
          // Si el horario NO está ocupado para este profesional, está disponible
          if (!horariosOcupados.contains(_horario)) {
            profesionalesDisponibles.add(profesional);
          }
        }
      }

      if (profesionalesDisponibles.isEmpty) {
        return null;
      }

      // Seleccionar uno al azar de los disponibles
      final random = Random();
      final profesionalSeleccionado = profesionalesDisponibles[random.nextInt(profesionalesDisponibles.length)];
      return profesionalSeleccionado.id;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar profesional: $e')),
        );
      }
      return null;
    }
  }

  /// Crear turno en la base de datos
  Future<bool> _crearTurno() async {
    try {
      // Obtener el usuario actual de Firebase
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay sesión activa')),
          );
        }
        return false;
      }

      final idToken = await user.getIdToken();

      // Formatear fecha como YYYY-MM-DD
      final fechaStr = '${_fecha!.year}-${_fecha!.month.toString().padLeft(2, '0')}-${_fecha!.day.toString().padLeft(2, '0')}';

      // Preparar datos del turno
      final turnoData = {
        'fecha': fechaStr,
        'horario': _horario,
        'id_profesional': _idProfesional, 
      };

      // Enviar al backend
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/turnos/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken', 
        },
        body: jsonEncode(turnoData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true; // Turno creado exitosamente
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al crear turno: ${response.statusCode}')),
          );
        }
        return false;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de conexión: $e')),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: pal.fondo,
      appBar: AppBar(
        title: const Text('Reservar turno'),
        backgroundColor: pal.colorPrimario,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),

      body: PageView(
        controller: _page,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // PASO 0: Especialidad + Profesional
          _StepContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _HeaderIcon(),
                const Text('Seleccioná la especialidad',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _loadingEspecialidades
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<int>(
                        initialValue: _idEspecialidad,
                        items: _especialidades
                            .map((e) => DropdownMenuItem(
                                  value: e.id,
                                  child: Text(e.nombre),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _idEspecialidad = val;
                            _idProfesional = null;
                            _profesionales = [];
                          });
                          if (val != null) {
                            _cargarProfesionales(val);
                          }
                        },
                        decoration: _inputDecoration(
                          hint: 'Especialidades',
                          prefix: Icons.medical_services_outlined,
                        ),
                      ),
                const SizedBox(height: 22),
                const Text('Seleccioná un profesional',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _loadingProfesionales
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<int?>(
                        initialValue: _idProfesional,
                        items: _profesionales.isEmpty
                            ? [
                                // Si no hay profesionales, mostrar mensaje
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  enabled: false,
                                  child: Text(
                                    'No hay profesionales disponibles',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ]
                            : [
                                // Opción "Cualquiera" solo si hay profesionales
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Cualquiera'),
                                ),

                                // Profesionales de la especialidad
                                ..._profesionales.map((p) => DropdownMenuItem<int?>(
                                      value: p.id,
                                      child: Text(p.nombre),
                                    )),
                              ],
                        onChanged: _idEspecialidad == null || _profesionales.isEmpty
                            ? null
                            : (val) {
                                setState(() => _idProfesional = val);
                                if (_fecha != null) {
                                  _cargarHorariosDisponibles();
                                }
                              },
                        decoration: _inputDecoration(
                          hint: 'Profesionales',
                          prefix: Icons.person_outline,
                        ),
                        disabledHint: const Text(
                          'No hay profesionales disponibles',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                SizedBox(height: media.size.height * 0.18),
                _PillButtons(
                  anterior: null, // primer paso
                  siguienteEnabled: _okStep0,
                  onSiguiente: () => _go(1),
                ),
              ],
            ),
          ),

          // PASO 1: Fecha + Horario
          _StepContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _HeaderIcon(),
                const Text('Seleccioná una fecha',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  readOnly: true,
                  controller: TextEditingController(
                    text: _fecha == null
                        ? 'MM/DD/YYYY'
                        : '${_fecha!.month.toString().padLeft(2,'0')}/${_fecha!.day.toString().padLeft(2,'0')}/${_fecha!.year}',
                  ),
                  decoration: _inputDecoration(hint: 'MM/DD/YYYY', prefix: Icons.event),
                    onTap: () async {
                    final now = DateTime.now();
                    final tomorrow = now.add(const Duration(days: 1));
                    final picked = await showDatePicker(
                      context: context,
                      // Si no hay fecha seleccionada, mostramos mañana como fecha inicial
                      initialDate: _fecha ?? tomorrow,
                      // Impedir seleccionar hoy o fechas anteriores; solo desde mañana en adelante
                      firstDate: tomorrow,
                      lastDate: DateTime(now.year + 1),
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: pal.colorAcento, onPrimary: Colors.white, onSurface: Colors.black87),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setState(() => _fecha = picked);
                      // Cargar horarios disponibles cuando se selecciona una fecha
                      await _cargarHorariosDisponibles();
                    }
                  },
                ),
                const SizedBox(height: 18),
                const Text('Seleccioná un horario',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _loadingHorarios
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                        initialValue: _horario,
                        menuMaxHeight: 250, // ← Limita la altura del menú (aprox 5 items)
                        items: _horariosDisponibles.isEmpty
                            ? [const DropdownMenuItem(
                                value: null,
                                child: Text('No hay horarios disponibles'),
                              )]
                            : _horariosDisponibles
                                .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                                .toList(),
                        onChanged: _horariosDisponibles.isEmpty
                            ? null
                            : (val) => setState(() => _horario = val),
                        decoration: _inputDecoration(
                          hint: 'Horarios disponibles',
                          prefix: Icons.schedule,
                        ),
                      ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Recordarme 24 hs antes'),
                  value: _recordatorio24h,
                  activeColor: pal.colorAcento,
                  onChanged: (v) => setState(() => _recordatorio24h = v),
                ),
                SizedBox(height: media.size.height * 0.12),
                _PillButtons(
                  anterior: () => _go(0),
                  siguienteEnabled: _okStep1,
                  onSiguiente: () async {
                    // Si el usuario seleccionó "Cualquiera", asignar un profesional disponible
                    if (_idProfesional == null) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );

                      final profesionalId = await _seleccionarProfesionalDisponible();
                      
                      if (mounted) Navigator.of(context).pop();

                      if (profesionalId != null) {
                        setState(() {
                          _idProfesional = profesionalId;
                        });
                        _go(2);
                      } else {
                        // No hay profesionales disponibles en este horario
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No hay profesionales disponibles para este horario'),
                            ),
                          );
                        }
                      }
                    } else {
                      // Ya tiene profesional específico seleccionado
                      _go(2);
                    }
                  },
                ),
              ],
            ),
          ),

          // PASO 2: Resumen
          _StepContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 6),
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.event_available, size: 48, color: pal.colorAcento),
                        const SizedBox(height: 12),
                        const Text('Resumen turno',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 16),
                        _KV('Especialidad', 
                            _especialidades.firstWhere((e) => e.id == _idEspecialidad, 
                                orElse: () => Especialidad(id: 0, nombre: '-')).nombre),
                        _KV('Profesional', 
                            _profesionales.firstWhere((p) => p.id == _idProfesional, 
                                orElse: () => Profesional(id: 0, nombre: '-', idEspecialidad: 0)).nombre),
                        _KV('Fecha', _fecha == null
                            ? '-' : '${_fecha!.day}/${_fecha!.month}/${_fecha!.year}'),
                        _KV('Horario', _horario ?? '-'),
                        if (_recordatorio24h) _KV('Recordatorio', '24 horas antes'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _PillButtons(
                  anterior: () => _go(1),
                  siguienteEnabled: true,
                  onSiguiente: () async {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );

                    // Crear turno en la base de datos
                    final exitoso = await _crearTurno();

                    if (mounted) Navigator.of(context).pop();

                    if (exitoso) {
                      // Si se creó correctamente, ir al paso de éxito
                      _go(3);
                    }
                    // Si falló, el usuario se queda en el resumen con el mensaje de error
                  },
                  textoSiguiente: 'Confirmar',
                ),
              ],
            ),
          ),

          // PASO 3: Éxito
          _StepContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 1,
                  child: const Padding(
                    padding: EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline, color: pal.colorAcento, size: 48),
                        SizedBox(height: 12),
                        Text('Turno reservado exitosamente',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pal.colorAcento,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const MisTurnosScreen()),
                        (r) => r.isFirst,
                      );
                    },
                    child: const Text('Aceptar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // Barra inferior 
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
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const MisTurnosScreen()),
                  (r) => r.isFirst,
                );
              } else {
                Navigator.of(context).maybePop();
              }
            },
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined, color: Colors.white), label: ''),
              NavigationDestination(icon: Icon(Icons.arrow_back_ios_new, color: Colors.white), label: ''),
            ],
          ),
        ),
      ),*/
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _bottomIndex,
        onDestinationSelected: (i) {
        setState(() => _bottomIndex = i);
        if (i == 0) {
        // Ir a Mis Turnos como “Home” de este flujo
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (r) => r.isFirst,
        );
        } else {
          Navigator.of(context).maybePop();
        }
        },
      ),

    );
  }

  void _go(int to) {
    _page.animateToPage(
      to,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }
}

// ---------- Widgets de apoyo ----------
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Icon(Icons.event_available, size: 72, color: pal.colorAcento),
    );
  }
}

class _StepContainer extends StatelessWidget {
  final Widget child;
  const _StepContainer({required this.child});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20, 16, 20, kBottomNavigationBarHeight + 24), 
      child: child,
    );
  }
}

class _PillButtons extends StatelessWidget {
  final VoidCallback? anterior;
  final VoidCallback? onSiguiente;
  final bool siguienteEnabled;
  final String textoSiguiente;
  const _PillButtons({
    required this.anterior,
    required this.siguienteEnabled,
    required this.onSiguiente,
    this.textoSiguiente = 'Siguiente',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        OutlinedButton(
          onPressed: anterior,
          style: OutlinedButton.styleFrom(
            shape: const StadiumBorder(),
            side: BorderSide(color: pal.colorAcento.withOpacity(.7)),
            foregroundColor: pal.colorAcento,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            minimumSize: const Size(140, 44),
          ),
          child: const Text('Anterior'),
        ),
        ElevatedButton(
          onPressed: siguienteEnabled ? onSiguiente : null,
          style: ElevatedButton.styleFrom(
            shape: const StadiumBorder(),
            backgroundColor: pal.colorAcento,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            minimumSize: const Size(140, 44),
          ),
          child: Text(textoSiguiente),
        ),
      ],
    );
  }
}

Widget _KV(String k, String v) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Row(
    children: [
      SizedBox(width: 130, child: Text('$k:', style: const TextStyle(fontWeight: FontWeight.w600))),
      Expanded(child: Text(v)),
    ],
  ),
);
