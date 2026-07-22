#!/bin/bash
set -e

# ==========================================================================
# Chặn chạy bằng sudo: script phải chạy dưới user thường
# ==========================================================================
# Nếu chạy nguyên script bằng sudo thì ~/.config/*, gsettings, im-config sẽ
# tác động vào root thay vì user -> bộ gõ và phím tắt không có tác dụng.
if [[ $EUID -eq 0 ]]; then
  MSG="Đừng chạy bằng sudo/root. Hãy chạy dưới tài khoản người dùng thường (script tự xin mật khẩu khi cần)."
  if command -v zenity >/dev/null 2>&1 && [[ -n "$DISPLAY$WAYLAND_DISPLAY" ]]; then
    zenity --error --text "$MSG"
  else
    echo "$MSG"
  fi
  exit 1
fi

# ==========================================================================
# Phát hiện môi trường desktop + bản phân phối (distro)
# ==========================================================================
# Mục đích: cài ĐÚNG phần cho từng desktop, KHÔNG cài chéo (Ubuntu không dính
# gói KDE và ngược lại). Hỗ trợ: GNOME (Ubuntu), KDE (Kubuntu),
# Cinnamon/MATE/Xfce (Linux Mint). Các phần đụng desktop: portal + phím Flameshot.
DESKTOP_ENV="unknown"
case "${XDG_CURRENT_DESKTOP,,}" in
  *kde*|*plasma*)  DESKTOP_ENV="kde" ;;
  *gnome*|*unity*) DESKTOP_ENV="gnome" ;;
  *cinnamon*)      DESKTOP_ENV="cinnamon" ;;
  *mate*)          DESKTOP_ENV="mate" ;;
  *xfce*)          DESKTOP_ENV="xfce" ;;
  *) : ;;
esac

# Nhận diện distro qua /etc/os-release (linuxmint/ubuntu/...) trong subshell
DISTRO_ID="$( . /etc/os-release 2>/dev/null; echo "${ID:-unknown}" )"

# ==========================================================================
# Chế độ giao diện: GUI (zenity) nếu có màn hình đồ hoạ, ngược lại Terminal
# ==========================================================================
GUI=0
if [[ -n "$DISPLAY$WAYLAND_DISPLAY" ]]; then
  # Nếu chưa có zenity mà lại đang ở phiên đồ hoạ -> thử cài bằng pkexec (hộp
  # thoại mật khẩu đồ hoạ), để người dùng không cần mở terminal.
  if ! command -v zenity >/dev/null 2>&1 && command -v pkexec >/dev/null 2>&1; then
    pkexec sh -c 'apt-get update -y; apt-get install -y zenity' >/dev/null 2>&1 || true
  fi
  command -v zenity >/dev/null 2>&1 && GUI=1
fi

echo "Desktop: $DESKTOP_ENV | Distro: $DISTRO_ID | Giao diện: $([[ $GUI == 1 ]] && echo GUI || echo Terminal)"

