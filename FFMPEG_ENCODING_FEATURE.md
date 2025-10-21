# 🎬 FFmpeg Encoding Feature - Documentation Complète

## Vue d'ensemble

Cette fonctionnalité ajoute l'encodage automatique FFmpeg dans le pipeline d'importation de Sonarr, permettant de transcoder les fichiers vidéo à la volée entre le téléchargement et l'importation dans la bibliothèque.

---

## 🎯 Cas d'Usage

### Pourquoi utiliser cette fonctionnalité ?

1. **Gain d'espace disque** : Re-encoder en HEVC peut réduire la taille des fichiers de 30-70%
2. **Standardisation** : Unifier tous vos médias dans un seul codec/format
3. **Optimisation streaming** : Encoder pour vos appareils (Plex, Jellyfin, etc.)
4. **Hardware transcoding** : Utiliser NVENC/AMF/QuickSync pour encoder rapidement
5. **Automatisation** : Pas besoin de scripts externes ou de post-processing manuel

### Exemples concrets

**Scénario 1**: Vous téléchargez un épisode en H.264 1080p (2.5 GB)
- ✅ Sonarr encode automatiquement en HEVC/Opus
- ✅ Fichier final : 1.2 GB (-52% de taille)
- ✅ Qualité visuelle quasi-identique
- ✅ Importé directement dans la bibliothèque

**Scénario 2**: Vous avez un GPU NVIDIA et voulez encoder rapidement
- ✅ Utilisation de NVENC (encodage matériel)
- ✅ Un épisode 1080p encode en ~2-5 minutes
- ✅ CPU reste disponible pour d'autres tâches

**Scénario 3**: Vous voulez encoder uniquement les gros fichiers
- ✅ Configurez "Minimum Size: 3 GB"
- ✅ Les petits fichiers sont importés directement
- ✅ Économise du temps de traitement

---

## 📋 Configuration

### Accéder aux paramètres

1. Ouvrir Sonarr
2. Aller dans **Settings** → **Media Management**
3. Scroller jusqu'à la section **"FFmpeg Encoding"**

### Options disponibles

#### ✅ Enable FFmpeg Encoding
- **Type**: Checkbox
- **Par défaut**: Désactivé
- **Description**: Active/désactive l'encodage automatique
- **Recommandation**: Activez après avoir testé votre configuration FFmpeg

#### 🔧 FFmpeg Path
- **Type**: Text
- **Par défaut**: `ffmpeg`
- **Description**: Chemin vers l'exécutable FFmpeg
- **Exemples**:
  - Windows: `C:\ffmpeg\bin\ffmpeg.exe`
  - Linux: `/usr/bin/ffmpeg`
  - macOS: `/opt/homebrew/bin/ffmpeg`
  - Dans le PATH: `ffmpeg`

#### 🎛️ FFmpeg Arguments
- **Type**: Text (large)
- **Par défaut**: `-c:v hevc_nvenc -preset p1 -b:v 4M -c:a libopus -b:a 128k`
- **Description**: Arguments de ligne de commande passés à FFmpeg
- **⚠️ Important**: Ne pas inclure `-i input` ni `output` (géré automatiquement)

**Exemples d'arguments**:

```bash
# NVIDIA GPU (NVENC) - Rapide
-c:v hevc_nvenc -preset p1 -b:v 4M -c:a libopus -b:a 128k

# AMD GPU (AMF) - Rapide
-c:v hevc_amf -quality speed -b:v 4M -c:a libopus -b:a 128k

# Intel GPU (QuickSync) - Rapide
-c:v hevc_qsv -preset fast -b:v 4M -c:a libopus -b:a 128k

# CPU (lent mais meilleure qualité)
-c:v libx265 -preset medium -crf 23 -c:a libopus -b:a 128k

# Qualité maximale (très lent)
-c:v libx265 -preset veryslow -crf 18 -c:a flac

# Vitesse maximale (qualité réduite)
-c:v hevc_nvenc -preset p1 -b:v 2M -c:a copy

# Encodage 2-pass pour meilleure qualité
-c:v libx265 -preset slow -b:v 4M -pass 1 -an -f null /dev/null && \
-c:v libx265 -preset slow -b:v 4M -pass 2 -c:a libopus -b:a 128k

# Conserver audio/sous-titres originaux
-c:v hevc_nvenc -preset p1 -b:v 4M -c:a copy -c:s copy

# HDR preserving (HEVC 10-bit)
-c:v hevc_nvenc -preset p4 -b:v 8M -pix_fmt p010le -c:a copy
```

