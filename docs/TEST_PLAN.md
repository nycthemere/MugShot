# MugShot — Plan de Test & Stratégie Qualité

Ce document définit la stratégie de test globale pour l'addon Elder Scrolls Online **MugShot**. Il détaille la pyramide de tests, les suites de tests automatisées hors-ligne, ainsi que le protocole de recette manuelle en jeu pour les déploiements et mises à jour d'API.

---

## 1. Philosophie & Pyramide de Test

L'environnement ESO impose une approche hybride :
1. **Tests Automatisés Hors-Ligne (CLI Lua)** : Exécutables sans lancer le client de jeu grâce à un harnais de simulation (`EsoMock.lua`). Ils couvrent la logique métier, la transformation des données, la gestion d'état, les réglages et l'intégration interne.
2. **Protocole de Recette Manuelle En Jeu (Boîte Noire)** : Validation finale indispensable dans le moteur réel d'ESO (rendu visuel, fluidité de la souris, scènes d'interface et interactions en combat réel).

```text
               ▲
              / \     Recette Manuelle en Jeu (Boîte Noire)
             /   \    - Mannequins de test, Raids (Rockgrove/Sanity's Edge)
            /─────\   - Drag & drop, /mugshotmove, scènes HUD
           /       \
          /         \  Tests d'Intégration & Mocks (tests/EsoMock.lua)
         /           \ - EsoAdapter, NativeFrameBridge, EventBindings, View, Main
        /─────────────\
       /               \ Tests Unitaires Purs (Lua Standard)
      /                 \- TargetState, TargetPolicy, Presentation, Portraits, Localisation
     /───────────────────\
```

---

## 2. Suites de Tests Automatisées

L'ensemble des tests s'exécute d'une seule commande depuis la racine de l'addon :
```bash
lua tests/run.lua
```

### Inventaire des Suites

