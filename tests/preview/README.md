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
| **`[ZQSD]` / `[WASD]`** | **Déplacement 3D exclusif** | Déplace la caméra à la première personne dans l'arène 3D (strictement réservé au mouvement). |
| **`[Souris]`** | **Orientation Caméra** | Pivote naturellement la caméra à la première personne pour regarder librement et cibler au réticule. |
| **`[Tab]`** | **Basculer Curseur libre** | Alterne entre le verrouillage caméra FPS et le curseur souris libre. |
| **`[1]` - `[5]`** | **Viser une entité** | Aligne instantanément la caméra sur une des 5 entités interactives (Boss, Joueuse, Compagnon, Familier, Mannequin). |
| **`[Flèches G/D ou B/H]`**| **Ajuster les PV** | Diminue / augmente les PV de la cible de 5% (déclenche `EVENT_POWER_UPDATE`). |
| **`[H]`** | **Soin complet** | Restaure 100% des PV de la cible et la réanime si elle était morte. |
| **`[K]`** / **`[Espace]`**| **Sur-Bouclier (Shield)** | Active / désactive le bouclier (+20%) via `EVENT_UNIT_ATTRIBUTE_VISUAL_*`. |
| **`[J]`** / **`[Suppr]`** | **Mort / Vie** | Déclenche `EVENT_UNIT_DEATH_STATE_CHANGED` (masque le cadre à la mort comme dans ESO). |
| **`[+]` / `[B]`** | **Ajouter un effet** | Ajoute dynamiquement un buff ou débuff du catalogue avec statut `castByPlayer = true`. |
| **`[-]` / `[N]`** | **Retirer un effet** | Retire le dernier effet appliqué. |
| **`[T]`** | **Stress Test (14 effets)** | Injecte 14 effets sur 2 rangées complètes pour valider le layout et l'expansion. |
| **`[G]`** | **Basculer Solo / Groupe** | Alterne entre Mode Solo (isolation stricte des débuffs joueur) et Mode Groupe 4 joueurs (affichage des débuffs alliés et fusions de badges multi-sources avec timer maximal). |
| **`[M]`** | **Mode Déplacement** | Exécute la véritable commande `/mugshot move` (bordures cyan, prévisualisation joueur, libération du curseur pour déplacement à la souris). |
| **`[X]`** | **Filtre Épreuve (Trial)** | Exécute la véritable commande `/mugshot trial` (bascule le filtre ennemis uniquement en Raid). |
| **`[R]`** | **Réinitialisation simulation** | Réinitialise complètement la simulation (restaure les 5 cibles, leurs PV à 100%, leurs effets initiaux, verrouille le cadre et le replace aux coordonnées par défaut). |
| **`[F1]`** | **Guide d'aide à l'écran** | Affiche / masque le panneau d'aide des commandes et raccourcis en surimpression. |
| **Clic gauche + glisser** | **Déplacer le cadre** | Déplace le cadre à la souris n'importe où sur l'écran *(autorisé en mode `/mugshot move`)*. |
| **`[F5]`** | **Rechargement forcé** | Force le rechargement immédiat de l'ensemble du code source sans fermer la fenêtre. |
| **`[Échap]`** | **Quitter** | Ferme la fenêtre de prévisualisation. |

---

## 4. Architecture & Hot-Reloading

- **Architecture Modulaire et Découplée** :
  - **`Arena3D.lua`** : Projection 3D à la première personne, géométrie de l'arène, piliers, brasiers animés et raycast du réticule.
  - **`Entities.lua`** : Définition des cibles 3D, catalogue d'effets et déclenchement d'événements ESO natifs purs (`EVENT_RETICLE_TARGET_CHANGED`, `EVENT_POWER_UPDATE`, etc.).
  - **`EsoUiRenderer.lua`** : Moteur de rendu Love2D agnostique pour les contrôles ESO (backdrops, textures, labels alignés nativement via `hAlign` et `vAlign`).
  - **`main.lua`** : Orchestrateur concis coordonnant l'arène, le mock ESO, et le rafraîchissement graphique.
- **Pipeline Événementiel Pur** : Aucune méthode privée du contrôleur n'est appelée directement. Toutes les mutations passent par les événements d'Elder Scrolls Online.
- **Observateur de Fichiers (Hot-Reload)** : Un watcher intégré surveille les fichiers sources de l'addon toutes les 300 ms. Toute modification enregistrée (`Ctrl+S`) est immédiatement rechargée et répercutée à l'écran sans interruption.
