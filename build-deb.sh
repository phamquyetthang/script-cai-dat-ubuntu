#!/bin/bash
# Đóng gói caidat.sh thành file .deb để gửi cho người dùng cuối.
# Chạy: ./build-deb.sh  -> tạo ra cai-dat-phan-mem_<version>_all.deb
set -e
cd "$(dirname "$0")"

PKG="cai-dat-phan-mem"
VERSION="$(grep -m1 '^Version:' packaging/DEBIAN/control | awk '{print $2}')"

BUILD="$(mktemp -d)"
# Chép khung gói (DEBIAN/control + usr/share/applications/...)
cp -r packaging/. "$BUILD/"
# Chép script cài thành lệnh /usr/bin/cai-dat-phan-mem
install -D -m 755 caidat.sh "$BUILD/usr/bin/$PKG"

# Chuẩn quyền thư mục
find "$BUILD" -type d -exec chmod 755 {} +
chmod 644 "$BUILD/usr/share/applications/$PKG.desktop"

OUT="${PKG}_${VERSION}_all.deb"
# --root-owner-group: file thuộc root:root (tránh cảnh báo quyền sở hữu)
dpkg-deb --build --root-owner-group "$BUILD" "$OUT"
rm -rf "$BUILD"

echo "Đã tạo: $OUT"
