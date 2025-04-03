#!/bin/bash

# Création des dossiers data et output
DATA_DIR="data"
OUTPUT_DIR="output"
mkdir -p "$DATA_DIR" "$OUTPUT_DIR"

cat << "EOF"
██╗    ██╗██████╗  ██████╗██╗  ██╗███████╗ ██████╗██╗  ██╗
██║    ██║██╔══██╗██╔════╝██║  ██║██╔════╝██╔════╝██║ ██╔╝
██║ █╗ ██║██████╔╝██║     ███████║█████╗  ██║     █████╔╝ 
██║███╗██║██╔═══╝ ██║     ██╔══██║██╔══╝  ██║     ██╔═██╗ 
╚███╔███╔╝██║     ╚██████╗██║  ██║███████╗╚██████╗██║  ██╗
 ╚══╝╚══╝ ╚═╝      ╚═════╝╚═╝  ╚═╝╚══════╝ ╚═════╝╚═╝  ╚═╝
                                                          
EOF

echo ""

# Variables de contrôle pour passer certains tests
skip_dirb=0
skip_nikto=0
skip_wapiti=0
skip_passwords=0
passive_mode=0

# Fonction d'affichage avec préfixe coloré
print_color() {
    case $1 in
        "green")
            echo -e "\033[0;32m[+]\033[0m $2"
            ;;
        "red")
            echo -e "\033[0;31m[!]\033[0m $2"
            ;;
        "yellow")
            echo -e "\033[1;33m[!]\033[0m $2"
            ;;
        "blue")
            echo -e "\033[1;34m[*]\033[0m $2"
            ;;
        *)
            echo "$2"
            ;;
    esac
}

# Fonction pour afficher une séparation de section
print_section() {
    echo -e "\n\033[1;34m========================================\033[0m"
    echo -e "\033[1;34m== $1\033[0m"
    echo -e "\033[1;34m========================================\033[0m\n"
}

# Fonction pour vérifier et installer WPScan
install_wpscan() {
    if ! command -v wpscan &> /dev/null; then
        print_color "yellow" "WPScan n'est pas installé. Installation..."
        sudo apt update
        sudo apt install ruby ruby-dev build-essential -y
        sudo gem install wpscan
    else
        print_color "green" "WPScan est déjà installé."
    fi
}

# Fonction pour vérifier et installer Hydra
install_hydra() {
    if ! command -v hydra &> /dev/null; then
        print_color "yellow" "Hydra n'est pas installé. Installation..."
        sudo apt update
        sudo apt install hydra -y
    else
        print_color "green" "Hydra est déjà installé."
    fi
}

# Fonction pour télécharger la wordlist WordPress dans le dossier data
download_wordlist() {
    if [ ! -f "$DATA_DIR/wordpress.fuzz.txt" ]; then
        print_color "yellow" "Wordlist introuvable. Téléchargement..."
        wget -q https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/CMS/wordpress.fuzz.txt -O "$DATA_DIR/wordpress.fuzz.txt"
    else
        print_color "green" "Wordlist déjà présente."
    fi
}

# Fonction pour vérifier et installer Nikto dans le dossier data
install_nikto() {
    if [ ! -d "$DATA_DIR/nikto" ]; then
        print_color "yellow" "Nikto n'est pas installé. Installation..."
        git clone https://github.com/sullo/nikto.git "$DATA_DIR/nikto"
        print_color "green" "Nikto installé avec succès."
    else
        print_color "green" "Nikto est déjà installé."
    fi
}

# Fonction pour vérifier et installer dirb
install_dirb() {
    if ! command -v dirb &> /dev/null; then
        print_color "yellow" "dirb n'est pas installé. Installation..."
        sudo apt install dirb -y
    else
        print_color "green" "dirb est déjà installé."
    fi
}