# ==========================================================================
# Tự cài shortcut vào Menu ứng dụng (để lần sau bấm icon là chạy được)
# ==========================================================================
# GNOME không cho chạy .desktop nằm trong thư mục thường; nhưng .desktop đặt
# trong ~/.local/share/applications thì hiện trong Menu và bấm chạy được.
install_menu_launcher() {
  local script_path apps_dir
  script_path="$(readlink -f "$0" 2>/dev/null)" || return 0
  [[ -f "$script_path" ]] || return 0
  # Nếu chạy từ bản cài .deb (/usr/...) thì đã có launcher hệ thống rồi -> khỏi
  # tạo bản trùng trong ~/.local.
  case "$script_path" in /usr/*) return 0 ;; esac
  apps_dir="$HOME/.local/share/applications"
  mkdir -p "$apps_dir"
  cat > "$apps_dir/cai-dat-phan-mem.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Cài đặt phần mềm văn phòng
Comment=Chọn và cài phần mềm cho máy Ubuntu/Kubuntu/Mint
Terminal=false
Icon=system-software-install
Categories=System;Utility;
Exec=bash "$script_path"
EOF
  chmod +x "$apps_dir/cai-dat-phan-mem.desktop" 2>/dev/null || true
  command -v update-desktop-database >/dev/null 2>&1 \
    && update-desktop-database "$apps_dir" 2>/dev/null || true
  echo "Đã thêm 'Cài đặt phần mềm văn phòng' vào Menu ứng dụng (tìm trong danh sách app)."
}
install_menu_launcher || true

# ==========================================================================
# Danh mục phần mềm (một nguồn duy nhất cho cả GUI lẫn Terminal)
# ==========================================================================
# Thứ tự hiển thị = thứ tự cài. Hàm cài của mỗi app là install_<tag>.
APP_ORDER=(chrome telegram ibus edge coccoc wechat lark wps msfonts archive anydesk vlc rclone fcitx5 flameshot)
declare -A APP_LABEL=(
  [chrome]="Google Chrome"
  [telegram]="Telegram Desktop (qua Flatpak/Flathub)"
  [ibus]="ibus-bamboo (bộ gõ tiếng Việt)"
  [edge]="Microsoft Edge (qua Flatpak/Flathub)"
  [coccoc]="Cốc Cốc (trình duyệt Việt Nam)"
  [wechat]="WeChat (qua Flatpak/Flathub)"
  [lark]="Lark (Lark Suite - bản .deb chính thức)"
  [wps]="WPS Office (qua Flatpak/Flathub)"
  [msfonts]="Font Microsoft (Times New Roman, Arial...)"
  [archive]="Bộ giải nén RAR/7z (unrar + p7zip)"
  [anydesk]="AnyDesk (điều khiển máy từ xa)"
  [vlc]="VLC (xem video mọi định dạng)"
  [rclone]="Rclone UI (app đồng bộ Google Drive/cloud)"
  [fcitx5]="fcitx5 + Unikey (bộ gõ tiếng Việt)"
  [flameshot]="Flameshot (chụp màn hình + phím tắt)"
)
# Mặc định BẬT sẵn 3 cái quan trọng nhất
declare -A APP_DEFAULT=(
  [chrome]=ON [telegram]=ON [ibus]=ON
  [edge]=OFF [coccoc]=OFF [wechat]=OFF [lark]=OFF [wps]=OFF [msfonts]=OFF
  [archive]=OFF [anydesk]=OFF [vlc]=OFF [rclone]=OFF [fcitx5]=OFF [flameshot]=OFF
)

# ==========================================================================
# Bước hỏi: cho user tick chọn cài cái gì (GUI: zenity | Terminal: whiptail)
# ==========================================================================
SELECTED=""   # danh sách tag đã chọn, cách nhau bằng dấu cách

if [[ $GUI == 1 ]]; then
  ZEN_ARGS=()
  for tag in "${APP_ORDER[@]}"; do
    [[ "${APP_DEFAULT[$tag]}" == ON ]] && chk=TRUE || chk=FALSE
    ZEN_ARGS+=("$chk" "$tag" "${APP_LABEL[$tag]}")
  done
  RAW=$(zenity --list --checklist \
    --title "Cài đặt phần mềm văn phòng" \
    --text "Tick chọn phần mềm cần cài rồi bấm OK:" \
    --width 620 --height 560 \
    --column "Cài?" --column "tag" --column "Phần mềm" \
    --hide-column=2 --print-column=2 --separator='|' \
    "${ZEN_ARGS[@]}") || { echo "Đã huỷ."; exit 0; }
  SELECTED="${RAW//|/ }"
else
  if ! command -v whiptail >/dev/null 2>&1; then
    echo "Đang cài whiptail để hiện màn hình chọn..."
    sudo apt install -y whiptail
  fi
  WT_ARGS=()
  for tag in "${APP_ORDER[@]}"; do
    WT_ARGS+=("$tag" "${APP_LABEL[$tag]}" "${APP_DEFAULT[$tag]}")
  done
  RAW=$(whiptail --title "Chọn phần mềm cần cài" \
    --checklist "Dùng MŨI TÊN di chuyển, SPACE tick chọn, ENTER xác nhận:" \
    22 80 16 "${WT_ARGS[@]}" \
    3>&1 1>&2 2>&3) || { echo "Đã huỷ. Không cài gì cả."; exit 0; }
  SELECTED="$(echo "$RAW" | tr -d '"')"
fi

if [[ -z "${SELECTED// }" ]]; then
  MSG="Bạn chưa tick chọn gì cả. Thoát."
  [[ $GUI == 1 ]] && zenity --info --text "$MSG" || echo "$MSG"
  exit 0
fi

# Kiểm tra một tag có được chọn hay không
is_selected() {
  [[ " $SELECTED " == *" $1 "* ]]
}

# --------------------------------------------------------------------------
# Helper kiểm tra "đã cài chưa" -> để bỏ qua, tránh cài lại + tránh lỗi trùng
# --------------------------------------------------------------------------
have_cmd()     { command -v "$1" >/dev/null 2>&1; }
have_deb()     { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"; }
have_flatpak() { flatpak info --system "$1" >/dev/null 2>&1; }   # trả false nếu chưa có flatpak
skip_msg()     { echo "=== $1 đã cài rồi, bỏ qua. ==="; }

# ==========================================================================
# Thiết lập sudo cho chế độ GUI: hỏi mật khẩu 1 lần bằng cửa sổ, cache lại
# ==========================================================================
# Nhờ vậy các lệnh sudo bên trong hàm cài KHÔNG cần terminal và không hỏi lại.
ASKPASS_FILE=""
KEEPALIVE_PID=""
cleanup() {
  [[ -n "$KEEPALIVE_PID" ]] && kill "$KEEPALIVE_PID" 2>/dev/null || true
  [[ -n "$ASKPASS_FILE" ]] && rm -f "$ASKPASS_FILE" 2>/dev/null || true
}
trap cleanup EXIT

if [[ $GUI == 1 ]]; then
  ASKPASS_FILE="$(mktemp)"
  cat > "$ASKPASS_FILE" <<'EOF'
#!/bin/bash
zenity --password --title="Nhập mật khẩu quản trị (sudo)"
EOF
  chmod +x "$ASKPASS_FILE"
  export SUDO_ASKPASS="$ASKPASS_FILE"
  # Mồi quyền sudo bằng hộp thoại đồ hoạ
  if ! sudo -A -v; then
    zenity --error --text "Sai mật khẩu hoặc đã huỷ. Không cài được."
    exit 1
  fi
  # Giữ quyền sudo còn hiệu lực suốt quá trình cài (cài lâu hơn timeout mặc định)
  ( while true; do sudo -n -v 2>/dev/null || exit; sleep 50; done ) &
  KEEPALIVE_PID=$!
fi

# ==========================================================================
# Các hàm cài đặt cho từng phần mềm
# ==========================================================================

install_chrome() {
  if have_cmd google-chrome-stable || have_cmd google-chrome; then skip_msg "Chrome"; return; fi
  echo "=== Đang cài Chrome ==="
  wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
  sudo apt install -y /tmp/chrome.deb
}

install_telegram() {
  if have_flatpak org.telegram.desktop; then skip_msg "Telegram"; return; fi
  echo "=== Đang cài Telegram (qua Flatpak) ==="
  ensure_flatpak
  sudo flatpak install --system -y flathub org.telegram.desktop
}

# Hàm dùng chung: đảm bảo có lệnh add-apt-repository (thêm PPA/multiverse).
# Kubuntu đôi khi không cài sẵn -> cài software-properties-common.
ensure_ppa_tool() {
  command -v add-apt-repository >/dev/null 2>&1 \
    || sudo apt install -y software-properties-common
}

# Hàm dùng chung: đảm bảo có flatpak + kho Flathub (mức hệ thống).
# Dùng cho các app cài qua Flatpak (WeChat, WPS...). Chỉ chạy phần nặng
# một lần dù gọi nhiều lần.
ensure_flatpak() {
  # Cài flatpak nếu chưa có
  if ! command -v flatpak >/dev/null 2>&1; then
    echo "  -> Chưa có flatpak, đang cài..."
    sudo apt update
    sudo apt install -y flatpak
  fi

  # Đăng ký kho Flathub ở mức hệ thống (--system) nếu chưa có.
  # Phải cùng mức với bước cài (dùng sudo = system), nếu không sẽ
  # lỗi "remote flathub not found".
  sudo flatpak remote-add --system --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo
}

install_wechat() {
  if have_flatpak com.tencent.WeChat; then skip_msg "WeChat"; return; fi
  echo "=== Đang cài WeChat (qua Flatpak) ==="
  ensure_flatpak
  sudo flatpak install --system -y flathub com.tencent.WeChat
}

install_lark() {
  if have_cmd lark || dpkg -l 2>/dev/null | grep -qiE '^ii +lark'; then
    skip_msg "Lark"; return
  fi
  echo "=== Đang cài Lark ==="
  sudo apt install -y curl
  # Lark không có link .deb cố định -> lấy link mới nhất từ API chính thức.
  # Link có chữ ký + hết hạn nhanh nên phải lấy động mỗi lần. platform=10 = Linux x64 .deb.
  # JSON dùng & cho ký tự '&' -> đổi lại bằng sed.
  local URL
  URL="$(curl -sL 'https://www.larksuite.com/api/package_info?platform=10' \
    | sed -n 's/.*"download_link":"\([^"]*\)".*/\1/p' | sed 's/\\u0026/\&/g')"
  if [[ -z "$URL" ]]; then
    echo "  ✗ Không lấy được link tải Lark từ API (có thể API đã đổi) -> bỏ qua."
    return
  fi
  wget -L "$URL" -O /tmp/lark.deb
  sudo apt install -y /tmp/lark.deb
}

