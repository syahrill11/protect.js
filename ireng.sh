#!/bin/bash

# ╔════════════════════════════════════════════════════════════════════╗
# ║ 🛡️  SYAH PROTECTOR SYSTEM v1.5                                     ║
# ║ Proteksi Controller Admin + File Download                          ║
# ╚════════════════════════════════════════════════════════════════════╝

RED="\033[1;31m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RESET="\033[0m"
VERSION="1.5"

clear
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║         SYAH Protect + Panel Builder                 ║"
echo "║                    Version $VERSION                  ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${RESET}"

echo -e "${YELLOW}Pilih mode:${RESET}"
echo "1) 🔐 Install Protect"
echo "2) ♻️ Restore Backup"
read -p "Masukkan pilihan (1/2): " MODE

declare -A CONTROLLERS
CONTROLLERS["NodeController.php"]="/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeController.php"
CONTROLLERS["NestController.php"]="/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/NestController.php"
CONTROLLERS["IndexController.php"]="/var/www/pterodactyl/app/Http/Controllers/Admin/Settings/IndexController.php"
CONTROLLERS["UserController.php"]="/var/www/pterodactyl/app/Http/Controllers/Admin/UserController.php"
CONTROLLERS["DownloadController.php"]="/var/www/pterodactyl/app/Http/Controllers/Server/DownloadController.php"

BACKUP_DIR="backup_pablo_protect"

if [[ "$MODE" == "1" ]]; then
    read -p "👤 Masukkan ID Admin Utama (contoh: 1): " ADMIN_ID
    [[ -z "$ADMIN_ID" ]] && echo -e "${RED}❌ Admin ID tidak boleh kosong.${RESET}" && exit 1

    mkdir -p "$BACKUP_DIR"
    echo -e "${YELLOW}📦 Membackup file asli ke: ${BLUE}$BACKUP_DIR${RESET}"

    for name in "${!CONTROLLERS[@]}"; do
        [[ -f "${CONTROLLERS[$name]}" ]] && cp "${CONTROLLERS[$name]}" "$BACKUP_DIR/$name.bak"
    done

    echo -e "${GREEN}🔧 Menerapkan Protect hanya untuk ID $ADMIN_ID...${RESET}"

    for name in "${!CONTROLLERS[@]}"; do
        path="${CONTROLLERS[$name]}"
        [[ ! -f "$path" ]] && echo -e "${RED}❌ File tidak ditemukan: $path${RESET}" && continue

        if [[ "$name" == "UserController.php" ]]; then
            # Protect Update/Delete User
            awk -v admin_id="$ADMIN_ID" '
            BEGIN { inserted_use=0; in_update=0; in_delete=0; }
            /^namespace / {
                print;
                if (!inserted_use) {
                    print "use Illuminate\\Support\\Facades\\Auth;";
                    print "use Pterodactyl\\Exceptions\\DisplayException;";
                    inserted_use = 1;
                }
                next;
            }
            /public function update\(UserFormRequest/ {
                print; in_update=1; next;
            }
            in_update==1 && /^\s*{/ {
                print;
                print "        $user = Auth::user();";
                print "        if (!$user || $user->id !== " admin_id ") {";
                print "            throw new DisplayException(\"Anda Bukan Admin Utama. Tidak Bisa Edit User/Password Orang Lain\");";
                print "        }";
                in_update=0; next;
            }
            /public function delete\(Request/ {
                print; in_delete=1; next;
            }
            in_delete==1 && /^\s*{/ {
                print;
                print "        $user = Auth::user();";
                print "        if (!$user || $user->id !== " admin_id ") {";
                print "            throw new DisplayException(\"Anda Bukan Admin Utama. Tidak Bisa Menghapus User Ini\");";
                print "        }";
                in_delete=0; next;
            }
            { print; }
            ' "$path" > "$path.patched" && mv "$path.patched" "$path"
            echo -e "${GREEN}✅ Protect UserController (Update/Delete) selesai${RESET}"

        elif [[ "$name" == "DownloadController.php" ]]; then
            # Protect Download File
            awk -v admin_id="$ADMIN_ID" '
            BEGIN { inserted_use=0; in_func=0; }
            /^namespace / {
                print;
                if (!inserted_use) {
                    print "use Illuminate\\Support\\Facades\\Auth;";
                    print "use Pterodactyl\\Exceptions\\DisplayException;";
                    inserted_use = 1;
                }
                next;
            }
            /public function download\(Request/ {
                print; in_func=1; next;
            }
            in_func==1 && /^\s*{/ {
                print;
                print "        $user = Auth::user();";
                print "        if (!$user) {";
                print "            throw new DisplayException(\"Tidak terautentikasi\");";
                print "        }";
                print "        // Cek apakah file milik server user atau bukan";
                print "        if ($user->id !== " admin_id " && $request->route('server')->owner_id !== $user->id) {";
                print "            throw new DisplayException(\"Anda Tidak Boleh Download File Server Orang Lain\");";
                print "        }";
                in_func=0; next;
            }
            { print; }
            ' "$path" > "$path.patched" && mv "$path.patched" "$path"
            echo -e "${GREEN}✅ Protect DownloadController selesai${RESET}"

        else
            # Protect Index di Admin Controllers
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
                print; in_func=1; next;
            }
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
            echo -e "${GREEN}✅ Protect diterapkan ke: $name${RESET}"
        fi
    done

    echo -e "${YELLOW}➤ Build ulang frontend panel...${RESET}"
    cd /var/www/pterodactyl || exit 1
    yarn build:production --progress

    echo -e "${BLUE}🎉 Protect selesai!${RESET}"
    echo -e "🛡️ Hanya ID $ADMIN_ID yang bisa edit/delete user, akses admin controller, dan download file milik server lain."

elif [[ "$MODE" == "2" ]]; then
    [[ ! -d "$BACKUP_DIR" ]] && echo -e "${RED}❌ Folder backup tidak ditemukan${RESET}" && exit 1

    echo -e "${CYAN}♻️ Mengembalikan file backup...${RESET}"
    for name in "${!CONTROLLERS[@]}"; do
        if [[ -f "$BACKUP_DIR/$name.bak" ]]; then
            cp "$BACKUP_DIR/$name.bak" "${CONTROLLERS[$name]}"
            echo -e "${GREEN}🔄 Dipulihkan: $name${RESET}"
        else
            echo -e "${RED}⚠️ Backup tidak ada untuk $name${RESET}"
        fi
    done

    echo -e "${YELLOW}➤ Build ulang frontend panel...${RESET}"
    cd /var/www/pterodactyl || exit 1
    yarn build:production --progress
    echo -e "${BLUE}✅ Restore selesai.${RESET}"
else
    echo -e "${RED}❌ Pilihan tidak valid.${RESET}"
    exit 1
fi
