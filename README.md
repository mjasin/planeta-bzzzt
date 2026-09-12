# 🪐 Planeta Bzzzt!

Kosmiczna gra zręcznościowa w wersjach **2D** oraz **3D**, stworzona w silniku **Godot 4** w ramach pokazu **Vibe Coding** na żywo podczas wydarzenia **[Robo Challenge 2026](https://www.facebook.com/naukowawioska.official/posts/1835639101798852)** organizowanego przez **[Naukową Wioskę](https://www.facebook.com/naukowawioska.official)** (12 września 2026).

---

## 💡 Koncepcja i Vibe Coding

Gra powstała jako demonstracja programowania wspomaganego sztuczną inteligencją dla uczniów szkoły podstawowej. 
Uczestnicy wcielili się w rolę **Dyrektorów Kreatywnych (Creative Directors)** – dyktując swoje pomysły, zasady gry, mechaniki i wygląd, a agent AI na żywo generował oraz modyfikował kod GDScript w silniku Godot 4.

---

## 🎮 Wersje gry

Projekt zawiera dwie w pełni grywalne wersje:
1. **Wersja 2D (`assets/2d/`)**:
   * Widok Top-Down z perspektywy kosmosu.
   * Zbieranie gwiazdek wokół planety, unikanie meteorów, walka mieczem i tarczą, ucieczka przed UFO i portale czasoprzestrzenne.
2. **Wersja 3D (`assets/3d/`)**:
   * Trójwymiarowa platforma orbitalna zawieszona nad centralną planetą.
   * Pościgi wrogich UFO z laserami, tarcza ochronna, bomby obszarowe niszczące wrogów i zbieranie gwiezdnego pyłu.

---

## 🚀 Technologie

* **Silnik gry:** [Godot Engine 4.x](https://godotengine.org) (GDScript)
* **Silnik fizyki 3D:** Jolt Physics
* **Eksport WWW:** WebAssembly + WebGL (SharedArrayBuffer)
* **Serwer i Hosting:** Docker + Nginx (obsługa nagłówków COOP/COEP) + Certbot (darmowy SSL Let's Encrypt)
* **Landing Page:** Czysty HTML5/CSS3/JavaScript w estetyce Space Synthwave

---

## 📁 Struktura projektu

```text
planeta-bzzzt/
├── assets/
│   ├── 2d/             # Sceny i skrypty GDScript wersji 2D (main.tscn, player, ufo, portal itp.)
│   ├── 3d/             # Sceny i modele wersji 3D (prototype_3d.tscn, ufo_3d itp.)
│   └── fonts/          # Zasoby czcionek (DejaVu Sans, glify)
├── landing/            # Responsywna strona główna (Landing Page)
├── web/                # Katalog montowany w kontenerze z wyeksportowanymi grami
│   ├── 2d/             # Build WebAssembly gry 2D
│   └── 3d/             # Build WebAssembly gry 3D
├── docker/             # Konfiguracja wdrożeniowa pod Docker & VPS
│   ├── nginx/          # Dockerfile i szablony konfiguracyjne Nginxa
│   ├── docker-compose.yml     # Środowisko produkcyjne z SSL
│   ├── docker-compose.dev.yml # Środowisko lokalne (dev)
│   └── init-letsencrypt.sh    # Skrypt inicjalizujący certyfikat SSL
├── export.sh           # Skrypt automatycznego eksportu obu wersji (CLI Godot)
├── export_presets.cfg  # Profile eksportu Web w Godocie
└── project.godot       # Główny plik konfiguracyjny projektu Godot
```

---

## 💻 Uruchomienie lokalne (Development)

### 1. W edytorze Godot
Otwórz projekt w Godot 4.7+ i uruchom scenę:
* Wersja 3D: `res://assets/3d/prototype_3d.tscn`
* Wersja 2D: `res://assets/2d/main.tscn`

### 2. Podgląd strony i gier w Dockerze (localhost)
W katalogu `docker/` przygotowane jest lekkie środowisko deweloperskie z zamontowanymi wolumenami na żywo:

```bash
cd docker
docker compose -f docker-compose.dev.yml up -d
```
Strona dostępna będzie pod adresem: **`http://localhost:8181`**

---

## 🔨 Eksport gier do WebAssembly

Z poziomu terminala możesz wyeksportować obie wersje gry jednym poleceniem (wymagany zainstalowany Godot w PATH):

```bash
chmod +x export.sh
./export.sh
```

Alternatywnie w edytorze: **Project → Export…** i wybierz zdefiniowane profile `Web 2D` oraz `Web 3D`.

---

## 🌐 Wdrożenie na serwer VPS (OVH / Linux)

Pełna instrukcja krok po kroku znajduje się w pliku [`docker/README.md`](docker/README.md).

### Szybki start na serwerze:
1. Sklonuj repozytorium:
   ```bash
   git clone -b prototype-3d https://github.com/mjasin/planeta-bzzzt.git
   cd planeta-bzzzt/docker
   ```
2. Skonfiguruj domenę w pliku `.env`:
   ```bash
   cp .env.example .env
   nano .env # wpisz: DOMAIN=twoja-domena.pl
   ```
3. Wgraj wyeksportowane pliki z lokalnej maszyny:
   ```bash
   rsync -avz web/2d/ user@VPS_IP:~/planeta-bzzzt/web/2d/
   rsync -avz web/3d/ user@VPS_IP:~/planeta-bzzzt/web/3d/
   ```
4. Wygeneruj certyfikat SSL i uruchom stos:
   ```bash
   chmod +x init-letsencrypt.sh
   ./init-letsencrypt.sh
   ```

---

## 📄 Licencja

Projekt stworzony w celach edukacyjnych i warsztatowych.
Baw się dobrze i twórz własne gry z AI! 🚀
