"""Upload 58 real donors from CSV to Firestore."""
import json, urllib.request, ssl, os, csv, random

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

# Auth
with open(os.path.expanduser('~/.config/configstore/firebase-tools.json')) as f:
    rt = json.load(f)['tokens']['refresh_token']
td = urllib.parse.urlencode({
    'client_id': '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    'client_secret': 'j9iVZfS8kkCEFUPaAeJV0sAi',
    'refresh_token': rt, 'grant_type': 'refresh_token',
}).encode()
r = urllib.request.Request('https://oauth2.googleapis.com/token', data=td)
token = json.loads(urllib.request.urlopen(r, context=ctx).read())['access_token']

BASE = 'https://firestore.googleapis.com/v1/projects/bloodbridge-62261/databases/(default)/documents'
HEADERS = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}

def api(url, method='GET', body=None):
    d = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=d, headers=HEADERS, method=method)
    return json.loads(urllib.request.urlopen(req, context=ctx).read())

# Read CSV
csv_path = '/Users/apple/Documents/Blood_Bridge/fyp/Donors list/donor_list.csv'
donors = []
with open(csv_path) as f:
    reader = csv.DictReader(f)
    for row in reader:
        donors.append({
            'name': row['Donor Name'].strip().title(),
            'age': int(row['Age'].strip()),
            'bloodGroup': row['Final BG'].strip(),
        })

print(f'📋 Read {len(donors)} donors from CSV')

print(f'📤 Uploading {len(donors)} donors one by one...')
uploaded = 0
for i, donor in enumerate(donors, 1):
    doc_id = f'real_donor_{i:04d}'
    fields = {
        'name': {'stringValue': donor['name']},
        'email': {'stringValue': f'donor.real{i}@bloodbridge.org'},
        'bloodGroup': {'stringValue': donor['bloodGroup']},
        'age': {'integerValue': str(donor['age'])},
        'role': {'stringValue': 'donor'},
        'gender': {'stringValue': 'Male'},
        'designation': {'stringValue': 'Donor'},
        'location': {'stringValue': ''},
        'contact': {'stringValue': ''},
        'cnic': {'stringValue': ''},
        'approved': {'booleanValue': False},
        'verified': {'booleanValue': False},
        'hasDonated': {'booleanValue': False},
        'available': {'booleanValue': True},
        'createdAt': {'timestampValue': '2026-06-24T00:00:00Z'},
    }
    # Create document with specified ID
    url = f'{BASE}/users?documentId={doc_id}'
    doc = {'fields': fields}
    try:
        api(url, 'POST', doc)
        uploaded += 1
    except Exception as e:
        print(f'  ❌ Failed: {donor["name"]} - {e}')

print(f'✅ DONE! {uploaded}/{len(donors)} donors added to Firestore!')
print('   Status: approved=false (contact hidden until admin approves)')
