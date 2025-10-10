import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Geo Tracker App', home: MapScreen());
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

  // 8. NUEVA FUNCIÓN para ajustar el mapa a los marcadores
  void _fitMapToBounds() {
    if (_currentPosition == null || _otherUserPosition == null) {
      // No podemos hacer nada si no tenemos ambos puntos
      return;
    }

    // Creamos un "límite" que encierra ambos puntos
    final bounds = LatLngBounds(_currentPosition!, _otherUserPosition!);

    // Le decimos al controlador que ajuste la cámara a esos límites,
    // añadiendo un pequeño padding para que los pines no queden en el borde.
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50.0)),
    );
  }

  void _connectToSocket() {
    socket = IO.io('http://127.0.0.1:5000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket.onConnect((_) {
      print('¡Conectado al servidor de WebSockets!');
    });

    socket.on('new_location', (data) {
      print('Nueva ubicación recibida por WebSocket: $data');
      setState(() {
        _otherUserPosition = LatLng(data['lat'], data['lng']);
      });
      // 9. LLAMAMOS A LA NUEVA FUNCIÓN aquí
      _fitMapToBounds();
    });

    socket.onDisconnect((_) => print('Desconectado del servidor'));
  }

  Future<void> _sendLocationToServer(Position position) async {
    // ...código para enviar ubicación...
  }

  void _getCurrentLocation() async {
    // ...código para obtener ubicación...
    Position position = await Geolocator.getCurrentPosition();
    await _sendLocationToServer(position);

    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _connectToSocket();
  }

  @override
  void dispose() {
    socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Mapa en Vivo')),
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
