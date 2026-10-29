"""Sube el header y la búsqueda (iOS 27+) a la biblioteca de assets de App Store Connect.

    python3 scripts/creative-upload.py            # muestra qué haría
    python3 scripts/creative-upload.py --apply    # sube lo que falte
    python3 scripts/creative-upload.py --apply --place 1.1
        # además los coloca en esa versión (debe ser editable): header y búsqueda de cada idioma
        # en su localización (en → en-US, es → es-MX y es-ES si existe)

Las imágenes salen de scripts/creative-assets.py (AppStore/creative-assets/<en|es>/). Se suben como
header-en.png, search-es.png…; si ya hay una con ese nombre en la biblioteca, no se repite.
Una imagen cambiada se sube con otro nombre (p. ej. header-en-v2.png) o borrando la anterior en App Store Connect.
Apple las revisa junto con la versión donde se colocan.
"""
import pathlib
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import asc  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
BUNDLE_ID = "com.tavoohoh.quietnumbers"
PLACEMENTS = {"header": "PRODUCT_PAGE_HEADER_ASSET", "search": "APP_STORE_SEARCH_RESULTS_ASSET"}
LOCALES = {"en": ["en-US"], "es": ["es-MX", "es-ES"]}


def upload(library, path, name):
    data = path.read_bytes()
    image = asc.request("POST", "/v1/appAssetLibraryImages", {"data": {
        "type": "appAssetLibraryImages",
        "attributes": {"category": "CREATIVE_ASSETS", "fileName": name, "fileSize": len(data)},
        "relationships": {"assetLibrary": {"data": {"type": "appAssetLibraries", "id": library}}},
    }})["data"]
    for op in image["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders") or []}
        asc.request(op["method"], "", raw=chunk, headers=headers, url=op["url"])
    asc.request("PATCH", f"/v1/appAssetLibraryImages/{image['id']}", {"data": {
        "type": "appAssetLibraryImages", "id": image["id"], "attributes": {"uploaded": True}}})
    for _ in range(40):
        state = asc.request("GET", f"/v1/appAssetLibraryImages/{image['id']}")["data"]["attributes"]
        if state["state"] not in ("AWAITING_UPLOAD", "UPLOAD_COMPLETE"):
            break
        time.sleep(5)
    print(f"  {name}: {state['state']} {state.get('stateDetails') or ''}")
    return image["id"]


def place(version_string, app_id, images, apply):
    versions = [v for v in asc.get_all(f"/v1/apps/{app_id}/appStoreVersions")
                if v["attributes"]["versionString"] == version_string]
    if not versions:
        raise SystemExit(f"No existe la versión {version_string} en App Store Connect.")
    version = versions[0]
    localizations = asc.get_all(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")
    for loc in localizations:
        locale = loc["attributes"]["locale"]
        lang = next((l for l, codes in LOCALES.items() if locale in codes), None)
        if not lang:
            continue
        existing = asc.get_all(f"/v1/appStoreVersionLocalizations/{loc['id']}/placements")
        for kind, placement in PLACEMENTS.items():
            image = images.get(f"{kind}-{lang}.png")
            print(f"{'colocar' if apply else 'colocaría'} {kind}-{lang}.png en {version_string} {locale}")
            if not apply or not image:
                continue
            for old in existing:
                if old["attributes"].get("placementType") == placement:
                    asc.request("DELETE", f"/v1/appAssetLibraryPlacements/{old['id']}")
            asc.request("POST", "/v1/appAssetLibraryPlacements", {"data": {
                "type": "appAssetLibraryPlacements",
                "attributes": {"placementType": placement},
                "relationships": {
                    "appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"]}},
                    "image": {"data": {"type": "appAssetLibraryImages", "id": image}},
                },
            }})


def main():
    apply = "--apply" in sys.argv
    version = sys.argv[sys.argv.index("--place") + 1] if "--place" in sys.argv else None
    app_id = asc.request("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}")["data"][0]["id"]
    library = asc.request("GET", f"/v1/apps/{app_id}/assetLibrary")["data"]["id"]
    current = {i["attributes"]["fileName"]: i for i in asc.get_all(f"/v1/appAssetLibraries/{library}/images")
               if i["attributes"].get("category") == "CREATIVE_ASSETS"}

    images = {}
    for lang in LOCALES:
        for kind in PLACEMENTS:
            name = f"{kind}-{lang}.png"
            path = ROOT / "AppStore" / "creative-assets" / lang / f"{kind}.png"
            if name in current:
                print(f"ya está {name} ({current[name]['attributes']['state']})")
                images[name] = current[name]["id"]
            elif apply:
                print(f"subiendo {name}")
                images[name] = upload(library, path, name)
            else:
                print(f"subiría {name} ({path.stat().st_size} bytes)")
    if version:
        place(version, app_id, images, apply)


if __name__ == "__main__":
    main()