install_wps() {
  if have_flatpak com.wps.Office; then skip_msg "WPS Office"; return; fi
  echo "=== Đang cài WPS Office (qua Flatpak) ==="
  ensure_flatpak
  sudo flatpak install --system -y flathub com.wps.Office
}

install_edge() {
  if have_flatpak com.microsoft.Edge; then skip_msg "Microsoft Edge"; return; fi
  echo "=== Đang cài Microsoft Edge (qua Flatpak) ==="
  ensure_flatpak
  sudo flatpak install --system -y flathub com.microsoft.Edge
}

install_coccoc() {
  if have_deb coccoc-browser-stable; then skip_msg "Cốc Cốc"; return; fi
  echo "=== Đang cài Cốc Cốc (trình duyệt Việt Nam) ==="
  # Thêm repo chính thức của Cốc Cốc rồi cài qua apt
  sudo apt install -y curl
  curl https://browser-linux.coccoc.com/deb/public.gpg \
    | sudo gpg --yes --dearmor -o /etc/apt/trusted.gpg.d/coccoc-browser.gpg
  echo "deb [arch=any] https://browser-linux.coccoc.com/deb/ stable main" \
    | sudo tee /etc/apt/sources.list.d/coccoc-browser.list > /dev/null
  sudo apt update
  sudo apt install -y coccoc-browser-stable
}

