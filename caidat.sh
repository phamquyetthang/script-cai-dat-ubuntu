#!/bin/bash
set -e

# ==========================================================================
# Chặn chạy bằng sudo: script phải chạy dưới user thường
# ==========================================================================
# Nếu chạy nguyên script bằng sudo thì ~/.config/*, gsettings, im-config sẽ
# tác động vào root thay vì user -> bộ gõ và phím tắt không có tác dụng.
if [[ $EUID -eq 0 ]]; then
  echo "Đừng chạy bằng sudo. Chạy: ./caidat.sh (script tự xin sudo khi cần)."
  exit 1
fi

# ==========================================================================
# Bước hỏi: hiện checkbox cho user tick chọn cài cái gì
# ==========================================================================
# Dùng whiptail (có sẵn trên Ubuntu). Nếu không có thì cài dialog/whiptail.
if ! command -v whiptail >/dev/null 2>&1; then
  echo "Đang cài whiptail để hiện màn hình chọn..."
  sudo apt install -y whiptail
fi

# Danh sách phần mềm: tag "mô tả" trạng-thái-mặc-định
CHOICES=$(whiptail --title "Chọn phần mềm cần cài" \
  --checklist "Dùng phím MŨI TÊN để di chuyển, SPACE để tick chọn, ENTER để xác nhận:" \
  22 80 15 \
  "chrome"   "Google Chrome"                                   ON \
  "telegram" "Telegram Desktop (qua Snap)"                     ON \
  "ibus"     "ibus-bamboo (bộ gõ tiếng Việt)"                  ON \
  "edge"     "Microsoft Edge (qua Flatpak/Flathub)"            OFF \
  "coccoc"   "Cốc Cốc (trình duyệt Việt Nam)"                  OFF \
  "wechat"   "WeChat (qua Flatpak/Flathub)"                    OFF \
  "wps"      "WPS Office (qua Flatpak/Flathub)"                OFF \
  "msfonts"  "Font Microsoft (Times New Roman, Arial...)"      OFF \
  "archive"  "Bộ giải nén RAR/7z (unrar + p7zip)"              OFF \
  "anydesk"  "AnyDesk (điều khiển máy từ xa)"                  OFF \
  "vlc"      "VLC (xem video mọi định dạng)"                   OFF \
  "rclone"   "Rclone UI (app đồng bộ Google Drive/cloud)"      OFF \
  "fcitx5"   "fcitx5 + Unikey (bộ gõ tiếng Việt)"              OFF \
  "flameshot" "Flameshot (chụp màn hình + phím tắt)"           OFF \
  3>&1 1>&2 2>&3) || { echo "Đã hủy. Không cài gì cả."; exit 0; }

if [[ -z "$CHOICES" ]]; then
  echo "Bạn chưa tick chọn gì cả. Thoát."
  exit 0
fi

# Hàm kiểm tra một tag có được tick hay không
is_selected() {
  [[ "$CHOICES" == *"\"$1\""* ]]
}

# ==========================================================================
# Các hàm cài đặt cho từng phần mềm
# ==========================================================================

install_chrome() {
  echo "=== Đang cài Chrome ==="
  wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
  sudo apt install -y /tmp/chrome.deb
}

install_telegram() {
  echo "=== Đang cài Telegram (qua Snap) ==="
  sudo snap install telegram-desktop
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
  echo "=== Đang cài WeChat (qua Flatpak) ==="
  ensure_flatpak
  sudo flatpak install --system -y flathub com.tencent.WeChat
}

install_wps() {
  echo "=== Đang cài WPS Office (qua Flatpak) ==="
  ensure_flatpak
  sudo flatpak install --system -y flathub com.wps.Office
}

install_edge() {
  echo "=== Đang cài Microsoft Edge (qua Flatpak) ==="
  ensure_flatpak
  sudo flatpak install --system -y flathub com.microsoft.Edge
}

install_coccoc() {
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
  echo "=== Đang cài font Microsoft (Times New Roman, Arial...) ==="
  # Font MS nằm trong kho multiverse -> bật lên trước
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
  echo "=== Đang cài bộ giải nén RAR/7z ==="
  # unrar nằm trong kho multiverse -> bật lên trước
  sudo add-apt-repository -y multiverse
  sudo apt update
  # unrar: giải nén .rar (kể cả RAR5) | p7zip: .7z và các định dạng khác
  sudo apt install -y unrar p7zip-full p7zip-rar
}

