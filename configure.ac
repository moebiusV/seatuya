AC_PREREQ([2.69])
AC_INIT([seatuya], [0.1.0], [david@clearbrookdistillery.com])
AC_CONFIG_SRCDIR([src/seatuya.cpp])
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_AUX_DIR([build-aux])
AC_CONFIG_MACRO_DIRS([m4])
AM_INIT_AUTOMAKE([foreign subdir-objects -Wall -Werror])

# Programs
AC_PROG_CC
AC_PROG_CXX
AM_PROG_AR
LT_INIT

# Require C++14
CXXFLAGS="$CXXFLAGS -std=c++14"
AC_LANG_PUSH([C++])
AC_MSG_CHECKING([whether $CXX supports C++14])
AC_COMPILE_IFELSE(
    [AC_LANG_PROGRAM([[#include <memory>]],
                     [[auto p = std::make_unique<int>(42);]])],
    [AC_MSG_RESULT([yes])],
    [AC_MSG_RESULT([no])
     AC_MSG_ERROR([A C++14 capable compiler is required.])])
AC_LANG_POP([C++])

# ---------- tuyapp (always bundled) ----------

AC_MSG_CHECKING([for tuyapp sources])
if test -f "$srcdir/deps/tuyapp/src/tuyaAPI.hpp"; then
    AC_MSG_RESULT([found in deps/tuyapp/])
else
    AC_MSG_RESULT([not found])
    AC_MSG_ERROR([
  tuyapp sources not found.  Run:
    ./fetch-deps.sh])
fi

# ---------- jsoncpp (system or bundled) ----------

use_bundled_jsoncpp=no
PKG_CHECK_MODULES([JSONCPP], [jsoncpp], [], [use_bundled_jsoncpp=yes])

if test "x$use_bundled_jsoncpp" = "xyes"; then
    AC_MSG_CHECKING([for bundled jsoncpp sources])
    if test -f "$srcdir/deps/jsoncpp/include/json/json.h"; then
        AC_MSG_RESULT([found in deps/jsoncpp/])
        JSONCPP_CFLAGS="-I\$(top_srcdir)/deps/jsoncpp/include"
        JSONCPP_LIBS=""
        AC_SUBST([JSONCPP_CFLAGS])
        AC_SUBST([JSONCPP_LIBS])
    else
        AC_MSG_RESULT([not found])
        AC_MSG_ERROR([
  jsoncpp not installed and bundled sources not found.  Run:
    ./fetch-deps.sh])
    fi
fi
AM_CONDITIONAL([BUNDLED_JSONCPP], [test "x$use_bundled_jsoncpp" = "xyes"])

# ---------- OpenSSL ----------

PKG_CHECK_MODULES([OPENSSL], [openssl], [],
    [AC_MSG_ERROR([OpenSSL not found. Try: sudo apt-get install libssl-dev])])

# ---------- libtls (optional, for seatuya-wizard) ----------

AC_ARG_WITH([libtls],
    [AS_HELP_STRING([--with-libtls],
        [use libtls instead of OpenSSL BIO for HTTPS in seatuya-wizard])],
    [with_libtls=$withval],
    [with_libtls=auto])

use_libtls=no
if test "x$with_libtls" != "xno"; then
    PKG_CHECK_MODULES([LIBTLS], [libtls], [use_libtls=yes], [
        if test "x$with_libtls" = "xyes"; then
            AC_MSG_ERROR([libtls requested but not found])
        fi
    ])
fi
AM_CONDITIONAL([USE_LIBTLS], [test "x$use_libtls" = "xyes"])
if test "x$use_libtls" = "xyes"; then
    AC_DEFINE([HAVE_LIBTLS], [1], [Define if libtls is available])
fi
AC_MSG_NOTICE([seatuya-wizard TLS backend: $(test "x$use_libtls" = "xyes" && echo libtls || echo OpenSSL)])

if test "x$use_libtls" != "xyes" && test "x$with_libtls" != "xno"; then
    AC_MSG_NOTICE([])
    AC_MSG_NOTICE([  Tip: libtls was not found. The wizard will use OpenSSL, which works])
    AC_MSG_NOTICE([  fine, but libtls provides a cleaner and safer TLS API. To install it:])
    AC_MSG_NOTICE([])
    # Detect distro and suggest the right package command
    if test -f /etc/os-release; then
        . /etc/os-release
        case "$ID" in
        ubuntu|debian|linuxmint|pop|elementary|zorin|kali|raspbian)
            AC_MSG_NOTICE([    sudo apt-get install libtls-dev]) ;;
        fedora)
            AC_MSG_NOTICE([    sudo dnf install libretls-devel]) ;;
        rhel|centos|rocky|alma|ol)
            AC_MSG_NOTICE([    sudo dnf install libretls-devel    (from EPEL)]) ;;
        opensuse*|suse|sles)
            AC_MSG_NOTICE([    sudo zypper addrepo https://download.opensuse.org/repositories/security:tls/openSUSE_Tumbleweed/security:tls.repo])
            AC_MSG_NOTICE([    sudo zypper refresh && sudo zypper install libretls-devel]) ;;
        arch|manjaro|endeavouros|artix|garuda)
            AC_MSG_NOTICE([    sudo pacman -S libressl]) ;;
        alpine)
            AC_MSG_NOTICE([    apk add libretls-dev]) ;;
        gentoo)
            AC_MSG_NOTICE([    sudo emerge dev-libs/libretls]) ;;
        void)
            AC_MSG_NOTICE([    sudo xbps-install libretls-devel]) ;;
        nixos)
            AC_MSG_NOTICE([    nix-env -iA nixpkgs.libretls    (or add to environment.systemPackages)]) ;;
        slackware)
            AC_MSG_NOTICE([    Install libtls from SlackBuilds.org]) ;;
        *)
            AC_MSG_NOTICE([    Install libretls or libressl from your package manager.]) ;;
        esac
    elif test "$(uname)" = "FreeBSD"; then
        AC_MSG_NOTICE([    pkg install libretls])
    elif test "$(uname)" = "OpenBSD"; then
        AC_MSG_NOTICE([    libtls is part of base OpenBSD — it should already be available.])
    elif test "$(uname)" = "NetBSD"; then
        AC_MSG_NOTICE([    pkg_add libretls])
    elif test "$(uname)" = "Darwin"; then
        AC_MSG_NOTICE([    brew install libressl])
    else
        AC_MSG_NOTICE([    Install libressl or libretls from your package manager.])
    fi
    AC_MSG_NOTICE([])
    AC_MSG_NOTICE([  Then re-run ./configure. To suppress this hint: ./configure --without-libtls])
    AC_MSG_NOTICE([])
