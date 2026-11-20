import base64, json, sys, urllib.request, uuid, pathlib
key = pathlib.Path('/home/liyutong/.config/opencode/secrets/ofox_api_key.txt').read_text().strip()
root = pathlib.Path('/home/liyutong/thief-sim')
import os
refs = [root/'docs/art_direction/a00_src/thief_noir_generated.png'] + ([root/'assets/art/CPy0UzlakIPj0kfwMuVCR.png'] if os.environ.get('WITH_COVER','1')=='1' else [])
prompt = open('q6_prompt.txt', encoding='utf-8').read().strip()
boundary = uuid.uuid4().hex
parts = []
def field(name, value):
    parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode('utf-8'))
def file(name, path):
    parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"; filename="{path.name}"\r\nContent-Type: image/png\r\n\r\n'.encode() + path.read_bytes() + b'\r\n')
field('model', 'openai/gpt-image-2')
field('prompt', prompt)
field('size', '1536x1024')
field('n', '1')
for r in refs:
    file('image[]', r)
parts.append(f'--{boundary}--\r\n'.encode())
body = b''.join(parts)
req = urllib.request.Request('https://api.ofox.ai/v1/images/edits', data=body, method='POST',
    headers={'Authorization': 'Bearer ' + key, 'Content-Type': f'multipart/form-data; boundary={boundary}'})
try:
    with urllib.request.urlopen(req, timeout=600) as resp:
        data = json.loads(resp.read())
except urllib.error.HTTPError as e:
    print('HTTP', e.code, e.read()[:500].decode('utf-8', 'replace')); sys.exit(1)
b64 = data['data'][0].get('b64_json')
if not b64:
    print('no b64', str(data)[:300]); sys.exit(1)
out = pathlib.Path('q6_chibi_storyboard.png')
out.write_bytes(base64.b64decode(b64)); print('wrote', out, out.stat().st_size)
