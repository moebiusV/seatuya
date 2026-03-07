lib_LTLIBRARIES = libseatuya.la

# seatuya wrapper
libseatuya_la_SOURCES = seatuya.cpp

# tuyapp sources (always bundled)
libseatuya_la_SOURCES += \
	$(top_srcdir)/deps/tuyapp/src/tuyaTCP.cpp \
	$(top_srcdir)/deps/tuyapp/src/tuyaAPI.cpp \
	$(top_srcdir)/deps/tuyapp/src/tuyaAPI31.cpp \
	$(top_srcdir)/deps/tuyapp/src/tuyaAPI33.cpp \
	$(top_srcdir)/deps/tuyapp/src/tuyaAPI34.cpp \
	$(top_srcdir)/deps/tuyapp/src/tuyaAPI35.cpp

# jsoncpp sources (only when not installed system-wide)
if BUNDLED_JSONCPP
libseatuya_la_SOURCES += \
	$(top_srcdir)/deps/jsoncpp/src/lib_json/json_reader.cpp \
	$(top_srcdir)/deps/jsoncpp/src/lib_json/json_value.cpp \
	$(top_srcdir)/deps/jsoncpp/src/lib_json/json_writer.cpp
endif

libseatuya_la_CXXFLAGS = \
	-I$(top_srcdir)/include \
	-I$(top_srcdir)/deps/tuyapp/src \
	$(JSONCPP_CFLAGS) \
	$(OPENSSL_CFLAGS) \
	$(PTHREAD_CFLAGS)

libseatuya_la_LIBADD = \
	$(JSONCPP_LIBS) \
	$(OPENSSL_LIBS) \
	$(PTHREAD_LIBS)

libseatuya_la_LDFLAGS = -version-info 0:0:0
