import os
import sys
import argparse
from flask import Flask, request, jsonify

from temps import collect_temperatures

app = Flask(__name__)

# token powinien być podany w zmiennej środowiskowej PC_TOKEN
TOKEN = os.getenv('PC_TOKEN')
if not TOKEN:
    print('Error: token not set (PC_TOKEN env variable)')
    sys.exit(1)


def _unauthorized():
    return jsonify({'error': 'unauthorized'}), 401


def _check_auth():
    return request.headers.get('X-Auth-Token') == TOKEN


@app.route('/status', methods=['GET'])
def status():
    if not _check_auth():
        return _unauthorized()
    return jsonify({'status': 'online'})


@app.route('/temps', methods=['GET'])
def temps():
    if not _check_auth():
        return _unauthorized()
    try:
        payload = collect_temperatures()
        payload['status'] = 'online'
        return jsonify(payload)
    except Exception as exc:  # noqa: BLE001 – zwracamy błąd do klienta
        return jsonify({
            'status': 'online',
            'sensors': [],
            'count': 0,
            'error': str(exc),
        }), 200


@app.route('/shutdown', methods=['POST'])
def shutdown():
    if not _check_auth():
        return _unauthorized()
    os.system('shutdown /s /t 0')
    return jsonify({'result': 'shutting down'})


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Simple PC control server')
    parser.add_argument('--host', default='0.0.0.0', help='Interface to bind')
    parser.add_argument('--port', type=int, default=5000, help='Port to listen on')
    args = parser.parse_args()
    app.run(host=args.host, port=args.port)
