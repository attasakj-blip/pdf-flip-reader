"""Translations for selling Pagelume Gold and Clear in the App Store (iOS),
where the Google Play wording does not fit. Made from the Microsoft Store
lines, with the store and account names changed."""
from translations_winstore import WINSTORE


def _apple(vals, fixes=None):
    out = {code: v.replace('Microsoft Store', 'App Store').replace('Microsoft', 'Apple') for code, v in vals.items()}
    out.update(fixes or {})
    for v in out.values():
        assert 'Microsoft' not in v, v
    return out


IOS = {
    'appStoreUnavailable': _apple(WINSTORE['msStoreUnavailable'], {
        'fr': 'L’App Store est injoignable pour le moment. Réessayez plus tard.',
        'it': 'Al momento l’App Store non è raggiungibile. Riprova più tardi.',
    }),
    'appleRestoredNone': _apple(WINSTORE['msRestoredNone']),
}
