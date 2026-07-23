      *> seatuya.cbl — GnuCOBOL FFI bindings for libseatuya
      *>
      *> GnuCOBOL (formerly OpenCOBOL) can call C functions via
      *> CALL STATIC or CALL DYNAMIC with appropriate LINKAGE SECTION
      *> declarations.  The opaque tuya_device_t* is stored as
      *> USAGE POINTER (a C void*).
      *>
      *> Usage:
      *>   COPY "seatuya.cpy".
      *>   CALL "seatuya-create" USING device-id address local-key version
      *>   CALL "seatuya-turn-on" USING dev dp
      *>
      *> Build: cobc -x -lseatuya example.cbl -o example

       IDENTIFICATION DIVISION.
       PROGRAM-ID. seatuya.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *> Constants
       01 CMD-CONTROL       PIC 9(9) COMP VALUE 7.
       01 CMD-DP-QUERY      PIC 9(9) COMP VALUE 10.
       01 CMD-HEART-BEAT    PIC 9(9) COMP VALUE 9.
       01 CMD-STATUS        PIC 9(9) COMP VALUE 8.
       01 CMD-CONTROL-NEW   PIC 9(9) COMP VALUE 13.
       01 CMD-DP-QUERY-NEW  PIC 9(9) COMP VALUE 16.
       01 PROTO-V31         PIC 9(9) COMP VALUE 0.
       01 PROTO-V33         PIC 9(9) COMP VALUE 1.
       01 PROTO-V34         PIC 9(9) COMP VALUE 2.
       01 PROTO-V35         PIC 9(9) COMP VALUE 3.
       01 DEFAULT-PORT      PIC 9(9) COMP VALUE 6668.
       01 BUFSIZE           PIC 9(9) COMP VALUE 1024.
       01 WS-DEV            USAGE POINTER.
       01 WS-RESULT         USAGE POINTER.
       01 WS-STR            PIC X(1024).
       01 WS-LEN            PIC 9(9) COMP.

       LINKAGE SECTION.
       01 LK-DEV            USAGE POINTER.
       01 LK-DEVICE-ID      PIC X(128).
       01 LK-ADDRESS        PIC X(128).
       01 LK-LOCAL-KEY      PIC X(128).
       01 LK-VERSION        PIC X(8).
       01 LK-HOST           PIC X(256).
       01 LK-KEY            PIC X(64).
       01 LK-DP             PIC 9(9) COMP.
       01 LK-VALUE-BOOL     PIC 9(9) COMP.
       01 LK-VALUE-INT      PIC 9(9) COMP.
       01 LK-VALUE-STR      PIC X(256).
       01 LK-VALUE-FLOAT    USAGE FLOAT-LONG.
       01 LK-JSON           PIC X(1024).
       01 LK-RET-INT        PIC 9(9) COMP.
       01 LK-RET-BOOL       PIC X(1).

      *> ── Lifecycle ──
       IDENTIFICATION DIVISION.
       PROGRAM-ID. seatuya-version.
       DATA DIVISION. WORKING-STORAGE SECTION.
       01 VER-PTR USAGE POINTER.
       PROCEDURE DIVISION RETURNING WS-STR.
         CALL STATIC "tuya_version" RETURNING VER-PTR END-CALL
         IF VER-PTR NOT = NULL
           CALL "CBL_GC_HOSTED" USING VER-PTR WS-STR
         END-IF
         GOBACK.

       IDENTIFICATION DIVISION.
       PROGRAM-ID. seatuya-create.
       DATA DIVISION. WORKING-STORAGE SECTION.
       01 WS-DID  PIC X(128). 01 WS-ADDR PIC X(128).
       01 WS-KEY  PIC X(128). 01 WS-VER  PIC X(8).
       01 WS-DEV  USAGE POINTER.
       PROCEDURE DIVISION USING LK-DEVICE-ID LK-ADDRESS
                                LK-LOCAL-KEY LK-VERSION
                                RETURNING WS-DEV.
         MOVE LK-DEVICE-ID TO WS-DID
         MOVE LK-ADDRESS   TO WS-ADDR
         MOVE LK-LOCAL-KEY TO WS-KEY
         MOVE LK-VERSION   TO WS-VER
         CALL STATIC "tuya_create"
           USING BY CONTENT WS-DID BY CONTENT WS-ADDR
                 BY CONTENT WS-KEY BY CONTENT WS-VER
           RETURNING WS-DEV
         END-CALL
         IF WS-DEV = NULL
           MOVE NULL TO WS-DEV
         END-IF
         GOBACK.

       IDENTIFICATION DIVISION.
       PROGRAM-ID. seatuya-destroy.
       PROCEDURE DIVISION USING LK-DEV.
         CALL STATIC "tuya_destroy" USING BY VALUE LK-DEV END-CALL
         GOBACK.

      *> ── Connection ──
       IDENTIFICATION DIVISION.
       PROGRAM-ID. seatuya-connect.
       DATA DIVISION. WORKING-STORAGE SECTION.
       01 WS-HOST PIC X(256).
       01 WS-RET  PIC 9(9) COMP.
       PROCEDURE DIVISION USING LK-DEV LK-HOST RETURNING WS-RET.
         MOVE LK-HOST TO WS-HOST
         CALL STATIC "tuya_connect"
           USING BY VALUE LK-DEV BY CONTENT WS-HOST
           RETURNING WS-RET
         END-CALL
         GOBACK.

       IDENTIFICATION DIVISION.
       PROGRAM-ID. seatuya-is-connected.
       DATA DIVISION. WORKING-STORAGE SECTION.
       01 WS-RET PIC 9(9) COMP.
       PROCEDURE DIVISION USING LK-DEV RETURNING WS-RET.
         CALL STATIC "tuya_is_connected"
           USING BY VALUE LK-DEV RETURNING WS-RET
         END-CALL
         GOBACK.

      *> ── High-level round-trip ──
       IDENTIFICATION DIVISION.
       PROGRAM-ID. seatuya-turn-on.
       DATA DIVISION. WORKING-STORAGE SECTION.
       01 WS-PTR USAGE POINTER.
       01 WS-JSON PIC X(1024).
       PROCEDURE DIVISION USING LK-DEV LK-DP RETURNING WS-JSON.
         CALL STATIC "tuya_turn_on"
           USING BY VALUE LK-DEV BY VALUE LK-DP
           RETURNING WS-PTR
         END-CALL
         IF WS-PTR NOT = NULL
           CALL "CBL_GC_HOSTED" USING WS-PTR WS-JSON
           CALL STATIC "tuya_free_string"
             USING BY VALUE WS-PTR
           END-CALL
         END-IF
         GOBACK.

       IDENTIFICATION DIVISION.
       PROGRAM-ID. seatuya-turn-off.
       DATA DIVISION. WORKING-STORAGE SECTION.
       01 WS-PTR USAGE POINTER.
       01 WS-JSON PIC X(1024).
       PROCEDURE DIVISION USING LK-DEV LK-DP RETURNING WS-JSON.
         CALL STATIC "tuya_turn_off"
           USING BY VALUE LK-DEV BY VALUE LK-DP
           RETURNING WS-PTR
         END-CALL
         IF WS-PTR NOT = NULL
           CALL "CBL_GC_HOSTED" USING WS-PTR WS-JSON
           CALL STATIC "tuya_free_string"
             USING BY VALUE WS-PTR
           END-CALL
         END-IF
         GOBACK.

       IDENTIFICATION DIVISION.
       PROGRAM-ID. seatuya-status.
       DATA DIVISION. WORKING-STORAGE SECTION.
       01 WS-PTR USAGE POINTER.
       01 WS-JSON PIC X(1024).
       PROCEDURE DIVISION USING LK-DEV RETURNING WS-JSON.
         CALL STATIC "tuya_status"
           USING BY VALUE LK-DEV RETURNING WS-PTR
         END-CALL
         IF WS-PTR NOT = NULL
           CALL "CBL_GC_HOSTED" USING WS-PTR WS-JSON
           CALL STATIC "tuya_free_string"
             USING BY VALUE WS-PTR
           END-CALL
         END-IF
         GOBACK.

       IDENTIFICATION DIVISION.
       PROGRAM-ID. seatuya-heartbeat.
       DATA DIVISION. WORKING-STORAGE SECTION.
       01 WS-PTR USAGE POINTER.
       01 WS-JSON PIC X(1024).
       PROCEDURE DIVISION USING LK-DEV RETURNING WS-JSON.
         CALL STATIC "tuya_heartbeat"
           USING BY VALUE LK-DEV RETURNING WS-PTR
         END-CALL
         IF WS-PTR NOT = NULL
           CALL "CBL_GC_HOSTED" USING WS-PTR WS-JSON
           CALL STATIC "tuya_free_string"
             USING BY VALUE WS-PTR
           END-CALL
         END-IF
         GOBACK.

       IDENTIFICATION DIVISION.
       PROGRAM-ID. seatuya-set-value-bool.
       DATA DIVISION. WORKING-STORAGE SECTION.
       01 WS-PTR USAGE POINTER.
       01 WS-JSON PIC X(1024).
       PROCEDURE DIVISION USING LK-DEV LK-DP LK-VALUE-BOOL
                         RETURNING WS-JSON.
         CALL STATIC "tuya_set_value_bool"
           USING BY VALUE LK-DEV BY VALUE LK-DP
                 BY VALUE LK-VALUE-BOOL
           RETURNING WS-PTR
         END-CALL
         IF WS-PTR NOT = NULL
           CALL "CBL_GC_HOSTED" USING WS-PTR WS-JSON
           CALL STATIC "tuya_free_string"
             USING BY VALUE WS-PTR
           END-CALL
         END-IF
         GOBACK.

       IDENTIFICATION DIVISION.
       PROGRAM-ID. seatuya-set-value-int.
       DATA DIVISION. WORKING-STORAGE SECTION.
       01 WS-PTR USAGE POINTER.
       01 WS-JSON PIC X(1024).
       PROCEDURE DIVISION USING LK-DEV LK-DP LK-VALUE-INT
                         RETURNING WS-JSON.
         CALL STATIC "tuya_set_value_int"
           USING BY VALUE LK-DEV BY VALUE LK-DP
                 BY VALUE LK-VALUE-INT
           RETURNING WS-PTR
         END-CALL
         IF WS-PTR NOT = NULL
           CALL "CBL_GC_HOSTED" USING WS-PTR WS-JSON
           CALL STATIC "tuya_free_string"
             USING BY VALUE WS-PTR
           END-CALL
         END-IF
         GOBACK.

       END PROGRAM seatuya.
