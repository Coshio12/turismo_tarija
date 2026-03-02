import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/public_provider.dart';
import '../../../core/models/package_model.dart';
import '../../../core/models/room_model.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  DateTime? _lastBackPress;
  late TabController _tabCtrl;

  // ── Búsqueda habitaciones ──────────────────────────────────────────
  final _roomSearchCtrl = TextEditingController();
  String _roomQuery = '';
  RoomType? _roomTypeFilter = null; // null = todos los tipos
  double? _roomMaxPrice = null; // null = sin límite

  // ── Búsqueda paquetes ──────────────────────────────────────────────
  final _pkgSearchCtrl = TextEditingController();
  String _pkgQuery = '';
  double? _pkgMaxPrice = null;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    final prov = context.read<PublicProvider>();
    prov.listenPackages();
    prov.listenRooms();
    _roomSearchCtrl.addListener(() =>
        setState(() => _roomQuery = _roomSearchCtrl.text.trim().toLowerCase()));
    _pkgSearchCtrl.addListener(() =>
        setState(() => _pkgQuery = _pkgSearchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _roomSearchCtrl.dispose();
    _pkgSearchCtrl.dispose();
    super.dispose();
  }

  // ── Filtros habitaciones ───────────────────────────────────────────
  List<RoomModel> _filteredRooms(List<RoomModel> all) {
    return all.where((r) {
      final matchQuery = _roomQuery.isEmpty ||
          r.roomName.toLowerCase().contains(_roomQuery) ||
          r.hotelName.toLowerCase().contains(_roomQuery) ||
          r.roomType.shortLabel.toLowerCase().contains(_roomQuery);
      final matchType =
          _roomTypeFilter == null || r.roomType == _roomTypeFilter;
      final matchPrice =
          _roomMaxPrice == null || r.pricePerNight <= _roomMaxPrice!;
      return matchQuery && matchType && matchPrice;
    }).toList();
  }

  // ── Filtros paquetes ───────────────────────────────────────────────
  List<PackageModel> _filteredPkgs(List<PackageModel> all) {
    return all.where((p) {
      final matchQuery = _pkgQuery.isEmpty ||
          p.packageName.toLowerCase().contains(_pkgQuery) ||
          p.hotelName.toLowerCase().contains(_pkgQuery);
      final matchPrice =
          _pkgMaxPrice == null || p.pricePerPerson <= _pkgMaxPrice!;
      return matchQuery && matchPrice;
    }).toList();
  }

  void _showRoomFilters() {
    // Snapshot para no leer Provider dentro del builder del sheet
    final rooms = context.read<PublicProvider>().rooms;
    final maxPriceAvailable = rooms.isEmpty
        ? 1000.0
        : rooms.map((r) => r.pricePerNight).reduce((a, b) => a > b ? a : b);

    RoomType? tempType = _roomTypeFilter;
    double? tempPrice = _roomMaxPrice;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('Filtrar hospedaje',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setSheet(() {
                        tempType = null;
                        tempPrice = null;
                      });
                    },
                    child: const Text('Limpiar'),
                  ),
                ]),
                const SizedBox(height: 14),

                // Tipo de habitación
                const Text('Tipo de habitación',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  _FilterChip(
                    label: 'Todos',
                    selected: tempType == null,
                    onTap: () => setSheet(() => tempType = null),
                  ),
                  ...RoomType.values.map((t) => _FilterChip(
                        label: t.shortLabel,
                        selected: tempType == t,
                        onTap: () => setSheet(() => tempType = t),
                      )),
                ]),

                const SizedBox(height: 20),

                // Precio máximo
                Row(children: [
                  const Text('Precio máximo / noche',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    tempPrice == null
                        ? 'Sin límite'
                        : 'Bs ${tempPrice!.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: Color(0xFF2E86C1), fontWeight: FontWeight.bold),
                  ),
                ]),
                Slider(
                  value: tempPrice ?? maxPriceAvailable,
                  min: 0,
                  max: maxPriceAvailable,
                  divisions: 20,
                  activeColor: const Color(0xFF2E86C1),
                  onChanged: (v) => setSheet(
                      () => tempPrice = v >= maxPriceAvailable ? null : v),
                ),

                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _roomTypeFilter = tempType;
                        _roomMaxPrice = tempPrice;
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Aplicar filtros'),
                  ),
                ),
              ]),
        ),
      ),
    );
  }

  void _showPkgFilters() {
    final pkgs = context.read<PublicProvider>().packages;
    final maxPriceAvailable = pkgs.isEmpty
        ? 2000.0
        : pkgs.map((p) => p.pricePerPerson).reduce((a, b) => a > b ? a : b);

    double? tempPrice = _pkgMaxPrice;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('Filtrar paquetes',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setSheet(() => tempPrice = null),
                    child: const Text('Limpiar'),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  const Text('Precio máximo / persona',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    tempPrice == null
                        ? 'Sin límite'
                        : 'Bs ${tempPrice!.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: Color(0xFF1A5276), fontWeight: FontWeight.bold),
                  ),
                ]),
                Slider(
                  value: tempPrice ?? maxPriceAvailable,
                  min: 0,
                  max: maxPriceAvailable,
                  divisions: 20,
                  activeColor: const Color(0xFF1A5276),
                  onChanged: (v) => setSheet(
                      () => tempPrice = v >= maxPriceAvailable ? null : v),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _pkgMaxPrice = tempPrice);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Aplicar filtros'),
                  ),
                ),
              ]),
        ),
      ),
    );
  }

  Future<void> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Presiona de nuevo para salir'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PublicProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _onWillPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'TURISMO TARIJA',
            style: GoogleFonts.bungee(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => context.read<AuthProvider>().logout(),
            ),
          ],
          bottom: TabBar(
            controller: _tabCtrl,
            // Color del texto e icono cuando el Tab está SELECCIONADO
            labelColor: Colors.white,
            // Color del texto e icono cuando el Tab NO está seleccionado
            unselectedLabelColor: Colors.black,
            // Opcional: Color de la línea indicadora debajo del tab
            indicatorColor: Colors.white,
            tabs: const [
              Tab(icon: Icon(Icons.bed_outlined), text: 'Hospedaje'),
              Tab(icon: Icon(Icons.tour_outlined), text: 'Paquetes turísticos'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/home/my-reservations'),
          backgroundColor: const Color(0xFF1A5276),
          icon: const Icon(Icons.bookmark_outlined, color: Colors.white),
          label: const Text(
            'Mis reservas',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            // ── Tab 1: Habitaciones ───────────────────────────────
            _RoomsTab(
              rooms: _filteredRooms(prov.rooms),
              allEmpty: prov.rooms.isEmpty,
              searchCtrl: _roomSearchCtrl,
              activeType: _roomTypeFilter,
              activeMaxPrice: _roomMaxPrice,
              onFilter: _showRoomFilters,
              onClearFilters: () => setState(() {
                _roomTypeFilter = null;
                _roomMaxPrice = null;
                _roomSearchCtrl.clear();
              }),
            ),

            // ── Tab 2: Paquetes turísticos ────────────────────────
            _PackagesTab(
              packages: _filteredPkgs(prov.packages),
              allEmpty: prov.packages.isEmpty,
              searchCtrl: _pkgSearchCtrl,
              activeMaxPrice: _pkgMaxPrice,
              onFilter: _showPkgFilters,
              onClearFilters: () => setState(() {
                _pkgMaxPrice = null;
                _pkgSearchCtrl.clear();
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// TAB WIDGETS CON BUSCADOR
// ══════════════════════════════════════════════════════════════════════

class _RoomsTab extends StatelessWidget {
  final List<RoomModel> rooms;
  final bool allEmpty;
  final TextEditingController searchCtrl;
  final RoomType? activeType;
  final double? activeMaxPrice;
  final VoidCallback onFilter;
  final VoidCallback onClearFilters;

  const _RoomsTab({
    required this.rooms,
    required this.allEmpty,
    required this.searchCtrl,
    required this.activeType,
    required this.activeMaxPrice,
    required this.onFilter,
    required this.onClearFilters,
  });

  bool get _hasActiveFilters => activeType != null || activeMaxPrice != null;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Barra de búsqueda ────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, hotel o tipo...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => searchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Botón de filtros
          Stack(children: [
            IconButton(
              onPressed: onFilter,
              icon: Icon(
                Icons.tune_rounded,
                color:
                    _hasActiveFilters ? const Color(0xFF2E86C1) : Colors.grey,
              ),
              tooltip: 'Filtros',
            ),
            if (_hasActiveFilters)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E86C1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ]),
        ]),
      ),

      // ── Chips de filtros activos ─────────────────────────────────
      if (_hasActiveFilters)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(children: [
            if (activeType != null)
              _ActiveFilterBadge(
                  label: activeType!.shortLabel,
                  color: const Color(0xFF2E86C1)),
            if (activeMaxPrice != null) ...[
              if (activeType != null) const SizedBox(width: 6),
              _ActiveFilterBadge(
                  label: 'Bs ≤ ${activeMaxPrice!.toStringAsFixed(0)}',
                  color: Colors.teal),
            ],
            const Spacer(),
            GestureDetector(
              onTap: onClearFilters,
              child: const Text('Limpiar todo',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      decoration: TextDecoration.underline)),
            ),
          ]),
        ),

      const SizedBox(height: 4),

      // ── Lista ────────────────────────────────────────────────────
      Expanded(
        child: allEmpty
            ? const _EmptyState(
                icon: Icons.bed_outlined,
                message: 'No hay habitaciones disponibles por el momento.')
            : rooms.isEmpty
                ? const _EmptyState(
                    icon: Icons.search_off_outlined,
                    message:
                        'No se encontraron habitaciones con esos criterios.')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: rooms.length,
                    itemBuilder: (_, i) => _RoomCard(room: rooms[i]),
                  ),
      ),
    ]);
  }
}

