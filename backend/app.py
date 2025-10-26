from flask import Flask, request, jsonify, render_template
from flask_socketio import SocketIO
from flask_cors import CORS

# 1. Importamos las herramientas de Shapely
from shapely.geometry import Point, Polygon

app = Flask(__name__)
CORS(app) 
app.config['SECRET_KEY'] = 'mi_clave_secreta_super_segura!'
socketio = SocketIO(app, cors_allowed_origins="*")

# 2. Definimos nuestra geocerca (un polígono simple alrededor del Zócalo)
# (longitud, latitud) - ¡OJO! Shapely usa el orden (x, y) que equivale a (lng, lat)
GEOFENCE_POLYGON = Polygon([
    (-99.1352, 19.4340), # Esquina Noroeste
    (-99.1314, 19.4340), # Esquina Noreste
    (-99.1314, 19.4315), # Esquina Sureste
    (-99.1352, 19.4315), # Esquina Suroeste
])


@app.route("/dashboard")
def dashboard():
    return render_template('index.html')

@app.route("/api/update_location", methods=['POST'])
def update_location():
    data = request.get_json()
    print(f"Datos recibidos: {data}")
    
    # 3. Lógica de Geofencing
    try:
        # Creamos un Punto con la ubicación recibida
        user_location = Point(data['lng'], data['lat'])
        
        # Verificamos si el punto está DENTRO del polígono
        if GEOFENCE_POLYGON.contains(user_location):
            print(">>> ¡ALERTA! Dispositivo DENTRO de la geocerca.")
            # Más adelante, aquí emitiremos un socket.io al dashboard
        else:
            print("...Dispositivo FUERA de la geocerca.")
            
    except Exception as e:
        print(f"Error en geofencing: {e}")

    # 4. Retransmitimos la ubicación (esto sigue igual)
    socketio.emit('new_location', data)
    
    return jsonify({"status": "success", "message": "Location received and broadcasted"})

if __name__ == "__main__":
    socketio.run(app, host='0.0.0.0', port=5000, debug=True)