fi

# ---------- pthreads ----------

AC_CHECK_LIB([pthread], [pthread_create], [PTHREAD_LIBS="-lpthread"],
    [AC_MSG_ERROR([pthreads required])])
AC_SUBST([PTHREAD_LIBS])

# Header / type checks
AC_CHECK_HEADERS([stdlib.h string.h unistd.h])
AC_TYPE_SIZE_T
AC_TYPE_UINT8_T
AC_TYPE_UINT32_T

AC_CONFIG_FILES([Makefile
                 bindings/Makefile
                 bindings/node/Makefile
                 bindings/picolisp/Makefile
                 bindings/ada/Makefile
                 bindings/csharp/Makefile
                 bindings/tcl/Makefile
                 bindings/lua/Makefile
                 bindings/julia/Makefile
                 bindings/janet/Makefile
                 bindings/perl/Makefile
                 bindings/python/Makefile
                 bindings/go/Makefile
                 bindings/ruby/Makefile
                 bindings/dart/Makefile
                 bindings/kotlin/Makefile
                 bindings/commonlisp/Makefile
                 bindings/guile/Makefile
                 bindings/racket/Makefile
                 bindings/rust/Makefile
                 bindings/swift/Makefile
                 bindings/zig/Makefile
                 bindings/odin/Makefile
                 bindings/haskell/Makefile
                 bindings/ocaml/Makefile
                 bindings/sml/Makefile
                 bindings/gauche/Makefile
                 bindings/chicken/Makefile
                 bindings/gerbil/Makefile
                 bindings/clojure/Makefile
                 bindings/nim/Makefile
                 bindings/crystal/Makefile
                 bindings/d/Makefile
                 bindings/erlang/Makefile
                 bindings/elixir/Makefile
                 bindings/fsharp/Makefile
                 bindings/r/Makefile
                 bindings/freepascal/Makefile
                 bindings/carp/Makefile
                 bindings/shen/Makefile
                 bindings/pony/Makefile
                 bindings/prolog/Makefile
                 bindings/red/Makefile
                 bindings/forth/Makefile
                 bindings/apl/Makefile
                 bindings/objc/Makefile
                 bindings/fortran/Makefile\
                 bindings/cobol/Makefile\
                 bindings/algol68/Makefile
                 bindings/bqn/Makefile
                 src/Makefile
                 include/Makefile
                 tests/Makefile
                 examples/Makefile])
AC_OUTPUT
