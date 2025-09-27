#!/bin/bash

# ╔════════════════════════════════════════════════════════════════════╗
# ║ 🛡️  SYAH PROTECT SYSTEM v1.7                                       ║
# ║ Anti Delete (Admin Controller) + Anti Download (FileController)    ║
# ╚════════════════════════════════════════════════════════════════════╝

# Warna
RED="\033[1;31m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RESET="\033[0m"
BOLD="\033[1m"
VERSION="1.7"

clear
echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║                SYAH PROTECT SYSTEM v$VERSION                ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${RESET}"

echo -e "${YELLOW}Pilih mode yang ingin dijalankan:${RESET}"
echo -e "1) 🔐 Install Protect (Tambahkan Proteksi)"
echo -e "2) ♻️ Restore Backup (Kembalikan Asli)"
read -p "Masukkan pilihan (1/2): " MODE

# File controller target
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

    echo -e "${GREEN}🔧 Menerapkan Proteksi hanya untuk ID $ADMIN_ID...${RESET}"

    # Patch Admin Controllers
    for name in NodeController.php NestController.php IndexController.php; do
        path="${CONTROLLERS[$name]}"
        if ! grep -q "public function index" "$path"; then
            echo -e "${RED}⚠️ Gagal: $name tidak punya 'public function index()'! Lewat.${RESET}"
            continue
        fi

        awk -v admin_id="$ADMIN_ID" '
        BEGIN { inserted_use=0; in_func=0; }
        /^namespace / {
            print;
            if (!inserted_use) {
                print "use Illuminate\\Support\\Facades\\Auth;";
                inserted_use = 1;
            }
            next;
        }
        /public function index\(.*\)/ {
            print; in_func = 1; next;
        }
        in_func == 1 && /^\s*{/ {
            print;
            print "        \$user = Auth::user();";
            print "        if (!\$user || \$user->id !== " admin_id ") {";
            print "            abort(403, \"Lu mau ngapain tolol?\");";
            print "        }";
            in_func = 0; next;
        }
        { print; }
        ' "$path" > "$path.patched" && mv "$path.patched" "$path"
        echo -e "${GREEN}✅ Proteksi diterapkan ke: $name${RESET}"
    done

    # Patch FileController (Anti Download)
    path="${CONTROLLERS["FileController.php"]}"
    if grep -q "function download" "$path"; then
        awk -v admin_id="$ADMIN_ID" '
        BEGIN { inserted_use=0; in_func=0; }
        /^namespace / {
            print;
            if (!inserted_use) {
                print "use Illuminate\\Support\\Facades\\Auth;";
                inserted_use = 1;
            }
            next;
        }
        /function download\(.*\)/ {
            print; in_func = 1; next;
        }
        in_func == 1 && /^\s*{/ {
            print;
            print "        \$user = Auth::user();";
            print "        if (!\$user || (\$user->id !== " admin_id " && \$user->id !== \$server->owner_id)) {";
            print "            abort(403, \"Download diblokir tolol!\");";
            print "        }";
            in_func = 0; next;
        }
        { print; }
        ' "$path" > "$path.patched" && mv "$path.patched" "$path"
        echo -e "${GREEN}✅ Proteksi Anti Download diterapkan ke: FileController.php${RESET}"
    else
        echo -e "${RED}⚠️ Gagal patch: FileController.php ga nemu fungsi download.${RESET}"
    fi

    echo -e "${YELLOW}➤ Build ulang frontend panel...${RESET}"
    sudo apt-get update -y >/dev/null
    sudo apt-get remove nodejs -y >/dev/null
    curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash - >/dev/null
    sudo apt-get install nodejs -y >/dev/null

    cd /var/www/pterodactyl || { echo -e "${RED}❌ Gagal ke direktori panel.${RESET}"; exit 1; }

    npm i -g yarn >/dev/null
    yarn add cross-env >/dev/null
    yarn build:production --progress

    echo -e "\n${BLUE}🎉 Proteksi selesai!"
    echo -e "📁 Backup file tersimpan di: $BACKUP_DIR"
    echo -e "🛡️ Sekarang:"
    echo -e "   • Hanya ID $ADMIN_ID bisa akses Nodes/Nests/Settings"
    echo -e "   • Hanya Admin Utama + Owner Server bisa download file"
    echo -e "${RESET}"

elif [[ "$MODE" == "2" ]]; then
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo -e "${RED}❌ Folder backup tidak ditemukan: $BACKUP_DIR"
        echo -e "⚠️ Jalankan mode Protect terlebih dahulu.${RESET}"
        exit 1
    fi

    echo -e "${CYAN}♻️ Mengembalikan file ke versi sebelum Proteksi...${RESET}"
    for name in "${!CONTROLLERS[@]}"; do
        if [[ -f "$BACKUP_DIR/$name.bak" ]]; then
            cp "$BACKUP_DIR/$name.bak" "${CONTROLLERS[$name]}"
            echo -e "${GREEN}🔄 Dipulihkan: $name${RESET}"
        else
            echo -e "${RED}⚠️ Backup tidak ditemukan untuk $name!${RESET}"
        fi
    done

    echo -e "${YELLOW}➤ Build ulang frontend panel...${RESET}"
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
