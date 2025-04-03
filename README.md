# WPCheck – Le Scanner de Sécurité WordPress Complet

## 🧐 Qu'est-ce que WPCheck ?

**WPCheck** est un scanner de sécurité **tout-en-un pour WordPress** écrit en Bash. Il automatise l'installation d'une série d'outils de sécurité et exécute plusieurs tests afin de détecter les vulnérabilités, les mauvaises configurations et les expositions courantes sur les sites WordPress. Que vous souhaitiez vérifier l'accessibilité de fichiers sensibles, scanner pour des vulnérabilités de login ou obtenir une note de sécurité détaillée via MDN Observatory, WPCheck centralise toutes ces fonctionnalités dans un seul script facile à utiliser.

---

## 🚀 Comment ça marche

1. **Préparation & Configuration de l'Environnement**  
   - Création des dossiers nécessaires (`data` et `output`) pour stocker les wordlists, les installations d'outils et les rapports de scan.
   - Vérification et installation automatique des outils requis tels que :
     - **WPScan** pour l'analyse des vulnérabilités et l'énumération des plugins.
     - **Dirb** avec une wordlist spécifique à WordPress pour la découverte de répertoires exposés.
     - **Nikto** pour le scan approfondi des vulnérabilités du serveur web.
     - **Wapiti** pour l'évaluation des vulnérabilités web (installé dans un environnement virtuel Python).
     - **Hydra** pour tester les mots de passe par défaut sur la page de login.
     - **wpprobe** (installé via Go) pour une analyse supplémentaire des plugins.
   - Vérification de l'installation de **Go** si wpprobe doit être utilisé.

