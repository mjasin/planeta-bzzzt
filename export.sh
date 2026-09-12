#!/bin/bash
set -e

GODOT_BIN="${GODOT_BIN:-godot}"
PROJECT_DIR="$(pwd)"

echo "🚀 [1/2] Eksportowanie Web 3D..."
mkdir -p web/3d
# Upewniamy się, że main_scene wskazuje na 3D
sed -i 's|run/main_scene=.*|run/main_scene="res://assets/3d/prototype_3d.tscn"|' project.godot
$GODOT_BIN --headless --export-release "Web 3D" web/3d/index.html

echo "🛸 [2/2] Eksportowanie Web 2D..."
mkdir -p web/2d
# Tymczasowo przestawiamy main_scene na 2D
sed -i 's|run/main_scene=.*|run/main_scene="res://main.tscn"|' project.godot
$GODOT_BIN --headless --export-release "Web 2D" web/2d/index.html

# Przywracamy domyślną scenę 3D
sed -i 's|run/main_scene=.*|run/main_scene="res://assets/3d/prototype_3d.tscn"|' project.godot

echo "✅ Obie wersje (2D i 3D) zostały poprawnie wyeksportowane do web/2d i web/3d!"