install_msfonts() {
  if have_deb ttf-mscorefonts-installer; then skip_msg "Font Microsoft"; return; fi
  echo "=== Đang cài font Microsoft (Times New Roman, Arial...) ==="
  # Font MS nằm trong kho multiverse -> bật lên trước
  ensure_ppa_tool
  sudo add-apt-repository -y multiverse
  sudo apt update
  # Tự đồng ý EULA để không bị kẹt ở màn hình hỏi (script chạy suôn)
  echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" \
    | sudo debconf-set-selections
  sudo apt install -y ttf-mscorefonts-installer
  # Cập nhật lại cache font cho ứng dụng nhận ngay
  sudo fc-cache -f
}

install_archive() {
  # Kiểm tra theo LỆNH (tên gói khác nhau giữa các bản Ubuntu) cho chắc:
  #   rar: unrar hoặc unar | 7z: 7z (p7zip-full) hoặc 7zz (gói 7zip mới)
  if { have_cmd unrar || have_cmd unar; } && { have_cmd 7z || have_cmd 7zz; }; then
    skip_msg "Bộ giải nén RAR/7z"; return
  fi
  echo "=== Đang cài bộ giải nén RAR/7z ==="
  # unrar nằm trong kho multiverse -> bật lên trước
  ensure_ppa_tool
  sudo add-apt-repository -y multiverse
  sudo apt update

  # unrar: giải nén .rar. Bản không có 'unrar' thì thử unrar-free/unar.
  sudo apt install -y unrar || sudo apt install -y unrar-free || sudo apt install -y unar

  # 7z: Ubuntu mới đổi 'p7zip-full' -> '7zip'. Cài cái nào có.
  sudo apt install -y 7zip || sudo apt install -y p7zip-full

  # p7zip-rar đã bị bỏ ở Ubuntu mới; gói 7zip/unrar đã lo được .rar rồi nên
  # cái này chỉ là bonus -> có thì cài, không có cũng không sao (không chết).
  sudo apt install -y p7zip-rar 2>/dev/null || true
}

