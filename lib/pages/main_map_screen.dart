import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:recollection_application/core/config.dart';
import 'package:recollection_application/models/contenedor.dart';
import 'package:http/http.dart' as http;
import 'package:recollection_application/models/ruta.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainMapScreen extends StatefulWidget {
  const MainMapScreen({super.key});

  @override
  State<MainMapScreen> createState() => _MainMapScreenState();
}

class _MainMapScreenState extends State<MainMapScreen> {

  final Completer<GoogleMapController> _controller = Completer();
  int? rutaSeleccionadaId;
  List<Ruta> rutasDisponibles = [];
  List<Contenedor> contenedores = [];
  List<Ruta> _rutas = [];
  bool cargando = true;
  String? error;
  LatLng? _currentLocation;
  final LatLng _defaultLocation = LatLng(19.817868351758715, -97.36101510185873);

  @override
  void initState(){
    super.initState();
    cargarContenedores();
    _getCurrentLocation();
    _updateCameraPosition();
  }

  Future<List<Ruta>> cargarRutas() async {

    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString('userId');

      if (id == null || id.isEmpty) {
        throw Exception('ID de usuario no disponible');
      }
    
      final String baseUrl = AppConfig.baseUrl;
      final response = await http.get(Uri.parse('$baseUrl/usuarios/$id/rutas'));
      if(response.statusCode == 200) {
        final List<dynamic> responseData = jsonDecode(response.body);
        return responseData
          .map((json) => Ruta.fromJson(json)).toList();
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        error = 'Los servicios de ubicación están desactivados.';
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          error = 'Los permisos de ubicación fueron denegados';
        });
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      setState(() {
        error = 'Los permisos de ubicación están permanentemente denegados, no podemos solicitar permisos.';
      });
      return;
    }

    try {
      // ignore: deprecated_member_use
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      _updateCameraPosition();
    } catch (e) {
      "Error obteniendo la ubicación: $e";
    }
  }

  Future<void> _updateCameraPosition() async {
    final GoogleMapController controller = await _controller.future;
    final LatLng target = _currentLocation ?? (_rutas.isNotEmpty ? contenedores[0].posicion : _defaultLocation);
    controller.animateCamera(CameraUpdate.newLatLngZoom(target, 15));
  }


  Future<void> cargarContenedores() async {
    try {
      _rutas = await cargarRutas();

      setState(() {
        rutasDisponibles = _rutas;
        rutaSeleccionadaId = _rutas.isNotEmpty ? _rutas[0].id : null;
      });

      if (_rutas.isNotEmpty) {
        final response = await http.get(Uri.parse('${AppConfig.baseUrl}/contenedores'));

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final contenedoresCargados = data.map((json) => Contenedor.fromJson(json)).toList();

          setState(() {
            contenedores = contenedoresCargados;
            cargando = false;
          });

          if (contenedores.isNotEmpty) {
            _moverCamaraALocalizacion();
          }
        } else {
          setState(() {
            error = 'Error al cargar datos: ${response.statusCode}';
            cargando = false;
          });
        }
      } else {
        setState(() {
          contenedores = [];
          cargando = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error de conexión: $e';
        cargando = false;
      });
    }
  }

  Future<void> _moverCamaraALocalizacion() async{
    if (contenedores.isEmpty || rutaSeleccionadaId == null) return;

  final contenedoresFiltrados = contenedores
      .where((c) => c.puntoRecoleccion?.ruta?.id == rutaSeleccionadaId)
      .toList();

  if (contenedoresFiltrados.isEmpty) return;

  final GoogleMapController controller = await _controller.future;
  controller.animateCamera(CameraUpdate.newLatLngZoom(
    contenedoresFiltrados[0].posicion, 14.0)
  );
  }

  Set<Marker> _createMarcadores() {
    Set<Marker> markers = {};
    
    if (_rutas.isNotEmpty) {
      // Añadir marcadores de contenedores
      final filtrados = contenedores
          .where((c) => c.puntoRecoleccion?.ruta?.id == rutaSeleccionadaId)
          .toList();

      markers.addAll(filtrados.map((contenedor) {
        return Marker(
          markerId: MarkerId('contenedor_${contenedor.contenedorId}'),
          position: contenedor.posicion,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            contenedor.estadoRecoleccion ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed
          ),
          infoWindow: InfoWindow(
            title: 'Contenedor ${contenedor.contenedorId}',
            snippet: 'QR: ${contenedor.codigoQR}, Ruta: ${contenedor.puntoRecoleccion?.ruta?.nombre} ''Estado: ${contenedor.estadoRecoleccion ? "Recolectado" : "No recolectado"}',
          ),
        );
      }));
    }

    // Añadir marcador de posición actual si está disponible
    if (_currentLocation != null) {
      markers.add(Marker(
        markerId: MarkerId('current_location'),
        position: _currentLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: 'Tu ubicación actual'),
      ));
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final CameraPosition posicionInicial = CameraPosition(
      target: _currentLocation ??(_rutas.isNotEmpty && contenedores.isNotEmpty ?
      contenedores[0].posicion : _defaultLocation),
      zoom: 14.0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Puntos de recolección'),
        actions: [
          if (_rutas.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: DropdownButton<int>(
                value: rutaSeleccionadaId,
                onChanged: (int? newValue) {
                  setState(() {
                    rutaSeleccionadaId = newValue;
                    _moverCamaraALocalizacion();
                  });
                },
                items: _rutas.map<DropdownMenuItem<int>>((Ruta ruta) {
                  return DropdownMenuItem<int>(
                    value: ruta.id,
                    child: Text(ruta.nombre, style: TextStyle(color: Colors.white)),
                  );
                }).toList(),
                dropdownColor: Theme.of(context).primaryColor,
                underline: Container(),
                icon: Icon(Icons.arrow_drop_down, color: Colors.white),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: posicionInicial,
            markers: _createMarcadores(),
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          if (_rutas.isEmpty)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.red,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'No tienes rutas asignadas. Contacta a tu supervisor.',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 20,
            left: 16,
            child: FloatingActionButton(
              onPressed: () {
                _getCurrentLocation();
                _updateCameraPosition();
              },
              mini: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              child: Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}