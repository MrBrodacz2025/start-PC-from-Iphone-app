import os
import sys
import argparse
from flask import Flask, request, jsonify

app = Flask(__name__)

# token powinien być podany w argumencie --token lub zmiennej środowiskowej PC_TOKEN
TOKEN = os.getenv('PC_TOKEN')
if not TOKEN:
    print('Error: token not set (PC_TOKEN env variable)')
    sys.exit(1)


@app.route('/status', methods=['GET'])
def status():
    auth = request.headers.get('X-Auth-Token')
    if auth != TOKEN:
        return jsonify({'error': 'unauthorized'}), 401
    return jsonify({'status': 'online'})


@app.route('/shutdown', methods=['POST'])
def shutdown():
    auth = request.headers.get('X-Auth-Token')
    if auth != TOKEN:
        return jsonify({'error': 'unauthorized'}), 401
    # wywołujemy systemowy shutdown
    os.system('shutdown /s /t 0')
    return jsonify({'result': 'shutting down'})


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Simple PC control server')
    parser.add_argument('--host', default='0.0.0.0', help='Interface to bind')
    parser.add_argument('--port', type=int, default=5000, help='Port to listen on')
    args = parser.parse_args()
    app.run(host=args.host, port=args.port)