#### 🗑️ Delete Original File
- **Type**: Checkbox
- **Par défaut**: Désactivé
- **Description**: Supprime le fichier original après encodage réussi
- **Comportement**:
  - ✅ **Coché**: Le fichier encodé remplace l'original (même nom)
  - ☐ **Décoché**: Les deux fichiers sont conservés (`.encoded.mkv` créé)
- **⚠️ Attention**: Activez uniquement si vous êtes sûr de vos paramètres d'encodage

#### 📏 Minimum Size (GB)
- **Type**: Number
- **Par défaut**: 0
- **Unité**: Gigabytes (Go)
- **Description**: Taille minimale du fichier pour déclencher l'encodage
- **Exemples**:
  - `0` : Encode tous les fichiers
  - `1` : Encode uniquement les fichiers > 1 GB
  - `3` : Encode uniquement les fichiers > 3 GB (épisodes 1080p/4K)
- **Recommandation**: 1-2 GB pour skip les petits fichiers déjà compressés

#### ⏭️ Skip Files Already in HEVC/H265
- **Type**: Checkbox
- **Par défaut**: Activé
- **Description**: Ignore les fichiers déjà encodés en HEVC/H.265
- **Détection**: Analyse le codec vidéo via MediaInfo
- **Recommandation**: Gardez activé pour éviter de re-encoder inutilement

#### ⏱️ Encoding Timeout (Minutes)
- **Type**: Number
- **Par défaut**: 0
- **Unité**: Minutes
- **Description**: Temps maximum autorisé pour l'encodage
- **Comportement**:
  - `0` : Aucun timeout (illimité)
  - `60` : Timeout après 1 heure
  - `120` : Timeout après 2 heures
- **⚠️ Si timeout atteint**: L'encodage est arrêté et le fichier original est importé
- **Recommandation**:
  - `0` pour encodages CPU lents
  - `60-120` pour encodages GPU rapides

---

## 🔄 Workflow Détaillé

```
┌─────────────────────────────────────────────────────────────┐
│  1. Téléchargement Terminé (Download Client)               │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  2. CompletedDownloadService - Détection fin de download   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  3. DownloadedEpisodesImportService.ProcessFile()          │
│     - Validation extension (.mkv, .mp4, etc.)              │
│     - Vérification fichier locked                          │
│     - Vérification fichiers dangereux                       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  4. 🆕 FFmpeg Encoding (SI ACTIVÉ)                          │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ a) Vérification conditions (ShouldEncode)          │   │
│  │    - FFmpeg activé ?                                │   │
│  │    - Fichier > taille minimum ?                     │   │
│  │    - Déjà HEVC ? (si skip activé)                   │   │
│  └─────────────────────────────────────────────────────┘   │
│                         │                                   │
│                         ▼                                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ b) Récupération MediaInfo                           │   │
│  │    - Lecture codec vidéo (H.264, HEVC, etc.)       │   │
│  │    - Extraction métadonnées                         │   │
│  └─────────────────────────────────────────────────────┘   │
│                         │                                   │
│                         ▼                                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ c) Création fichier temporaire                      │   │
│  │    - Nom: [filename].encoding.mkv                   │   │
│  │    - Même dossier que l'original                    │   │
│  └─────────────────────────────────────────────────────┘   │
│                         │                                   │
│                         ▼                                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ d) Exécution FFmpeg                                 │   │
│  │    - Commande: ffmpeg -i input.mkv [args] temp.mkv │   │
│  │    - Monitoring progression (time=XX:XX:XX)         │   │
│  │    - Logging en temps réel (Trace/Debug)            │   │
│  │    - Timeout si configuré                           │   │
│  └─────────────────────────────────────────────────────┘   │
│                         │                                   │
│                         ▼                                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ e) Vérification résultat                            │   │
│  │    - Exit code = 0 ?                                │   │
│  │    - Fichier de sortie existe ?                     │   │
│  │    - Taille > 0 bytes ?                             │   │
│  └─────────────────────────────────────────────────────┘   │
│                         │                                   │
│            ┌────────────┴────────────┐                      │
│            ▼                         ▼                      │
│  ┌──────────────────┐      ┌──────────────────────┐        │
│  │ f) SUCCÈS        │      │ g) ERREUR            │        │
│  │                  │      │                      │        │
│  │ Delete original? │      │ - Log erreur         │        │
│  │                  │      │ - Cleanup temp file  │        │
│  │ ✓ OUI:           │      │ - Return original    │        │
│  │   - Delete orig  │      │                      │        │
│  │   - Rename temp  │      └──────────────────────┘        │
│  │                  │                                       │
│  │ ✗ NON:           │                                       │
│  │   - Keep orig    │                                       │
│  │   - Save .encoded│                                       │
│  └──────────────────┘                                       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  5. ImportDecisionMaker - Évaluation du fichier (encodé)   │
│     - Vérification qualité                                  │
│     - Matching avec épisodes                                │
│     - Vérification upgrades                                 │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  6. ImportApprovedEpisodes - Import final                  │
│     - Déplacement vers bibliothèque                         │
│     - Renommage selon format configuré                      │
│     - Mise à jour base de données                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  7. ✅ Fichier disponible dans la bibliothèque Sonarr       │
└─────────────────────────────────────────────────────────────┘
```

