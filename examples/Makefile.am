noinst_PROGRAMS = sousctl seatuya-wizard-openssl tuyaprobe

sousctl_SOURCES = sousctl.c
sousctl_CFLAGS = -I$(top_srcdir)/include
sousctl_LDADD = $(top_builddir)/src/libseatuya.la -lm

tuyaprobe_SOURCES = tuyaprobe.c
tuyaprobe_CFLAGS = -I$(top_srcdir)/include
tuyaprobe_LDADD = $(top_builddir)/src/libseatuya.la

seatuya_wizard_openssl_SOURCES = wizard-common.c wizard-https-openssl.c
seatuya_wizard_openssl_CFLAGS = -I$(top_srcdir)/include $(OPENSSL_CFLAGS)
seatuya_wizard_openssl_LDADD = $(top_builddir)/src/libseatuya.la $(OPENSSL_LIBS)

if USE_LIBTLS
noinst_PROGRAMS += seatuya-wizard
seatuya_wizard_SOURCES = wizard-common.c wizard-https-libtls.c
seatuya_wizard_CFLAGS = -I$(top_srcdir)/include $(LIBTLS_CFLAGS) $(OPENSSL_CFLAGS)
seatuya_wizard_LDADD = $(top_builddir)/src/libseatuya.la $(LIBTLS_LIBS) $(OPENSSL_LIBS)
endif

EXTRA_DIST = sousvide-ramp.lsp seatuya-wizard.lsp wizard-common.h tuyascan.c
