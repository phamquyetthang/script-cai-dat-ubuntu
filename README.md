# Script cài đặt Ubuntu cho dân văn phòng VN

Script `caidat.sh` giúp cài nhanh các phần mềm thường dùng trên Ubuntu (GNOME).
Khi chạy, script hiện **màn hình checkbox** để bạn tick chọn cần cài gì — không
cài bừa cả loạt.

## Danh sách phần mềm

| Mục | Cách cài | Mặc định |
|-----|----------|:--------:|
| Google Chrome | `.deb` chính thức | ✅ ON |
| Telegram Desktop | Snap | ✅ ON |
| ibus-bamboo (bộ gõ tiếng Việt) | PPA | ✅ ON |
| Microsoft Edge | Flatpak (Flathub) | ⬜ OFF |
| Cốc Cốc (trình duyệt Việt Nam) | repo chính thức | ⬜ OFF |
| WeChat | Flatpak (Flathub) | ⬜ OFF |
| WPS Office | Flatpak (Flathub) | ⬜ OFF |
| Font Microsoft (Times New Roman, Arial...) | apt (multiverse) | ⬜ OFF |
| Bộ giải nén RAR/7z (unrar + p7zip) | apt (multiverse) | ⬜ OFF |
| AnyDesk (điều khiển từ xa) | repo chính thức | ⬜ OFF |
| VLC | apt | ⬜ OFF |
| Rclone UI (đồng bộ Google Drive/cloud) | `.deb` chính thức | ⬜ OFF |
| fcitx5 + Unikey (bộ gõ tiếng Việt) | apt | ⬜ OFF |
| Flameshot (chụp màn hình + phím Ctrl+Shift+S) | apt | ⬜ OFF |

## Cách dùng

> ⚠️ **Không chạy bằng `sudo`** và **không chạy kiểu `curl ... | bash`**.
> Script có giao diện checkbox (whiptail) và bước hỏi cần bàn phím, nếu pipe
> qua `| bash` sẽ hỏng. Hãy **tải file về rồi chạy**.

```bash
git clone https://github.com/phamquyetthang/script-cai-dat-ubuntu.git
cd script-cai-dat-ubuntu
chmod +x caidat.sh
./caidat.sh
```

Hoặc tải nhanh một file:

```bash
curl -o caidat.sh https://raw.githubusercontent.com/phamquyetthang/script-cai-dat-ubuntu/main/caidat.sh
chmod +x caidat.sh
./caidat.sh
```

Trong màn hình chọn: dùng **mũi tên** để di chuyển, **SPACE** để tick, **ENTER**
để xác nhận. Script tự xin `sudo` khi cần.

## Ghi chú

- **Bộ gõ tiếng Việt**: chọn **một** trong hai (ibus-bamboo *hoặc* fcitx5+Unikey).
  Nếu lỡ tick cả hai, script sẽ cảnh báo. Sau khi cài nhớ **đăng xuất/khởi động
  lại** để bộ gõ có hiệu lực.
- **App Flatpak** (Edge, WeChat, WPS): nếu chưa thấy trong menu ứng dụng, đăng
  xuất/đăng nhập lại một lần.
- **AnyDesk trên Wayland**: có thể xem được nhưng điều khiển chuột/bàn phím bị
  hạn chế. Cần điều khiển đầy đủ thì đăng nhập chọn session "Ubuntu on Xorg".

## Môi trường

Chạy được trên các bản nền Ubuntu, tự nhận diện desktop để **không cài chéo**:

- **Ubuntu (GNOME)** — đầy đủ, gán phím Flameshot tự động.
- **Kubuntu (KDE)** — cài portal KDE, Telegram tự cài `snapd`, phím Flameshot gán tay.
- **Linux Mint (Cinnamon/MATE/Xfce)** — Telegram cài qua Flatpak (Mint chặn snap),
  portal `gtk`, phím Flameshot gán tay.

Lưu ý: **LMDE** (Mint bản Debian) không dùng được PPA nên ibus-bamboo sẽ không cài
được; các mục khác vẫn chạy.

## Giấy phép

[MIT](LICENSE)
