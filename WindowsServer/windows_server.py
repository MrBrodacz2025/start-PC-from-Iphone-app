import os
import sys
import time
import argparse
import threading
from flask import Flask, request, jsonify

from temps import collect_temperatures, ensure_libre_hardware_monitor

app = Flask(__name__)

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
    except Exception as exc:  # noqa: BLE001
        return jsonify({
            'status': 'online',
            'sensors': [],
            'count': 0,
            'metrics': {},
            'error': str(exc),
        }), 200


@app.route('/sleep', methods=['POST'])
def sleep_pc():
    if not _check_auth():
        return _unauthorized()

    def _do_sleep():
        time.sleep(1.2)
        # 0 = sleep (nie hibernacja), 1 = force, 0 = allow wake events
        os.system('rundll32.exe powrprof.dll,SetSuspendState 0,1,0')

    threading.Thread(target=_do_sleep, daemon=True).start()
    return jsonify({'result': 'sleeping'})


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
    # Podgrzewamy LibreHardwareMonitor przy starcie (CPU/dysk temps)
    try:
        ensure_libre_hardware_monitor()
    except Exception as exc:  # noqa: BLE001
        print(f'LHM bootstrap: {exc}')
    app.run(host=args.host, port=args.port)