install_anydesk() {
  if have_deb anydesk || have_cmd anydesk; then skip_msg "AnyDesk"; return; fi
  echo "=== Đang cài AnyDesk ==="
  # AnyDesk không có trên kho Ubuntu -> thêm repo chính thức của họ
  sudo apt update
  sudo apt install -y ca-certificates curl apt-transport-https
  sudo install -m 0755 -d /etc/apt/keyrings
  # Thêm khóa GPG của AnyDesk (--yes để ghi đè khi chạy lại, tránh gpg báo lỗi)
  curl -fsSL https://keys.anydesk.com/repos/DEB-GPG-KEY \
    | sudo gpg --yes --dearmor -o /etc/apt/keyrings/anydesk.gpg
  sudo chmod a+r /etc/apt/keyrings/anydesk.gpg
  # Thêm nguồn cài đặt (ký bằng khóa vừa thêm)
  echo "deb [signed-by=/etc/apt/keyrings/anydesk.gpg] http://deb.anydesk.com/ all main" \
    | sudo tee /etc/apt/sources.list.d/anydesk-stable.list >/dev/null
  sudo apt update
  sudo apt install -y anydesk
}

install_vlc() {
  if have_cmd vlc; then skip_msg "VLC"; return; fi
  echo "=== Đang cài VLC ==="
  sudo apt install -y vlc
}

install_rclone() {
  if have_flatpak com.rcloneui.RcloneUI; then skip_msg "Rclone UI"; return; fi
  echo "=== Đang cài Rclone UI (qua Flatpak) ==="
  # rclone CLI (cho lệnh nền) — cài nếu chưa có
  have_cmd rclone && echo "  -> rclone CLI đã có." || sudo apt install -y rclone
  # Rclone UI (app desktop) qua Flatpak cho an toàn
  ensure_flatpak
  sudo flatpak install --system -y flathub com.rcloneui.RcloneUI
}

