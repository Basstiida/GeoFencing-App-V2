from flask import Flask, request, jsonify
from flask_socketio import SocketIO

app = Flask(__name__)
# Añadimos una clave secreta, necesaria para Socket.IO
app.config['SECRET_KEY'] = 'mi_clave_secreta_super_segura!'
# Inicializamos Socket.IO con nuestra aplicación de Flask
socketio = SocketIO(app, cors_allowed_origins="*")

@app.route("/")
def hola_mundo():
    return "¡Hola, soy tu servidor con WebSockets!"

@app.route("/api/update_location", methods=['POST'])
def update_location():
    data = request.get_json()
    print(f"Datos recibidos: {data}")
    # ¡LA LÍNEA MÁGICA!
    # Emitimos un evento llamado 'new_location' a todos los clientes conectados.
    # El contenido del evento son los datos de ubicación que recibimos.
    socketio.emit('new_location', data)
    
    return jsonify({"status": "success", "message": "Location received and broadcasted"})

if __name__ == "__main__":
    # Ahora usamos socketio para correr la aplicación
    socketio.run(app, debug=True)