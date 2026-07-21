#!/bin/bash
set -e

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
  20 70 6 \
  "chrome"   "Google Chrome"                          ON \
  "telegram" "Telegram Desktop (qua Snap)"            ON \
  "ibus"     "ibus-bamboo (bộ gõ tiếng Việt)"         ON \
  "flameshot" "Flameshot (chụp màn hình + phím tắt)"  ON \
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
is_selected chrome    && install_chrome
is_selected telegram  && install_telegram
is_selected ibus      && install_ibus
is_selected flameshot && install_flameshot

echo ""
echo "=== XONG! ==="
if is_selected ibus; then
  echo "Nhớ đăng xuất/khởi động lại máy để dùng được ibus-bamboo (bộ gõ tiếng Việt)."
  echo "Sau khi khởi động lại, vào Settings > Keyboard > Input Sources, thêm 'Bamboo' để dùng."
fi
if is_selected flameshot; then
  echo "Flameshot đã được gán vào tổ hợp Ctrl+Shift+S, dùng thử ngay được (có thể cần đăng xuất/đăng nhập lại nếu chưa nhận phím)."
  echo "Lần đầu bấm Ctrl+Shift+S, nếu GNOME hiện hộp thoại xin quyền chụp màn hình, nhớ bấm Allow/Cho phép."
fi
