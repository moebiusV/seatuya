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
                 src/Makefile
                 include/Makefile
                 tests/Makefile])
AC_OUTPUT
