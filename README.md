# Script cài đặt Ubuntu cho dân văn phòng VN

Script `caidat.sh` giúp cài nhanh các phần mềm thường dùng trên Ubuntu (GNOME).
Khi chạy, script hiện **màn hình checkbox** để bạn tick chọn cần cài gì — không
cài bừa cả loạt.

## Danh sách phần mềm

| Mục | Cách cài | Mặc định |
|-----|----------|:--------:|
| Google Chrome | `.deb` chính thức | ✅ ON |
| Telegram Desktop | Flatpak (Flathub) | ✅ ON |
| ibus-bamboo (bộ gõ tiếng Việt) | PPA | ✅ ON |
| Microsoft Edge | Flatpak (Flathub) | ⬜ OFF |
| Cốc Cốc (trình duyệt Việt Nam) | repo chính thức | ⬜ OFF |
| WeChat | Flatpak (Flathub) | ⬜ OFF |
| Lark (Lark Suite) | `.deb` chính thức (lấy link động qua API) | ⬜ OFF |
| WPS Office | Flatpak (Flathub) | ⬜ OFF |
| Font Microsoft (Times New Roman, Arial...) | apt (multiverse) | ⬜ OFF |
| Bộ giải nén RAR/7z (unrar + p7zip) | apt (multiverse) | ⬜ OFF |
| AnyDesk (điều khiển từ xa) | repo chính thức | ⬜ OFF |
| VLC | apt | ⬜ OFF |
| Rclone UI (đồng bộ Google Drive/cloud) | Flatpak (Flathub) | ⬜ OFF |
| fcitx5 + Unikey (bộ gõ tiếng Việt) | apt | ⬜ OFF |
| Flameshot (chụp màn hình + phím Ctrl+Shift+S) | apt | ⬜ OFF |

## Cách dùng

Script tự nhận biết môi trường:
- **Có màn hình đồ hoạ** → hiện **cửa sổ tick chọn (zenity)**, hỏi mật khẩu bằng
  cửa sổ, có thanh tiến trình. Không cần dùng terminal.
- **Chạy trong terminal** (không có đồ hoạ) → hiện checkbox `whiptail`.

### Cho người dùng cuối (không rành máy) — double-click

1. Tải toàn bộ thư mục về (bấm **Code ▸ Download ZIP** trên GitHub rồi giải nén).
2. Mở thư mục, **double-click** file **`cai-dat-phan-mem.desktop`**.
   - Lần đầu trên GNOME/Ubuntu: chuột phải file → **Allow Launching** (Cho phép
     chạy), rồi double-click lại.
3. Cửa sổ hiện lên → tick phần mềm cần cài → **OK** → nhập mật khẩu máy → chờ
   thanh tiến trình chạy xong.

### Cho người rành dùng dòng lệnh

```bash
git clone https://github.com/phamquyetthang/script-cai-dat-ubuntu.git
cd script-cai-dat-ubuntu
chmod +x caidat.sh
./caidat.sh
```

> ⚠️ **Không chạy bằng `sudo`** và **không `curl ... | bash`** — script tự xin
> mật khẩu khi cần, và giao diện chọn cần bàn phím/đồ hoạ nên pipe sẽ hỏng.

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
- **Kubuntu (KDE)** — cài portal KDE, phím Flameshot gán tay.
- **Linux Mint (Cinnamon/MATE/Xfce)** — portal `gtk`, phím Flameshot gán tay.

Các app nhắn tin/office (Telegram, WeChat, WPS, Edge, Rclone UI) đều cài qua
**Flatpak/Flathub** nên giống nhau trên mọi bản.

Lưu ý: **LMDE** (Mint bản Debian) không dùng được PPA nên ibus-bamboo sẽ không cài
được; các mục khác vẫn chạy.

## Giấy phép

[MIT](LICENSE)
