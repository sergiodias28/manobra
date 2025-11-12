# -*- coding: utf-8 -*-
import os
import re
from typing import Dict, List, Optional, Tuple

from flask import Flask, jsonify, request, send_from_directory
import paramiko

APP_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(APP_DIR)
COMANDOS_FILE = os.path.join(ROOT_DIR, 'Comandos.txt')

SSH_HOST = os.environ.get('SSH_HOST', '10.140.40.73')
SSH_USER = os.environ.get('SSH_USER', 'sagetr1')
SSH_PASS = os.environ.get('SSH_PASS', 'sagetr1')
SSH_PORT = int(os.environ.get('SSH_PORT', '22'))

# Parse commands from Comandos.txt
_commands_by_step: Dict[str, List[str]] = {}


def _load_commands() -> Dict[str, List[str]]:
    mapping: Dict[str, List[str]] = {}
    if not os.path.exists(COMANDOS_FILE):
        return mapping

    pattern = re.compile(r"Item\s+(\d+\.\d+)\s+comando[s]?\s+'([^']+)'(?:\s+e\s+'([^']+)')?", re.IGNORECASE)
    with open(COMANDOS_FILE, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            m = pattern.search(line)
            if not m:
                continue
            step = m.group(1)
            cmd1 = m.group(2)
            cmd2 = m.group(3) if len(m.groups()) >= 3 else None
            cmds = [cmd1]
            if cmd2:
                cmds.append(cmd2)
            mapping[step] = cmds
    return mapping


def _ensure_commands_loaded():
    global _commands_by_step
    if not _commands_by_step:
        _commands_by_step = _load_commands()


def _resolve_ssh_config(payload: Optional[dict]) -> Tuple[str, str, str, int]:
    """Resolve SSH config from request payload (overrides) or globals."""
    global SSH_HOST, SSH_USER, SSH_PASS, SSH_PORT
    if not payload:
        return SSH_HOST, SSH_USER, SSH_PASS, SSH_PORT
    ssh = payload.get('ssh') or {}
    host = payload.get('ssh_host') or ssh.get('host') or SSH_HOST
    user = payload.get('ssh_user') or ssh.get('user') or SSH_USER
    passwd = payload.get('ssh_pass') or ssh.get('pass') or SSH_PASS
    port_val = payload.get('ssh_port') or ssh.get('port') or SSH_PORT
    try:
        port = int(port_val)
    except Exception:
        port = SSH_PORT
    return host, user, passwd, port


app = Flask(__name__, static_folder=ROOT_DIR, static_url_path='')


@app.route('/')
def root():
    # Serve the UI from workspace root
    return send_from_directory(ROOT_DIR, 'index.html')


@app.route('/api/commands', methods=['GET'])
def api_list_commands():
    _ensure_commands_loaded()
    return jsonify(_commands_by_step)


@app.route('/api/commands/<step_number>', methods=['GET'])
def api_get_commands(step_number: str):
    _ensure_commands_loaded()
    cmds = _commands_by_step.get(step_number)
    if not cmds:
        return jsonify({
            'ok': False,
            'error': f'Nenhum comando mapeado para o item {step_number}'
        }), 404
    return jsonify({'ok': True, 'step': step_number, 'commands': cmds})


def _ssh_exec_commands(commands: List[str], host: Optional[str] = None, user: Optional[str] = None, passwd: Optional[str] = None, port: Optional[int] = None, timeout: int = 20) -> List[Dict[str, Optional[str]]]:
    results: List[Dict[str, Optional[str]]] = []
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    h = host or SSH_HOST
    u = user or SSH_USER
    p = passwd or SSH_PASS
    prt = int(port or SSH_PORT)

    try:
        client.connect(h, port=prt, username=u, password=p, timeout=10, banner_timeout=10, auth_timeout=10)
        for cmd in commands:
            try:
                stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
                exit_status = stdout.channel.recv_exit_status()
                out = stdout.read().decode('utf-8', errors='ignore')
                err = stderr.read().decode('utf-8', errors='ignore')
                results.append({
                    'command': cmd,
                    'exit_status': exit_status,
                    'stdout': out.strip() if out else '',
                    'stderr': err.strip() if err else ''
                })
            except Exception as ex:
                results.append({
                    'command': cmd,
                    'exit_status': None,
                    'stdout': '',
                    'stderr': f'Falha ao executar comando: {ex}'
                })
    finally:
        try:
            client.close()
        except Exception:
            pass
    return results


@app.route('/api/execute', methods=['POST'])
def api_execute():
    _ensure_commands_loaded()
    data = request.get_json(silent=True) or {}
    step = str(data.get('step') or '').strip()
    index = data.get('index')

    if not step:
        return jsonify({'ok': False, 'error': 'Campo "step" ausente'}), 400

    cmds = _commands_by_step.get(step)
    if not cmds:
        # No commands mapped for this step: no-op
        return jsonify({'ok': True, 'step': step, 'executed': [], 'message': 'Sem comandos para este item'}), 200

    selected_cmds: List[str]
    if isinstance(index, int):
        if index < 0 or index >= len(cmds):
            return jsonify({'ok': False, 'error': f'Indice invalido para o item {step}'}), 400
        selected_cmds = [cmds[index]]
    else:
        selected_cmds = cmds

    host, user, passwd, port = _resolve_ssh_config(data)

    results = _ssh_exec_commands(selected_cmds, host=host, user=user, passwd=passwd, port=port)
    ok = all(r.get('exit_status') == 0 for r in results if r.get('exit_status') is not None)
    return jsonify({'ok': ok, 'step': step, 'executed': results})


@app.route('/api/reload', methods=['POST'])
def api_reload():
    # Optional: reload the commands file without restarting the server
    global _commands_by_step
    _commands_by_step = _load_commands()
    return jsonify({'ok': True, 'count': len(_commands_by_step)})


@app.route('/api/config', methods=['GET', 'POST'])
def api_config():
    global SSH_HOST, SSH_USER, SSH_PASS, SSH_PORT
    if request.method == 'GET':
        return jsonify({
            'host': SSH_HOST,
            'user': SSH_USER,
            'port': SSH_PORT,
            'pass': '***'
        })
    data = request.get_json(silent=True) or {}
    if 'host' in data:
        SSH_HOST = str(data['host'])
    if 'user' in data:
        SSH_USER = str(data['user'])
    if 'pass' in data:
        SSH_PASS = str(data['pass'])
    if 'port' in data:
        try:
            SSH_PORT = int(data['port'])
        except Exception:
            return jsonify({'ok': False, 'error': 'Porta invalida'}), 400
    return jsonify({'ok': True, 'host': SSH_HOST, 'user': SSH_USER, 'port': SSH_PORT})


if __name__ == '__main__':
    _ensure_commands_loaded()
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', '5000')), debug=True)
