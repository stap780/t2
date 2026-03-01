#!/usr/bin/env python3
"""
Process barcodes: T2 search -> CarParts search -> extract inbound_case ID.
Run kamal commands manually or via subprocess.
"""
import re
import sys
import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin

T2_BASE = "https://cpt.dizauto.ru"
T2_SEARCH = T2_BASE + "/products?q%5Btitle_or_variants_sku_or_variants_barcode_cont%5D=000000{num}&commit=Поиск"
CP_BASE = "http://138.197.52.153"
CP_SEARCH = CP_BASE + "/items?utf8=✓&q%5Bt_s_b_ict_s_c_cont_all%5D=000000{num}&button="
CP_LOGIN = CP_BASE + "/sessions"
CP_EMAIL = "panaet80@gmail.com"
CP_PASS = "071080"
T2_EMAIL = "admin@dizauto.ru"
T2_PASS = "admin123"

def login_carparts(session):
    """Login to CarParts and return session with cookies."""
    r = session.get(CP_BASE + "/")
    soup = BeautifulSoup(r.text, "html.parser")
    form = soup.find("form", action="/sessions")
    if not form:
        return False
    token = form.find("input", {"name": "authenticity_token"})
    data = {
        "utf8": "✓",
        "email": CP_EMAIL,
        "password": CP_PASS,
    }
    if token:
        data["authenticity_token"] = token.get("value", "")
    r = session.post(CP_LOGIN, data=data, allow_redirects=True)
    return "Вход в сервис" not in r.text  # Not login page = logged in

def login_t2(session):
    """Login to T2."""
    r = session.get(T2_BASE + "/")
    soup = BeautifulSoup(r.text, "html.parser")
    form = soup.find("form", {"action": re.compile(r"sign_in|login")})
    if not form:
        form = soup.find("form")
    if not form:
        return False
    data = {}
    for inp in form.find_all("input", {"name": True}):
        if inp.get("type") == "hidden":
            data[inp["name"]] = inp.get("value", "")
    data["user[email]"] = T2_EMAIL
    data["user[password]"] = T2_PASS
    r = session.post(urljoin(T2_BASE, form.get("action", "/")), data=data, allow_redirects=True)
    return r.status_code == 200

def t2_has_result(session, num):
    """Check if T2 search returns any products."""
    url = T2_SEARCH.format(num=num)
    r = session.get(url)
    # Look for product table or "нет" / "ничего"
    if "Ничего не найдено" in r.text or "ничего не найдено" in r.text.lower():
        return False
    if "tbody" in r.text and "product" in r.text.lower():
        return True
    # Alternative: check for product rows
    soup = BeautifulSoup(r.text, "html.parser")
    table = soup.find("table")
    if table and table.find("tbody") and table.find_all("tr", limit=5):
        return True
    return False

def carparts_find_inbound_id(session, num):
    """Search CarParts and extract inbound_case ID from href or У: ID in Док column."""
    url = CP_SEARCH.format(num=num)
    r = session.get(url)
    soup = BeautifulSoup(r.text, "html.parser")
    ids = set()
    # Find href with /inbound_cases/
    for a in soup.find_all("a", href=True):
        m = re.search(r"/inbound_cases/(\d+)", a["href"])
        if m:
            ids.add(m.group(1))
    # Find "У: ID" pattern in text
    for text in soup.stripped_strings:
        m = re.search(r"У:\s*(\d+)", text)
        if m:
            ids.add(m.group(1))
    return list(ids)[0] if ids else None

def main():
    numbers = [
        8581419, 8574435, 8581372, 8587572, 8576897, 8565877, 8580597, 8503855, 8420244, 8508577,
        8489913, 8468789, 8507174, 8456632, 8500106, 8456618, 8510129, 8493170, 8484413, 8465887,
        8465535, 8469458, 8450265, 8457202, 8445698, 8432889, 8439345, 8418975, 8441201, 8446800,
        8428097, 8587800, 8587688, 8573612, 8588548, 8573131, 8582829, 8578990, 8575647, 8574466,
        8580719
    ]
    session = requests.Session()
    session.headers.update({"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"})
    print("Logging into CarParts...")
    if not login_carparts(session):
        print("CarParts login failed")
        sys.exit(1)
    print("CarParts OK")
    print("Logging into T2...")
    if not login_t2(session):
        print("T2 login failed (may need different form handling)")
    results = []
    for i, num in enumerate(numbers):
        print(f"[{i+1}/{len(numbers)}] {num}...", end=" ")
        in_t2 = t2_has_result(session, num)
        if in_t2:
            print("SKIP (in T2)")
            results.append((num, None, "SKIP"))
            continue
        cpid = carparts_find_inbound_id(session, num)
        if cpid:
            print(f"ID={cpid}")
            results.append((num, cpid, "NEED_KAMAL"))
        else:
            print("ERROR (no ID in CarParts)")
            results.append((num, None, "ERROR"))
    for num, cpid, status in results:
        print(f"{num}\t{cpid or '-'}\t{status}")

    # Print table
    print("\n\n| Number | T2 found? | CarParts ID (if needed) | Kamal command |")
    print("|--------|-----------|-------------------------|---------------|")
    for num, cpid, status in results:
        t2_found = "Yes" if status == "SKIP" else "No"
        cp_id = cpid or "-"
        kamal = f"bin/rails 'incase:update_barcode_by_inbound_id[{cpid},panaet80@gmail.com,071080]'" if cpid else "-"
        print(f"| {num} | {t2_found} | {cp_id} | {kamal} |")

if __name__ == "__main__":
    main()
