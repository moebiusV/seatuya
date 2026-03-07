Name:           seatuya
Version:        0.1.0
Release:        1%{?dist}
Summary:        C wrapper library for tuyapp Tuya device communication

License:        BSD-2-Clause AND GPL-3.0-or-later AND MIT
URL:            https://github.com/MAINTAINER/seatuya
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  gcc-c++
BuildRequires:  autoconf
BuildRequires:  automake
BuildRequires:  libtool
BuildRequires:  openssl-devel
BuildRequires:  jsoncpp-devel
BuildRequires:  pkgconfig
BuildRequires:  git-core

%description
seatuya is a C wrapper library for tuyapp, providing a pure C API for
local Tuya smart-device communication.  Supports protocol versions 3.1,
3.3, 3.4, and 3.5.

%package        devel
Summary:        Development files for %{name}
Requires:       %{name}%{?_isa} = %{version}-%{release}
Requires:       openssl-devel

%description    devel
Headers, symlinks, and manpage for developing against %{name}.

%prep
%setup -q
./fetch-deps.sh

%build
autoreconf -fi
%configure
%make_build

%install
%make_install
find %{buildroot} -name '*.la' -delete

%check
%make_build check

%files
%license COPYING
%doc README NEWS
%{_libdir}/libseatuya.so.*

%files devel
%{_includedir}/seatuya.h
%{_libdir}/libseatuya.so
%{_mandir}/man3/seatuya.3*

%changelog
# Packager: add your changelog entries below in standard RPM format.
# * Thu Mar 06 2026 Your Name <your@email.com> - 0.1.0-1
# - Initial package