# Fonction pour vérifier et installer Wapiti dans le dossier data
install_wapiti() {
    # Vérifier si l'environnement virtuel existe et le sourcer
    if [ -f "$DATA_DIR/wapiti_env/bin/activate" ]; then
        source "$DATA_DIR/wapiti_env/bin/activate"
    fi

    # Tester si la commande wapiti est disponible
    if ! command -v wapiti &> /dev/null; then
        print_color "yellow" "Wapiti n'est pas installé. Installation..."
        sudo apt install python3 python3-pip -y
        # Créer l'environnement virtuel si nécessaire
        if [ ! -d "$DATA_DIR/wapiti_env" ]; then
            python3 -m venv "$DATA_DIR/wapiti_env"
        fi
        # Sourcer l'environnement virtuel et installer wapiti3
        source "$DATA_DIR/wapiti_env/bin/activate"
        pip install wapiti3
    else
        print_color "green" "Wapiti est déjà installé."
    fi
}

# Vérifie et installe Go s'il n'est pas présent.
check_install_go() {
    if ! command -v go &> /dev/null; then
        print_color "yellow" "Go n'est pas installé. Installation..."
        sudo apt update
        sudo apt install golang -y
    else
        print_color "green" "Go est déjà installé."
    fi
}

# Lance le scan wpprobe :
# - Installe wpprobe via "go install github.com/Chocapikk/wpprobe@latest"
# - Exécute ./wpprobe update, update-db et scan -u <site_url>
scan_wpprobe() {
    local url=$1
    print_color "blue" "Installation de wpprobe via Go..."
    go install github.com/Chocapikk/wpprobe@latest
    local WPPROBE_BIN="$HOME/go/bin/wpprobe"
    if [ ! -x "$WPPROBE_BIN" ]; then
         print_color "red" "wpprobe n'a pas été trouvé après l'installation. Vérifiez votre GOPATH."
         exit 1
    fi
    print_color "blue" "Mise à jour de wpprobe..."
    "$WPPROBE_BIN" update > /dev/null
    print_color "blue" "Mise à jour de la base de données de wpprobe..."
    "$WPPROBE_BIN" update-db > /dev/null
    print_color "blue" "Lancement du scan wpprobe sur $url..."
    "$WPPROBE_BIN" scan -u "$url"
}

run_wpscan() {
    local url=$1
    local api_token=$2
    print_color "blue" "Lancement de WPScan sur $url..."

    if [ -z "$api_token" ]; then
        if [ "$passive_mode" -eq 1 ]; then
            # Mode passif : scan minimal sans mise à jour ni options agressives
            output=$(wpscan --url "$url" --disable-tls-checks --no-banner --stealthy 2>&1)
        else
            output=$(wpscan --url "$url" --update --disable-tls-checks --random-user-agent --no-banner 2>&1)
        fi
    else
        if [ "$passive_mode" -eq 1 ]; then
            # Mode passif : scan minimal sans mise à jour ni options agressives
            output=$(wpscan --url "$url" --update --api-token "$api_token" --disable-tls-checks --random-user-agent --no-banner --stealthy 2>&1)
        else
            output=$(wpscan --url "$url" --update --api-token "$api_token" --disable-tls-checks --random-user-agent --no-banner 2>&1)
        fi
    fi

    echo "$output"

    if echo "$output" | grep -qi "does not seem to be running WordPress"; then
        print_color "red" "WPScan indique que $url ne semble pas être un site WordPress. Arrêt du script."
        exit 1
    fi
}

# Fonction pour lancer un scan dirb en utilisant la wordlist depuis data
scan_dirb() {
    local url=$1
    if [ "$passive_mode" -eq 1 ]; then
        print_color "yellow" "Mode passif activé : Récupération de robots.txt sur $url..."
        curl -s "$url/robots.txt" | while IFS= read -r line; do
            echo "$line"
        done
    else
        print_color "blue" "Lancement du scan dirb sur $url..."
        dirb "$url" "$DATA_DIR/wordpress.fuzz.txt" -w -N 302,500
    fi
}

# Fonction pour lancer le scan Nikto
scan_nikto() {
    local url=$1
    if [ "$passive_mode" -eq 1 ]; then
        print_color "yellow" "Mode passif activé : Scan Nikto ignoré."
        return
    fi
    print_color "blue" "Lancement du scan Nikto sur $url..."
    cd "$DATA_DIR/nikto/program" || exit
    perl nikto.pl -h "$url"
    cd - > /dev/null || exit
}

