#!/bin/bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export DEBEMAIL=github-actions@github.com
export DEBFULLNAME=github-actions

git config --global user.email github-actions@github.com
git config --global user.name github-actions

set -x

apt-get update
apt-get -y full-upgrade
apt-get -y install packaging-dev equivs

(
  cd linux

  LANG=C fakeroot debian/rules clean
  mk-build-deps -i -r -t "apt-get -f -y --force-yes"

  # Local changes
  git revert --no-edit ebddb1404900657b7f03a56ee4c34a9d218c4030
  sed -i "/^CONFIG_NF_NAT_OVS/d" ./debian.master/config/annotations
  dch --local "+adari" "Rebuilt for Adari"
  dch --release ""

  LANG=C fakeroot debian/rules binary-headers binary-generic binary-perarch
)

(
  cd linux-meta

  LANG=C fakeroot debian/rules clean
  mk-build-deps -i -r -t "apt-get -f -y --force-yes"

  # Local changes
  cat << 'EOF' >> debian/control.d/generic
Package: linux-image-unsigned-generic${variant:suffix}
Architecture: amd64 armhf arm64 powerpc ppc64el s390x
Section: kernel
Provides: ${dkms:v4l2loopback-modules} ${dkms:zfs-modules} ${dkms:virtualbox-guest-modules} ${dkms:wireguard-linux-compat-modules}
Depends: ${misc:Depends}, linux-image-unsigned-${kernel-abi-version}-generic, linux-modules-extra-${kernel-abi-version}-generic [amd64 arm64 powerpc ppc64el s390x], linux-firmware [amd64 armhf arm64 ppc64el], intel-microcode [amd64], amd64-microcode [amd64]
Recommends: thermald [amd64]
Description: Generic Linux unsigned kernel image
 This package will always depend on the latest generic unsigned kernel image
 available.

Package: linux-unsigned-generic${variant:suffix}
Architecture: amd64 armhf arm64 powerpc ppc64el s390x
Section: kernel
Provides: ${test:provides-full-generic} ${test:provides-full-preferred}
Depends: ${misc:Depends}, linux-image-unsigned-generic${variant:suffix} (= ${binary:Version}), linux-headers-generic${variant:suffix} (= ${binary:Version})
Description: Complete Generic Linux unsigned kernel and headers
 This package will always depend on the latest complete generic unsigned Linux kernel
 and headers.
EOF
  dch --local "+adari" "Rebuilt for Adari"
  dch --release ""

  LANG=C fakeroot debian/rules binary
)
