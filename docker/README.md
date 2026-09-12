# Planeta Bzzzt! 🪐 — Deployment Guide

Kompletna instrukcja wdrożenia gry i landing page na VPS OVH w Dockerze.

---

## 📋 Wymagania wstępne

| Wymaganie | Opis |
|---|---|
| **VPS OVH** | Ubuntu 22.04+ lub Debian 12+ |
| **Docker & Docker Compose** | v24+ |
| **Nginx Proxy Manager (NPM)** | Działa w Dockerze i zarządza domenami oraz SSL |

---

## 🌟 Najprostszy wariant: Nginx Proxy Manager (NPM)

Jeśli na swoim VPS posiadasz już **Nginx Proxy Manager**, wdrożenie zajmuje 2 minuty:

### 1. Sprawdź nazwę sieci NPM
Na VPS wpisz:
```bash
docker network ls
```
Znajdź sieć, w której działa NPM (najczęściej: `npm_network`, `npm_default` lub nazwa katalogu NPM).

### 2. Uruchom kontener gry
W pliku `docker/docker-compose.npm.yml` upewnij się, że nazwa sieci w sekcji `networks` zgadza się z siecią NPM, a następnie uruchom:
```bash
cd ~/planeta-bzzzt/docker
docker compose -f docker-compose.npm.yml up -d --build
```

### 3. Skonfiguruj Proxy Host w panelu NPM
W przeglądarce w panelu Nginx Proxy Manager:
1. **Proxy Hosts** → **Add Proxy Host**
2. **Details**:
   * **Domain Names:** `twoja-domena.pl`
   * **Scheme:** `http`
   * **Forward Hostname / IP:** `planeta-bzzzt-web`
   * **Forward Port:** `80`
   * Zaznacz: **Block Common Exploits**, **Websockets Support**