install_fcitx5() {
  if have_deb fcitx5-unikey; then skip_msg "fcitx5 + Unikey"; return; fi
  echo "=== Đang cài fcitx5 + Unikey ==="
  sudo apt update
  # fcitx5 lõi + Unikey (bộ gõ tiếng Việt) + các module cầu nối cho GTK/Qt/Wayland
  sudo apt install -y \
    fcitx5 \
    fcitx5-unikey \
    fcitx5-config-qt \
    fcitx5-frontend-gtk3 \
    fcitx5-frontend-qt5

  echo "=== Đặt fcitx5 làm bộ gõ mặc định của hệ thống ==="
  # Guard: im-config không phải lúc nào cũng có sẵn; thiếu nó thì bỏ qua
  # thay vì để set -e giết cả script.
  if command -v im-config >/dev/null 2>&1; then
    im-config -n fcitx5
  else
    echo "  (Không tìm thấy im-config, bỏ qua bước này)"
  fi

  echo "=== Set biến môi trường cho fcitx5 (GTK/Qt/Wayland nhận bộ gõ) ==="
  # Ghi vào /etc/environment để có hiệu lực toàn hệ thống sau khi logout/login
  for VAR in "GTK_IM_MODULE=fcitx" "QT_IM_MODULE=fcitx" "XMODIFIERS=@im=fcitx"; do
    KEY="${VAR%%=*}"
    if ! grep -q "^${KEY}=" /etc/environment 2>/dev/null; then
      echo "$VAR" | sudo tee -a /etc/environment >/dev/null
    fi
  done

  echo "=== Tự thêm Unikey vào danh sách bộ gõ của fcitx5 ==="
  # Ghi thẳng file profile để không phải mở fcitx5-configtool bằng tay.
  # Chỉ ghi khi CHƯA có profile, tránh xóa cấu hình fcitx5 cũ (nếu máy đã
  # thêm các bộ gõ khác như tiếng Nhật/Trung...).
  mkdir -p ~/.config/fcitx5
  if [[ -f ~/.config/fcitx5/profile ]]; then
    echo "  (Đã có ~/.config/fcitx5/profile sẵn, KHÔNG ghi đè."
    echo "   Nếu chưa thấy Unikey: mở fcitx5-configtool để thêm thủ công.)"
  else
    cat > ~/.config/fcitx5/profile << 'EOF'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=unikey

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=unikey
Layout=

[GroupOrder]
0=Default
EOF
  fi

  echo "=== Cho fcitx5 tự chạy nền mỗi khi khởi động máy ==="
  mkdir -p ~/.config/autostart
  cat > ~/.config/autostart/fcitx5.desktop << 'EOF'
[Desktop Entry]
Type=Application
Exec=fcitx5
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Fcitx5
EOF
}

install_ibus() {
  if have_deb ibus-bamboo; then skip_msg "ibus-bamboo"; return; fi
  echo "=== Đang cài ibus-bamboo ==="
  ensure_ppa_tool
  sudo add-apt-repository -y ppa:bamboo-engine/ibus-bamboo
  sudo apt update
  sudo apt install -y ibus-bamboo
  ibus restart || true   # tránh set -e giết script nếu ibus chưa chạy
}

# Gán phím Ctrl+Shift+S cho Flameshot trên GNOME (dùng gsettings).
# Tách riêng để chỉ chạy khi desktop là GNOME.
flameshot_shortcut_gnome() {
  echo "=== (GNOME) Đang gán phím Ctrl+Shift+S cho Flameshot ==="
  local KEY_BASE="org.gnome.settings-daemon.plugins.media-keys"
  local CUSTOM_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom-flameshot/"

  local EXISTING
  EXISTING=$(gsettings get $KEY_BASE custom-keybindings)
  if [[ "$EXISTING" != *"custom-flameshot"* ]]; then
    local NEW_LIST
    if [[ "$EXISTING" == "@as []" || "$EXISTING" == "[]" ]]; then
      NEW_LIST="['$CUSTOM_PATH']"
    else
      # Bỏ dấu ']' cuối chuỗi rồi nối thêm phần tử mới (tránh dùng sed vì CUSTOM_PATH chứa dấu '/')
      local TRIMMED="${EXISTING%]}"
      NEW_LIST="${TRIMMED}, '$CUSTOM_PATH']"
    fi
    gsettings set $KEY_BASE custom-keybindings "$NEW_LIST"
  fi

  gsettings set $KEY_BASE.custom-keybinding:$CUSTOM_PATH name 'Flameshot'
  gsettings set $KEY_BASE.custom-keybinding:$CUSTOM_PATH command 'flameshot gui'
  gsettings set $KEY_BASE.custom-keybinding:$CUSTOM_PATH binding '<Control><Shift>s'
}