| Suite                 | Fichier                                                                 | Rôle & Périmètre                                                                                                                                                       |
|:----------------------|:------------------------------------------------------------------------|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **TargetState**       | [`tests/TargetStateTest.lua`](../tests/TargetStateTest.lua)             | Cycle de vie de l'état canonique, initialisation, reset atomique, incrémentation de génération.                                                                        |
| **TargetPolicy**      | [`tests/TargetPolicyTest.lua`](../tests/TargetPolicyTest.lua)           | Règle de visibilité conditionnelle (`exists == true`).                                                                                                                 |
| **Presentation**      | [`tests/PresentationTest.lua`](../tests/PresentationTest.lua)           | Formatage des nombres (`2.1m`, `5k`), calculs de pourcentages, gestion des boucliers, noms de joueurs vs PNJ, et slots de buffs.                                       |
| **Portraits**         | [`tests/PortraitsTest.lua`](../tests/PortraitsTest.lua)                 | Résolution des portraits spécifiques (boss d'épreuves, mannequins), fallbacks de classe, icônes statiques et atlas animés `LibCustomIcons` / `HodorReflexes`.          |
| **Localisation**      | [`tests/LocalisationTest.lua`](../tests/LocalisationTest.lua)           | Intégrité des dictionnaires bilingues (en / fr), parité des clés, formattage avec arguments, et fallbacks.                                                             |
| **TargetController**  | [`tests/TargetControllerTest.lua`](../tests/TargetControllerTest.lua)   | Orchestration complète, gestion des modes déplacement et debug, mise à jour dynamique des réactions, et **barrière de génération (Generation Fence)**.                 |
| **EsoAdapter**        | [`tests/EsoAdapterTest.lua`](../tests/EsoAdapterTest.lua)               | Extraction sécurisée de l'identité, de la vie, du bouclier et tri des buffs (priorité aux effets du joueur et tri par durée restante).                                 |
| **NativeFrameBridge** | [`tests/NativeFrameBridgeTest.lua`](../tests/NativeFrameBridgeTest.lua) | Suppression réversible du cadre natif (`ZO_TargetUnitFramereticleover`), respect des masquages par d'autres addons (`_wasHiddenByUs`), et résilience en cas d'absence. |
| **EventBindings**     | [`tests/EventBindingsTest.lua`](../tests/EventBindingsTest.lua)         | Inscription/désinscription des événements ESO, configuration des filtres de puissance et d'unitTag, ticker d'effets 250ms.                                             |
| **Settings**          | [`tests/SettingsTest.lua`](../tests/SettingsTest.lua)                   | Chargement, fusion récursive des options par défaut, migration automatique de schéma (`schemaVersion`), et persistance `Set()`.                                        |
| **TargetFrameView**   | [`tests/TargetFrameViewTest.lua`](../tests/TargetFrameViewTest.lua)     | Hiérarchie de contrôles UI, barres de santé/bouclier, badges d'alliance et de race, pool de 10 slots de buffs, bordure cyan en mode déplacement.                       |
| **MainIntegration**   | [`tests/MainIntegrationTest.lua`](../tests/MainIntegrationTest.lua)     | Démarrage via `EVENT_ADD_ON_LOADED`, enregistrement et fonctionnement des 4 commandes slash (`/mugshot`, `/mugshotmove`, `/mugshotreset`, `/mugshothodor`).            |

---

## 3. Protocole de Recette Manuelle En Jeu (Boîte Noire)

Cette checklist doit être validée avant chaque publication de version ou mise à jour d'APIVersion.

### Étape 1 : Premier Lancement (Profil Vierge)
1. Supprimer ou renommer temporairement `SavedVariables/MugShotSV.lua`.
2. Se connecter sur un personnage en jeu.
3. Vérifier l'absence d'erreurs d'interface (UI Errors / BugCatcher).
4. Vérifier que le cadre se positionne par défaut à `TOPLEFT (100, 200)`.

### Étape 2 : Commandes Slash & Mode Déplacement
1. **`/mugshotmove` (Déverrouillage)** :
   * Le curseur de la souris doit apparaître (`SetGameCameraUIMode(true)`).
   * Le cadre affiche une prévisualisation **WYSIWYG** du joueur actuel (nom, santé, bouclier, icône de classe/avatar).
   * Une bordure cyan lumineuse entoure la barre de vie et le cadre de portrait.
   * Si le joueur n'a aucun buff, 3 icônes d'exemples doivent s'afficher.
2. **Glisser-Déplacer (Drag & Drop)** :
   * Cliquer et maintenir le bouton gauche sur n'importe quelle partie du cadre (barre de vie, portrait, conteneur de buffs).
   * Déplacer le cadre vers un nouvel endroit. Le déplacement doit être fluide et bloqué aux bords de l'écran (`ClampedToScreen`).
3. **`/mugshotmove` (Verrouillage)** :
   * La caméra revient en mode normal.
   * La position doit être conservée et persistée dans `MugShotSV`.
4. **`/mugshotreset`** :
   * Vérifier que le cadre revient instantanément aux coordonnées `(100, 200)` et que le mode déplacement s'active.
5. **`/mugshot` (Désactivation/Réactivation)** :
   * Taper `/mugshot` : le cadre MugShot disparaît, et le cadre de cible d'origine d'ESO réapparaît immédiatement sous le réticule.
   * Retapez `/mugshot` : MugShot reprend le contrôle et masque à nouveau le cadre natif.

### Étape 3 : Scénarios de Combat & Ciblage
1. **Mannequin de raid (Target Dummy)** :
   * Cibler un *Target Iron Atronach* : vérifier le portrait spécifique, la barre rouge foncé, et le texte `21m/21m`.
2. **Transition Neutre → Hostile** :
   * Cibler un PNJ neutre (barre jaune `255, 215, 0`).
   * Attaquer le PNJ : au premier impact de dégâts, la barre doit immédiatement basculer en rouge vif sans désélectionner la cible.
3. **Ciblage Joueur & Avatars Hodor** :
   * Cibler un autre joueur ayant un avatar HodorReflexes / LibCustomIcons configuré : le portrait personnalisé et ses coordonnées UV doivent s'afficher.
   * Taper `/mugshothodor` : le portrait doit basculer instantanément sur l'icône de classe native gamepad sans recharger l'interface.
4. **Bouclier d'absorption (Damage Shield)** :
   * Cibler une unité disposant d'un bouclier (ou soi-même en mode `/mugshotmove` avec un bouclier actif) :
   * La jauge cyan translucide doit se superposer sur la barre de vie.
   * Le texte doit inclure la valeur entre crochets (ex: `24.3k/24.3k [3.6k]`).
5. **Comptes à rebours des Buffs/Debuffs** :
   * Appliquer un effet avec durée (ex: dot ou vulnérabilité) :
   * Le décompte doit s'égrener chaque seconde de façon fluide (géré par le ticker 250ms).
   * L'icône doit disparaître ou le slot se vider à l'expiration.

### Étape 4 : Intégration des Scènes HUD
1. Avoir une cible sous le réticule.
2. Appuyer sur `Entrée` pour ouvrir le chat : le cadre MugShot **doit rester visible** (`HUD_UI_SCENE`).
3. Ouvrir l'inventaire (`I`) ou la carte (`M`) : le cadre doit se masquer proprement avec le reste du HUD de combat.
4. Perdre la cible (regarder le sol) : le cadre doit disparaître instantanément.

---

## 4. Tests de Performance & GC (Garbage Collector)

* **Environnement recommandé** : Épreuve à 12 joueurs (ex: *Rockgrove*, *Dreadsail Reef*).
* **Critères d'acceptation** :
  * Aucun pic de gel (stuttering) ressenti lors du ciblage d'un boss avec 50+ effets actifs.
  * Arrêt automatique du ticker 250ms (`StopEffectTimer`) dès qu'aucune cible n'existe ou que la cible n'a que des effets passifs (durée = 0).
  * Consommation mémoire de l'addon stable au fil du temps.

---

## 5. Procédure de Validation lors d'une Mise à Jour d'APIVersion ESO

Lors de la sortie d'un nouveau patch majeur ou d'une mise à jour de l'API (ex: `101051` vers `101052`) :
1. Mettre à jour `## APIVersion` dans [`MugShot.txt`](../MugShot.txt).
2. Lancer la suite de test locale : `lua tests/run.lua`.
3. Vérifier les éventuelles modifications de signatures dans la documentation d'API officielle de ZeniMax (`ESOUIDocumentation.txt`).
4. Exécuter la checklist de recette en jeu sur le PTS (Public Test Server).
5. Empaqueter via `python package_addon.py`.
