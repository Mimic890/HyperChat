SHELL   := /bin/bash
DC      := docker compose
DC_DEV  := docker compose -f docker-compose.dev.yml

.DEFAULT_GOAL := help
.ONESHELL:
.SILENT:

.PHONY: help secrets check build email dns email-test \
        start pull up down restart upgrade clear monitoring \
        status watch health logs backup admin shell \
        prune-volumes \
        dev dev-down dev-reset dev-status dev-logs dev-admin dev-shell

# ── ANSI codes ────────────────────────────────────────────────────────────────
GR := \033[32m
YL := \033[33m
RD := \033[31m
CY := \033[36m
B  := \033[1m
D  := \033[2m
R  := \033[0m

# ── Box header ────────────────────────────────────────────────────────────────
define _header
printf '\n$(CY)$(B)  ╔══════════════════════════════════════════════════╗$(R)\n'
printf   '$(CY)$(B)  ║$(R)  🔥  $(B)HyperChat$(R)   %-33s$(CY)$(B) ║$(R)\n' '$(1)'
printf   '$(CY)$(B)  ╚══════════════════════════════════════════════════╝$(R)\n\n'
endef

# ── Python: status table ──────────────────────────────────────────────────────
define _status_py
import json, sys
R  = '\033[0m';  B  = '\033[1m';  D  = '\033[2m'
GR = '\033[32m'; YL = '\033[33m'; RD = '\033[31m'; CY = '\033[36m'
raw = sys.stdin.read().strip()
if not raw:
    print(f'\n  {YL}No containers found.{R}\n')
    sys.exit(0)
services = []
for line in raw.split('\n'):
    line = line.strip()
    if line:
        try: services.append(json.loads(line))
        except json.JSONDecodeError: pass
if not services:
    print(f'\n  {YL}No services running.{R}\n')
    sys.exit(0)
services = [s for s in services if not (s.get('Service') or s.get('Name','')).endswith('-init')]
services.sort(key=lambda s: s.get('Service') or s.get('Name', ''))
if not services:
    print(f'\n  {YL}No services running.{R}\n')
    sys.exit(0)
col_n = max(max(len(s.get('Service') or s.get('Name', ''))      for s in services), len('Service')) + 1
col_s = max(max(len(s.get('State', '') or '')                   for s in services), len('State'))   + 1
col_h = max(max(len(s.get('Health', '') or '—')                 for s in services), len('Health'))  + 1
col_u = max(max(len(s.get('RunningFor', '') or '—')             for s in services), len('Uptime'))  + 1
def hline(l, mc, r):
    return (f'  {CY}{l}{"─"*(col_n+4)}{mc}{"─"*(col_s+2)}'
            f'{mc}{"─"*(col_h+2)}{mc}{"─"*(col_u+2)}{r}{R}')
print()
print(hline('╭','┬','╮'))
print(f'  {CY}│{R}   {B}{"Service":<{col_n}}{R} '
      f'{CY}│{R} {D}{"State":<{col_s}}{R} '
      f'{CY}│{R} {D}{"Health":<{col_h}}{R} '
      f'{CY}│{R} {D}{"Uptime":<{col_u}}{R} {CY}│{R}')
print(hline('├','┼','┤'))
running = stopped = 0
for s in services:
    name   = s.get('Service') or s.get('Name', '?')
    state  = s.get('State', '?')
    health = s.get('Health', '') or '—'
    uptime = s.get('RunningFor', '') or '—'
    if state == 'running':
        running += 1; icon = f'{GR}●{R}'; sc = GR
    elif state == 'exited':
        stopped += 1; icon = f'{RD}●{R}'; sc = RD
    else:
        icon = f'{YL}●{R}'; sc = YL
    hc = GR if health == 'healthy' else (RD if health == 'unhealthy' else D)
    print(f'  {CY}│{R} {icon} {B}{name:<{col_n}}{R} '
          f'{CY}│{R} {sc}{state:<{col_s}}{R} '
          f'{CY}│{R} {hc}{health:<{col_h}}{R} '
          f'{CY}│{R} {D}{uptime:<{col_u}}{R} {CY}│{R}')
print(hline('╰','┴','╯'))
sc = RD if stopped > 0 else D
print(f'\n  {D}{len(services)} services{R}  {CY}·{R}  {GR}{B}{running} running{R}  {CY}·{R}  {sc}{stopped} stopped{R}\n')
endef

# ── Python: health details ────────────────────────────────────────────────────
define _health_py
import json, sys, subprocess
R  = '\033[0m';  B  = '\033[1m';  D  = '\033[2m'
GR = '\033[32m'; YL = '\033[33m'; RD = '\033[31m'
res = subprocess.run(['docker','compose','ps','--format','json'],
                     capture_output=True, text=True)
services = [json.loads(l) for l in res.stdout.strip().split('\n') if l.strip()]
if not services:
    print(f'\n  {YL}No services found.{R}\n'); sys.exit(0)
services.sort(key=lambda s: s.get('Service') or s.get('Name', ''))
for s in services:
    name   = s.get('Service') or s.get('Name', '?')
    state  = s.get('State', '?')
    health = s.get('Health', '') or 'none'
    status = s.get('Status', '')
    sc = GR if state == 'running' else (RD if state == 'exited' else D)
    hc = GR if health == 'healthy' else (RD if health == 'unhealthy' else D)
    print(f'  {sc}●{R}  {B}{name:<24}{R}  {sc}{state:<10}{R}  health: {hc}{health}{R}')
    if status:
        print(f'       {D}{status}{R}')
    if health == 'unhealthy':
        r2 = subprocess.run(['docker','compose','ps','-q',name], capture_output=True, text=True)
        cid = r2.stdout.strip()
        if cid:
            r3 = subprocess.run(
                ['docker','inspect','--format',
                 '{{range .State.Health.Log}}{{.Output}}{{end}}', cid],
                capture_output=True, text=True)
            for line in r3.stdout.strip().split('\n')[-3:]:
                if line.strip(): print(f'       {RD}{line.strip()}{R}')
    print()
endef

# ── Python: secrets manager ───────────────────────────────────────────────────
define _secrets_py
import os, re, subprocess, sys, shutil
from datetime import datetime
R  = '\033[0m';  B  = '\033[1m';  D  = '\033[2m'
GR = '\033[32m'; YL = '\033[33m'; RD = '\033[31m'; CY = '\033[36m'
ENV_FILE = '.env'
AUTO = {
    'POSTGRES_PASSWORD':           24,
    'MACAROON_SECRET_KEY':         32,
    'FORM_SECRET':                 32,
    'REGISTRATION_SHARED_SECRET':  32,
    'TURN_SECRET':                 32,
    'LIVEKIT_API_SECRET':          32,
    'GARAGE_RPC_SECRET':           32,
    'S3_ACCESS_KEY':               16,
    'S3_SECRET_KEY':               32,
    'BRIDGE_TELEGRAM_DB_PASSWORD': 16,
    'BRIDGE_WHATSAPP_DB_PASSWORD': 16,
    'BRIDGE_DISCORD_DB_PASSWORD':  16,
    'BRIDGE_SIGNAL_DB_PASSWORD':   16,
    'MAS_CLIENT_SECRET':           32,
    'MAS_ADMIN_TOKEN':             32,
    'MAS_ENCRYPTION_KEY':          32,
    'MAS_DB_PASSWORD':             24,
}
if not os.path.exists(ENV_FILE):
    if not os.path.exists('.env.example'):
        print(f'\n  {RD}✗{R}  {ENV_FILE} not found\n'); sys.exit(1)
    shutil.copy('.env.example', ENV_FILE)
    print(f'  {GR}✓{R}  Created {ENV_FILE} from example\n')
with open(ENV_FILE) as f:
    content = f.read()
# Only generate garage/s3 keys if those storage types are configured
import re as _re
_st_match = _re.search(r'^STORAGE_TYPE=(.+)$$', content, _re.M)
_storage_type = (_st_match.group(1).strip().lower() if _st_match else 'volumes')
if _storage_type not in ('garage', 's3'):
    AUTO.pop('S3_ACCESS_KEY', None)
    AUTO.pop('S3_SECRET_KEY', None)
if _storage_type != 'garage':
    AUTO.pop('GARAGE_RPC_SECRET', None)
_mas_match = _re.search(r'^ENABLE_MAS=(.+)$$', content, _re.M)
if (_mas_match.group(1).strip().lower() if _mas_match else 'false') != 'true':
    for k in ('MAS_CLIENT_SECRET','MAS_ADMIN_TOKEN','MAS_ENCRYPTION_KEY','MAS_DB_PASSWORD'):
        AUTO.pop(k, None)
def get_val(key):
    m = re.search(rf'^{key}=(.+)$$', content, re.M)
    return m.group(1).strip() if m else ''
existing = {k for k in AUTO if get_val(k)}
force = False
if existing:
    print(f'  {YL}⚠{R}  {len(existing)} secret(s) already set\n')
    try: ans = input(f'  Regenerate ALL secrets (existing will be lost)? [y/N]: ').strip().lower()
    except (KeyboardInterrupt, EOFError): print(f'\n  {D}Cancelled{R}\n'); sys.exit(0)
    print()
    force = (ans == 'y')
    if not force:
        print(f'  {D}Only filling empty secrets{R}\n')
os.makedirs('backups', exist_ok=True)
ts = datetime.now().strftime('%Y%m%d_%H%M%S')
bak = f'backups/.env.{ts}'
shutil.copy(ENV_FILE, bak)
print(f'  {D}backup → {bak}{R}\n')
generated = []; kept = []
new_content = content
for key, nbytes in AUTO.items():
    has_val = bool(get_val(key))
    if has_val and not force:
        kept.append(key); continue
    val = subprocess.run(['openssl','rand','-hex',str(nbytes)],
                         capture_output=True, text=True).stdout.strip()
    m = re.search(rf'^{key}=.*$$', new_content, re.M)
    if m:
        new_content = re.sub(rf'^{key}=.*$$', f'{key}={val}', new_content, flags=re.M)
    else:
        new_content += f'\n{key}={val}\n'
    generated.append(key)
with open(ENV_FILE, 'w') as f:
    f.write(new_content)
col = max(len(k) for k in AUTO) + 2
print(f'  {CY}{B}{"Key":<{col}}{R}  Status')
print(f'  {"─"*col}  {"──────────"}')
for k in AUTO:
    if k in generated: print(f'  {B}{k:<{col}}{R}  {GR}✓ generated{R}')
    else:              print(f'  {D}{k:<{col}}{R}  {D}— kept{R}')
print()
if generated:
    print(f'  {GR}{B}✓ {len(generated)} secret(s) generated{R}  {CY}·{R}  {D}{len(kept)} kept{R}\n')
    print(f'  {D}Next step: {CY}make check{R}\n')
else:
    print(f'  {GR}✓ All secrets already set — nothing changed{R}\n')
endef

# ── Python: config checker ────────────────────────────────────────────────────
define _check_py
import os, re, socket, sys
R  = '\033[0m';  B  = '\033[1m';  D  = '\033[2m'
GR = '\033[32m'; YL = '\033[33m'; RD = '\033[31m'; CY = '\033[36m'
ENV_FILE = '.env'
if not os.path.exists(ENV_FILE):
    print(f'\n  {RD}✗{R}  {ENV_FILE} not found — run: make secrets\n'); sys.exit(1)
env = {}
with open(ENV_FILE) as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith('#'):
            m = re.match(r'^([A-Z_][A-Z0-9_]*)=(.*)$$', line)
            if m: env[m.group(1)] = m.group(2).strip('"\'')
def get(k, d=''): return env.get(k, d)
errors = []; warnings = []
mode_raw = get('DEPLOY_MODE', '1')
try:
    mode = int(mode_raw)
    if mode not in (1,2,3,4): raise ValueError
except ValueError:
    errors.append(f'DEPLOY_MODE must be 1, 2, 3, or 4 (got: {mode_raw!r})')
    mode = 1
domain = get('DOMAIN', '')
if mode in (3,4):
    if not domain or domain == 'localhost':
        errors.append('DOMAIN is required for server modes (3 and 4)')
    elif domain.startswith('http'):
        errors.append(f'DOMAIN must not include https:// — got: {domain!r}')
if mode == 4:
    if not get('LETSENCRYPT_EMAIL'):
        errors.append('LETSENCRYPT_EMAIL is required for mode 4 (Traefik + SSL)')
SECRETS = ['POSTGRES_PASSWORD','MACAROON_SECRET_KEY','FORM_SECRET',
           'REGISTRATION_SHARED_SECRET','TURN_SECRET','LIVEKIT_API_SECRET',
           'BRIDGE_TELEGRAM_DB_PASSWORD','BRIDGE_WHATSAPP_DB_PASSWORD',
           'BRIDGE_DISCORD_DB_PASSWORD','BRIDGE_SIGNAL_DB_PASSWORD']
storage_type_check = get('STORAGE_TYPE','volumes').lower()
if storage_type_check in ('garage','s3'):
    for k in ['S3_ACCESS_KEY','S3_SECRET_KEY']:
        if not get(k): errors.append(f'{k} is required for STORAGE_TYPE={storage_type_check} — run: make secrets')
if storage_type_check == 'garage':
    if not get('GARAGE_RPC_SECRET'): errors.append('GARAGE_RPC_SECRET is required for STORAGE_TYPE=garage — run: make secrets')
empty_secrets = [k for k in SECRETS if not get(k)]
if empty_secrets:
    errors.append(f'{len(empty_secrets)} secret(s) are empty — run: make secrets')
ports_seen = {}
PORT_KEYS = ['PORT_SYNAPSE','PORT_ELEMENT','PORT_CINNY','PORT_ADMIN','PORT_LIVEKIT','PORT_STICKERS','PORT_MAS']
for pk in PORT_KEYS:
    v = get(pk)
    if v:
        try:
            p = int(v)
            if not (1024 <= p <= 65535):
                errors.append(f'{pk}={v} — port must be between 1024 and 65535')
            elif v in ports_seen:
                errors.append(f'{pk}={v} conflicts with {ports_seen[v]}')
            else:
                ports_seen[v] = pk
        except ValueError:
            errors.append(f'{pk}={v!r} — must be an integer')
if mode in (2,4):
    for port in ([80] if mode == 2 else [80, 443]):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.settimeout(1)
                if s.connect_ex(('127.0.0.1', port)) == 0:
                    warnings.append(f'Port {port} appears to be in use on localhost')
        except Exception:
            pass
bridge_enabled = any(get(f'ENABLE_BRIDGE_{b}','').lower()=='true'
                     for b in ('TELEGRAM','WHATSAPP','DISCORD','SIGNAL'))
if get('ENABLE_MAS','').lower()=='true':
    for k in ('MAS_CLIENT_SECRET','MAS_ADMIN_TOKEN','MAS_ENCRYPTION_KEY','MAS_DB_PASSWORD'):
        if not get(k): errors.append(f'{k} is required for ENABLE_MAS=true — run: make secrets')
    subdomain_mas = get('SUBDOMAIN_MAS','auth')
    if not subdomain_mas:
        errors.append('SUBDOMAIN_MAS must not be empty when ENABLE_MAS=true')
if get('ENABLE_BRIDGE_TELEGRAM','').lower()=='true' and not get('TELEGRAM_API_ID'):
    warnings.append('TELEGRAM_API_ID is empty — bridge will not work without it')
if get('ENABLE_BRIDGE_TELEGRAM','').lower()=='true' and not get('TELEGRAM_API_HASH'):
    warnings.append('TELEGRAM_API_HASH is empty — bridge will not work without it')
if get('ENABLE_BRIDGE_DISCORD','').lower()=='true' and not get('DISCORD_BOT_TOKEN'):
    warnings.append('DISCORD_BOT_TOKEN is empty — bridge will not work without it')
MODE_LABELS = {1:'local (no proxy)', 2:'local + Traefik (HTTP)', 3:'server (own proxy)', 4:'server + Traefik (HTTPS + Let\'s Encrypt)'}
col = 26
print()
print(f'  {CY}{B}{"Setting":<{col}}{R}  Value')
print(f'  {"─"*col}  {"─"*30}')
print(f'  {B}{"DEPLOY_MODE":<{col}}{R}  {mode} — {MODE_LABELS.get(mode,"")}')
print(f'  {B}{"DOMAIN":<{col}}{R}  {domain or D+"(not set)"+R}')
svc_on = [k.replace("ENABLE_","").lower() for k,v in env.items()
          if k.startswith("ENABLE_") and v.lower()=="true"]
print(f'  {B}{"Services":<{col}}{R}  {", ".join(svc_on) if svc_on else D+"none"+R}')
secret_ok = len(SECRETS) - len(empty_secrets)
print(f'  {B}{"Secrets":<{col}}{R}  {GR}{secret_ok}/{len(SECRETS)} filled{R}')
print()
if warnings:
    for w in warnings: print(f'  {YL}⚠{R}  {w}')
    print()
if errors:
    for e in errors: print(f'  {RD}✗{R}  {e}')
    print(f'\n  {RD}{B}✗ {len(errors)} error(s) — fix before running make build{R}\n')
    sys.exit(1)
else:
    print(f'  {GR}{B}✓ All checks passed{R}  — run {CY}make build{R} to generate configs\n')
endef

# ── Python: config builder ────────────────────────────────────────────────────
define _build_py
import os, re, shutil, subprocess, sys
from pathlib import Path
R  = '\033[0m';  B  = '\033[1m';  D  = '\033[2m'
GR = '\033[32m'; YL = '\033[33m'; RD = '\033[31m'; CY = '\033[36m'
def die(msg): print(f'\n  {RD}✗{R}  {msg}\n'); sys.exit(1)
def ok(msg):  print(f'  {GR}✓{R}  {msg}')
def info(msg):print(f'  {CY}→{R}  {msg}')
ENV_FILE = '.env'
if not Path(ENV_FILE).exists():
    die(f'{ENV_FILE} not found — run: make secrets')
env = {}
with open(ENV_FILE) as f:
    for line in f:
        s = line.strip()
        if s and not s.startswith('#'):
            m = re.match(r'^([A-Z_][A-Z0-9_]*)=(.*)$$', s)
            if m: env[m.group(1)] = m.group(2).strip('"\'')
def get(k, d=''): return env.get(k, d)
mode = int(get('DEPLOY_MODE','1'))
domain = get('DOMAIN','localhost')
server_name = get('SERVER_NAME','hyperchat')
le_email = get('LETSENCRYPT_EMAIL','')
def _make_host(sub, d): return f'{sub}.{d}' if sub.strip() else d
host_matrix   = _make_host(get('SUBDOMAIN_MATRIX',   'matrix'),   domain)
host_element  = _make_host(get('SUBDOMAIN_ELEMENT',  ''),         domain)
host_cinny    = _make_host(get('SUBDOMAIN_CINNY',    'cinny'),    domain)
host_livekit  = _make_host(get('SUBDOMAIN_LIVEKIT',  'livekit'),  domain)
host_stickers = _make_host(get('SUBDOMAIN_STICKERS', 'stickers'), domain)
host_mas      = _make_host(get('SUBDOMAIN_MAS',      'auth'),     domain)
is_server  = mode in (3,4)
is_traefik = mode in (2,4)
is_ssl     = mode == 4
if is_server:
    matrix_server_name = domain
    matrix_base_url    = f'https://{host_matrix}'
    traefik_tls        = 'true'
    traefik_ep         = 'websecure'
    serve_wellknown    = 'true'
    bind_addr          = '0.0.0.0'
else:
    port_synapse       = get('PORT_SYNAPSE','8008')
    matrix_server_name = 'localhost'
    matrix_base_url    = f'http://localhost:{port_synapse}'
    traefik_tls        = 'false'
    traefik_ep         = 'web'
    serve_wellknown    = 'false'
    bind_addr          = '127.0.0.1'
en = lambda k: get(f'ENABLE_{k}','false').lower() == 'true'
profiles = []
if en('ELEMENT'):         profiles.append('element')
if en('CINNY'):           profiles.append('cinny')
if en('VOIP'):            profiles.append('voip')
if en('BRIDGE_TELEGRAM'): profiles.append('bridge-telegram')
if en('BRIDGE_WHATSAPP'): profiles.append('bridge-whatsapp')
if en('BRIDGE_DISCORD'):  profiles.append('bridge-discord')
if en('BRIDGE_SIGNAL'):   profiles.append('bridge-signal')
if en('STICKERS'):        profiles.append('stickers')
if en('MAS'):             profiles.append('mas')
if is_traefik:
    compose_file = 'docker-compose.yml:docker-compose.traefik.yml'
else:
    compose_file = 'docker-compose.yml:docker-compose.ports.yml'
has_bridges = any(en(f'BRIDGE_{b}') for b in ('TELEGRAM','WHATSAPP','DISCORD','SIGNAL'))
if has_bridges:
    bridge_entries = ['app_service_config_files:']
    for bname in ('telegram','whatsapp','discord','signal'):
        if en(f'BRIDGE_{bname.upper()}'):
            bridge_entries.append(f'  - /bridges/{bname}/registration.yaml')
    app_svc_block = '\n'.join(bridge_entries)
else:
    app_svc_block = '# app_service_config_files: []  # no bridges enabled'
smtp_enabled = 'true' if (get('ENABLE_EMAIL','false').lower()=='true' and get('SMTP_HOST')) else 'false'
smtp_disabled = 'false' if smtp_enabled == 'true' else 'true'
mas_disabled  = 'false' if en('MAS') else 'true'
element_call_url = f'https://{host_livekit}' if en('VOIP') else 'https://call.element.io'
storage_type = get('STORAGE_TYPE', 'volumes').lower()
data_path    = get('DATA_PATH', '').rstrip('/')
s3_enabled   = 'true' if storage_type in ('s3', 'garage') else 'false'
# Validate storage config
if storage_type == 'local' and not data_path:
    die('STORAGE_TYPE=local requires DATA_PATH to be set (absolute path)')
if storage_type == 's3' and not get('S3_BUCKET'):
    die('STORAGE_TYPE=s3 requires S3_BUCKET to be set')
if storage_type == 'garage' and not get('S3_BUCKET'):
    die('STORAGE_TYPE=garage requires S3_BUCKET to be set (bucket name)')
full_env = dict(env)
full_env.update({
    'MATRIX_SERVER_NAME':       matrix_server_name,
    'MATRIX_BASE_URL':          matrix_base_url,
    'SERVER_NAME':              server_name,
    'BIND_ADDR':                bind_addr,
    'TRAEFIK_TLS':              traefik_tls,
    'TRAEFIK_ENTRYPOINTS':      traefik_ep,
    'TRAEFIK_SSL':              'true' if is_ssl else 'false',
    'SERVE_WELLKNOWN':          serve_wellknown,
    'SMTP_ENABLED':             smtp_enabled,
    'APP_SERVICE_CONFIG_FILES': app_svc_block,
    'DEPLOY_MODE_LABEL':        f'mode {mode}',
    'LETSENCRYPT_EMAIL':        le_email,
    'ENABLE_S3':                s3_enabled,
    'HOST_MATRIX':              host_matrix,
    'HOST_ELEMENT':             host_element,
    'HOST_CINNY':               host_cinny,
    'HOST_LIVEKIT':             host_livekit,
    'HOST_STICKERS':            host_stickers,
    'HOST_MAS':                 host_mas,
    'SMTP_DISABLED':            smtp_disabled,
    'MAS_DISABLED':             mas_disabled,
    'ELEMENT_CALL_URL':         element_call_url,
})
if storage_type == 'garage':
    profiles.append('garage')
    full_env['S3_ENDPOINT'] = 'http://garage:3900'
    full_env['S3_REGION'] = get('S3_REGION', 'garage')
def replace_var(m):
    key = m.group(1); default = m.group(2) or ''
    return full_env.get(key, default)
def process_template(src, dst):
    with open(src) as f: content = f.read()
    def strip_if_blocks(text):
        def replacer(m):
            var   = m.group(1)
            block = m.group(2)
            return block if full_env.get(var,'false').lower() == 'true' else ''
        return re.sub(r'# \{\{IF (\w+)\}\}\n(.*?)# \{\{ENDIF\}\}\n',
                      replacer, text, flags=re.DOTALL)
    content = strip_if_blocks(content)
    content = re.sub(r'\$${([A-Z_][A-Z0-9_]*)(?::-([^}]*))?}', replace_var, content)
    Path(dst).parent.mkdir(parents=True, exist_ok=True)
    with open(dst, 'w') as f: f.write(content)
    ok(dst)
print()
info('Generating config files...\n')
process_template('synapse/homeserver.yaml.template',        'synapse/homeserver.yaml')
process_template('element/config.json.template',            'element/config.json')
process_template('coturn/turnserver.conf.template',         'coturn/turnserver.conf')
process_template('livekit/livekit.yaml.template',           'livekit/livekit.yaml')
process_template('bridges/telegram/config.yaml.template',  'bridges/telegram/config.yaml')
process_template('bridges/whatsapp/config.yaml.template',  'bridges/whatsapp/config.yaml')
process_template('bridges/discord/config.yaml.template',   'bridges/discord/config.yaml')
process_template('bridges/signal/config.yaml.template',    'bridges/signal/config.yaml')
if en('CINNY'):
    process_template('cinny/config.json.template', 'cinny/config.json')
if is_traefik:
    Path('traefik').mkdir(exist_ok=True)
    process_template('traefik/traefik.yml.template', 'traefik/traefik.yml')
if storage_type == 'garage':
    process_template('garage/garage.toml.template', 'garage/garage.toml')
if en('MAS'):
    process_template('mas/config.yaml.template', 'mas/config.yaml')
# ── Storage override ──────────────────────────────────────────────────────────
storage_compose = None
if storage_type == 'local':
    for d in [f'{data_path}/postgres', f'{data_path}/synapse', f'{data_path}/redis']:
        Path(d).mkdir(parents=True, exist_ok=True)
    storage_compose = 'docker-compose.storage.yml'
    with open(storage_compose, 'w') as f:
        f.write('# Generated by make build — do not edit\n')
        f.write('# Overrides named volumes with bind-mounts at DATA_PATH\n')
        f.write('volumes:\n')
        f.write(f'  postgres_data:\n    driver: local\n    driver_opts:\n      type: none\n      o: bind\n      device: "{data_path}/postgres"\n')
        f.write(f'  synapse_data:\n    driver: local\n    driver_opts:\n      type: none\n      o: bind\n      device: "{data_path}/synapse"\n')
        f.write(f'  redis_data:\n    driver: local\n    driver_opts:\n      type: none\n      o: bind\n      device: "{data_path}/redis"\n')
    ok(storage_compose)
    info(f'Storage: bind-mount → {data_path}\n')
elif storage_type == 's3':
    info(f'Storage: remote S3 — bucket {get("S3_BUCKET")}\n')
elif storage_type == 'garage':
    info(f'Storage: Garage local S3 — bucket {get("S3_BUCKET")}\n')
elif storage_type == 'volumes':
    pass
else:
    die(f'Unknown STORAGE_TYPE={storage_type}. Use: volumes, local, s3, garage')
if storage_compose:
    compose_file = f'{compose_file}:{storage_compose}'
info('\nWriting .env...\n')
with open(ENV_FILE) as src: original_env = src.read()
with open('.env','w') as f:
    f.write('# Generated by make build — do not edit\n\n')
    f.write(f'COMPOSE_FILE={compose_file}\n')
    f.write(f'COMPOSE_PROFILES={",".join(profiles)}\n')
    f.write(f'BIND_ADDR={bind_addr}\n')
    f.write(f'TRAEFIK_ENTRYPOINTS={traefik_ep}\n')
    f.write(f'TRAEFIK_TLS={traefik_tls}\n')
    f.write(f'HOST_MATRIX={host_matrix}\n')
    f.write(f'HOST_ELEMENT={host_element}\n')
    f.write(f'HOST_CINNY={host_cinny}\n')
    f.write(f'HOST_LIVEKIT={host_livekit}\n')
    f.write(f'HOST_STICKERS={host_stickers}\n')
    f.write(f'HOST_MAS={host_mas}\n')
    f.write(f'ELEMENT_CALL_URL={element_call_url}\n\n')
    f.write('# From .env:\n')
    f.write(original_env)
ok('.env')
MODE_LABELS = {1:'local',2:'local + Traefik',3:'server (own proxy)',4:'server + Traefik + SSL'}
print(f'\n  {GR}{B}✓ Build complete{R}')
print(f'  {D}Mode:     {MODE_LABELS[mode]}{R}')
print(f'  {D}Domain:   {matrix_server_name}{R}')
print(f'  {D}Profiles: {", ".join(profiles) if profiles else "none"}{R}')
print(f'\n  Next: {CY}make start{R}\n')
endef

# ── Python: email wizard ──────────────────────────────────────────────────────
define _email_py
import os, re, sys, smtplib, ssl
R  = '\033[0m'; B = '\033[1m'; D = '\033[2m'
GR = '\033[32m'; YL = '\033[33m'; RD = '\033[31m'; CY = '\033[36m'
ENV_FILE = '.env'
def read_env():
    if not os.path.exists(ENV_FILE): return {}
    v = {}
    with open(ENV_FILE) as f:
        for line in f:
            m = re.match(r'^([A-Z_]+)=(.*)$$', line.rstrip())
            if m: v[m.group(1)] = m.group(2)
    return v
def write_env(key, val):
    with open(ENV_FILE) as f: c = f.read()
    if re.search(rf'^{key}=', c, re.M):
        c = re.sub(rf'^{key}=.*$$', f'{key}={val}', c, flags=re.M)
    else:
        c += f'\n{key}={val}\n'
    with open(ENV_FILE, 'w') as f: f.write(c)
if not os.path.exists(ENV_FILE):
    print(f'\n  {RD}✗{R}  {ENV_FILE} not found — run: make secrets first\n'); sys.exit(1)
env = read_env()
def ask(label, key, default=''):
    cur = env.get(key,'') or default
    hint = f' [{CY}{cur}{R}]' if cur else ''
    try: val = input(f'  {B}{label}{R}{hint}: ').strip()
    except (KeyboardInterrupt, EOFError): print(f'\n  {YL}Cancelled{R}\n'); sys.exit(0)
    return val if val else cur
print()
smtp_host = ask('SMTP host      ', 'SMTP_HOST', 'smtp.gmail.com')
smtp_port = ask('SMTP port      ', 'SMTP_PORT', '587')
smtp_user = ask('SMTP username  ', 'SMTP_USER')
smtp_pass = ask('SMTP password  ', 'SMTP_PASS')
domain    = env.get('DOMAIN','example.com')
smtp_from = ask('From address   ', 'SMTP_FROM', f'HyperChat <noreply@{domain}>')
print()
print(f'  {CY}→{R}  Testing {smtp_host}:{smtp_port}...')
try:
    port = int(smtp_port)
    if port == 465:
        ctx = ssl.create_default_context()
        with smtplib.SMTP_SSL(smtp_host, port, context=ctx, timeout=10) as s:
            if smtp_user and smtp_pass: s.login(smtp_user, smtp_pass)
    else:
        with smtplib.SMTP(smtp_host, port, timeout=10) as s:
            s.ehlo()
            if port == 587: s.starttls(); s.ehlo()
            if smtp_user and smtp_pass: s.login(smtp_user, smtp_pass)
    print(f'  {GR}✓{R}  Connection successful\n')
    save = True
except Exception as e:
    print(f'  {YL}⚠{R}  Test failed: {D}{e}{R}')
    try: save = input(f'\n  Save anyway? [y/N]: ').strip().lower() == 'y'
    except (KeyboardInterrupt, EOFError): save = False
    print()
if not save:
    print(f'  {D}Settings not saved{R}\n'); sys.exit(0)
for key, val in [('SMTP_HOST',smtp_host),('SMTP_PORT',smtp_port),
                 ('SMTP_USER',smtp_user),('SMTP_PASS',smtp_pass),('SMTP_FROM',smtp_from)]:
    write_env(key, val)
    masked = '*'*len(val) if key=='SMTP_PASS' else val
    print(f'  {GR}✓{R}  {B}{key}{R} = {D}{masked}{R}')
print(f'\n  {GR}{B}✓ Saved{R}  — run {CY}make build{R} to apply\n')
endef

# ── Python: caddy config generator ───────────────────────────────────────────
define _caddy_py
import os, re, sys
R='\033[0m'; B='\033[1m'; D='\033[2m'; CY='\033[36m'; GR='\033[32m'; RD='\033[31m'; YL='\033[33m'
ENV_FILE = '.env'
if not os.path.exists(ENV_FILE):
    print(f'\n  {RD}✗{R}  .env not found — run: make build first\n'); sys.exit(1)
env = {}
with open(ENV_FILE) as f:
    for line in f:
        m = re.match(r'^([A-Z_][A-Z0-9_]*)=(.*)', line.rstrip())
        if m: env[m.group(1)] = m.group(2).strip('"\'')
def get(k, d=''): return env.get(k, d)
mode = int(get('DEPLOY_MODE', '1'))
domain = get('DOMAIN', 'localhost')
def _host(k, default, d): sub = get(k, default).strip(); return f'{sub}.{d}' if sub else d
host_matrix   = get('HOST_MATRIX')   or _host('SUBDOMAIN_MATRIX',   'matrix',   domain)
host_element  = get('HOST_ELEMENT')  or _host('SUBDOMAIN_ELEMENT',  '',         domain)
host_cinny    = get('HOST_CINNY')    or _host('SUBDOMAIN_CINNY',    'cinny',    domain)
host_livekit  = get('HOST_LIVEKIT')  or _host('SUBDOMAIN_LIVEKIT',  'livekit',  domain)
host_stickers = get('HOST_STICKERS') or _host('SUBDOMAIN_STICKERS', 'stickers', domain)
host_mas      = get('HOST_MAS')      or _host('SUBDOMAIN_MAS',      'auth',     domain)
port_synapse  = get('PORT_SYNAPSE',  '8008')
port_element  = get('PORT_ELEMENT',  '8080')
port_cinny    = get('PORT_CINNY',    '8081')
port_admin    = get('PORT_ADMIN',    '8082')
port_livekit  = get('PORT_LIVEKIT',  '7880')
port_stickers = get('PORT_STICKERS', '8090')
port_mas      = get('PORT_MAS',      '8083')
en = lambda k: get(f'ENABLE_{k}', 'false').lower() == 'true'
if mode in (2, 4):
    print(f'\n  {YL}⚠{R}  DEPLOY_MODE={mode} uses Traefik — Caddy config not needed.\n')
    sys.exit(0)
if mode == 1:
    print(f'\n  {YL}⚠{R}  DEPLOY_MODE=1 is local — no reverse proxy needed.\n')
    sys.exit(0)
# mode 3: server with own proxy
wk_server = '{"m.server": "' + host_matrix + ':443"}'
wk_client = '{"m.homeserver":{"base_url":"https://' + host_matrix + '"}}'
sec_headers = '''\
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        Referrer-Policy "strict-origin-when-cross-origin"
        -Server
    }'''
lines = []
lines.append(f'# ── HyperChat — generated by: make caddy ──────────────────────────────────')
lines.append(f'')
lines.append(f'# Matrix homeserver')
lines.append(f'{host_matrix} {{')
lines.append(f'    encode zstd gzip')
lines.append(sec_headers)
lines.append(f'    reverse_proxy localhost:{port_synapse} {{')
lines.append(f'        flush_interval -1')
lines.append(f'    }}')
lines.append(f'}}')
lines.append(f'')
if en('ELEMENT'):
    lines.append(f'# Element Web client + .well-known for Matrix federation')
    lines.append(f'{host_element} {{')
    lines.append(f'    encode zstd gzip')
    lines.append(sec_headers)
    lines.append(f'')
    lines.append(f'    handle /.well-known/matrix/server {{')
    lines.append(f'        respond `{wk_server}` 200')
    lines.append(f'    }}')
    lines.append(f'    handle /.well-known/matrix/client {{')
    lines.append(f'        header Access-Control-Allow-Origin *')
    lines.append(f'        respond `{wk_client}` 200')
    lines.append(f'    }}')
    lines.append(f'    handle {{')
    lines.append(f'        reverse_proxy localhost:{port_element}')
    lines.append(f'    }}')
    lines.append(f'}}')
    lines.append(f'')
else:
    lines.append(f'# .well-known for Matrix federation (no web client on this domain)')
    lines.append(f'{host_element} {{')
    lines.append(f'    handle /.well-known/matrix/server {{')
    lines.append(f'        respond `{wk_server}` 200')
    lines.append(f'    }}')
    lines.append(f'    handle /.well-known/matrix/client {{')
    lines.append(f'        header Access-Control-Allow-Origin *')
    lines.append(f'        respond `{wk_client}` 200')
    lines.append(f'    }}')
    lines.append(f'}}')
    lines.append(f'')
if en('CINNY'):
    lines.append(f'# Cinny client')
    lines.append(f'{host_cinny} {{')
    lines.append(f'    encode zstd gzip')
    lines.append(sec_headers)
    lines.append(f'    reverse_proxy localhost:{port_cinny}')
    lines.append(f'}}')
    lines.append(f'')
if en('VOIP'):
    lines.append(f'# LiveKit (VoIP / Element Call)')
    lines.append(f'{host_livekit} {{')
    lines.append(f'    reverse_proxy localhost:{port_livekit} {{')
    lines.append(f'        flush_interval -1')
    lines.append(f'    }}')
    lines.append(f'}}')
    lines.append(f'')
if en('STICKERS'):
    lines.append(f'# Sticker picker')
    lines.append(f'{host_stickers} {{')
    lines.append(f'    encode zstd gzip')
    lines.append(f'    reverse_proxy localhost:{port_stickers}')
    lines.append(f'}}')
    lines.append(f'')
if en('MAS'):
    lines.append(f'# Matrix Authentication Service (QR login, OIDC)')
    lines.append(f'{host_mas} {{')
    lines.append(f'    encode zstd gzip')
    lines.append(sec_headers)
    lines.append(f'    reverse_proxy localhost:{port_mas}')
    lines.append(f'}}')
    lines.append(f'')
lines.append(f'# Synapse Admin — protected, localhost only (bind: 127.0.0.1:{port_admin})')
lines.append(f'# Access via SSH tunnel: ssh -L {port_admin}:localhost:{port_admin} user@{domain}')
lines.append(f'# Then open: http://localhost:{port_admin}')
config = '\n'.join(lines)
print(f'\n  {B}Caddyfile blocks for {CY}{domain}{R}{B}:{R}\n')
print('  ' + '-'*60)
print(config)
print('  ' + '-'*60)
print(f'\n  Paste into {B}/etc/caddy/Caddyfile{R}, then:\n')
print(f'    sudo systemctl reload caddy\n')
print(f'  {D}DNS records needed:{R}')
needed = [host_matrix]
if host_element != host_matrix: needed.append(host_element)
if en('CINNY'):    needed.append(host_cinny)
if en('VOIP'):     needed.append(host_livekit)
if en('STICKERS'): needed.append(host_stickers)
if en('MAS'):      needed.append(host_mas)
for r in needed:
    print(f'    {CY}{r}{R}  →  <your server IP>')
print()
endef

# ── Python: DNS checker ───────────────────────────────────────────────────────
define _dns_py
import re, socket, sys, urllib.request
R='\033[0m'; B='\033[1m'; D='\033[2m'; CY='\033[36m'; GR='\033[32m'; RD='\033[31m'; YL='\033[33m'
ENV_FILE = '.env'
if not __import__('os').path.exists(ENV_FILE):
    print(f'\n  {RD}✗{R}  .env not found — run: make build first\n'); sys.exit(1)
env = {}
with open(ENV_FILE) as f:
    for line in f:
        m = re.match(r'^([A-Z_][A-Z0-9_]*)=(.*)', line.rstrip())
        if m: env[m.group(1)] = m.group(2).strip('"\'')
def get(k, d=''): return env.get(k, d)
mode = int(get('DEPLOY_MODE', '1'))
domain = get('DOMAIN', '')
en = lambda k: get(f'ENABLE_{k}', 'false').lower() == 'true'
def _host(k, default, d): sub = get(k, default).strip(); return f'{sub}.{d}' if sub else d
host_matrix   = get('HOST_MATRIX')   or _host('SUBDOMAIN_MATRIX',   'matrix',   domain)
host_element  = get('HOST_ELEMENT')  or _host('SUBDOMAIN_ELEMENT',  '',         domain)
host_cinny    = get('HOST_CINNY')    or _host('SUBDOMAIN_CINNY',    'cinny',    domain)
host_livekit  = get('HOST_LIVEKIT')  or _host('SUBDOMAIN_LIVEKIT',  'livekit',  domain)
host_stickers = get('HOST_STICKERS') or _host('SUBDOMAIN_STICKERS', 'stickers', domain)
host_mas      = get('HOST_MAS')      or _host('SUBDOMAIN_MAS',      'auth',     domain)
if mode == 1:
    print(f'\n  {YL}⚠{R}  DEPLOY_MODE=1 (local) — DNS check not applicable.\n'); sys.exit(0)
if not domain or domain == 'localhost':
    print(f'\n  {RD}✗{R}  DOMAIN is not set.\n'); sys.exit(1)
print(f'\n  {CY}→{R}  Getting server public IP...')
try:
    server_ip = urllib.request.urlopen('https://api.ipify.org', timeout=5).read().decode().strip()
    print(f'  {D}Server IP: {server_ip}{R}\n')
except Exception as e:
    server_ip = None
    print(f'  {YL}⚠{R}  Could not detect server IP ({e}) — will show resolved IPs only\n')
hosts = [host_matrix]
if host_element != host_matrix: hosts.append(host_element)
if en('CINNY'):    hosts.append(host_cinny)
if en('VOIP'):     hosts.append(host_livekit)
if en('STICKERS'): hosts.append(host_stickers)
if en('MAS'):      hosts.append(host_mas)
col = max(len(h) for h in hosts) + 2
print(f'  {B}{"Host":<{col}}{R}  {"Resolved IP":<16}  Status')
print(f'  {"─"*col}  {"─"*16}  {"─"*10}')
ok_count = 0; fail_count = 0
for host in hosts:
    try:
        resolved = socket.gethostbyname(host)
        if server_ip and resolved == server_ip:
            status = f'{GR}✓ ok{R}'; ok_count += 1
        elif server_ip:
            status = f'{RD}✗ wrong IP{R}'; fail_count += 1
        else:
            status = f'{YL}? unknown{R}'
    except socket.gaierror:
        resolved = 'NXDOMAIN'; status = f'{RD}✗ not found{R}'; fail_count += 1
    print(f'  {B}{host:<{col}}{R}  {resolved:<16}  {status}')
print()
if fail_count:
    print(f'  {RD}✗{R}  {fail_count} record(s) not pointing to this server')
    print(f'  {D}Add DNS A records for the hosts above pointing to {server_ip or "your server IP"}{R}\n')
else:
    print(f'  {GR}✓{R}  All DNS records look good\n')
endef

# ── Python: email connection test ─────────────────────────────────────────────
define _email_check_py
import re, smtplib, ssl, sys, os
R='\033[0m'; B='\033[1m'; D='\033[2m'; CY='\033[36m'; GR='\033[32m'; RD='\033[31m'; YL='\033[33m'
ENV_FILE = '.env'
if not os.path.exists(ENV_FILE):
    print(f'\n  {RD}✗{R}  .env not found — run: make build first\n'); sys.exit(1)
env = {}
with open(ENV_FILE) as f:
    for line in f:
        m = re.match(r'^([A-Z_][A-Z0-9_]*)=(.*)', line.rstrip())
        if m: env[m.group(1)] = m.group(2).strip('"\'')
def get(k, d=''): return env.get(k, d)
if get('ENABLE_EMAIL','false').lower() != 'true':
    print(f'\n  {YL}⚠{R}  ENABLE_EMAIL=false — email is disabled.\n  Set ENABLE_EMAIL=true and configure SMTP settings.\n'); sys.exit(0)
host = get('SMTP_HOST')
port = int(get('SMTP_PORT', '587'))
user = get('SMTP_USER')
pwd  = get('SMTP_PASS')
if not host:
    print(f'\n  {RD}✗{R}  SMTP_HOST is not set\n'); sys.exit(1)
print(f'\n  {CY}→{R}  Testing {host}:{port}...')
try:
    if port == 465:
        ctx = ssl.create_default_context()
        with smtplib.SMTP_SSL(host, port, context=ctx, timeout=10) as s:
            if user and pwd: s.login(user, pwd)
    else:
        with smtplib.SMTP(host, port, timeout=10) as s:
            s.ehlo()
            if port == 587: s.starttls(); s.ehlo()
            if user and pwd: s.login(user, pwd)
    print(f'  {GR}✓{R}  Connection successful — {host}:{port}\n')
except Exception as e:
    print(f'  {RD}✗{R}  Connection failed: {e}\n'); sys.exit(1)
endef

# ── Python: monitoring hints ──────────────────────────────────────────────────
define _monitoring_py
import re, os, sys
R='\033[0m'; B='\033[1m'; D='\033[2m'; CY='\033[36m'; GR='\033[32m'; RD='\033[31m'; YL='\033[33m'
ENV_FILE = '.env'
if not os.path.exists(ENV_FILE):
    print(f'\n  {RD}✗{R}  .env not found — run: make build first\n'); sys.exit(1)
env = {}
with open(ENV_FILE) as f:
    for line in f:
        m = re.match(r'^([A-Z_][A-Z0-9_]*)=(.*)', line.rstrip())
        if m: env[m.group(1)] = m.group(2).strip('"\'')
def get(k, d=''): return env.get(k, d)
def en(k): return get(f'ENABLE_{k}', 'false').lower() == 'true'
domain   = get('DOMAIN', 'localhost')
host_matrix   = get('HOST_MATRIX', f'matrix.{domain}')
host_livekit  = get('HOST_LIVEKIT', f'livekit.{domain}')
host_mas      = get('HOST_MAS',     f'auth.{domain}')
enabled = en('MONITORING')
if not enabled:
    print(f'\n  {YL}⚠{R}  ENABLE_MONITORING=false — Synapse metrics are off.')
    print(f'  Set {B}ENABLE_MONITORING=true{R} in .env and re-run {CY}make build{R}.\n')
    sys.exit(0)
print(f'\n  {GR}✓{R}  Synapse metrics enabled — port {B}9000{R} (localhost only)\n')
print(f'  {B}Prometheus scrape_configs block:{R}\n')
print(f'  {D}# ── HyperChat ────────────────────────────────────────────{R}')
print(f'  scrape_configs:')
print(f'    - job_name: synapse')
print(f'      static_configs:')
print(f'        - targets: [\'<server_ip>:9000\']')
print(f'      metrics_path: /_synapse/metrics')
if en('MAS'):
    print(f'    - job_name: mas')
    print(f'      static_configs:')
    print(f'        - targets: [\'<server_ip>:8083\']')
    print(f'      metrics_path: /metrics')
if en('VOIP'):
    print(f'    - job_name: livekit')
    print(f'      static_configs:')
    print(f'        - targets: [\'<server_ip>:7880\']')
    print(f'      metrics_path: /metrics')
print(f'\n  {D}Replace <server_ip> with your server address.{R}')
print(f'  {D}Or use SSH tunnel: ssh -L 9000:localhost:9000 user@{domain}{R}\n')
print(f'  {B}Loki — ship Docker logs with Promtail:{R}\n')
print(f'  {D}# promtail/config.yaml{R}')
print(f'  clients:')
print(f'    - url: http://<loki_host>:3100/loki/api/v1/push')
print(f'  scrape_configs:')
print(f'    - job_name: hyperchat')
print(f'      docker_sd_configs:')
print(f'        - host: unix:///var/run/docker.sock')
print(f'          filters:')
print(f'            - name: label')
print(f'              values: [\"com.docker.compose.project=hyperchat\"]')
print(f'      relabel_configs:')
print(f'        - source_labels: [\'__meta_docker_container_name\']')
print(f'          regex: \'/hyperchat-(.*)-[0-9]+\'')
print(f'          target_label: service')
print(f'\n  {B}Grafana — recommended dashboards (import by ID):{R}\n')
print(f'    {CY}14105{R}  Synapse overview')
print(f'    {CY}13697{R}  Synapse detailed')
if en('VOIP'):
    print(f'    {CY}search{R}  "LiveKit" on grafana.com/dashboards')
print(f'\n  {D}Grafana data sources:{R}')
print(f'    Prometheus  →  http://<prometheus_host>:9090')
print(f'    Loki        →  http://<loki_host>:3100\n')
endef

# ── Python: live watch TUI ────────────────────────────────────────────────────
define _watch_py
import subprocess, json, time, sys, signal

HIDE = '\033[?25l'; SHOW = '\033[?25h'; CLEAR = '\033[2J\033[H'
R  = '\033[0m';  B  = '\033[1m';  D  = '\033[2m'
GR = '\033[32m'; YL = '\033[33m'; RD = '\033[31m'; CY = '\033[36m'

def get_ps():
    r = subprocess.run(['docker','compose','ps','--format','json'], capture_output=True, text=True)
    out = []
    for line in r.stdout.strip().split('\n'):
        if line.strip():
            try: out.append(json.loads(line))
            except: pass
    return out

def get_stats():
    r = subprocess.run(['docker','stats','--no-stream','--format',
                        '{"name":"{{.Name}}","cpu":"{{.CPUPerc}}","mem":"{{.MemUsage}}"}'],
                       capture_output=True, text=True)
    stats = {}
    for line in r.stdout.strip().split('\n'):
        if line.strip():
            try:
                d = json.loads(line)
                stats[d['name']] = d
            except: pass
    return stats

def cpu_color(val):
    try:
        v = float(val.rstrip('%'))
        return GR if v < 30 else (YL if v < 70 else RD)
    except: return D

def render(svcs, stats):
    svcs = [s for s in svcs if not (s.get('Service') or s.get('Name','')).endswith('-init')]
    svcs.sort(key=lambda s: s.get('Service') or s.get('Name',''))
    if not svcs:
        return f'\n  {YL}No services running.{R}\n'
    col_n = max(max(len(s.get('Service') or s.get('Name','')) for s in svcs), 7) + 1
    W = dict(s=10, h=9, c=7, m=20, u=22)
    def hline(l, mc, r):
        return (f'  {CY}{l}{"─"*(col_n+4)}{"┬".join(["─"*(W[k]+2) for k in "shcmu"])}{r}{R}')
    def hline(l, mc, r):
        segs = f'{mc}{"─"*(W["s"]+2)}{mc}{"─"*(W["h"]+2)}{mc}{"─"*(W["c"]+2)}{mc}{"─"*(W["m"]+2)}{mc}{"─"*(W["u"]+2)}'
        return f'  {CY}{l}{"─"*(col_n+4)}{segs}{r}{R}'
    running = stopped = 0
    rows = []
    for s in svcs:
        name   = s.get('Service') or s.get('Name','?')
        state  = s.get('State','?')
        health = s.get('Health','') or '—'
        uptime = s.get('RunningFor','') or '—'
        stat   = next((v for k,v in stats.items() if f'-{name}-' in k), None)
        cpu    = stat['cpu'] if stat else '—'
        mem    = (stat['mem'].split('/')[0].strip() if stat and '/' in stat['mem'] else stat['mem'] if stat else '—')
        if state == 'running': running += 1; icon = f'{GR}●{R}'; sc = GR
        elif state == 'exited': stopped += 1; icon = f'{RD}●{R}'; sc = RD
        else: icon = f'{YL}●{R}'; sc = YL
        hc = GR if health == 'healthy' else (RD if health == 'unhealthy' else D)
        cc = cpu_color(cpu)
        rows.append(
            f'  {CY}│{R} {icon} {B}{name:<{col_n}}{R}'
            f' {CY}│{R} {sc}{state:<{W["s"]}}{R}'
            f' {CY}│{R} {hc}{health:<{W["h"]}}{R}'
            f' {CY}│{R} {cc}{cpu:>{W["c"]}}{R}'
            f' {CY}│{R} {D}{mem:<{W["m"]}}{R}'
            f' {CY}│{R} {D}{uptime:<{W["u"]}}{R}'
            f' {CY}│{R}'
        )
    sc = RD if stopped > 0 else D
    header = (f'  {CY}│{R}   {B}{"Service":<{col_n}}{R}'
              f' {CY}│{R} {D}{"State":<{W["s"]}}{R}'
              f' {CY}│{R} {D}{"Health":<{W["h"]}}{R}'
              f' {CY}│{R} {D}{"CPU":>{W["c"]}}{R}'
              f' {CY}│{R} {D}{"Memory":<{W["m"]}}{R}'
              f' {CY}│{R} {D}{"Uptime":<{W["u"]}}{R}'
              f' {CY}│{R}')
    out = [f'\n  {B}🔥  HyperChat{R}  {D}live monitor  ·  Ctrl+C to exit  ·  refreshes every 3s{R}\n',
           hline('╭','┬','╮'), header, hline('├','┼','┤')]
    out += rows
    out += [hline('╰','┴','╯'),
            f'\n  {D}{len(svcs)} services{R}  {CY}·{R}  {GR}{running} running{R}  {CY}·{R}  {sc}{stopped} stopped{R}\n']
    return '\n'.join(out)

def _exit(sig, frame):
    sys.stdout.write(SHOW + '\n'); sys.stdout.flush(); sys.exit(0)
signal.signal(signal.SIGINT, _exit)
signal.signal(signal.SIGTERM, _exit)
sys.stdout.write(HIDE); sys.stdout.flush()
try:
    while True:
        svcs  = get_ps()
        stats = get_stats()
        sys.stdout.write(CLEAR + render(svcs, stats))
        sys.stdout.flush()
        time.sleep(3)
finally:
    sys.stdout.write(SHOW); sys.stdout.flush()
endef

# ── Write scripts to /tmp at Make-evaluation time ────────────────────────────
$(file > /tmp/hc_status.py,$(_status_py))
$(file > /tmp/hc_health.py,$(_health_py))
$(file > /tmp/hc_secrets.py,$(_secrets_py))
$(file > /tmp/hc_check.py,$(_check_py))
$(file > /tmp/hc_build.py,$(_build_py))
$(file > /tmp/hc_email.py,$(_email_py))
$(file > /tmp/hc_caddy.py,$(_caddy_py))
$(file > /tmp/hc_dns.py,$(_dns_py))
$(file > /tmp/hc_email_check.py,$(_email_check_py))
$(file > /tmp/hc_monitoring.py,$(_monitoring_py))
$(file > /tmp/hc_watch.py,$(_watch_py))

# ═════════════════════════════════════════════════════════════════════════════
#  help
# ═════════════════════════════════════════════════════════════════════════════

help:
	$(call _header,)
	printf '  $(B)Install$(R)\n'
	printf '    $(CY)make secrets$(R)            Generate missing secrets in .env\n'
	printf '    $(CY)make check$(R)              Validate .env before building\n'
	printf '    $(CY)make build$(R)              Generate all configs from .env\n'
	printf '    $(CY)make caddy$(R)              Print ready-to-paste Caddyfile blocks\n'
	printf '    $(CY)make storage$(R)            Show current storage configuration\n'
	printf '    $(CY)make dns$(R)                Check DNS records for all services\n'
	printf '    $(CY)make email-test$(R)         Test SMTP connection\n'
	printf '    $(CY)make email$(R)              Interactive SMTP setup wizard\n'
	printf '    $(CY)make monitoring$(R)         Print Prometheus/Loki config snippets\n'
	printf '\n'
	printf '  $(B)Lifecycle$(R)\n'
	printf '    $(CY)make start$(R)              Pull images and start all services\n'
	printf '    $(CY)make up$(R)                 Start services (no pull)\n'
	printf '    $(CY)make down$(R)               Stop all services\n'
	printf '    $(CY)make restart$(R)            Restart all services\n'
	printf '\n'
	printf '  $(B)Updates$(R)\n'
	printf '    $(CY)make pull$(R)               Pull latest images (no restart)\n'
	printf '    $(CY)make upgrade$(R)            Pull + restart services with new images\n'
	printf '\n'
	printf '  $(B)Maintenance$(R)\n'
	printf '    $(CY)make clear$(R)              Remove dangling Docker images\n'
	printf '    $(CY)make prune$(R)              Remove images not used by this stack\n'
	printf '    $(CY)make volumes$(R)            Show data volumes and their sizes\n'
	printf '    $(CY)make prune-volumes$(R)      Remove orphaned volumes not used by any container\n'
	printf '    $(CY)make reset$(R)              Wipe all data volumes (with confirmation)\n'
	printf '    $(CY)make backup$(R)             Dump all PostgreSQL databases to ./backups/\n'
	printf '\n'
	printf '  $(B)Monitoring$(R)\n'
	printf '    $(CY)make status$(R)             Service status dashboard\n'
	printf '    $(CY)make watch$(R)              Live monitor with CPU/RAM (Ctrl+C to exit)\n'
	printf '    $(CY)make health$(R)             Container health-check details\n'
	printf '    $(CY)make logs$(R)               Follow logs for all services\n'
	printf '    $(CY)make logs s=NAME$(R)        Follow logs for a specific service\n'
	printf '\n'
	printf '  $(B)Admin$(R)\n'
	printf '    $(CY)make admin$(R)              Create a Matrix admin user\n'
	printf '    $(CY)make shell s=NAME$(R)       Open a shell inside a service container\n'
	printf '\n'
	printf '  $(B)Local dev$(R)  $(D)(no domain · no TLS · open registration)$(R)\n'
	printf '    $(CY)make dev$(R)                Start dev stack $(D)(Element :8080 · Synapse :8008)$(R)\n'
	printf '    $(CY)make dev-down$(R)           Stop dev stack\n'
	printf '    $(CY)make dev-reset$(R)          Wipe dev volumes and restart fresh\n'
	printf '    $(CY)make dev-status$(R)         Dev service status dashboard\n'
	printf '    $(CY)make dev-logs [s=NAME]$(R)  Follow dev stack logs\n'
	printf '    $(CY)make dev-admin$(R)          Create admin user in dev Synapse\n'
	printf '    $(CY)make dev-shell s=NAME$(R)   Open a shell inside a dev container\n'
	printf '\n'

# ═════════════════════════════════════════════════════════════════════════════
#  secrets
# ═════════════════════════════════════════════════════════════════════════════

secrets:
	$(call _header,— secrets)
	if ! command -v openssl &>/dev/null; then
	  printf '  $(RD)✗$(R)  openssl not found\n\n'; exit 1
	fi
	python3 /tmp/hc_secrets.py

# ═════════════════════════════════════════════════════════════════════════════
#  check
# ═════════════════════════════════════════════════════════════════════════════

check:
	$(call _header,— check)
	python3 /tmp/hc_check.py

# ═════════════════════════════════════════════════════════════════════════════
#  build
# ═════════════════════════════════════════════════════════════════════════════

build:
	$(call _header,— build)
	python3 /tmp/hc_build.py

# ═════════════════════════════════════════════════════════════════════════════
#  email
# ═════════════════════════════════════════════════════════════════════════════

caddy:
	$(call _header,— caddy config)
	@python3 /tmp/hc_caddy.py

storage:
	$(call _header,— storage)
	@if [ ! -f .env ]; then printf '  $(RD)✗$(R)  .env not found — run: make build first\n\n'; exit 1; fi
	@python3 -c "\
import re, os; \
env = {}; \
[env.update({m.group(1): m.group(2)}) for line in open('.env') for m in [re.match(r'^([A-Z_][A-Z0-9_]*)=(.*)', line.rstrip())] if m]; \
t = env.get('STORAGE_TYPE','volumes'); \
print(); \
print(f'  \033[1mStorage type:\033[0m  {t}'); \
t=='local'  and print(f'  \033[1mData path:\033[0m     {env.get(\"DATA_PATH\",\"(not set)\")}'); \
t in ('s3','garage') and print(f'  \033[1mS3 bucket:\033[0m     {env.get(\"S3_BUCKET\",\"(not set)\")}'); \
t=='s3'     and print(f'  \033[1mS3 endpoint:\033[0m   {env.get(\"S3_ENDPOINT\",\"(default AWS)\")}'); \
t=='garage' and print(f'  \033[1mS3 endpoint:\033[0m   http://garage:3900 (local container)'); \
print() \
"

dns:
	$(call _header,— dns check)
	@python3 /tmp/hc_dns.py

email-test:
	$(call _header,— email test)
	@python3 /tmp/hc_email_check.py

email:
	$(call _header,— email setup)
	python3 /tmp/hc_email.py

monitoring:
	$(call _header,— monitoring)
	@python3 /tmp/hc_monitoring.py

# ═════════════════════════════════════════════════════════════════════════════
#  lifecycle
# ═════════════════════════════════════════════════════════════════════════════

start:
	$(call _header,— start)
	if [ ! -f .env ]; then \
	  printf '  $(RD)✗$(R)  .env not found — run: make build first\n\n'; exit 1; \
	fi
	if [ -d synapse/homeserver.yaml ]; then \
	  printf '  $(RD)✗$(R)  synapse/homeserver.yaml is a directory — run: rm -rf synapse/homeserver.yaml && make build\n\n'; exit 1; \
	fi
	if [ ! -f synapse/homeserver.yaml ]; then \
	  printf '  $(RD)✗$(R)  synapse/homeserver.yaml not found — run: make build first\n\n'; exit 1; \
	fi
	printf '  $(CY)→$(R)  Pulling latest images...\n\n'
	$(DC) pull
	printf '\n'
	$(DC) up -d
	printf '\n'
	$(MAKE) --no-print-directory status

up:
	$(call _header,— starting)
	if [ ! -f .env ]; then \
	  printf '  $(RD)✗$(R)  .env not found — run: make build first\n\n'; exit 1; \
	fi
	if [ -d synapse/homeserver.yaml ]; then \
	  printf '  $(RD)✗$(R)  synapse/homeserver.yaml is a directory — run: rm -rf synapse/homeserver.yaml && make build\n\n'; exit 1; \
	fi
	if [ ! -f synapse/homeserver.yaml ]; then \
	  printf '  $(RD)✗$(R)  synapse/homeserver.yaml not found — run: make build first\n\n'; exit 1; \
	fi
	$(DC) up -d
	printf '\n'
	$(MAKE) --no-print-directory status

down:
	$(call _header,— stopping)
	$(DC) down
	printf '\n  $(D)Stack stopped.$(R)\n\n'

reset:
	$(call _header,— reset)
	printf '  $(RD)!$(R)  This will DELETE all data volumes (postgres, synapse). Continue? [y/N] ' && read ans && [ "$${ans}" = y ]
	$(DC) down -v
	printf '\n  $(GR)✓$(R)  All volumes removed. Run make build && make up to start fresh.\n\n'

restart:
	$(call _header,— restarting)
	$(DC) restart
	printf '\n'
	$(MAKE) --no-print-directory status

# ═════════════════════════════════════════════════════════════════════════════
#  updates
# ═════════════════════════════════════════════════════════════════════════════

pull:
	$(call _header,— pull)
	printf '  $(CY)→$(R)  Pulling latest images $(D)(stack will not restart)$(R)\n\n'
	$(DC) pull
	printf '\n  $(GR)✓$(R)  Done — run $(CY)make upgrade$(R) to apply\n\n'

upgrade:
	$(call _header,— upgrade)
	printf '  $(CY)→$(R)  Checking for updated images...\n\n'
	before=$$($(DC) images -q 2>/dev/null | sort | tr '\n' ':')
	$(DC) pull
	printf '\n'
	after=$$($(DC) images -q 2>/dev/null | sort | tr '\n' ':')
	if [ "$$before" = "$$after" ]; then
	  printf '  $(GR)✓$(R)  All images up to date — stack unchanged\n\n'
	else
	  printf '  $(CY)→$(R)  New images detected, restarting...\n\n'
	  $(DC) up -d
	  printf '\n'
	  $(MAKE) --no-print-directory status
	fi

# ═════════════════════════════════════════════════════════════════════════════
#  maintenance
# ═════════════════════════════════════════════════════════════════════════════

clear:
	$(call _header,— clear)
	dangling=$$(docker images -f dangling=true -q 2>/dev/null)
	if [ -z "$$dangling" ]; then
	  printf '  $(GR)✓$(R)  No unused images\n\n'; exit 0
	fi
	count=$$(echo "$$dangling" | wc -l | tr -d ' ')
	printf '  $(YL)⚠$(R)  %s dangling image(s) found\n\n' "$$count"
	docker image prune -f >/dev/null
	printf '  $(GR)✓$(R)  Removed %s image(s)\n\n' "$$count"

prune:
	$(call _header,— prune)
	printf '  $(CY)→$(R)  Removing images no longer used by this stack...\n\n'
	$(DC) down --rmi local 2>/dev/null || true
	docker image prune -f >/dev/null
	printf '  $(GR)✓$(R)  Done. Run $(CY)make pull$(R) + $(CY)make up$(R) to restore.\n\n'

volumes:
	$(call _header,— volumes)
	printf '  %-30s %s\n' "Volume" "Size"
	printf '  %-30s %s\n' "──────────────────────────────" "────────"
	for v in $$(docker volume ls -q | grep "^hyperchat_"); do \
	  size=$$(docker run --rm -v $$v:/data alpine:3 du -sh /data 2>/dev/null | cut -f1); \
	  printf '  %-30s %s\n' "$$v" "$${size:-?}"; \
	done
	printf '\n'

prune-volumes:
	$(call _header,— prune volumes)
	orphans=$$(docker volume ls -f dangling=true -q | grep "^hyperchat_" 2>/dev/null)
	if [ -z "$$orphans" ]; then
	  printf '  $(GR)✓$(R)  No orphaned volumes found\n\n'; exit 0
	fi
	count=$$(echo "$$orphans" | wc -l | tr -d ' ')
	printf '  $(YL)⚠$(R)  %s orphaned volume(s) not used by any container:\n\n' "$$count"
	echo "$$orphans" | while read v; do printf '    $(D)%s$(R)\n' "$$v"; done
	printf '\n  Remove them? [y/N] ' && read ans && [ "$${ans}" = y ] || { printf '\n  $(D)Cancelled$(R)\n\n'; exit 0; }
	echo "$$orphans" | xargs docker volume rm
	printf '\n  $(GR)✓$(R)  Removed %s volume(s)\n\n' "$$count"

backup:
	$(call _header,— backup)
	mkdir -p backups
	TS=$$(date +%Y%m%d_%H%M%S)
	FILE="backups/hyperchat_$${TS}.sql.gz"
	printf '  $(CY)→$(R)  Dumping all databases...\n'
	if $(DC) exec -T postgres pg_dumpall -U synapse 2>/dev/null | gzip > "$$FILE"; then
	  SIZE=$$(du -sh "$$FILE" | cut -f1)
	  printf '  $(GR)✓$(R)  $(B)%s$(R)  $(D)(%s)$(R)\n\n' "$$FILE" "$$SIZE"
	else
	  rm -f "$$FILE"
	  printf '  $(RD)✗$(R)  Backup failed — is postgres running?\n\n'; exit 1
	fi

# ═════════════════════════════════════════════════════════════════════════════
#  monitoring
# ═════════════════════════════════════════════════════════════════════════════

status:
	$(call _header,— status)
	$(DC) ps --format json 2>/dev/null | python3 /tmp/hc_status.py

watch:
	$(call _header,— live monitor)
	python3 /tmp/hc_watch.py

health:
	$(call _header,— health)
	python3 /tmp/hc_health.py

logs:
	$(call _header,— logs)
	if [ -n "$(s)" ]; then
	  printf '  $(CY)→$(R)  Following $(B)$(s)$(R) $(D)(Ctrl-C to stop)$(R)\n\n'
	  $(DC) logs -f --tail=100 $(s)
	else
	  printf '  $(CY)→$(R)  Following all services $(D)(Ctrl-C to stop)$(R)\n\n'
	  $(DC) logs -f --tail=50
	fi

# ═════════════════════════════════════════════════════════════════════════════
#  admin
# ═════════════════════════════════════════════════════════════════════════════

admin:
	$(call _header,— create admin user)
	@if grep -q '^ENABLE_MAS=true' .env 2>/dev/null; then \
	  printf '  $(CY)→$(R)  MAS is enabled — creating user via MAS CLI\n\n'; \
	  printf '  Username: '; read _u; \
	  stty -echo; printf '  Password: '; read _p; stty echo; printf '\n'; \
	  $(DC) exec mas mas-cli --config /config/config.yaml manage register-user --yes "$$_u" --admin && \
	  $(DC) exec mas mas-cli --config /config/config.yaml manage set-password "$$_u" "$$_p"; \
	else \
	  printf '  $(CY)→$(R)  Follow the prompts below\n\n'; \
	  $(DC) exec synapse register_new_matrix_user \
	    -c /config/homeserver.yaml --admin http://localhost:8008; \
	fi
	printf '\n'

shell:
	if [ -z "$(s)" ]; then
	  printf '\n  $(RD)✗$(R)  Specify a service:  $(CY)make shell s=synapse$(R)\n\n'; exit 1
	fi
	$(call _header,— shell: $(s))
	$(DC) exec $(s) sh 2>/dev/null || $(DC) exec $(s) bash

# ═════════════════════════════════════════════════════════════════════════════
#  dev stack
# ═════════════════════════════════════════════════════════════════════════════

dev:
	$(call _header,— dev mode)
	printf '  $(YL)⚠$(R)  $(B)Local dev stack$(R) — hardcoded passwords, open registration\n'
	printf '  $(D)   NOT for production use$(R)\n\n'
	$(DC_DEV) up -d
	printf '\n'
	$(DC_DEV) ps --format json 2>/dev/null | python3 /tmp/hc_status.py
	printf '  $(CY)→$(R)  Element Web   $(B)http://localhost:8080$(R)\n'
	printf '  $(CY)→$(R)  Synapse API   $(B)http://localhost:8008$(R)\n'
	printf '  $(CY)→$(R)  Synapse Admin $(B)http://localhost:8082$(R)\n\n'

dev-down:
	$(call _header,— dev: stopping)
	$(DC_DEV) down
	printf '\n  $(D)Dev stack stopped.$(R)\n\n'

dev-reset:
	$(call _header,— dev: reset)
	printf '  $(YL)⚠$(R)  Wiping dev volumes...\n\n'
	$(DC_DEV) down -v
	printf '  $(GR)✓$(R)  Volumes removed\n\n'
	$(MAKE) --no-print-directory dev

dev-status:
	$(call _header,— dev: status)
	$(DC_DEV) ps --format json 2>/dev/null | python3 /tmp/hc_status.py

dev-logs:
	$(call _header,— dev: logs)
	if [ -n "$(s)" ]; then
	  printf '  $(CY)→$(R)  Following $(B)$(s)$(R) $(D)(Ctrl-C to stop)$(R)\n\n'
	  $(DC_DEV) logs -f --tail=100 $(s)
	else
	  printf '  $(CY)→$(R)  Following all dev services $(D)(Ctrl-C to stop)$(R)\n\n'
	  $(DC_DEV) logs -f --tail=50
	fi

dev-admin:
	$(call _header,— dev: create admin user)
	printf '  $(CY)→$(R)  Follow the prompts below\n\n'
	$(DC_DEV) exec synapse register_new_matrix_user \
	  -c /config/homeserver.yaml --admin http://localhost:8008
	printf '\n'

dev-shell:
	if [ -z "$(s)" ]; then
	  printf '\n  $(RD)✗$(R)  Specify a service:  $(CY)make dev-shell s=synapse$(R)\n\n'; exit 1
	fi
	$(call _header,— dev shell: $(s))
	$(DC_DEV) exec $(s) sh 2>/dev/null || $(DC_DEV) exec $(s) bash