---

## 📊 Logs et Monitoring

### Logs produits par la fonctionnalité

L'encodage FFmpeg produit des logs détaillés dans Sonarr :

#### Niveau TRACE
```
FFmpeg: frame= 1234 fps= 87 q=28.0 size=   12345kB time=00:01:23.45 bitrate=1234.5kbits/s speed=3.48x
```

#### Niveau DEBUG
```
FFmpeg encoding is enabled, checking if file should be encoded: /downloads/Show.S01E01.mkv
Executing FFmpeg: ffmpeg -i "/downloads/Show.S01E01.mkv" -c:v hevc_nvenc -preset p1 -b:v 4M -c:a libopus -b:a 128k "/downloads/Show.S01E01.encoding.mkv" -y
FFmpeg encoding progress: 83.45s encoded
Encoded file size: 1234567890 bytes
Keeping both original and encoded files
```

#### Niveau INFO
```
Starting FFmpeg encoding for file: /downloads/Show.S01E01.mkv
File was encoded by FFmpeg, using encoded file for import: /downloads/Show.S01E01.encoded.mkv
FFmpeg encoding completed successfully for: /downloads/Show.S01E01.mkv
```

#### Niveau ERROR
```
FFmpeg encoding failed with exit code 1. Error: [error details]
Error during FFmpeg encoding, continuing with original file: /downloads/Show.S01E01.mkv
```

### Accéder aux logs

**Via Interface Web**:
1. System → Logs → Files
2. Chercher "FFmpeg" ou "Encoding"

**Fichiers de log** (Windows):
```
C:\ProgramData\Sonarr\logs\sonarr.txt       # Log principal
C:\ProgramData\Sonarr\logs\sonarr.debug.txt # Debug détaillé
```

---

## ⚡ Performance et Temps d'Encodage

### Comparaison selon le hardware

| Hardware | Épisode 1080p (2GB) | Film 4K (40GB) |
|----------|---------------------|----------------|
| **CPU i5 (libx265)** | ~30-45 min | ~8-12 heures |
| **CPU i9 (libx265)** | ~15-25 min | ~4-6 heures |
| **NVIDIA RTX 3060 (NVENC)** | ~2-4 min | ~30-60 min |
| **NVIDIA RTX 4090 (NVENC)** | ~1-2 min | ~15-30 min |
| **AMD RX 6800 (AMF)** | ~2-5 min | ~40-80 min |
| **Intel Arc A770 (QuickSync)** | ~2-4 min | ~30-70 min |

### Facteurs influençant la vitesse

1. **Codec source**: H.264 → HEVC plus rapide que VP9 → HEVC
2. **Résolution**: 720p < 1080p < 4K < 8K
3. **Preset FFmpeg**: `p1` (rapide) vs `p7` (lent)
4. **Bitrate cible**: Plus bas = plus rapide
5. **Complexité vidéo**: Animation simple < film d'action < grain de film

---

## 🎛️ Configurations Recommandées

