import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/config/api.dart';
import 'package:flutter_application_1/config/paleta_colores.dart' as pal;
import 'package:flutter_application_1/widgets/barra_nav_inferior.dart';
import 'package:flutter_application_1/widgets/barra_nav_superior.dart';
import 'package:http/http.dart' as http;

import '../Turnos/reservar_turno.dart';

class Especialidad {
  final int id;
  final String nombre;
  const Especialidad({required this.id, required this.nombre});

  factory Especialidad.fromJson(Map<String, dynamic> j) =>
      Especialidad(id: j['id'] as int, nombre: j['nombre'] as String);
}

class Profesional {
  final int id;
  final String nombre;
  final int idEspecialidad;
  final String? avatarUrl;
  final String? subhead; // matrícula, etc.
  final String? especialidadNombre; // viene del backend

  const Profesional({
    required this.id,
    required this.nombre,
    required this.idEspecialidad,
    this.avatarUrl,
    this.subhead,
    this.especialidadNombre,
  });

  factory Profesional.fromJson(Map<String, dynamic> j) => Profesional(
    id: j['id'] as int,
    nombre: j['nombre'] as String,
    idEspecialidad: j['id_especialidad'] as int,
    especialidadNombre: j['especialidad'] != null
        ? (j['especialidad']['nombre'] as String)
        : null,
  );
}

// -------------------- PANTALLA --------------------
class ProfesionaleScreen extends StatefulWidget {
  const ProfesionaleScreen({super.key});
  @override
  State<ProfesionaleScreen> createState() => _ProfesionalesMockScreenState();
}

class _ProfesionalesMockScreenState extends State<ProfesionaleScreen> {
  final _searchCtrl = TextEditingController();
  final GlobalKey _filterKey = GlobalKey();
  Timer? _debounce;

  int _bottomIndex = 0;

  List<Especialidad> _especialidades = const [];
  List<Profesional> _items = const [];
  List<Profesional> _itemsAll = const [];

  Especialidad? _filtro; // especialidad elegida
  bool _loading = false;

  // Mapa para resolver nombre de especialidad
  late Map<int, String> _espNombrePorId;

  @override
  void initState() {
    super.initState();
    _espNombrePorId = {};
    _cargarInicial();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarInicial() async {
    setState(() {
      _loading = true;
    });

    try {
      // 1) pedir especialidades al backend
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/especialidades'),
        headers: {'Content-Type': 'application/json'},
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      final list = (json.decode(res.body) as List).cast<Map<String, dynamic>>();
      _especialidades = list
          .map(
            (e) =>
                Especialidad(id: e['id'] as int, nombre: e['nombre'] as String),
          )
          .toList();

      // 2) mapa id = nombre para mostrar en la lista
      _espNombrePorId = {for (final e in _especialidades) e.id: e.nombre};

      // 3) primera carga de profesionales
      await _buscar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cargando datos: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _buscar());
  }

  Future<void> _buscar() async {
    setState(() {
      _loading = true;
    });

    try {
      // 1) pedir profesionales al backend (con filtro por especialidad)
      final q = <String, String>{};
      if (_filtro?.id != null) q['id_especialidad'] = '${_filtro!.id}';

      final res = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/profesionales/',
        ).replace(queryParameters: q),
        headers: {'Content-Type': 'application/json'},
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      final list = (json.decode(res.body) as List).cast<Map<String, dynamic>>();
      final todos = list
          .map(
            (j) => Profesional(
              id: j['id'] as int,
              nombre: j['nombre'] as String,
              idEspecialidad: j['id_especialidad'] as int,
              subhead: null,
              avatarUrl: null,
              especialidadNombre: j['especialidad'] != null
                  ? j['especialidad']['nombre'] as String
                  : null,
            ),
          )
          .toList();

      _itemsAll = todos;

      // 2) filtro de texto local
      final txt = _searchCtrl.text.trim().toLowerCase();
      var data = _itemsAll
          .where((p) => txt.isEmpty || p.nombre.toLowerCase().contains(txt))
          .toList();
      data.sort((a, b) => a.nombre.compareTo(b.nombre));

      setState(() => _items = data);
    } catch (e) {
      setState(() => _items = const []);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error buscando profesionales: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _mostrarMenuEspecialidades() async {
    final RenderBox box =
        _filterKey.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(
        box.localToGlobal(Offset.zero, ancestor: overlay).dx,
        box.localToGlobal(Offset.zero, ancestor: overlay).dy + box.size.height,
        box.size.width,
        0,
      ),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<Especialidad?>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem<Especialidad?>(
          value: null,
          child: Text('Todas las especialidades'),
        ),
        ..._especialidades.map(
          (e) => PopupMenuItem<Especialidad?>(value: e, child: Text(e.nombre)),
        ),
      ],
    );

    if (selected != _filtro) {
      setState(() => _filtro = selected);
      _buscar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pal.fondo,

      // Barra superior
      appBar: CustomTopBar.back(title: 'Profesionales'),

      // Cuerpo
      body: SafeArea(
        child: Column(
          children: [
            // Buscador
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Buscar…',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  prefixIcon: const Icon(Icons.search, color: Colors.black54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.black.withOpacity(.15),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.black.withOpacity(.15),
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: pal.colorAcento, width: 1.4),
                  ),
                ),
              ),
            ),

            // Filtro por especialidad
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                children: [
                  InkWell(
                    key: _filterKey,
                    borderRadius: BorderRadius.circular(22),
                    onTap: _especialidades.isEmpty
                        ? null
                        : _mostrarMenuEspecialidades,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: pal.colorSecundario,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.tune,
                            color: pal.colorAcento,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _filtro?.nombre ?? 'Seleccionar especialidad',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Lista / estados
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                  ? const Center(
                      child: Text(
                        'Sin resultados',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _ProfesionalTile(
                        pro: _items[i],
                        especialidad:
                            _items[i].especialidadNombre ??
                            (_espNombrePorId[_items[i].idEspecialidad] ?? '—'),
                      ),
                    ),
            ),
          ],
        ),
      ),

      // Barra inferior + FAB
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _bottomIndex,
        onDestinationSelected: (i) {
          setState(() => _bottomIndex = i);
          if (i == 0) {
            Navigator.of(context).popUntil((r) => r.isFirst); // Home
          } else {
            Navigator.of(context).maybePop(); // Atrás
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: pal.colorAcento,
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ReservarTurnoWizard()),
          );
        },
        child: const Icon(Icons.calendar_month),
      ),
    );
  }
}

// -------------------- ITEM DE LISTA --------------------
class _ProfesionalTile extends StatelessWidget {
  final Profesional pro;
  final String especialidad;
  const _ProfesionalTile({required this.pro, required this.especialidad});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: pal.colorSecundario,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        // Tile solo visual: deshabilitamos la acción onTap para que no haga nada al pulsar
        onTap: null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: pal.colorAcento.withOpacity(.15),
                backgroundImage: pro.avatarUrl != null
                    ? NetworkImage(pro.avatarUrl!)
                    : null,
                child: pro.avatarUrl == null
                    ? Text(
                        pro.nombre.isNotEmpty
                            ? pro.nombre[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: pal.colorAcento,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pro.nombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pro.subhead ?? especialidad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),

              // Espacio reservado (sin botón de opciones)
              const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}
