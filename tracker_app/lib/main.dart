import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

const String NGROK_URL = "tectricial-leon-unhurryingly.ngrok-free.dev";

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Geo Tracker App',
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _currentPosition;
  final MapController _mapController = MapController();
  LatLng? _otherUserPosition;
  late IO.Socket socket;
  // Ya no necesitamos la variable _lastUpdateTime
  bool _isConnected = false;

  void _fitMapToBounds() {
    if (_currentPosition == null || _otherUserPosition == null) return;
    final bounds = LatLngBounds(_currentPosition!, _otherUserPosition!);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50.0)),
    );
  }

  void _connectToSocket() {
    socket = IO.io('https://$NGROK_URL', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'extraHeaders': {'ngrok-skip-browser-warning': 'true'},
    });

    socket.onConnect((_) {
      print('¡Conectado al servidor de WebSockets!');
      setState(() {
        _isConnected = true;
      });

      // --- ¡CAMBIO CLAVE AQUÍ! ---
      // Solo obtenemos y enviamos la ubicación DESPUÉS de que la conexión es exitosa.
      _getInitialLocation();
    });

    socket.on('new_location', (data) {
      print('Nueva ubicación recibida por WebSocket: $data');
      setState(() {
        _otherUserPosition = LatLng(data['lat'], data['lng']);
      });
      _fitMapToBounds();
    });

    socket.onDisconnect((_) {
      print('Desconectado del servidor');
      setState(() {
        _isConnected = false;
      });
    });
  }

  Future<void> _sendLocationToServer(Position position) async {
    // Ya no necesitamos el check de _isConnected aquí, porque esta función
    // solo se llama DESPUÉS de que _isConnected es true.

    final url = Uri.parse('https://$NGROK_URL/api/update_location');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'lat': position.latitude,
          'lng': position.longitude,
          'user_id': 'flutter_app_1',
        }),
      );
      if (response.statusCode == 200) {
        print('Ubicación enviada exitosamente.');
      } else {
        print('Error al enviar la ubicación: ${response.statusCode}');
      }
    } catch (e) {
      print('Error de conexión: $e');
    }
  }

  // Esta función ahora solo se ejecuta cuando se lo pedimos
  void _getInitialLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Servicios de ubicación desactivados");
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("Permiso denegado");
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      print("Permiso denegado permanentemente");
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      print(
        "Posición inicial obtenida: ${position.latitude}, ${position.longitude}",
      );

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });

      // Enviamos la posición inicial al servidor
      _sendLocationToServer(position);
    } catch (e) {
      print("Error obteniendo la ubicación: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    // --- ¡CAMBIO CLAVE AQUÍ! ---
    // Ahora solo iniciamos la conexión.
    _connectToSocket();
    // La función _getInitialLocation() se movió a 'onConnect'.
  }

  @override
  void dispose() {
    socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Mapa en Vivo'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: Icon(
              Icons.circle,
              color: _isConnected ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentPosition!,
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.mibastida.geotracker',
                ),
                MarkerLayer(
                  markers: [
                    if (_currentPosition != null)
                      Marker(
                        point: _currentPosition!,
                        width: 80,
                        height: 80,
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.blue,
                          size: 40,
                        ),
                      ),
                    if (_otherUserPosition != null)
                      Marker(
                        point: _otherUserPosition!,
                        width: 80,
                        height: 80,
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.green,
                          size: 60,
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