# Fonction pour lancer le scan Wapiti avec le rapport placé dans le dossier output
scan_wapiti() {
    local url=$1
    # Extraction du domaine en retirant le protocole et "www."
    local domain
    domain=$(echo "$url" | sed -e 's|http[s]*://||' -e 's|www\.||')
    if [ "$passive_mode" -eq 1 ]; then
        print_color "yellow" "Mode passif activé. Scan Wapiti ignoré."
        return
    else
        print_color "blue" "Lancement du scan Wapiti sur $url..."
        wapiti --flush-session -m all -u "$url" --color -o "$OUTPUT_DIR/wapiti-report-$domain"
    fi
}

# Fonction pour vérifier la page de login par défaut
check_login_page() {
    local url=$1
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url/wp-login.php")
    if [ "$response" -eq 200 ]; then
        print_color "red" "Page de login trouvée ($url/wp-login.php)."
        return 0
    else
        print_color "green" "Page de login non trouvée sur $url/wp-login.php."
        return 1
    fi
}

# Vérification de xmlrpc.php
check_xmlrpc() {
    local url=$1
    local file_url="$url/xmlrpc.php"
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" "$file_url")
    local content
    content=$(curl -s "$file_url")
    if [ "$code" -eq 403 ] || [ "$code" -eq 404 ] || echo "$content" | grep -qiE "unauthorized|not found|non trouvée|Forbidden"; then
        print_color "green" "xmlrpc est protégé ou n'existe pas (HTTP 403/non autorisé/page non trouvée) à $file_url."
    elif echo "$content" | grep -qi "XML-RPC"; then
        print_color "red" "xmlrpc semble accessible à $file_url."
    else
        print_color "green" "xmlrpc non trouvé ou inaccessible à $file_url."
    fi
}

# Vérification du debug.log
check_debug_log() {
    local url=$1
    local file_url="$url/debug.log"
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" "$file_url")
    local content
    content=$(curl -s "$file_url")
    if [ "$code" -eq 403 ] || [ "$code" -eq 404 ] || echo "$content" | grep -qiE "unauthorized|not found|non trouvée|Forbidden"; then
        print_color "green" "debug.log est protégé ou n'existe pas (HTTP 403/non autorisé/page non trouvée) à $file_url."
    elif [ -n "$content" ]; then
        print_color "red" "debug.log est accessible à $file_url."
    else
        print_color "green" "debug.log non trouvé à $file_url."
    fi
}

# Vérification des fichiers de sauvegarde pour wp-config.php
check_backup_files() {
    local url=$1
    local found=0
    for file in "$url/wp-config.php~" "$url/wp-config.php.bak"; do
        local code
        code=$(curl -s -o /dev/null -w "%{http_code}" "$file")
        local content
        content=$(curl -s "$file")
        if [ "$code" -eq 403 ] || [ "$code" -eq 404 ] || echo "$content" | grep -qiE "unauthorized|not found|non trouvée|Forbidden"; then
            print_color "green" "Le fichier de sauvegarde $file est protégé ou n'existe pas (HTTP 403/non autorisé/page non trouvée)."
            found=1
        elif [ -n "$content" ]; then
            print_color "red" "Fichier de sauvegarde trouvé et accessible : $file."
            found=1
        fi
    done
    if [ $found -eq 0 ]; then
        print_color "green" "Aucun fichier de sauvegarde pour wp-config.php trouvé sur $url."
    fi
}

# Vérification de sitemap.xml
check_sitemap() {
    local url=$1
    local file_url="$url/sitemap.xml"
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" "$file_url")
    local content
    content=$(curl -s "$file_url")
    if [ "$code" -eq 403 ] || [ "$code" -eq 404 ] || echo "$content" | grep -qiE "unauthorized|not found|non trouvée|Forbidden"; then
        print_color "green" "sitemap.xml est protégé ou n'existe pas (HTTP 403/non autorisé/page non trouvée) à $file_url."
    elif [ -n "$content" ]; then
        print_color "red" "sitemap.xml est accessible à $file_url."
    else
        print_color "green" "sitemap.xml non trouvé à $file_url."
    fi
}