3. **SSL**:
   * Wybierz: **Request a new SSL Certificate** (Let's Encrypt)
   * Zaznacz: **Force SSL**, **HTTP/2 Support**
4. **Advanced** (Kluczowe dla gier Godot WebAssembly!):
   Wklej poniższe reguły, aby przeglądarka zezwoliła na `SharedArrayBuffer`:
   ```nginx
   proxy_pass_header Cross-Origin-Opener-Policy;
   proxy_pass_header Cross-Origin-Embedder-Policy;
   proxy_pass_header Cross-Origin-Resource-Policy;
   ```
5. Kliknij **Save**. Gotowe! 🚀

---

---

## 🎮 Krok 1: Eksport gry z Godot (lokalnie)

Zanim wgrasz pliki na serwer, musisz wyeksportować obie wersje gry do WebAssembly.

### Eksport wersji 2D

1. Otwórz projekt w **Godot Editor**
2. `Project` → `Export…`
3. Kliknij `Add…` → wybierz **Web**
4. W polu `Export Path` ustaw: `web/2d/index.html`
5. Kliknij **Export Project**

### Eksport wersji 3D

1. Zmień aktywną scenę na `assets/3d/prototype_3d.tscn`
2. Ponownie `Project` → `Export…` → **Web**
3. W polu `Export Path` ustaw: `web/3d/index.html`
4. Kliknij **Export Project**

> [!IMPORTANT]
> Po eksporcie w katalogu `web/2d/` i `web/3d/` powinny znajdować się pliki:
> `index.html`, `*.wasm`, `*.pck`, `*.js`

---

## 🖥️ Krok 2: Przygotowanie VPS

### Instalacja Dockera (jeśli nie ma)

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker
```

### Sklonowanie/Wgranie projektu

```bash
# Opcja A: git clone (jeśli repo jest publiczne lub prywatne z kluczem SSH)
git clone git@github.com:TWOJ_USER/planeta-bzzzt.git
cd planeta-bzzzt

# Opcja B: rsync z lokalnej maszyny
rsync -avz --exclude='.git' --exclude='.godot' \
    /home/mjasin/Projekty/planeta-bzzzt/ \
    user@VPS_IP:~/planeta-bzzzt/
```

---

## 🔧 Krok 3: Konfiguracja

```bash
cd ~/planeta-bzzzt/docker

# Skopiuj przykładowy plik konfiguracji
cp .env.example .env

# Edytuj i wpisz swoją domenę
nano .env
```

Zawartość `.env`:
```env
DOMAIN=twoja-domena.pl
```

---

## 🔐 Krok 4: Inicjalizacja SSL (tylko raz!)

```bash
cd ~/planeta-bzzzt/docker
chmod +x init-letsencrypt.sh
./init-letsencrypt.sh
```

Skrypt:
1. Pyta o email dla Let's Encrypt
2. Pobiera certyfikat SSL (Certbot standalone)
3. Automatycznie uruchamia `docker compose up -d`

> [!NOTE]
> Port 80 musi być wolny przed uruchomieniem skryptu. Jeśli coś już nasłuchuje na porcie 80, skrypt automatycznie to zatrzyma.

---

## 🚀 Krok 5: Uruchomienie (po pierwszej inicjalizacji)

```bash
cd ~/planeta-bzzzt/docker
docker compose up -d
```

### Sprawdzenie statusu

```bash
# Status kontenerów
docker compose ps

# Logi nginx
docker compose logs -f web

# Logi certbot
docker compose logs certbot
```

---

## 🔄 Aktualizacja gry (po nowym eksporcie)

Gra jest montowana jako **volume** — wystarczy podmienić pliki i przeładować nginx:

```bash
# Wgraj nowe pliki eksportu (np. przez rsync)
rsync -avz web/2d/ user@VPS_IP:~/planeta-bzzzt/web/2d/
rsync -avz web/3d/ user@VPS_IP:~/planeta-bzzzt/web/3d/

# Przeładuj nginx (bez downtime)
docker compose exec web nginx -s reload
```

---

## 🔄 Aktualizacja landing page

Strona jest **wbudowana w obraz Docker** — wymaga przebudowy:

```bash
# Na VPS, po zaktualizowaniu plików landing/
docker compose up -d --build web
```

---

## 🌐 Weryfikacja

Po uruchomieniu sprawdź:

| URL | Co powinno działać |
|---|---|
| `https://twoja-domena.pl` | Landing page Planeta Bzzzt! |
| `https://twoja-domena.pl/game/2d/` | Gra 2D (WebAssembly) |
| `https://twoja-domena.pl/game/3d/` | Gra 3D (WebAssembly) |

### Sprawdzenie nagłówków COOP/COEP

```bash
curl -I https://twoja-domena.pl/game/2d/index.html
# Powinno zwrócić:
# cross-origin-opener-policy: same-origin
# cross-origin-embedder-policy: require-corp
```

---

## 🏗️ Struktura katalogów

```
planeta-bzzzt/
├── landing/               # Landing page (baked into Docker image)
│   ├── index.html
│   └── style.css
├── web/                   # Godot HTML5 exports (mounted as volumes)
│   ├── 2d/
│   │   ├── index.html
│   │   ├── *.wasm
│   │   └── *.pck
│   └── 3d/
│       ├── index.html
│       ├── *.wasm
│       └── *.pck
└── docker/
    ├── .env               # Your domain config (not in git!)
    ├── .env.example       # Template
    ├── docker-compose.yml
    ├── init-letsencrypt.sh
    ├── certbot/           # Auto-created, holds SSL certs
    │   ├── conf/
    │   └── www/
    └── nginx/
        ├── Dockerfile
        └── nginx.conf.template
```

---

## 🛠️ Rozwiązywanie problemów

### Gra nie uruchamia się (błąd SharedArrayBuffer)

Sprawdź czy nagłówki COOP/COEP są ustawione:
```bash
curl -I https://twoja-domena.pl/game/2d/index.html | grep -i "cross-origin"
```

### Certbot nie może pobrać certyfikatu

- Sprawdź czy DNS wskazuje na IP VPS: `dig twoja-domena.pl`
- Sprawdź czy port 80 jest otwarty: `sudo ufw status`
- Sprawdź logi: `docker compose logs certbot`

### Nginx nie startuje

```bash
# Sprawdź konfigurację
docker compose exec web nginx -t

# Sprawdź logi
docker compose logs web
```

### Jak sprawdzić datę ważności certyfikatu

```bash
docker compose exec certbot certbot certificates
```

---

## 🔒 Automatyczne odnawianie certyfikatu

Certbot uruchomiony w docker-compose **automatycznie odnawia certyfikat co 12 godzin**.
Certyfikaty Let's Encrypt są ważne 90 dni i odnawiają się po osiągnięciu 60. dnia.
