#!/usr/bin/env bash
set -e

# Cinemuse Debian Package Builder
# Usage: ./linux/packaging/build_deb.sh [VERSION] [ARCH]
# Example: ./linux/packaging/build_deb.sh 1.2.0 amd64

VERSION="${1:-1.0.0}"
ARCH="${2:-amd64}"
PKG_NAME="cinemuse-app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUNDLE_DIR="${ROOT_DIR}/build/linux/x64/release/bundle"
WORK_DIR="${ROOT_DIR}/build/linux/deb_packaging"

echo "=== Building Cinemuse Debian Package ==="
echo "Version: ${VERSION}"
echo "Architecture: ${ARCH}"
echo "Bundle Dir: ${BUNDLE_DIR}"

if [ ! -d "${BUNDLE_DIR}" ] || [ ! -f "${BUNDLE_DIR}/cinemuse_app" ]; then
    echo "Error: Bundle not found at ${BUNDLE_DIR}."
    echo "Please build the Flutter release bundle first: flutter build linux --release"
    exit 1
fi

# Clean up previous packaging workspace
rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}/DEBIAN"
mkdir -p "${WORK_DIR}/opt/cinemuse_app"
mkdir -p "${WORK_DIR}/usr/bin"
mkdir -p "${WORK_DIR}/usr/share/applications"
mkdir -p "${WORK_DIR}/usr/share/icons/hicolor"

# 1. Copy bundle contents to /opt/cinemuse_app
cp -r "${BUNDLE_DIR}"/* "${WORK_DIR}/opt/cinemuse_app/"

# 2. Create launcher symlink in /usr/bin
ln -sf /opt/cinemuse_app/cinemuse_app "${WORK_DIR}/usr/bin/cinemuse_app"

# 3. Copy desktop file
cp "${SCRIPT_DIR}/cinemuse.desktop" "${WORK_DIR}/usr/share/applications/cinemuse.desktop"

# 4. Copy icons
if [ -d "${SCRIPT_DIR}/icons/hicolor" ]; then
    cp -r "${SCRIPT_DIR}/icons/hicolor"/* "${WORK_DIR}/usr/share/icons/hicolor/"
fi

# 5. Generate Debian control file
cat <<EOF > "${WORK_DIR}/DEBIAN/control"
Package: ${PKG_NAME}
Version: ${VERSION}
Section: video
Priority: optional
Architecture: ${ARCH}
Depends: libc6, libgtk-3-0, libglib2.0-0, libsecret-1-0, libmpv2 | libmpv1
Maintainer: Cinemuse Team <contact@cinemuse.app>
Description: Modern media browser and player
 Cinemuse is a desktop and mobile media browser and player for movies,
 TV shows, anime, and live streams with hardware-accelerated playback.
EOF

# 6. Generate postinst script for desktop and icon caches
cat <<'EOF' > "${WORK_DIR}/DEBIAN/postinst"
#!/bin/sh
set -e

if which update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q /usr/share/applications || true
fi

if which gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi

exit 0
EOF
chmod 755 "${WORK_DIR}/DEBIAN/postinst"

# 7. Generate postrm script
cat <<'EOF' > "${WORK_DIR}/DEBIAN/postrm"
#!/bin/sh
set -e

if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
    if which update-desktop-database >/dev/null 2>&1; then
        update-desktop-database -q /usr/share/applications || true
    fi
    if which gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
    fi
fi

exit 0
EOF
chmod 755 "${WORK_DIR}/DEBIAN/postrm"

# 8. Set correct file permissions for dpkg
find "${WORK_DIR}" -type d -exec chmod 755 {} +
find "${WORK_DIR}/opt/cinemuse_app" -type f -exec chmod 644 {} +
chmod 755 "${WORK_DIR}/opt/cinemuse_app/cinemuse_app"
[ -d "${WORK_DIR}/opt/cinemuse_app/lib" ] && find "${WORK_DIR}/opt/cinemuse_app/lib" -type f -exec chmod 644 {} +
[ -d "${WORK_DIR}/usr/share" ] && find "${WORK_DIR}/usr/share" -type f -exec chmod 644 {} +
chmod 755 "${WORK_DIR}/DEBIAN/control"

# 9. Build .deb package
OUTPUT_DIR="${ROOT_DIR}/build/linux"
mkdir -p "${OUTPUT_DIR}"
DEB_FILE="${OUTPUT_DIR}/cinemuse_${VERSION}_${ARCH}.deb"

dpkg-deb --build --root-owner-group "${WORK_DIR}" "${DEB_FILE}"

echo "=== Successfully built Debian package ==="
echo "Package: ${DEB_FILE}"
ls -lh "${DEB_FILE}"