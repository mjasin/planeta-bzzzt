# Antigravity Agent Instructions & Project Assumptions — Planeta Bzzzt

## 1. Project Overview & Context

- **Project Name:** Planeta Bzzzt! (Planet Bzzzt!)
- **Target Audience:** 2nd grade primary school students (ages 7–8).
- **Format:** Live "Vibe Coding" workshop demonstration.
- **Tech Stack:**
  - **Engine:** Godot 4.x (GDScript)
  - **OS:** Pop!_OS (Linux)
  - **IDE:** Antigravity / VS Code with `godot-tools`
  - **AI Agent:** Antigravity Agent (Gemini)

## 2. Core Objective

Demonstrate the power and fun of **Vibe Coding** to young children. Instead of writing boilerplate code manually, the user acts as the Creative Director by describing high-level intentions (prompts). The AI Agent acts as the Junior Developer executing code changes instantly in Godot GDScript.

## 3. Mandatory Skill Requirement
>
> 🚨 **CRITICAL INSTRUCTION FOR AGENT WORKFLOW:**
> Whenever generating, modifying, refactoring, or reviewing any GDScript code or Godot scene architecture in this project, **YOU MUST POSITIVELY USE AND STRICTLY ADHERE TO THE DEDICATED SKILL** located at:
> `.agent/skills/godot-gdscript-patterns`
>
> Refer to `.agent/skills/godot-gdscript-patterns/SKILL.md` and `.agent/skills/godot-gdscript-patterns/resources/implementation-playbook.md` for proper Godot 4 architecture, signals, node structures, `@export` variables, and best practices.

## 4. Architectural Assumptions & Code Guidelines

1. **Godot 4 GDScript Compatibility:**
   - Always use Godot 4 syntax (`CharacterBody2D`, `@export`, `@onready`, `move_and_slide()`, typed variables).
2. **Modular & High-Impact Modifications:**
   - Code must be structured modularly so features can be added, tweaked, or toggled instantly during live prompts.
   - Isolate event handling into clean, dedicated methods (e.g., `apply_speed_boost()`, `trigger_crazy_scaling()`, `start_chasing_player()`).
   - Prioritize **high-impact visual/gameplay feedback** (scale changes, speed boosts, screen shakes, color flashes, particle bursts) over complex subtle calculations.
3. **Readability & Comments:**
   - Keep GDScript clean, concise, and well-commented.
   - Use clear variable names that are easy to explain during a live presentation.

## 5. Main Components

- **Player (`player.gd`):** Top-down 2D controller (`CharacterBody2D`) ready for live modifier injections (speed, size, colors, spacebar abilities).
- **Star (`star.gd`):** Collectible item (`Area2D`) with signal callbacks for score increments and trigger effects.
- **Meteor (`meteor.gd`):** Interactive obstacle (`Area2D` / `RigidBody2D`) with empty process/signal slots ready for live AI logic (e.g. tracking player, spinning).
- **Main (`main.gd` / UI):** Score tracker (`CanvasLayer` + `Label`) managing global state and game reset functions.