### Configuration 1: Débutant (Sûr)
```
✅ Enable FFmpeg Encoding: Activé
FFmpeg Path: ffmpeg
FFmpeg Arguments: -c:v libx265 -crf 23 -c:a copy
Delete Original: ☐ Désactivé
Minimum Size: 2 GB
Skip HEVC: ✅ Activé
Timeout: 180 minutes
```
**Avantages**: Encodage CPU compatible partout, qualité excellente, fichiers conservés
**Inconvénients**: Lent

### Configuration 2: GPU NVIDIA (Rapide)
```
✅ Enable FFmpeg Encoding: Activé
FFmpeg Path: ffmpeg
FFmpeg Arguments: -c:v hevc_nvenc -preset p4 -b:v 5M -c:a libopus -b:a 160k
Delete Original: ✅ Activé
Minimum Size: 1 GB
Skip HEVC: ✅ Activé
Timeout: 60 minutes
```
**Avantages**: Très rapide, bonne qualité
**Inconvénients**: Nécessite GPU NVIDIA

### Configuration 3: Économie d'Espace Maximale
```
✅ Enable FFmpeg Encoding: Activé
FFmpeg Path: ffmpeg
FFmpeg Arguments: -c:v libx265 -crf 28 -preset slow -c:a libopus -b:a 96k
Delete Original: ✅ Activé
Minimum Size: 0 GB
Skip HEVC: ✅ Activé
Timeout: 0
```
**Avantages**: Gain d'espace maximal (60-80%)
**Inconvénients**: Très lent, qualité légèrement réduite

### Configuration 4: Qualité Maximale
```
✅ Enable FFmpeg Encoding: Activé
FFmpeg Path: ffmpeg
FFmpeg Arguments: -c:v libx265 -crf 18 -preset veryslow -c:a flac
Delete Original: ☐ Désactivé
Minimum Size: 5 GB
Skip HEVC: ✅ Activé
Timeout: 0
```
**Avantages**: Qualité visuelle quasi-transparente
**Inconvénients**: Très lent, fichiers volumineux

### Configuration 5: Compatible Plex/Jellyfin
```
✅ Enable FFmpeg Encoding: Activé
FFmpeg Path: ffmpeg
FFmpeg Arguments: -c:v hevc_nvenc -preset p4 -b:v 6M -c:a aac -b:a 192k -c:s mov_text
Delete Original: ✅ Activé
Minimum Size: 1 GB
Skip HEVC: ✅ Activé
Timeout: 120 minutes
```
**Avantages**: Direct play sur Plex/Jellyfin, sous-titres préservés
**Inconvénients**: Nécessite GPU

---

## 🐛 Troubleshooting

### Problème: FFmpeg ne démarre pas

**Symptômes**:
```
FFmpeg encoding is enabled but FFmpeg path is not configured
Error during FFmpeg encoding, continuing with original file
```

**Solutions**:
1. Vérifier que FFmpeg est installé: `ffmpeg -version`
2. Utiliser le chemin complet: `C:\ffmpeg\bin\ffmpeg.exe`
3. Ajouter FFmpeg au PATH système
4. Vérifier les permissions d'exécution

### Problème: Encodage très lent

**Symptômes**: Encodage prend plusieurs heures

**Solutions**:
1. Utiliser un preset plus rapide: `-preset fast` ou `-preset p1`
2. Passer à l'encodage GPU (NVENC/AMF/QuickSync)
3. Augmenter le bitrate au lieu de CRF: `-b:v 4M`
4. Réduire la qualité: `-crf 28` au lieu de `-crf 20`

### Problème: Fichier encodé plus gros que l'original

**Symptômes**: Le fichier `.encoded.mkv` est plus volumineux

**Causes possibles**:
- Bitrate trop élevé (`-b:v 10M` pour un fichier déjà compressé)
- Source déjà bien compressée (x265, AV1)
- Audio non compressé (`-c:a flac`)

**Solutions**:
1. Réduire le bitrate: `-b:v 3M`
2. Activer "Skip HEVC" pour éviter de re-encoder
3. Compresser l'audio: `-c:a libopus -b:a 128k`
4. Utiliser CRF au lieu de bitrate: `-crf 23`

### Problème: Qualité dégradée après encodage