check_security_headers() {
    local url=$1
    # Extraction du domaine
    local domain
    domain=$(echo "$url" | sed -e 's|http[s]*://||' -e 's|www\.||')
    
    # Constitution de l'URL de l'API MDN Observatory
    local api_url="https://observatory-api.mdn.mozilla.net/api/v2/scan?host=${domain}"
    print_color "blue" "Démarrage du scan de sécurité via l'API MDN Observatory : $api_url"
    
    # Exécution de la requête POST
    local response
    response=$(curl -s -X POST "$api_url")
    
    # Extraction du champ error
    local error_field
    error_field=$(echo "$response" | grep -oP '"error"\s*:\s*\K(null|".*?")')
    error_field=$(echo "$error_field" | sed 's/"//g')
    
    if [ "$error_field" != "null" ] && [ -n "$error_field" ]; then
        print_color "red" "Erreur pour ${domain} : $error_field"
    else
        local grade
        grade=$(echo "$response" | grep -oP '"grade"\s*:\s*"\K[^"]+')
        local score
        score=$(echo "$response" | grep -oP '"score"\s*:\s*\K[0-9]+')
        local details_url
        details_url=$(echo "$response" | grep -oP '"details_url"\s*:\s*"\K[^"]+')
        
        if [ -n "$grade" ] && [ -n "$score" ] && [ -n "$details_url" ]; then
            echo "Security score for ${domain} : Grade $grade, Score $score/100"
            echo "Detailed analysis URL: $details_url"
        else
            print_color "red" "Impossible de récupérer les informations de sécurité pour ${domain}."
        fi
    fi
}

# Vérification des mots de passe par défaut avec Hydra
check_default_passwords() {
    if [ "$passive_mode" -eq 1 ]; then
        print_color "yellow" "Mode passif activé : Vérification des mots de passe ignorée."
        return
    fi
    local url=$1
    # Extraction du domaine
    local target
    target=$(echo "$url" | sed 's|http[s]*://||')
    
    # Création du fichier passwords.txt dans le dossier data
    cat > "$DATA_DIR/passwords.txt" <<EOL
admin
123456
password
12345678
666666
111111
1234567
qwerty
siteadmin
administrator
root
123123
123321
1234567890
letmein123
test123
demo123
pass123
123qwe
qwe123
654321
loveyou
adminadmin123
EOL

    if check_login_page "$url"; then
        local users=("admin" "administrator" "test" "root" "user" "manager" "guest" "support" "webmaster" "info" "demo" "wpadmin" "wpuser" "editor" "owner" "developer" "sysadmin" "superadmin" "admin1" "admin2")
        for user in "${users[@]}"; do
            print_color "yellow" "Tentative avec $user sur $url/wp-login.php"
            hydra -l "$user" -P "$DATA_DIR/passwords.txt" "$target" http-post-form "/wp-login.php:log=^USER^&pwd=^PASS^&wp-submit=Se+connecter&redirect_to=http%3A%2F%2F82.165.172.108%2Fwp-admin%2F&testcookie=1:S=Location"
        done
    fi
}

# Nouvelle fonction : Vérifier et télécharger le dossier uploads
check_uploads() {
    local url=$1
    local uploads_url="${url}/wp-content/uploads/"
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" "$uploads_url")
    if [ "$response" -eq 200 ]; then
        print_color "red" "Le dossier uploads existe à $uploads_url."
        # Extraction du nom de domaine
        local domain
        domain=$(echo "$url" | sed -e 's|http[s]*://||' -e 's|/.*||')
        # Créer le dossier de destination dans output (pour les uploads)
        mkdir -p "$OUTPUT_DIR/uploads/$domain"
        print_color "blue" "Téléchargement des fichiers du dossier uploads vers '$OUTPUT_DIR/uploads/$domain'..."
        local output
        output=$(wget --recursive --no-parent --reject "index.html*,*.jpg,*.jpeg,*.png,*.gif,*.html,*.htm,*.webp,*.ttf,*.otf,*.mp4,*.svg" --no-clobber -nv -P "$OUTPUT_DIR/uploads/$domain" "$uploads_url" 2>&1)
        local ret=$?
        if [ $ret -eq 0 ]; then
            echo "$output" | grep -i "Saving to:" | while read -r line; do
                local file
                file=$(echo "$line" | sed "s/.*Saving to: ‘\(.*\)’/\1/")
                if [ -z "$file" ]; then
                    file=$(echo "$line" | sed 's/.*Saving to: "\(.*\)"/\1/')
                fi
                if [ -n "$file" ]; then
                    print_color "green" "Téléchargé : $file"
                fi
            done
        else
            print_color "yellow" "Erreur lors du téléchargement depuis $uploads_url. Détails :"
            echo "$output"
        fi
    else
        print_color "green" "Le dossier uploads n'existe pas à $uploads_url."
    fi
}