install_flameshot() {
  if have_cmd flameshot; then skip_msg "Flameshot"; return; fi
  echo "=== Đang cài Flameshot ==="
  # Portal cài ĐÚNG theo desktop, KHÔNG cài chéo:
  #   GNOME -> gnome | KDE -> kde | Cinnamon/MATE/Xfce/khác -> gtk
  local PORTAL_PKG
  case "$DESKTOP_ENV" in
    kde)   PORTAL_PKG="xdg-desktop-portal-kde" ;;
    gnome) PORTAL_PKG="xdg-desktop-portal-gnome" ;;
    *)     PORTAL_PKG="xdg-desktop-portal-gtk" ;;
  esac
  sudo apt install -y flameshot xdg-desktop-portal "$PORTAL_PKG"

  echo "=== Đang cấp quyền chụp màn hình cho Flameshot (fix lỗi Wayland 'Unable to capture screen') ==="
  # PermissionStore là của xdg-desktop-portal (dùng chung cho cả GNOME lẫn KDE).
  # Xóa quyền cũ để hệ thống hỏi lại quyền chụp màn hình.
  dbus-send --session --print-reply=literal \
    --dest=org.freedesktop.impl.portal.PermissionStore \
    /org/freedesktop/impl/portal/PermissionStore \
    org.freedesktop.impl.portal.PermissionStore.Delete \
    string:'screenshot' string:'screenshot' 2>/dev/null || true

  # Gán phím tắt: GNOME làm tự động; các desktop khác hướng dẫn làm tay.
  if [[ "$DESKTOP_ENV" == "gnome" ]]; then
    flameshot_shortcut_gnome
  else
    echo "=== ($DESKTOP_ENV) Không tự gán phím được -> gán tay lệnh 'flameshot gui' cho Ctrl+Shift+S. ==="
  fi

  # Cho Flameshot tự chạy nền mỗi khi khởi động máy (chuẩn freedesktop).
  mkdir -p ~/.config/autostart
  cat > ~/.config/autostart/flameshot.desktop << 'EOF'
[Desktop Entry]
Type=Application
Exec=flameshot
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Flameshot
EOF
}

# ==========================================================================
# Xử lý xung đột 2 bộ gõ (fcitx5 + ibus) trước khi cài
# ==========================================================================
SKIP_IBUS=0
if is_selected fcitx5 && is_selected ibus; then
  Q="Bạn đã chọn CẢ fcitx5 LẪN ibus-bamboo. Chạy song song 2 bộ gõ dễ xung đột, nên chỉ dùng 1.

Bấm OK để chỉ cài fcitx5 (bỏ ibus). Bấm Cancel để cài cả hai."
  if [[ $GUI == 1 ]]; then
    if zenity --question --title "Trùng bộ gõ" --text "$Q"; then SKIP_IBUS=1; fi
  else
    echo "⚠️  $Q"
    read -r -p "Bỏ ibus? [Enter = bỏ ibus / gõ 'n' rồi Enter = cài cả 2]: " ANSWER
    [[ "$ANSWER" != "n" && "$ANSWER" != "N" ]] && SKIP_IBUS=1
  fi
fi

# ==========================================================================
# Dựng danh sách app sẽ cài (theo thứ tự APP_ORDER)
# ==========================================================================
RUN_LIST=()
for tag in "${APP_ORDER[@]}"; do
  is_selected "$tag" || continue
  [[ "$tag" == "ibus" && "$SKIP_IBUS" == 1 ]] && continue
  RUN_LIST+=("$tag")
done

LOG="$HOME/caidat-log.txt"
FAILLOG="$(mktemp)"
: > "$LOG"

# Cài 1 app, ghi log; trả 0 nếu OK, 1 nếu lỗi (không để set -e giết vòng lặp)
install_one() {
  local tag="$1"
  { echo "########## ${APP_LABEL[$tag]} ##########"; "install_$tag"; } >>"$LOG" 2>&1
}

