"""Checks App Store Connect is ready for an upload: the API key works, the
bundle ID is registered and the app exists. Prints a plain message for
each problem. Used by the iOS workflow.

Usage: asc_check.py KEY.p8 KEY_ID ISSUER_ID BUNDLE_ID
"""
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt  # PyJWT


def main(key_path, key_id, issuer, bundle):
    token = jwt.encode(
        {'iss': issuer, 'iat': int(time.time()), 'exp': int(time.time()) + 600, 'aud': 'appstoreconnect-v1'},
        open(key_path).read(), algorithm='ES256', headers={'kid': key_id})

    def get(path, **query):
        url = 'https://api.appstoreconnect.apple.com/v1/' + path + '?' + urllib.parse.urlencode(query)
        req = urllib.request.Request(url, headers={'Authorization': 'Bearer ' + token})
        try:
            with urllib.request.urlopen(req) as r:
                return json.load(r)['data']
        except urllib.error.HTTPError as e:
            print(f'::error::App Store Connect said {e.code} for {path}: {e.read().decode()[:500]}')
            if e.code == 401:
                print('::error::The API key was refused: check APPSTORE_KEY_ID, APPSTORE_ISSUER_ID and APPSTORE_P8.')
            sys.exit(1)

    ok = True
    if not get('bundleIds', **{'filter[identifier]': bundle}):
        print(f'::error::Bundle ID {bundle} is not registered (developer.apple.com > Identifiers).')
        ok = False
    apps = get('apps', **{'filter[bundleId]': bundle})
    if not apps:
        print(f'::error::No app for {bundle} in App Store Connect (Apps > + > New App).')
        ok = False
    else:
        print(f"App Store Connect app: {apps[0]['attributes']['name']}")
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main(*sys.argv[1:5])