# Fonction d'affichage de l'utilisation du script
usage() {
    cat << EOF
Usage: $0 --url <site_url> [OPTIONS]

Required:
  --url <site_url>         Spécifie l'URL cible à scanner.

Optional:
  --api-token <token>      Fournit un token API pour WPScan afin d'obtenir des résultats plus détaillés.
  --skip-dirb              Ignore le scan Dirb (recherche de répertoires).
  --skip-nikto             Ignore le scan Nikto (vulnérabilités connues).
  --skip-wapiti            Ignore le scan Wapiti (vulnérabilités web).
  --skip-passwords         Ignore la vérification des mots de passe par défaut avec Hydra.
  --passive                Active le mode passif (scan non agressif) :
                           - Pour Dirb, affiche uniquement le contenu de robots.txt.
                           - Pour WPScan, limite certaines options agressives.
                           - Ignore les tests de brute force et de téléchargement de uploads.
                           (Le scan wpprobe s'exécute quand même, quel que soit le mode.)

Example:
  $0 --url http://example.com --api-token ABC123 --passive

EOF
    exit 1
}

# Vérification des arguments requis
if [ "$#" -lt 2 ]; then
    usage
fi

# Traitement des arguments
while [[ "$1" != "" ]]; do
    case $1 in
        --url)
            shift
            site_url=$1
            ;;
        --api-token)
            shift
            api_token=$1
            ;;
        --skip-wapiti)
            skip_wapiti=1
            ;;
        --skip-dirb)
            skip_dirb=1
            ;;
        --skip-nikto)
            skip_nikto=1
            ;;
        --skip-passwords)
            skip_passwords=1
            ;;
        --passive)
            passive_mode=1
            ;;
        *)
            usage
            ;;
    esac
    shift
done

# Vérification que l'URL est définie
if [ -z "$site_url" ]; then
    usage
fi

# Suppression du "/" final s'il est présent
site_url="${site_url%/}"

#=== Installation des outils nécessaires ===#
print_section "Installation des outils"
install_wpscan

if [ $skip_dirb -eq 0 ]; then
    install_dirb
    download_wordlist
fi

if [ $skip_nikto -eq 0 ]; then
    install_nikto
fi

install_hydra

if [ $skip_wapiti -eq 0 ]; then
    install_wapiti
fi

check_install_go  # S'assure que Go est installé pour wpprobe

#=== Lancement des scans ===#
print_section "Scan wpprobe"
scan_wpprobe "$site_url"

if [ $skip_wapiti -eq 0 ]; then
    print_section "Scan Wapiti"
    scan_wapiti "$site_url"
fi

if [ $skip_dirb -eq 0 ]; then
    print_section "Scan Dirb"
    scan_dirb "$site_url"
fi

if [ $skip_nikto -eq 0 ]; then
    print_section "Scan Nikto"
    scan_nikto "$site_url"
fi

print_section "Scan WPScan"
run_wpscan "$site_url" "$api_token"

print_section "Vérification xmlrpc.php"
check_xmlrpc "$site_url"

print_section "Vérification debug.log"
check_debug_log "$site_url"

print_section "Vérification des sauvegardes wp-config.php"
check_backup_files "$site_url"

print_section "Vérification sitemap.xml"
check_sitemap "$site_url"

print_section "Scan des Security Headers"
check_security_headers "$site_url"

print_section "Téléchargement du dossier uploads"
check_uploads "$site_url"

if [ $skip_passwords -eq 0 ]; then
    print_section "Vérification des mots de passe par défaut"
    check_default_passwords "$site_url"
else
    print_color "yellow" "Vérification des mots de passe ignorée."
fi
