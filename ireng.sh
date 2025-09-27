#!/bin/bash

# ╔════════════════════════════════════════════════════════════════════╗
# ║ 🛡️  SYAH PROTECTOR SYSTEM v1.7                                    ║
# ║ Proteksi Admin Controller + FileController (owner bisa akses)      ║
# ╚════════════════════════════════════════════════════════════════════╝

RED="\033[1;31m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RESET="\033[0m"
VERSION="1.7"

clear
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║         SYAH Protect + Panel Builder                 ║"
echo "║                    Version $VERSION                  ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${RESET}"

echo -e "${YELLOW}Pilih mode yang ingin dijalankan:${RESET}"
echo -e "1) 🔐 Install Protect (Add Protect)"
echo -e "2) ♻️ Restore Backup (Restore)"
read -p "Masukkan pilihan (1/2): " MODE

declare -A CONTROLLERS
CONTROLLERS["NodeController.php"]="/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeController.php"
CONTROLLERS["NestController.php"]="/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/NestController.php"
CONTROLLERS["IndexController.php"]="/var/www/pterodactyl/app/Http/Controllers/Admin/Settings/IndexController.php"
CONTROLLERS["FileController.php"]="/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/FileController.php"

BACKUP_DIR="backup_syah_protect"

if [[ "$MODE" == "1" ]]; then
    read -p "👤 Masukkan ID Admin Utama (contoh: 1): " ADMIN_ID
    if [[ -z "$ADMIN_ID" ]]; then
        echo -e "${RED}❌ Admin ID tidak boleh kosong.${RESET}"
        exit 1
    fi

    mkdir -p "$BACKUP_DIR"

    echo -e "${YELLOW}📦 Membackup file asli sebelum di protect ke: ${BLUE}$BACKUP_DIR${RESET}"
    for name in "${!CONTROLLERS[@]}"; do
        cp "${CONTROLLERS[$name]}" "$BACKUP_DIR/$name.bak"
    done

    echo -e "${GREEN}🔧 Menerapkan Protect hanya untuk ID $ADMIN_ID...${RESET}"

    for name in "${!CONTROLLERS[@]}"; do
        path="${CONTROLLERS[$name]}"
        if [[ "$name" == "FileController.php" ]]; then
            # Proteksi download & upload (admin utama + owner server)
            awk -v admin_id="$ADMIN_ID" -v version="$VERSION" '
            BEGIN { inserted_use=0; in_func=0; }
            /^namespace / {
                print;
                if (!inserted_use) {
                    print "use Illuminate\\Support\\Facades\\Auth;";
                    print "use Pterodactyl\\Exceptions\\DisplayException;";
                    inserted_use=1;
                }
                next;
            }
            (/public function download\(.*\)/ || /public function upload\(.*\)/) {
                print; in_func=1; next;
            }
            in_func==1 && /^\s*{/ {
                print;
                print "        $user = Auth::user();";
                print "        if (!$user) {";
                print "            throw new DisplayException(\"Anda tidak memiliki akses (SYAH Protect V\" . version . \")\");";
                print "        }";
                print "        if ($user->id !== " admin_id ") {";
                print "            if ($server->owner_id !== $user->id) {";
                print "                throw new DisplayException(\"Anda bukan pemilik server ini. Upload/Download ditolak (SYAH Protect V\" . version . \")\");";
                print "            }";
                print "        }";
                in_func=0; next;
            }
            { print; }
            ' "$path" > "$path.patched" && mv "$path.patched" "$path"
            echo -e "${GREEN}✅ Protect diterapkan ke: $name (Upload/Download)${RESET}"
        else
            # Proteksi index (hanya admin utama)
            awk -v admin_id="$ADMIN_ID" '
            BEGIN { inserted_use=0; in_func=0; }
            /^namespace / {
                print;
                if (!inserted_use) {
                    print "use Illuminate\\Support\\Facades\\Auth;";
                    inserted_use=1;
                }
                next;
            }
            /public function index\(.*\)/ { print; in_func=1; next; }
            in_func==1 && /^\s*{/ {
                print;
                print "        $user = Auth::user();";
                print "        if (!$user || $user->id !== " admin_id ") {";
                print "            abort(403, \"SYAH Protect - Akses ditolak\");";
                print "        }";
                in_func=0; next;
            }
            { print; }
            ' "$path" > "$path.patched" && mv "$path.patched" "$path"
            echo -e "${GREEN}✅ Protect diterapkan ke: $name (Index)${RESET}"
        fi
    done

    echo -e "${YELLOW}➤ Install Node.js 16 dan build frontend panel...${RESET}"
    sudo apt-get update -y >/dev/null
    sudo apt-get remove nodejs -y >/dev/null
    curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash - >/dev/null
    sudo apt-get install nodejs -y >/dev/null

    cd /var/www/pterodactyl || { echo -e "${RED}❌ Gagal ke direktori panel.${RESET}"; exit 1; }

    npm i -g yarn >/dev/null
    yarn add cross-env >/dev/null
    yarn build:production --progress

    echo -e "\n${BLUE}🎉 Protect selesai!"
    echo -e "📁 Backup file tersimpan di: $BACKUP_DIR"
    echo -e "🛡️ Hanya ID $ADMIN_ID & owner server yang bisa upload/download file"
    echo -e "🛡️ Hanya ID $ADMIN_ID yang bisa edit Nodes/Nests/Settings"
    echo -e "${RESET}"

elif [[ "$MODE" == "2" ]]; then
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo -e "${RED}❌ Folder backup tidak ditemukan: $BACKUP_DIR"
        echo -e "⚠️ Jalankan mode Protect terlebih dahulu.${RESET}"
        exit 1
    fi

    echo -e "${CYAN}♻️ Mengembalikan file ke versi sebelum Protect...${RESET}"
    for name in "${!CONTROLLERS[@]}"; do
        if [[ -f "$BACKUP_DIR/$name.bak" ]]; then
            cp "$BACKUP_DIR/$name.bak" "${CONTROLLERS[$name]}"
            echo -e "${GREEN}🔄 Dipulihkan: $name${RESET}"
        else
            echo -e "${RED}⚠️ Backup tidak ditemukan untuk $name!${RESET}"
        fi
    done

    echo -e "${YELLOW}➤ Install Node.js 16 dan build frontend panel...${RESET}"
    sudo apt-get update -y >/dev/null
    sudo apt-get remove nodejs -y >/dev/null
    curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash - >/dev/null
    sudo apt-get install nodejs -y >/dev/null

    cd /var/www/pterodactyl || { echo -e "${RED}❌ Gagal ke direktori panel.${RESET}"; exit 1; }

    npm i -g yarn >/dev/null
    yarn add cross-env >/dev/null
    yarn build:production --progress

    echo -e "\n${BLUE}✅ Restore selesai. Semua file dikembalikan ke versi asli.${RESET}"

else
    echo -e "${RED}❌ Pilihan tidak valid. Masukkan 1 atau 2.${RESET}"
    exit 1
fi