**Symptômes**: Image pixelisée, artifacts visibles

**Solutions**:
1. Réduire le CRF (plus bas = meilleure qualité): `-crf 20` au lieu de `-crf 28`
2. Augmenter le bitrate: `-b:v 6M` au lieu de `-b:v 3M`
3. Utiliser un preset plus lent: `-preset medium` au lieu de `-preset fast`
4. Pour NVENC, utiliser un preset plus lent: `-preset p6` au lieu de `-preset p1`

### Problème: Timeout atteint systématiquement

**Symptômes**:
```
FFmpeg encoding timed out after 60 minutes
```

**Solutions**:
1. Augmenter le timeout: `120` ou `0` (illimité)
2. Utiliser un preset plus rapide
3. Passer à l'encodage GPU
4. Augmenter le "Minimum Size" pour skip les gros fichiers

### Problème: Erreur "Cannot find encoder"

**Symptômes**:
```
Unknown encoder 'hevc_nvenc'
```

**Solutions**:
1. Vérifier les encodeurs disponibles: `ffmpeg -encoders | grep hevc`
2. Pour NVENC: Installer pilotes NVIDIA récents
3. Pour AMF: Installer pilotes AMD récents
4. Fallback sur CPU: `-c:v libx265`

### Problème: Sous-titres perdus après encodage

**Solutions**:
1. Ajouter `-c:s copy` aux arguments FFmpeg
2. Pour sous-titres bitmap: `-c:s dvdsub`
3. Pour MP4: `-c:s mov_text`

---

## 📈 Statistiques et Métriques

### Gain d'espace typique

| Source | Encodage | Réduction Taille |
|--------|----------|------------------|
| H.264 1080p → HEVC 1080p | CRF 23 | ~40-50% |
| H.264 1080p → HEVC 1080p | CRF 28 | ~60-70% |
| H.264 4K → HEVC 4K | CRF 23 | ~50-60% |
| MPEG-2 → HEVC | CRF 20 | ~70-85% |

### Qualité visuelle (VMAF)

| CRF | VMAF Score | Qualité Perçue |
|-----|------------|----------------|
| 18 | 95-98 | Quasi-transparente |
| 20 | 92-95 | Excellente |
| 23 | 88-92 | Très bonne |
| 26 | 82-88 | Bonne |
| 28 | 75-82 | Acceptable |
| 30+ | <75 | Dégradée |

---

## 🔐 Sécurité

### Validation des arguments FFmpeg

⚠️ **Important**: Les arguments FFmpeg sont exécutés directement par le système. Sonarr ne valide pas la sécurité des commandes.

**Bonnes pratiques**:
- ❌ Ne PAS inclure de commandes shell (`&&`, `;`, `|`)
- ❌ Ne PAS utiliser de variables non contrôlées
- ✅ Utiliser uniquement des arguments FFmpeg standards
- ✅ Tester les arguments manuellement avant configuration

**Exemple UNSAFE** ❌:
```
-c:v hevc_nvenc -b:v 4M; rm -rf /
```

**Exemple SAFE** ✅:
```
-c:v hevc_nvenc -preset p4 -b:v 4M -c:a libopus -b:a 128k
```

---

## 🚀 Évolutions Futures (Suggestions)

- [ ] Interface de test FFmpeg dans Settings
- [ ] Profils d'encodage prédéfinis (Low/Medium/High)
- [ ] Statistiques d'encodage (temps total, espace économisé)
- [ ] Queue d'encodage avec priorités
- [ ] Encodage en arrière-plan (non bloquant)
- [ ] Support multi-GPU
- [ ] Encodage HDR → SDR tone mapping
- [ ] Intégration Tdarr-like pour bibliothèque existante

---

## 📞 Support

- **Bugs**: [GitHub Issues](https://github.com/aubertlucas/Sonarr/issues)
- **Discussion**: [Sonarr Forums](https://forums.sonarr.tv/)
- **Discord**: [Sonarr Discord](https://discord.gg/M6BvZn5)

---

## 📄 Licence

Cette fonctionnalité est distribuée sous licence GPL-3.0, en accord avec le projet Sonarr.

---

**Créé par**: Claude Code
**Version**: 1.0.0
**Date**: 2025-01-21

🤖 Generated with [Claude Code](https://claude.com/claude-code)