# ==========================================================================
# Chạy cài đặt
# ==========================================================================
if [[ $GUI == 1 ]]; then
  # Xuất tiến trình cho zenity --progress: dòng '# text' = mô tả, số = phần trăm
  run_gui() {
    local total=${#RUN_LIST[@]} i=0 tag
    for tag in "${RUN_LIST[@]}"; do
      i=$((i+1))
      echo "# ($i/$total) Đang cài ${APP_LABEL[$tag]} ..."
      echo $(( (i-1)*100 / (total>0?total:1) ))
      install_one "$tag" || echo "$tag" >> "$FAILLOG"
    done
    echo "# Hoàn tất"
    echo 100
  }
  run_gui | zenity --progress --title "Đang cài đặt phần mềm" \
    --text "Chuẩn bị..." --percentage=0 --auto-close --no-cancel --width 520 || true
else
  # Terminal: in trực tiếp cho thấy tiến trình; dừng ngay nếu 1 app lỗi (set -e)
  for tag in "${RUN_LIST[@]}"; do
    echo "########## ${APP_LABEL[$tag]} ##########"
    "install_$tag" || echo "$tag" >> "$FAILLOG"
  done
fi

# ==========================================================================
# Ghi chú sau cài (in ra terminal hoặc gộp vào 1 cửa sổ zenity)
# ==========================================================================
build_notes() {
  if is_selected telegram; then
    echo "• Telegram/WeChat/WPS/Edge/Rclone UI cài qua Flatpak: nếu chưa thấy trong menu, hãy ĐĂNG XUẤT/ĐĂNG NHẬP lại."
  fi
  if is_selected rclone; then
    echo "• Rclone UI: mở app rồi thêm remote (Google Drive/cloud), sau đó kéo-thả file để đồng bộ."
  fi
  if is_selected fcitx5; then
    echo "• fcitx5: ĐĂNG XUẤT/KHỞI ĐỘNG LẠI để bộ gõ có hiệu lực. Chuyển gõ tiếng Việt: Ctrl+Space. Đổi Telex/VNI: mở fcitx5-configtool."
  fi
  if is_selected ibus && [[ "$SKIP_IBUS" != 1 ]]; then
    echo "• ibus-bamboo: ĐĂNG XUẤT/KHỞI ĐỘNG LẠI, rồi vào Cài đặt bàn phím > Input Sources thêm 'Bamboo'."
  fi
  if is_selected flameshot; then
    if [[ "$DESKTOP_ENV" == "gnome" ]]; then
      echo "• Flameshot: đã gán phím Ctrl+Shift+S để chụp màn hình."
    else
      echo "• Flameshot: hãy vào Cài đặt phím tắt của desktop, gán lệnh 'flameshot gui' cho Ctrl+Shift+S."
    fi
  fi
}

FAILED="$( [[ -s "$FAILLOG" ]] && while read -r t; do echo "${APP_LABEL[$t]}"; done < "$FAILLOG" )"
rm -f "$FAILLOG"

if [[ $GUI == 1 ]]; then
  SUMMARY="✅ Đã cài xong (chi tiết log: $LOG)"
  NOTES="$(build_notes)"
  [[ -n "$NOTES" ]] && SUMMARY="$SUMMARY

Lưu ý:
$NOTES"
  if [[ -n "$FAILED" ]]; then
    SUMMARY="$SUMMARY

⚠️ Một số mục CHƯA cài được:
$FAILED
Xem log: $LOG"
    zenity --warning --title "Hoàn tất (có lỗi)" --text "$SUMMARY" --width 560
  else
    zenity --info --title "Hoàn tất" --text "$SUMMARY" --width 560
  fi
else
  echo ""
  echo "=== XONG! ==="
  build_notes
  if [[ -n "$FAILED" ]]; then
    echo ""
    echo "⚠️ Một số mục CHƯA cài được:"
    echo "$FAILED"
    echo "Xem log: $LOG"
  fi
fi