install_anydesk() {
  echo "=== Đang cài AnyDesk ==="
  # AnyDesk không có trên kho Ubuntu -> thêm repo chính thức của họ
  sudo apt update
  sudo apt install -y ca-certificates curl apt-transport-https
  sudo install -m 0755 -d /etc/apt/keyrings
  # Thêm khóa GPG của AnyDesk
  curl -fsSL https://keys.anydesk.com/repos/DEB-GPG-KEY \
    | sudo gpg --dearmor -o /etc/apt/keyrings/anydesk.gpg
  sudo chmod a+r /etc/apt/keyrings/anydesk.gpg
  # Thêm nguồn cài đặt (ký bằng khóa vừa thêm)
  echo "deb [signed-by=/etc/apt/keyrings/anydesk.gpg] http://deb.anydesk.com/ all main" \
    | sudo tee /etc/apt/sources.list.d/anydesk-stable.list >/dev/null
  sudo apt update
  sudo apt install -y anydesk
}

install_vlc() {
  echo "=== Đang cài VLC ==="
  sudo apt install -y vlc
}

install_rclone() {
  echo "=== Đang cài Rclone UI (app desktop) ==="
  # Cài rclone CLI trước (Rclone UI dùng rclone ở bên dưới; và để có lệnh nền)
  sudo apt install -y rclone

  # Tải bản .deb chính thức của Rclone UI rồi cài như Chrome.
  # get.rcloneui.com/linux-deb tự chuyển hướng tới bản mới nhất; wget bám theo.
  echo "  -> Tải bản .deb mới nhất của Rclone UI..."
  wget -L https://get.rcloneui.com/linux-deb -O /tmp/rcloneui.deb
  sudo apt install -y /tmp/rcloneui.deb
}

install_fcitx5() {
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
  echo "=== Đang cài ibus-bamboo ==="
  sudo add-apt-repository -y ppa:bamboo-engine/ibus-bamboo
  sudo apt update
  sudo apt install -y ibus-bamboo
  ibus restart
}

