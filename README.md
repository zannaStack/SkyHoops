# Hoop Climb (Working Title)

> Un physics-runner 2D arcade per Android sviluppato con Godot 4.
> Combina la corsa su colline ondulate in stile *Hill Climb Racing*, la precisione aerea dei tiri ai cerchi stile *Quidditch* e l'ascesa verticale di *Doodle Jump*.

---

## 🎮 Concept di Gioco
- **Core Loop:** Corri su terreni accidentati e mantieni viva la barra della **Stamina**.
- **Bullet Time Aim:** Tocca e trascina lo schermo per rallentare il tempo, calcolare la traiettoria parabolica e scagliare la palla nei canestri.
- **Canestri & Dimensioni:** 
  - Canestri Standard: ricarica stamina base + 1 moneta.
  - Canestri Micro: ricarica stamina aumentata + mega turbo + 3 monete.
- **Upgrade System:** Spendi le monete per potenziare **Forza** (velocità e turbo) e **Mirino** (lunghezza e precisione traiettoria).

---

## 🛠️ Stack Tecnologico
- **Engine:** Godot Engine 4 (2D)
- **Linguaggio:** GDScript
- **Piattaforma:** Android (Google Play Store)
- **Target Design:** 2D Flat / Cartoon pulito

---

## 📂 Struttura del Progetto (Pianificata)
```text
├── assets/         # Sprite, font ed effetti sonori
├── scenes/         # Scene di Godot (.tscn)
│   ├── Ball.tscn
│   ├── Hoop.tscn
│   ├── Player.tscn
│   └── Main.tscn
├── scripts/        # Script GDScript (.gd)
├── GAME_DESIGN_DOCUMENT.md
└── README.md
```

---

## 🚀 Roadmap di Sviluppo
- [x] **Milestone 0:** Setup repository, .gitignore e Game Design Document.
- [ ] **Milestone 1:** Palla e fisica balistica 2D.
- [ ] **Milestone 2:** Input Drag-to-Aim con Bullet Time.
- [ ] **Milestone 3:** Mirino predittivo a parabola con `Line2D`.
- [ ] **Milestone 4:** Canestro con rilevamento goal (`Area2D`).
- [ ] **Milestone 5:** Personaggio, scorrimento terreno e camera follow.
- [ ] **Milestone 6:** Barra stamina, turbo boost e loop di Game Over.
- [ ] **Milestone 7:** Sistema monete, negozio upgrade (Forza/Mirino) e salvataggi.
- [ ] **Milestone 8:** Build Android (`.aab`) e test su dispositivo.
