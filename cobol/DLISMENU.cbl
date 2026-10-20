      *================================================================*
      * CICS/COBOL Program                                           *
      * Program : DLISMENU                                           *
      * Trans   : DL01                                              *
      * Map     : DLISMM / DLISMM01                                 *
      * Desc    : DLIS Main Menu - routes to all transactions        *
      *================================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. DLISMENU.

       ENVIRONMENT DIVISION.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
           COPY DLISWS.
           COPY DLISCSEC.

       LINKAGE SECTION.
       01  DFHCOMMAREA            PIC X(350).

       PROCEDURE DIVISION.
       MAIN-LOGIC.
           IF EIBCALEN = 0
               PERFORM INIT-SCREEN
           ELSE
               MOVE DFHCOMMAREA TO DLIS-COMMAREA
               PERFORM PROCESS-INPUT
           END-IF
           STOP RUN.

       INIT-SCREEN.
           MOVE CURRENT-DATE(1:10) TO DMMDATE
           MOVE SPACES TO DMMMSG
           EXEC CICS SEND MAP('DLISMM01') MAPSET('DLISMM')
               ERASE FREEKB RESP(WS-RESP1)
           END-EXEC
           EXEC CICS RETURN TRANSID('DL01')
               COMMAREA(DLIS-COMMAREA) LENGTH(350)
           END-EXEC.

       PROCESS-INPUT.
           EXEC CICS RECEIVE MAP('DLISMM01') MAPSET('DLISMM')
               RESP(WS-RESP1)
           END-EXEC
           IF EIBAID = DFHPF12
               EXEC CICS RETURN END-EXEC
           END-IF
           IF EIBAID NOT = DFHENTER
               MOVE 'PRESS ENTER TO SELECT OR F12 TO EXIT' TO DMMMSG
               PERFORM REDISPLAY-MENU
           END-IF
           IF DMMOPTI = SPACES OR DMMOPTI = LOW-VALUES
               MOVE 'PLEASE SELECT AN OPTION (1-10)' TO DMMMSG
               PERFORM REDISPLAY-MENU
           END-IF

           EVALUATE DMMOPTI
               WHEN '1'  EXEC CICS XCTL PROGRAM('DLISCAND')
                             COMMAREA(DLIS-COMMAREA) LENGTH(350)
                         END-EXEC
               WHEN '2'  EXEC CICS XCTL PROGRAM('DLISCAND')
                             COMMAREA(DLIS-COMMAREA) LENGTH(350)
                         END-EXEC
               WHEN '3'  EXEC CICS XCTL PROGRAM('DLISAPPL')
                             COMMAREA(DLIS-COMMAREA) LENGTH(350)
                         END-EXEC
               WHEN '4'  EXEC CICS XCTL PROGRAM('DLISSTAT')
                             COMMAREA(DLIS-COMMAREA) LENGTH(350)
                         END-EXEC
               WHEN '5'  EXEC CICS XCTL PROGRAM('DLISELIG')
                             COMMAREA(DLIS-COMMAREA) LENGTH(350)
                         END-EXEC
               WHEN '6'  EXEC CICS XCTL PROGRAM('DLISHIST')
                             COMMAREA(DLIS-COMMAREA) LENGTH(350)
                         END-EXEC
               WHEN '7'  EXEC CICS XCTL PROGRAM('DLISPAY')
                             COMMAREA(DLIS-COMMAREA) LENGTH(350)
                         END-EXEC
               WHEN '8'  EXEC CICS XCTL PROGRAM('DLISAP1')
                             COMMAREA(DLIS-COMMAREA) LENGTH(350)
                         END-EXEC
               WHEN '9'  EXEC CICS XCTL PROGRAM('DLISAP2')
                             COMMAREA(DLIS-COMMAREA) LENGTH(350)
                         END-EXEC
               WHEN '10' EXEC CICS XCTL PROGRAM('DLISISSU')
                             COMMAREA(DLIS-COMMAREA) LENGTH(350)
                         END-EXEC
               OTHER
                   MOVE 'INVALID OPTION. PLEASE SELECT 1-10' TO DMMMSG
                   PERFORM REDISPLAY-MENU
           END-EVALUATE
           STOP RUN.

       REDISPLAY-MENU.
           EXEC CICS SEND MAP('DLISMM01') MAPSET('DLISMM')
               DATAONLY FREEKB RESP(WS-RESP1)
           END-EXEC
           EXEC CICS RETURN TRANSID('DL01')
               COMMAREA(DLIS-COMMAREA) LENGTH(350)
           END-EXEC.
