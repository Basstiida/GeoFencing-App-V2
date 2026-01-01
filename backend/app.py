from flask import Flask, request, jsonify, render_template
from flask_socketio import SocketIO
from flask_cors import CORS
from shapely.geometry import Point, Polygon

app = Flask(__name__)
CORS(app) 
app.config['SECRET_KEY'] = 'mi_clave_secreta_super_segura!'
socketio = SocketIO(app, cors_allowed_origins="*")

# Geocerca del Zócalo
GEOFENCE_POLYGON = Polygon([
    (-99.1352, 19.4340), 
    (-99.1314, 19.4340), 
    (-99.1314, 19.4315), 
    (-99.1352, 19.4315), 
])

@app.route("/dashboard")
def dashboard():
    return render_template('index.html')

@app.route("/api/update_location", methods=['POST'])
def update_location():
    data = request.get_json()
    print(f"Datos recibidos: {data}")
    
    # --- NUEVA LÓGICA DE ALERTA ---
    try:
        user_location = Point(data['lng'], data['lat'])
        
        if GEOFENCE_POLYGON.contains(user_location):
            print(">>> ¡ALERTA! DENTRO DE LA ZONA")
            # Emitimos un evento específico de alerta
            socketio.emit('geofence_event', {'status': 'DANGER', 'message': '¡DISPOSITIVO DENTRO DE LA GEOCERCA!'})
        else:
            print("...Dispositivo fuera de zona")
            # Emitimos evento de normalidad
            socketio.emit('geofence_event', {'status': 'SAFE', 'message': 'Monitoreo Activo - Zona Segura'})
            
    except Exception as e:
        print(f"Error: {e}")

    # Retransmitimos la ubicación (para mover el pin)
    socketio.emit('new_location', data)
    
    return jsonify({"status": "success"})

if __name__ == "__main__":
    socketio.run(app, host='0.0.0.0', port=5000, debug=True)