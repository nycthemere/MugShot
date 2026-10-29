# MugShot — Live UI Preview (Love2D)

Outil de prévisualisation graphique interactif et dynamique pour tester l'interface de MugShot hors d'Elder Scrolls Online en temps réel, sans avoir à lancer le jeu.

Le moteur de prévisualisation est **100 % branché sur le vrai code source de l'addon** (contrôleur, adapteur, résolveur de portraits, formatage de présentation et styles) et dispose d'un **système de rechargement à chaud (Hot-Reload)** automatique dès qu'un fichier source est sauvegardé.

---

## 1. Prérequis (Optionnel)

L'utilisation de cette prévisualisation est **100 % optionnelle** et n'a aucun impact sur les tests unitaires automatisés (`lua tests/run.lua`).

Pour lancer la prévisualisation graphique :
1. **LÖVE (Love2D)** : Téléchargeable sur [https://love2d.org/](https://love2d.org/).
   - Soit extrait en version portable dans `tests/preview/` (ex: dossier `love-11.5-win64/`).
   - Soit installé sur le système (`C:\Program Files\LOVE\love.exe`).
   - Soit accessible directement dans la variable d'environnement `PATH`.
2. **Python 3** *(optionnel, recommandé)* : Assure une détection sécurisée et multiplateforme (Windows, macOS, Linux).

---

## 2. Lancement

Plusieurs méthodes simples sont disponibles selon votre environnement :

### Méthode 1 : Script Python (Recommandé / Multiplateforme)
```bash
python tests/preview.py
```

### Méthode 2 : Double-clic Windows ou PowerShell
Double-cliquez sur **`tests/preview.bat`** ou lancez depuis PowerShell :
```powershell
.\tests\preview.bat
```
*(Le script batch délègue automatiquement à `preview.py` avec repli autonome).*

### Méthode 3 : Ligne de commande Love2D directe
```bash
love tests/preview
```

---

## 3. Commandes interactives & Contrôles

| Touche / Action | Effet | Détails |
| :--- | :--- | :--- |
| **`[1]`** | **Boss d'épreuve** | *Oaxiltso* (résolu dynamiquement via [`Data/Portraits.lua`](file:///C:/Users/sub/Documents/Elder Scrolls Online/live/Addons/MugShot/Data/Portraits.lua), PV 70%, debuffs actifs). |
| **`[2]`** | **Compagnon** | *Bastian Hallix* (résolu dynamiquement via la catégorie de collectibles, vert allié). |
| **`[3]`** | **Familier** | *Familier instable* (résolu dynamiquement via les compétences de familier). |
| **`[4]`** ou **`[M]`** | **Mode Déplacement** | Exécute la véritable commande `/mugshot move` de l'addon (bordures cyan lumineuses, prévisualisation joueur WYSIWYG, déplacement à la souris déverrouillé). |
| **`[5]`** | **Sans Icône (Fallback)** | *Target Skeleton* (la jauge s'étire automatiquement sur 100% de la largeur du cadre). |
| **`[Gauche]` / `[Droite]`** | **Ajuster les PV** | Diminue / augmente les PV de 5% en direct (déclenche le vrai événement `EVENT_POWER_UPDATE`). |
| **`[S]`** | **Sur-Bouclier (Shield)** | Active / désactive le bouclier cyan (+20%) et met à jour le texte formaté (`[250k]`). |
| **`[+]` / `[B]`** | **Ajouter un effet** | Ajoute dynamiquement un buff ou débuff (timers courts, longs `3m`/`1h`, permanents, cumuls x2, x3, x5). |
| **`[-]`** | **Retirer un effet** | Retire le dernier effet pour tester la réduction du conteneur. |
| **`[T]`** | **Stress Test (14 effets)** | Injecte 14 effets sur 2 rangées complètes pour valider le wrapping (10 slots/ligne) et l'expansion en hauteur. |
| **`[X]`** | **Filtre Épreuve (Trial)** | Exécute la véritable commande `/mugshot trial` (bascule le filtre ennemis uniquement en Raid). |
| **`[D]`** | **Mort de la cible** | Déclenche `EVENT_UNIT_DEATH_STATE_CHANGED` (masque instantanément tout le cadre). |
| **`[R]`** | **Réinitialisation** | Exécute la véritable commande `/mugshot reset` (replace le cadre aux coordonnées par défaut `(100, 200)` et déverrouille le mode déplacement). |
| **Clic gauche + glisser** | **Déplacer le cadre** | Déplace le cadre à la souris n'importe où sur l'écran *(autorisé en mode `/mugshot move`)*. |
| **`[F5]`** | **Rechargement forcé** | Force le rechargement immédiat de l'ensemble du code source sans fermer la fenêtre. |
| **`[Échap]`** | **Quitter** | Ferme la fenêtre de prévisualisation. |

---

## 4. Architecture & Hot-Reloading

- **Pipeline Réel** : Aucun texte ou icône n'est codé en dur. Les données brutes d'unités sont transmises au mock ESO, qui déclenche les événements officiels (`EVENT_RETICLE_TARGET_CHANGED`, `EVENT_POWER_UPDATE`, etc.) traités par `TargetController` -> `EsoAdapter` -> `Portraits` -> `Presentation` -> `TargetFrameView`.
- **Défilement Continu des Timers** : Les décomptes s'égrènent chaque seconde via le ticker officiel de l'addon (`MugShot_TimerUpdate`). Dès qu'un effet arrive à expiration, il boucle automatiquement à sa durée initiale pour une observation continue.
- **Observateur de Fichiers (Hot-Reload)** : Un watcher intégré surveille les 16 fichiers sources de l'addon toutes les 300 ms. Toute modification enregistrée (`Ctrl+S`) dans votre éditeur est immédiatement rechargée et répercutée à l'écran sans interruption.
