AC_PREREQ([2.69])
AC_INIT([seatuya], [0.1.0], [david@clearbrookdistillery.com])
AC_CONFIG_SRCDIR([src/seatuya.c])
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_AUX_DIR([build-aux])
AM_INIT_AUTOMAKE([foreign -Wall -Werror])

# Checks for programs.
AC_PROG_CC
AC_PROG_CXX
AM_PROG_AR
LT_INIT

# Checks for libraries.
# TODO: check for tuyapp

# Checks for header files.
AC_CHECK_HEADERS([stdlib.h string.h])

# Checks for typedefs, structures, and compiler characteristics.
AC_TYPE_SIZE_T

AC_CONFIG_FILES([Makefile
                 src/Makefile
                 include/Makefile
                 tests/Makefile])
AC_OUTPUT
