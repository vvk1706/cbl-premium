      *================================================================*
      * CICS/COBOL Program                                           *
      * Program : DLISHIST                                           *
      * Trans   : DL06                                              *
      * Map     : DLISHC / DLISHC01                                 *
      * Desc    : Driving History Check                              *
      *           F1=Run Check  F3=Lookup  F7/F8=Scroll  F12=Exit   *
      *================================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. DLISHIST.

       ENVIRONMENT DIVISION.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
           COPY DLISWS.
           COPY DLISCSEC.
           COPY DLISDCLG.

       01  WS-DEMERIT-TOTAL       PIC S9(5)  COMP-3  VALUE 0.
       01  WS-SUSP-FLAG           PIC X(1)           VALUE 'N'.
       01  WS-FINE-FLAG           PIC X(1)           VALUE 'N'.
       01  WS-HIST-FAIL-MSG       PIC X(200).
       01  WS-SCROLL-TOP          PIC S9(4)  COMP    VALUE 1.
       01  WS-ROW-COUNT           PIC S9(4)  COMP    VALUE 0.

       01  WS-HIST-TABLE.
           05  WS-HIST-ROW        OCCURS 50 TIMES.
               10 WS-HR-DATE      PIC X(10).
               10 WS-HR-TYPE      PIC X(2).
               10 WS-HR-DESC      PIC X(30).
               10 WS-HR-DMRT      PIC S9(3)  COMP-3.

       EXEC SQL INCLUDE SQLCA END-EXEC.
       EXEC SQL DECLARE HISTCUR CURSOR FOR
           SELECT INCIDENT_DATE, INCIDENT_TYPE,
                  INCIDENT_DESC, DEMERIT_POINTS,
                  FINE_AMOUNT, FINE_PAID_STATUS,
                  SUSP_START_DATE, SUSP_END_DATE
           FROM   DLIS.DRIVING_HISTORY
           WHERE  CANDIDATE_ID  = :CANDIDATE-ID OF DCLDLIS-LICENSE-APPL
           AND    RECORD_STATUS = 'A'
           ORDER BY INCIDENT_DATE DESC
       END-EXEC.

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
           MOVE CURRENT-DATE(1:10) TO DHCDATE
           EXEC CICS SEND MAP('DLISHC01') MAPSET('DLISHC')
               ERASE FREEKB RESP(WS-RESP1)
           END-EXEC
           EXEC CICS RETURN TRANSID('DL06')
               COMMAREA(DLIS-COMMAREA) LENGTH(350)
           END-EXEC.

       PROCESS-INPUT.
           EXEC CICS RECEIVE MAP('DLISHC01') MAPSET('DLISHC')
               RESP(WS-RESP1)
           END-EXEC
           EVALUATE TRUE
               WHEN EIBAID = DFHPF1   PERFORM RUN-HISTORY-CHECK
               WHEN EIBAID = DFHPF3   PERFORM LOAD-APPLICATION
               WHEN EIBAID = DFHPF7
                   SUBTRACT 7 FROM WS-SCROLL-TOP
                   IF WS-SCROLL-TOP < 1 MOVE 1 TO WS-SCROLL-TOP
                   PERFORM DISPLAY-HISTORY
               WHEN EIBAID = DFHPF8
                   ADD 7 TO WS-SCROLL-TOP
                   PERFORM DISPLAY-HISTORY
               WHEN EIBAID = DFHPF12
                   EXEC CICS RETURN END-EXEC
               OTHER
                   MOVE 'USE F1 F3 F7 F8 OR F12' TO DHCMSG
           END-EVALUATE
           EXEC CICS SEND MAP('DLISHC01') MAPSET('DLISHC')
               DATAONLY FREEKB RESP(WS-RESP1)
           END-EXEC
           EXEC CICS RETURN TRANSID('DL06')
               COMMAREA(DLIS-COMMAREA) LENGTH(350)
           END-EXEC.

       LOAD-APPLICATION.
           IF DHCAIDI = ZEROS
               MOVE 'ENTER APPLICATION ID' TO DHCMSG
               GO TO LOAD-APP-EXIT
           END-IF
           MOVE DHCAIDI TO APPLICATION-ID OF DCLDLIS-LICENSE-APPL
           EXEC SQL
               SELECT A.CANDIDATE_ID, A.LICENSE_TYPE,
                      C.FIRST_NAME, C.LAST_NAME
               INTO   :CANDIDATE-ID OF DCLDLIS-LICENSE-APPL,
                      :LICENSE-TYPE OF DCLDLIS-LICENSE-APPL,
                      :FIRST-NAME, :LAST-NAME OF DCLDLIS-CANDIDATE
               FROM   DLIS.LICENSE_APPLICATION A
               JOIN   DLIS.CANDIDATE C
                  ON  A.CANDIDATE_ID = C.CANDIDATE_ID
               WHERE  A.APPLICATION_ID = :APPLICATION-ID
                                         OF DCLDLIS-LICENSE-APPL
           END-EXEC
           IF SQLCODE = 100
               MOVE 'APPLICATION NOT FOUND' TO DHCMSG
               GO TO LOAD-APP-EXIT
           END-IF
           STRING FIRST-NAME OF DCLDLIS-CANDIDATE DELIMITED SPACE
                  ' ' DELIMITED SIZE
                  LAST-NAME  OF DCLDLIS-CANDIDATE DELIMITED SPACE
               INTO DHCCNAMO
           MOVE LICENSE-TYPE OF DCLDLIS-LICENSE-APPL TO DHCLTYO
           PERFORM LOAD-HISTORY-TABLE
           PERFORM DISPLAY-HISTORY
           MOVE 'APPLICATION LOADED' TO DHCMSG.
       LOAD-APP-EXIT. EXIT.

       LOAD-HISTORY-TABLE.
           MOVE 0 TO WS-ROW-COUNT
           MOVE 0 TO WS-DEMERIT-TOTAL
           MOVE 'N' TO WS-SUSP-FLAG
           MOVE 'N' TO WS-FINE-FLAG

           EXEC SQL OPEN HISTCUR END-EXEC
           PERFORM UNTIL SQLCODE NOT = 0
               EXEC SQL FETCH HISTCUR INTO
                   :INCIDENT-DATE, :INCIDENT-TYPE,
                   :INCIDENT-DESC, :DEMERIT-POINTS,
                   :FINE-AMOUNT, :FINE-PAID-STATUS,
                   :SUSP-START-DATE, :SUSP-END-DATE
                   OF DCLDLIS-DRIVING-HIST
               END-EXEC
               IF SQLCODE = 0
                   ADD 1 TO WS-ROW-COUNT
                   IF WS-ROW-COUNT <= 50
                       MOVE INCIDENT-DATE  OF DCLDLIS-DRIVING-HIST
                           TO WS-HR-DATE(WS-ROW-COUNT)
                       MOVE INCIDENT-TYPE  OF DCLDLIS-DRIVING-HIST
                           TO WS-HR-TYPE(WS-ROW-COUNT)
                       MOVE INCIDENT-DESC  OF DCLDLIS-DRIVING-HIST
                           TO WS-HR-DESC(WS-ROW-COUNT)
                       MOVE DEMERIT-POINTS OF DCLDLIS-DRIVING-HIST
                           TO WS-HR-DMRT(WS-ROW-COUNT)
                       ADD DEMERIT-POINTS  OF DCLDLIS-DRIVING-HIST
                           TO WS-DEMERIT-TOTAL
                   END-IF
                   IF INCIDENT-TYPE OF DCLDLIS-DRIVING-HIST
                                    IN ('SU','DQ')
                       IF SUSP-END-DATE OF DCLDLIS-DRIVING-HIST >= CURRENT DATE
                          OR SUSP-END-DATE OF DCLDLIS-DRIVING-HIST = SPACES
                           MOVE 'Y' TO WS-SUSP-FLAG
                       END-IF
                   END-IF
                   IF FINE-AMOUNT OF DCLDLIS-DRIVING-HIST > 0
                       IF FINE-PAID-STATUS OF DCLDLIS-DRIVING-HIST = 'N'
                           MOVE 'Y' TO WS-FINE-FLAG
                       END-IF
                   END-IF
               END-IF
           END-PERFORM
           EXEC SQL CLOSE HISTCUR END-EXEC

           MOVE WS-DEMERIT-TOTAL TO DHCDMRTO
           MOVE WS-SUSP-FLAG     TO DHCSUSPO
           MOVE WS-FINE-FLAG     TO DHCFINEO.

       DISPLAY-HISTORY.
           MOVE SPACES TO DHCHL1O DHCHL2O DHCHL3O DHCHL4O
                          DHCHL5O DHCHL6O DHCHL7O
           PERFORM VARYING WS-SCROLL-TOP FROM WS-SCROLL-TOP BY 1
               UNTIL WS-SCROLL-TOP > WS-ROW-COUNT
                  OR WS-SCROLL-TOP > 7
               EVALUATE WS-SCROLL-TOP
                   WHEN 1 STRING WS-HR-DATE(1) ' ' WS-HR-TYPE(1)
                               ' ' WS-HR-DESC(1) INTO DHCHL1O
                   WHEN 2 STRING WS-HR-DATE(2) ' ' WS-HR-TYPE(2)
                               ' ' WS-HR-DESC(2) INTO DHCHL2O
                   WHEN 3 STRING WS-HR-DATE(3) ' ' WS-HR-TYPE(3)
                               ' ' WS-HR-DESC(3) INTO DHCHL3O
                   WHEN 4 STRING WS-HR-DATE(4) ' ' WS-HR-TYPE(4)
                               ' ' WS-HR-DESC(4) INTO DHCHL4O
                   WHEN 5 STRING WS-HR-DATE(5) ' ' WS-HR-TYPE(5)
                               ' ' WS-HR-DESC(5) INTO DHCHL5O
                   WHEN 6 STRING WS-HR-DATE(6) ' ' WS-HR-TYPE(6)
                               ' ' WS-HR-DESC(6) INTO DHCHL6O
                   WHEN 7 STRING WS-HR-DATE(7) ' ' WS-HR-TYPE(7)
                               ' ' WS-HR-DESC(7) INTO DHCHL7O
               END-EVALUATE
           END-PERFORM.

       RUN-HISTORY-CHECK.
           IF DHCAIDI = ZEROS
               MOVE 'ENTER APPLICATION ID FIRST' TO DHCMSG
               GO TO RUN-HIST-EXIT
           END-IF
           PERFORM LOAD-APPLICATION
           IF DHCMSG NOT = 'APPLICATION LOADED'
               GO TO RUN-HIST-EXIT
           END-IF
      *    Check eligibility was passed first
           EXEC SQL
               SELECT ELIG_CHECK_STATUS
               INTO   :ELIG-CHECK-STATUS OF DCLDLIS-LICENSE-APPL
               FROM   DLIS.LICENSE_APPLICATION
               WHERE  APPLICATION_ID = :APPLICATION-ID
                                       OF DCLDLIS-LICENSE-APPL
           END-EXEC
           IF ELIG-CHECK-STATUS OF DCLDLIS-LICENSE-APPL NOT = 'P'
               MOVE 'ELIGIBILITY CHECK MUST BE PASSED FIRST' TO DHCMSG
               GO TO RUN-HIST-EXIT
           END-IF

           MOVE SPACES TO WS-HIST-FAIL-MSG
           MOVE 'N'    TO WS-FAIL-FLAG
           IF WS-SUSP-FLAG = 'Y'
               MOVE 'Y' TO WS-FAIL-FLAG
               MOVE 'ACTIVE SUSPENSION OR DISQUALIFICATION ON FILE'
                   TO WS-HIST-FAIL-MSG
           END-IF
           IF WS-DEMERIT-TOTAL > 12 AND WS-FAIL-FLAG = 'N'
               MOVE 'Y' TO WS-FAIL-FLAG
               MOVE 'TOTAL DEMERIT POINTS EXCEED THRESHOLD OF 12'
                   TO WS-HIST-FAIL-MSG
           END-IF
           IF WS-FINE-FLAG = 'Y' AND WS-FAIL-FLAG = 'N'
               MOVE 'Y' TO WS-FAIL-FLAG
               MOVE 'OUTSTANDING UNPAID FINES ON FILE'
                   TO WS-HIST-FAIL-MSG
           END-IF

           IF WS-FAIL-FLAG = 'Y'
               MOVE 'F'  TO WS-HISTORY-STATUS
               MOVE 'FAIL' TO DHCHSTSO
               MOVE WS-HIST-FAIL-MSG TO DHCHSDSO
               MOVE 'RE' TO APPLICATION-STATUS OF DCLDLIS-LICENSE-APPL
           ELSE
               MOVE 'P'  TO WS-HISTORY-STATUS
               MOVE 'PASS' TO DHCHSTSO
               MOVE SPACES  TO DHCHSDSO
               MOVE 'HC' TO APPLICATION-STATUS OF DCLDLIS-LICENSE-APPL
           END-IF

           EXEC SQL
               UPDATE DLIS.LICENSE_APPLICATION SET
                   HIST_CHECK_STATUS  = :WS-HISTORY-STATUS,
                   HIST_CHECK_DATE    = CURRENT DATE,
                   HIST_CHECK_NOTES   = :WS-HIST-FAIL-MSG,
                   APPLICATION_STATUS = :APPLICATION-STATUS
                                        OF DCLDLIS-LICENSE-APPL,
                   LAST_UPDATED_DATE  = CURRENT DATE,
                   LAST_UPDATED_BY    = EIBTRMID
               WHERE APPLICATION_ID   = :APPLICATION-ID
                                        OF DCLDLIS-LICENSE-APPL
           END-EXEC

           IF WS-HISTORY-STATUS = 'P'
               MOVE 'HISTORY CHECK PASSED' TO DHCMSG
           ELSE
               MOVE WS-HIST-FAIL-MSG TO DHCMSG
           END-IF.
       RUN-HIST-EXIT. EXIT.
