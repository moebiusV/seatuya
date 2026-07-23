      *> example.cbl — demonstrate libseatuya via GnuCOBOL
      *>
      *> Build: cobc -x -lseatuya seatuya.cbl example.cbl -o example

       IDENTIFICATION DIVISION.
       PROGRAM-ID. example.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-DEVICE-ID  PIC X(128).
       01 WS-LOCAL-KEY  PIC X(128).
       01 WS-IP         PIC X(128).
       01 WS-VERSION    PIC X(8).
       01 WS-DEV        USAGE POINTER.
       01 WS-RESULT-INT PIC 9(9) COMP.
       01 WS-RESULT-JSON PIC X(1024).
       01 WS-VER-STR    PIC X(32).
       01 WS-CONNECTED  PIC X(3).

       PROCEDURE DIVISION.
      *> Get env vars with fallbacks
         ACCEPT WS-DEVICE-ID FROM ENVIRONMENT "TUYA_DEVICE_ID"
         IF WS-DEVICE-ID = SPACES
           MOVE "0123456789abcdef01234567" TO WS-DEVICE-ID
         END-IF
         ACCEPT WS-LOCAL-KEY FROM ENVIRONMENT "TUYA_LOCAL_KEY"
         IF WS-LOCAL-KEY = SPACES
           MOVE "0123456789abcdef" TO WS-LOCAL-KEY
         END-IF
         ACCEPT WS-IP FROM ENVIRONMENT "TUYA_IP"
         IF WS-IP = SPACES
           MOVE "192.168.1.100" TO WS-IP
         END-IF
         ACCEPT WS-VERSION FROM ENVIRONMENT "TUYA_VERSION"
         IF WS-VERSION = SPACES
           MOVE "3.4" TO WS-VERSION
         END-IF

         CALL "seatuya-version" RETURNING WS-VER-STR
         DISPLAY "seatuya version: " WS-VER-STR

         CALL "seatuya-create" USING WS-DEVICE-ID WS-IP
               WS-LOCAL-KEY WS-VERSION RETURNING WS-DEV
         IF WS-DEV = NULL
           DISPLAY "ERROR: Could not create device handle"
           STOP RUN RETURNING 1
         END-IF

         CALL "seatuya-is-connected" USING WS-DEV
               RETURNING WS-RESULT-INT
         IF WS-RESULT-INT = 0
           MOVE "NO" TO WS-CONNECTED
         ELSE
           MOVE "YES" TO WS-CONNECTED
         END-IF
         DISPLAY "Connected: " WS-CONNECTED

         CALL "seatuya-turn-on" USING WS-DEV 1
               RETURNING WS-RESULT-JSON
         DISPLAY "turn_on: " WS-RESULT-JSON

         CALL "seatuya-status" USING WS-DEV
               RETURNING WS-RESULT-JSON
         DISPLAY "status: " WS-RESULT-JSON

         CALL "seatuya-turn-off" USING WS-DEV 1
               RETURNING WS-RESULT-JSON
         DISPLAY "turn_off: " WS-RESULT-JSON

         CALL "seatuya-destroy" USING WS-DEV
         DISPLAY "Done."
         STOP RUN.