2. **Scan & Analyse**  
   - **Scan wpprobe :** Installe, met à jour et exécute wpprobe (outil Go) sur le site cible.
   - **Scan Wapiti :** Réalise un scan des vulnérabilités web et enregistre un rapport détaillé dans le dossier `output`.
   - **Scan Dirb :** Utilise une wordlist WordPress pour détecter des répertoires exposés ou, en mode passif, récupère le contenu de `robots.txt`.
   - **Scan Nikto :** Vérifie les vulnérabilités connues du serveur web.
   - **Scan WPScan :** Exécute WPScan avec des options adaptées aux modes actif ou passif.
   - **Vérifications des Fichiers & Endpoints :**  
     - Contrôle l’accessibilité de pages et fichiers critiques tels que `wp-login.php`, `xmlrpc.php`, `debug.log`, les sauvegardes de `wp-config.php` et `sitemap.xml`.
     - Télécharge le contenu du dossier `uploads` (s'il existe) dans le répertoire `output`, en filtrant les fichiers non désirés.
   - **Analyse des Headers de Sécurité :**  
     - Utilise l'API MDN Observatory pour vérifier la présence des bons headers HTTP de sécurité, en fournissant une note, un score et une URL de rapport détaillé.
   - **Test des Mots de Passe par Défaut :**  
     - Optionnellement, teste des combinaisons courantes (via Hydra) sur la page de login (cette étape est ignorée en mode passif).

---

## ⚙️ Fonctionnalités

- ✅ **Installation Automatique des Outils :** WPCheck installe les dépendances manquantes (WPScan, Hydra, Nikto, Dirb, Wapiti et Go pour wpprobe) de manière autonome.
- ✅ **Multiples Méthodes de Scan :** Combine les scans de wpprobe, Wapiti, Dirb, Nikto et WPScan pour une évaluation complète de la sécurité.
- ✅ **Vérification des Fichiers & Endpoints Critiques :** Analyse des fichiers tels que `xmlrpc.php`, `debug.log`, les sauvegardes de `wp-config.php` et `sitemap.xml`.
- ✅ **Évaluation des Headers de Sécurité :** Grâce à l'API MDN Observatory, obtention d'une note de sécurité et d'un score.
- ✅ **Téléchargement du Dossier Uploads :** Récupération des fichiers du dossier `uploads` (filtrage des fichiers non critiques) dans le dossier `output`.
- ✅ **Test des Mots de Passe par Défaut :** Possibilité d'exécuter un test de force brute sur la page de login avec Hydra.
- ✅ **Mode Passif :** Offre une option non agressive qui limite certaines fonctionnalités :
  - Pour Dirb, affiche uniquement le contenu de `robots.txt`.
  - Pour WPScan, limite certaines options agressives.
  - Ignore les tests de brute force et le téléchargement du dossier uploads.
- ✅ **Modularité :** Possibilité de passer certains tests via des options en ligne de commande (Dirb, Nikto, Wapiti ou vérification des mots de passe).

---

## 📌 Limitations

- 🔹 **Privilèges Sudo Nécessaires :** Certaines installations d'outils requièrent des droits administrateur.
- 🔹 **Impact Réseau :** Les scans actifs (notamment les tests de brute force) peuvent générer un trafic important – à utiliser de manière responsable.
- 🔹 **Variations Selon le Site :** Les résultats peuvent varier en fonction de la configuration et des mesures de sécurité mises en place sur le site cible.
- 🔹 **Contraintes du Mode Passif :** Le mode passif réduit l'impact sur le serveur, mais peut ne pas révéler l'ensemble des vulnérabilités.

---

## 🔧 Installation

### Prérequis

- **Bash**
- **curl, wget, git**
- **Python3 & pip** (pour Wapiti)
- **Go** (pour l'installation de wpprobe)
- **Privilèges sudo** (pour l'installation des dépendances manquantes)

### Installation Manuelle

1. **Cloner le Dépôt**
   ```bash
   git clone https://github.com/votre-utilisateur/wpcheck.git
   cd wpcheck
   ```
2. **Rendre le Script Exécutable**
   ```bash
   chmod +x wpcheck.sh
   ```
   
---

## 🕵️ Utilisation

### Paramètre Requis

- `--url <site_url>`  
  Spécifie l'URL du site WordPress à scanner.

### Paramètres Optionnels

- `--api-token <token>`  
  Fournit un token API pour WPScan afin d'obtenir des résultats plus détaillés.
- `--skip-dirb`  
  Ignore le scan Dirb (recherche de répertoires exposés).
- `--skip-nikto`  
  Ignore le scan Nikto (vérification des vulnérabilités connues du serveur web).
- `--skip-wapiti`  
  Ignore le scan Wapiti (évaluation des vulnérabilités web).
- `--skip-passwords`  
  Ignore la vérification des mots de passe par défaut avec Hydra.
- `--passive`  
  Active le mode passif (scan non agressif) qui :
  - Pour Dirb, affiche uniquement le contenu de `robots.txt`.
  - Pour WPScan, limite certaines options agressives.
  - Ignore les tests de brute force et le téléchargement du dossier uploads.  
  *(Note : Le scan wpprobe s'exécute quel que soit le mode choisi.)*

### Exemples

- **Scan Complet avec Token API pour WPScan**
  ```bash
  ./wpcheck.sh --url http://example.com --api-token VOTRE_TOKEN --passive
  ```

- **Scan sans Tests Dirb et Nikto**
  ```bash
  ./wpcheck.sh --url http://example.com --skip-dirb --skip-nikto
  ```

- **Scan sans Vérification des Mots de Passe par Défaut**
  ```bash
  ./wpcheck.sh --url http://example.com --skip-passwords
  ```

---

## 🎯 Pourquoi WPCheck ?

WPCheck offre une solution **tout-en-un** pour évaluer la sécurité de vos sites WordPress. En automatisant l'installation des outils et en combinant plusieurs techniques de scan, il vous permet de :
- **Identifier rapidement** les vulnérabilités et les mauvaises configurations.
- **Gagner du temps** grâce à l'automatisation et aux tests modulaires.
- **Renforcer la sécurité** de votre site en mettant en évidence les points faibles avant que des attaquants ne les exploitent.

---

## 🤖 Améliorations Futures

- **Rapports Améliorés :** Exporter les résultats du scan dans des formats tels que CSV ou JSON.
- **Intégrations d'API Supplémentaires :** Ajouter d'autres sources d'informations et API de sécurité.
- **Exécution Parallèle :** Optimiser le temps de scan grâce à l'exécution de processus en parallèle.
- **Interface Utilisateur Améliorée :** Développer une interface CLI interactive ou un tableau de bord web pour un suivi en temps réel.

## ✨ Crédits

Le script utilise divers outils open-source tels que WPScan, Hydra, Nikto, Dirb, Wapiti et wpprobe.

---

