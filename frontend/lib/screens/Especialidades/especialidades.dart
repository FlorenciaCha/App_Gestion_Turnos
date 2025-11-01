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

// -------------------- PANTALLA --------------------
class EspecialidadesScreen extends StatefulWidget {
  const EspecialidadesScreen({super.key});

  @override
  State<EspecialidadesScreen> createState() => _EspecialidadesScreenState();
}

class _EspecialidadesScreenState extends State<EspecialidadesScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  int _bottomIndex = 0;

  List<Especialidad> _items = const [];
  List<Especialidad> _itemsAll = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _cargarEspecialidades();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarEspecialidades() async {
    setState(() {
      _loading = true;
    });

    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/especialidades'),
        headers: {'Content-Type': 'application/json'},
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      final list = (json.decode(res.body) as List).cast<Map<String, dynamic>>();
      final todas = list
          .map(
            (j) =>
                Especialidad(id: j['id'] as int, nombre: j['nombre'] as String),
          )
          .toList();

      _itemsAll = todas;
      _aplicarFiltro();
    } catch (e) {
      setState(() => _items = const []);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando especialidades: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _aplicarFiltro(),
    );
  }

  void _aplicarFiltro() {
    final txt = _searchCtrl.text.trim().toLowerCase();
    var data = _itemsAll
        .where((e) => txt.isEmpty || e.nombre.toLowerCase().contains(txt))
        .toList();
    data.sort((a, b) => a.nombre.compareTo(b.nombre));
    setState(() => _items = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pal.fondo,

      // Barra superior
      appBar: CustomTopBar.back(title: 'Especialidades'),

      // Cuerpo
      body: SafeArea(
        child: Column(
          children: [
            // Buscador
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) =>
                          _EspecialidadTile(especialidad: _items[i]),
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
class _EspecialidadTile extends StatelessWidget {
  final Especialidad especialidad;

  const _EspecialidadTile({required this.especialidad});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: pal.colorSecundario,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        // Tile solo visual: deshabilitamos la acción onTap para que no muestre nada
        onTap: null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar/Icono
              CircleAvatar(
                radius: 22,
                backgroundColor: pal.colorAcento.withOpacity(.15),
                child: Icon(
                  Icons.local_hospital,
                  color: pal.colorAcento,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // Texto
              Expanded(
                child: Text(
                  especialidad.nombre,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
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
