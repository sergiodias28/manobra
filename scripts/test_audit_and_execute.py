#!/usr/bin/env python3
"""
scripts/test_audit_and_execute.py

Cria um arquivo de auditoria remoto com uma linha que corresponde ao comando mapeado,
chama o endpoint /api/execute e exibe um resumo da resposta.

Requisitos:
  pip install requests paramiko

Uso:
  python scripts/test_audit_and_execute.py --step 1.8 [--index 0] \
    --api http://localhost:5000 \
    --ssh-host 10.140.40.73 --ssh-user sagetr1 --ssh-pass sagetr1

Observações:
- O usuário SSH precisa ter permissão de escrita em /var/sage/arqs (ou ajuste --remote-dir).
- O script tenta escrever via SFTP; se o diretório exigir sudo, crie o arquivo manualmente.
"""
import argparse
import datetime
import os
import sys
import paramiko
import requests

MONTHS_PT = ['jan','fev','mar','abr','mai','jun','jul','ago','set','out','nov','dez']

def build_aud_filename(dt: datetime.datetime) -> str:
    m = MONTHS_PT[dt.month - 1]
    return f"{m}{dt.day:02d}{dt.year % 100:02d}.aud"

def create_remote_aud(ssh_host, ssh_user, ssh_pass, ssh_port, remote_dir, filename, line):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(ssh_host, port=ssh_port, username=ssh_user, password=ssh_pass, timeout=10)
    sftp = client.open_sftp()
    try:
        try:
            sftp.stat(remote_dir)
        except IOError:
            # tenta criar diretório (sem sudo)
            sftp.mkdir(remote_dir)
        remote_path = os.path.join(remote_dir, filename)
        with sftp.open(remote_path, 'w') as f:
            f.write(line + "\n")
    finally:
        try:
            sftp.close()
        except Exception:
            pass
        try:
            client.close()
        except Exception:
            pass
    return remote_path

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--api', default='http://localhost:5000', help='URL do servidor API')
    p.add_argument('--step', required=True, help='Item a executar (ex: 1.8)')
    p.add_argument('--index', type=int, default=None, help='Índice do comando (0-based)')
    p.add_argument('--ssh-host', default=os.environ.get('SSH_HOST','10.140.40.73'))
    p.add_argument('--ssh-user', default=os.environ.get('SSH_USER','sagetr1'))
    p.add_argument('--ssh-pass', default=os.environ.get('SSH_PASS','sagetr1'))
    p.add_argument('--ssh-port', type=int, default=int(os.environ.get('SSH_PORT','22')))
    p.add_argument('--remote-dir', default='/var/sage/arqs', help='Diretório remoto para arquivos .aud')
    args = p.parse_args()

    api_base = args.api.rstrip('/')
    step = args.step

    # 1) Obter comandos mapeados para o step
    try:
        r = requests.get(f'{api_base}/api/commands/{step}', timeout=10)
        r.raise_for_status()
    except Exception as ex:
        print("Erro ao obter comandos do servidor:", ex)
        sys.exit(2)
    js = r.json()
    if not js.get('ok'):
        print("API /api/commands retornou erro:", js)
        sys.exit(2)
    cmds = js.get('commands', [])
    if not cmds:
        print("Nenhum comando mapeado para", step)
        sys.exit(2)

    # escolher comando
    if args.index is not None:
        if args.index < 0 or args.index >= len(cmds):
            print("Índice inválido para os comandos disponíveis.")
            sys.exit(2)
        cmd_to_test = cmds[args.index]
        index = args.index
    else:
        cmd_to_test = cmds[0]
        index = None

    print("Comando selecionado:", cmd_to_test)

    # extrair token central e expected marker (esperado último token)
    parts = cmd_to_test.strip().split()
    if len(parts) < 2:
        print("Formato de comando inesperado:", cmd_to_test)
        sys.exit(2)
    central = parts[1]
    expected = parts[-1] if len(parts) >= 3 else None
    marker = 'echou' if expected == '1' else 'briu' if expected == '0' else None

    # 2) Criar arquivo .aud remoto com linha que deve ser encontrada pelo servidor
    now = datetime.datetime.now()
    filename = build_aud_filename(now)
    timestamp = now.strftime('%H:%M:%S')
    # linha de exemplo: "HH:MM:SS CTM:34C3-2:89 ... echou"
    aud_line = f"{timestamp} {central} comando executou {marker}" if marker else f"{timestamp} {central} comando executou"
    print(f"Criando arquivo remoto {filename} em {args.remote_dir} com linha:\n  {aud_line}")

    try:
        remote_path = create_remote_aud(args.ssh_host, args.ssh_user, args.ssh_pass, args.ssh_port, args.remote_dir, filename, aud_line)
        print("Arquivo criado em:", remote_path)
    except Exception as ex:
        print("Falha ao criar arquivo .aud remoto:", ex)
        print("Se o diretório precisar de permissões elevadas, crie o arquivo manualmente no host remoto.")
        sys.exit(2)

    # 3) Chamar endpoint /api/execute
    payload = {'step': step}
    if index is not None:
        payload['index'] = index
    try:
        resp = requests.post(f'{api_base}/api/execute', json=payload, timeout=60)
        resp.raise_for_status()
    except Exception as ex:
        print("Erro ao chamar /api/execute:", ex)
        sys.exit(2)

    js = resp.json()
    # 4) Mostrar resumo
    print("\n=== Resumo da execução ===")
    print("OK geral:", js.get('ok'))
    if 'error' in js:
        print("Erro retornado:", js.get('error'))
    executed = js.get('executed', [])
    for i, e in enumerate(executed, start=1):
        print(f"\n--- Comando {i} ---")
        print("command:", e.get('command'))
        print("exit_status:", e.get('exit_status'))
        # prints compact preview if long
        stdout = e.get('stdout') or ''
        stderr = e.get('stderr') or ''
        print("stdout (len={}):".format(len(stdout)))
        print(stdout if len(stdout) < 1000 else stdout[:1000] + "\n...[truncated]")
        print("stderr (len={}):".format(len(stderr)))
        print(stderr if len(stderr) < 1000 else stderr[:1000] + "\n...[truncated]")

    # also show audit info if present
    if 'audit' in js:
        print("\n--- Audit info ---")
        import json
        print(json.dumps(js['audit'], indent=2, ensure_ascii=False))

    print("\nTeste concluído.")

if __name__ == '__main__':
    main()