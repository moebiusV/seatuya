# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools

DESCRIPTION="C wrapper library for tuyapp Tuya device communication"
HOMEPAGE="https://github.com/MAINTAINER/seatuya"
SRC_URI="https://github.com/MAINTAINER/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="BSD-2 GPL-3+ MIT"
SLOT="0"
KEYWORDS="~amd64 ~x86 ~arm ~arm64"

RDEPEND="
	dev-libs/openssl:=
	dev-libs/jsoncpp:=
"
DEPEND="${RDEPEND}"
BDEPEND="
	dev-vcs/git
	virtual/pkgconfig
"

src_prepare() {
	default
	./fetch-deps.sh || die "fetch-deps.sh failed"
	eautoreconf
}

src_configure() {
	econf
}

src_compile() {
	emake
}

src_test() {
	emake check
}

src_install() {
	default
	find "${ED}" -name '*.la' -delete || die
}
