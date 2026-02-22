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
        8573742, 8580504, 8573285, 8588241, 8588340, 8587695, 8587336, 8580525, 8580634, 8587947,
        8587589, 8578372, 8579997, 8580030, 8587954, 8565174, 8576446, 8587473, 8579676, 8587343,
        8585660, 8581198, 8573032, 8565198, 8573223, 8579836, 8580290, 8580672, 8581167, 8587350,
        8580337, 8587244, 8580207, 8587893, 8587558, 8588562, 8587770, 8580825, 8581808, 8587718,
        8587701, 8587848, 8579614, 8565167, 8588180, 8578921, 8565310, 8578822, 8577092, 8578471,
        8588067, 8576668, 8582386, 8582805
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

if __name__ == "__main__":
    main()