install_flameshot() {
  echo "=== Đang cài Flameshot ==="
  sudo apt install -y flameshot xdg-desktop-portal xdg-desktop-portal-gnome

  echo "=== Đang cấp quyền chụp màn hình cho Flameshot (fix lỗi Wayland 'Unable to capture screen') ==="
  # Xóa quyền cũ (nếu từng bị từ chối) để GNOME hỏi lại quyền chụp màn hình
  dbus-send --session --print-reply=literal \
    --dest=org.freedesktop.impl.portal.PermissionStore \
    /org/freedesktop/impl/portal/PermissionStore \
    org.freedesktop.impl.portal.PermissionStore.Delete \
    string:'screenshot' string:'screenshot' 2>/dev/null || true

  echo "=== Đang gán phím Ctrl+Shift+S cho Flameshot ==="
  # Thêm custom shortcut mới gọi Flameshot bằng tổ hợp Ctrl+Shift+S
  KEY_BASE="org.gnome.settings-daemon.plugins.media-keys"
  CUSTOM_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom-flameshot/"

  EXISTING=$(gsettings get $KEY_BASE custom-keybindings)
  if [[ "$EXISTING" != *"custom-flameshot"* ]]; then
    if [[ "$EXISTING" == "@as []" || "$EXISTING" == "[]" ]]; then
      NEW_LIST="['$CUSTOM_PATH']"
    else
      # Bỏ dấu ']' cuối chuỗi rồi nối thêm phần tử mới (tránh dùng sed vì CUSTOM_PATH chứa dấu '/')
      TRIMMED="${EXISTING%]}"
      NEW_LIST="${TRIMMED}, '$CUSTOM_PATH']"
    fi
    gsettings set $KEY_BASE custom-keybindings "$NEW_LIST"
  fi

  gsettings set $KEY_BASE.custom-keybinding:$CUSTOM_PATH name 'Flameshot'
  gsettings set $KEY_BASE.custom-keybinding:$CUSTOM_PATH command 'flameshot gui'
  gsettings set $KEY_BASE.custom-keybinding:$CUSTOM_PATH binding '<Control><Shift>s'

  # Cho Flameshot tự chạy nền mỗi khi khởi động máy
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
# Chạy cài đặt theo lựa chọn
# ==========================================================================
# Cảnh báo nếu lỡ tick cả 2 bộ gõ cùng lúc (dễ xung đột, chỉ nên dùng 1)
if is_selected fcitx5 && is_selected ibus; then
  echo "⚠️  CẢNH BÁO: Bạn đã chọn CẢ fcitx5 LẪN ibus-bamboo."
  echo "    Chạy song song 2 bộ gõ dễ gây xung đột, gõ lỗi lung tung."
  echo "    Khuyên chỉ dùng fcitx5. Bỏ qua ibus? [Enter = bỏ ibus / gõ 'y' = vẫn cài cả 2]"
  read -r ANSWER
  if [[ "$ANSWER" != "y" && "$ANSWER" != "Y" ]]; then
    echo "    → Sẽ chỉ cài fcitx5, bỏ qua ibus-bamboo."
    SKIP_IBUS=1
  fi
fi

is_selected chrome    && install_chrome
is_selected telegram  && install_telegram
is_selected wechat    && install_wechat
is_selected wps       && install_wps
is_selected edge      && install_edge
is_selected coccoc    && install_coccoc
is_selected msfonts   && install_msfonts
is_selected archive   && install_archive
is_selected anydesk   && install_anydesk
is_selected vlc       && install_vlc
is_selected rclone    && install_rclone
is_selected fcitx5    && install_fcitx5
is_selected ibus && [[ "${SKIP_IBUS:-0}" != "1" ]] && install_ibus
is_selected flameshot && install_flameshot

echo ""
echo "=== XONG! ==="
if is_selected wechat; then
  echo "[WeChat] Cài qua Flatpak. Nếu chưa thấy trong menu ứng dụng, đăng xuất/đăng nhập lại một lần."
  echo "[WeChat] Chạy tay bằng lệnh: flatpak run com.tencent.WeChat"
fi
if is_selected wps; then
  echo "[WPS] Cài qua Flatpak. Nếu chưa thấy trong menu ứng dụng, đăng xuất/đăng nhập lại một lần."
  echo "[WPS] Chạy tay bằng lệnh: flatpak run com.wps.Office"
fi
if is_selected edge; then
  echo "[Edge] Cài qua Flatpak. Nếu chưa thấy trong menu ứng dụng, đăng xuất/đăng nhập lại một lần."
  echo "[Edge] Chạy tay bằng lệnh: flatpak run com.microsoft.Edge"
fi
if is_selected rclone; then
  echo "[Rclone UI] Mở app 'Rclone UI' trong menu ứng dụng. Lần đầu vào thêm remote (Google Drive/cloud) rồi kéo-thả file."
fi
if is_selected fcitx5; then
  echo "[fcitx5] Nhớ ĐĂNG XUẤT/KHỞI ĐỘNG LẠI máy để bộ gõ có hiệu lực (biến môi trường + session mới)."
  echo "[fcitx5] Unikey đã được thêm sẵn vào danh sách bộ gõ. Chuyển English <-> tiếng Việt bằng: Ctrl + Space."
  echo "[fcitx5] Muốn đổi kiểu gõ (Telex/VNI) hoặc bảng mã: mở 'Fcitx5 Configuration' (lệnh: fcitx5-configtool)."
fi
if is_selected ibus && [[ "${SKIP_IBUS:-0}" != "1" ]]; then
  echo "[ibus] Nhớ đăng xuất/khởi động lại máy để dùng được ibus-bamboo (bộ gõ tiếng Việt)."
  echo "[ibus] Sau khi khởi động lại, vào Settings > Keyboard > Input Sources, thêm 'Bamboo' để dùng."
fi
if is_selected flameshot; then
  echo "Flameshot đã được gán vào tổ hợp Ctrl+Shift+S, dùng thử ngay được (có thể cần đăng xuất/đăng nhập lại nếu chưa nhận phím)."
  echo "Lần đầu bấm Ctrl+Shift+S, nếu GNOME hiện hộp thoại xin quyền chụp màn hình, nhớ bấm Allow/Cho phép."
fi