// ── Tab Paquetes ──────────────────────────────────────────────────────

class _PackagesTab extends StatelessWidget {
  final List<PackageModel> packages;
  final bool allEmpty;
  final TextEditingController searchCtrl;
  final double? activeMaxPrice;
  final VoidCallback onFilter;
  final VoidCallback onClearFilters;

  const _PackagesTab({
    required this.packages,
    required this.allEmpty,
    required this.searchCtrl,
    required this.activeMaxPrice,
    required this.onFilter,
    required this.onClearFilters,
  });

  bool get _hasActiveFilters => activeMaxPrice != null;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Barra de búsqueda ────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o hotel...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => searchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Stack(children: [
            IconButton(
              onPressed: onFilter,
              icon: Icon(
                Icons.tune_rounded,
                color:
                    _hasActiveFilters ? const Color(0xFF1A5276) : Colors.grey,
              ),
              tooltip: 'Filtrar por precio',
            ),
            if (_hasActiveFilters)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A5276),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ]),
        ]),
      ),

      // ── Chips de filtros activos ─────────────────────────────────
      if (_hasActiveFilters)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(children: [
            _ActiveFilterBadge(
                label: 'Bs ≤ ${activeMaxPrice!.toStringAsFixed(0)}/pers.',
                color: const Color(0xFF1A5276)),
            const Spacer(),
            GestureDetector(
              onTap: onClearFilters,
              child: const Text('Limpiar',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      decoration: TextDecoration.underline)),
            ),
          ]),
        ),

      const SizedBox(height: 4),

      // ── Lista ────────────────────────────────────────────────────
      Expanded(
        child: allEmpty
            ? const _EmptyState(
                icon: Icons.tour_outlined,
                message:
                    'No hay paquetes turísticos disponibles por el momento.')
            : packages.isEmpty
                ? const _EmptyState(
                    icon: Icons.search_off_outlined,
                    message: 'No se encontraron paquetes con esos criterios.')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: packages.length,
                    itemBuilder: (_, i) => _PackageCard(package: packages[i]),
                  ),
      ),
    ]);
  }
}

