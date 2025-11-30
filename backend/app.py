from flask import Flask, request, jsonify, render_template
from flask_socketio import SocketIO
from flask_cors import CORS
from shapely.geometry import Point, Polygon

app = Flask(__name__)
# Añadimos CORS para permitir conexiones externas de forma explícita
CORS(app) 
app.config['SECRET_KEY'] = 'mi_clave_secreta_super_segura!'
# Inicializamos SocketIO permitiendo cualquier origen
socketio = SocketIO(app, cors_allowed_origins="*")

# Definimos nuestra geocerca (un polígono simple alrededor del Zócalo)
# (longitud, latitud)
GEOFENCE_POLYGON = Polygon([
    (-99.1352, 19.4340), # Esquina Noroeste
    (-99.1314, 19.4340), # Esquina Noreste
    (-99.1314, 19.4315), # Esquina Sureste
    (-99.1352, 19.4315), # Esquina Suroeste
])

@app.route("/dashboard")
def dashboard():
    # Sirve la página web del dashboard
    return render_template('index.html')

@app.route("/api/update_location", methods=['POST'])
def update_location():
    data = request.get_json()
    print(f"Datos recibidos: {data}")
    
    # Lógica de Geofencing
    try:
        user_location = Point(data['lng'], data['lat'])
        if GEOFENCE_POLYGON.contains(user_location):
            print(">>> ¡ALERTA! Dispositivo DENTRO de la geocerca.")
            # Más adelante, emitiremos un evento al dashboard:
            # socketio.emit('geofence_alert', {'status': 'inside', 'user_id': data.get('user_id', 'unknown')})
        else:
            print("...Dispositivo FUERA de la geocerca.")
            # socketio.emit('geofence_alert', {'status': 'outside', 'user_id': data.get('user_id', 'unknown')})
            
    except Exception as e:
        print(f"Error en geofencing: {e}")

    # Retransmitimos la ubicación a todos los clientes conectados por WebSocket
    socketio.emit('new_location', data)
    
    return jsonify({"status": "success", "message": "Location received and broadcasted"})

if __name__ == "__main__":
    # La línea clave: escucha en todas las IPs disponibles en el puerto 5000
    # Flask-SocketIO usará eventlet automáticamente si está instalado
    socketio.run(app, host='0.0.0.0', port=5000, debug=True)