// ── Chip de filtro seleccionable ──────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2E86C1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF2E86C1) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

// ── Badge de filtro activo ────────────────────────────────────────────

class _ActiveFilterBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _ActiveFilterBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)),
        ]),
      );
}

// ── Tarjeta de habitación ─────────────────────────────────────────────
class _RoomCard extends StatelessWidget {
  final RoomModel room;
  const _RoomCard({required this.room});

  IconData _icon(RoomType t) {
    switch (t) {
      case RoomType.single:
        return Icons.single_bed_outlined;
      case RoomType.double_:
        return Icons.bed_outlined;
      case RoomType.matrimonial:
        return Icons.king_bed_outlined;
      case RoomType.suite:
        return Icons.hotel_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // FIX: ruta correcta que coincide con app_router.dart
        onTap: () => context.push('/home/room/${room.roomId}', extra: room),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(_icon(room.roomType),
                    color: const Color(0xFF2E86C1), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(room.hotelName,
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(room.roomType.shortLabel,
                      style: const TextStyle(
                          color: Color(0xFF2E86C1),
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 6),
              Text(room.roomName,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              if (room.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(room.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey)),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Icon(Icons.people_outline,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('Máx. ${room.capacity} pers.',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 13)),
                  ]),
                  Text(
                    'Bs ${room.pricePerNight.toStringAsFixed(0)}/noche',
                    style: const TextStyle(
                      color: Color(0xFF2E86C1),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tarjeta de paquete turístico ──────────────────────────────────────
class _PackageCard extends StatelessWidget {
  final PackageModel package;
  const _PackageCard({required this.package});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(
          '/home/package/${package.packageId}',
          extra: package,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.tour_outlined, color: Colors.teal, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(package.hotelName,
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ),
              ]),
              const SizedBox(height: 6),
              Text(package.packageName,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(package.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: [
                _tag(Icons.bed_outlined, 'Hospedaje incluido'),
                _tag(Icons.tour_outlined, 'Guía turística'),
              ]),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bs ${package.pricePerPerson.toStringAsFixed(0)}/persona',
                    style: const TextStyle(
                      color: Color(0xFF1A5276),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: Colors.teal.shade700),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.teal.shade700,
                  fontWeight: FontWeight.w500)),
        ]),
      );
}
