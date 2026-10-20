      *================================================================*
      * CICS/COBOL Program                                           *
      * Program : DLISELIG                                           *
      * Trans   : DL05                                              *
      * Map     : DLISEC / DLISEC01                                 *
      * Desc    : Eligibility Check                                  *
      *           F1=Run Check  F3=Lookup App  F12=Exit             *
      *================================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. DLISELIG.

       ENVIRONMENT DIVISION.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
           COPY DLISWS.
           COPY DLISCSEC.
           COPY DLISDCLG.

       01  WS-DOB-YEAR            PIC 9(4).
       01  WS-CURR-YEAR           PIC 9(4).
       01  WS-CALC-AGE            PIC S9(3) COMP-3.
       01  WS-PRIOR-COUNT         PIC S9(5) COMP-3.

       EXEC SQL INCLUDE SQLCA END-EXEC.

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
           MOVE CURRENT-DATE(1:10) TO DECDATE
           EXEC CICS SEND MAP('DLISEC01') MAPSET('DLISEC')
               ERASE FREEKB RESP(WS-RESP1)
           END-EXEC
           EXEC CICS RETURN TRANSID('DL05')
               COMMAREA(DLIS-COMMAREA) LENGTH(350)
           END-EXEC.

       PROCESS-INPUT.
           EXEC CICS RECEIVE MAP('DLISEC01') MAPSET('DLISEC')
               RESP(WS-RESP1)
           END-EXEC
           EVALUATE TRUE
               WHEN EIBAID = DFHPF1   PERFORM RUN-ELIGIBILITY-CHECK
               WHEN EIBAID = DFHPF3   PERFORM LOAD-APPLICATION
               WHEN EIBAID = DFHPF12  EXEC CICS RETURN END-EXEC
               OTHER
                   MOVE 'USE F1 F3 OR F12' TO DECMSG
           END-EVALUATE
           EXEC CICS SEND MAP('DLISEC01') MAPSET('DLISEC')
               DATAONLY FREEKB RESP(WS-RESP1)
           END-EXEC
           EXEC CICS RETURN TRANSID('DL05')
               COMMAREA(DLIS-COMMAREA) LENGTH(350)
           END-EXEC.

       LOAD-APPLICATION.
           IF DECAIDI = ZEROS
               MOVE 'ENTER APPLICATION ID' TO DECMSG
               GO TO LOAD-APPLICATION-EXIT
           END-IF
           MOVE DECAIDI TO APPLICATION-ID OF DCLDLIS-LICENSE-APPL
           EXEC SQL
               SELECT A.APPLICATION_ID, A.CANDIDATE_ID, A.LICENSE_TYPE,
                      C.FIRST_NAME, C.LAST_NAME, C.DATE_OF_BIRTH
               INTO   :APPLICATION-ID, :CANDIDATE-ID, :LICENSE-TYPE
                      OF DCLDLIS-LICENSE-APPL,
                      :FIRST-NAME, :LAST-NAME, :DATE-OF-BIRTH
                      OF DCLDLIS-CANDIDATE
               FROM   DLIS.LICENSE_APPLICATION A
               JOIN   DLIS.CANDIDATE C
                  ON  A.CANDIDATE_ID = C.CANDIDATE_ID
               WHERE  A.APPLICATION_ID = :APPLICATION-ID
                                         OF DCLDLIS-LICENSE-APPL
           END-EXEC
           IF SQLCODE = 100
               MOVE 'APPLICATION NOT FOUND' TO DECMSG
               GO TO LOAD-APPLICATION-EXIT
           END-IF
           STRING FIRST-NAME OF DCLDLIS-CANDIDATE DELIMITED SPACE
                  ' ' DELIMITED SIZE
                  LAST-NAME  OF DCLDLIS-CANDIDATE DELIMITED SPACE
               INTO DECCNAMO
           MOVE DATE-OF-BIRTH  OF DCLDLIS-CANDIDATE TO DECDOBO
           MOVE LICENSE-TYPE   OF DCLDLIS-LICENSE-APPL TO DECLTYO
           EVALUATE LICENSE-TYPE OF DCLDLIS-LICENSE-APPL
               WHEN 'L'  MOVE 'LEARNER'    TO DECLDSO
                         MOVE 16           TO DECMAGEO
               WHEN 'P'  MOVE 'PROBATION'  TO DECLDSO
                         MOVE 17           TO DECMAGEO
               WHEN 'O'  MOVE 'OPEN'       TO DECLDSO
                         MOVE 18           TO DECMAGEO
           END-EVALUATE
           MOVE 'APPLICATION LOADED' TO DECMSG.
       LOAD-APPLICATION-EXIT. EXIT.

       RUN-ELIGIBILITY-CHECK.
           IF DECAIDI = ZEROS
               MOVE 'ENTER APPLICATION ID FIRST' TO DECMSG
               GO TO RUN-ELIG-EXIT
           END-IF
           IF DECCHKBYI = SPACES
               MOVE 'CHECKED-BY IS REQUIRED' TO DECMSG
               GO TO RUN-ELIG-EXIT
           END-IF
           PERFORM LOAD-APPLICATION
           IF DECMSG NOT = 'APPLICATION LOADED'
               GO TO RUN-ELIG-EXIT
           END-IF

      *    Calculate age
           MOVE DATE-OF-BIRTH OF DCLDLIS-CANDIDATE(1:4)
               TO WS-DOB-YEAR
           MOVE CURRENT-DATE(1:4) TO WS-CURR-YEAR
           COMPUTE WS-CALC-AGE = WS-CURR-YEAR - WS-DOB-YEAR
           MOVE WS-CALC-AGE TO DECAGEO

           MOVE 'N' TO WS-FAIL-FLAG
           MOVE SPACES TO WS-ELIG-FAIL-REASON

      *    Age check
           EVALUATE LICENSE-TYPE OF DCLDLIS-LICENSE-APPL
               WHEN 'L'
                   IF WS-CALC-AGE < 16
                       MOVE 'Y' TO WS-FAIL-FLAG
                       MOVE 'AGE BELOW 16 - LEARNER LICENSE REQUIRES MIN AGE 16'
                           TO WS-ELIG-FAIL-REASON
                   END-IF
               WHEN 'P'
                   IF WS-CALC-AGE < 17
                       MOVE 'Y' TO WS-FAIL-FLAG
                       MOVE 'AGE BELOW 17 - PROBATION LICENSE REQUIRES MIN AGE 17'
                           TO WS-ELIG-FAIL-REASON
                   END-IF
               WHEN 'O'
                   IF WS-CALC-AGE < 18
                       MOVE 'Y' TO WS-FAIL-FLAG
                       MOVE 'AGE BELOW 18 - OPEN LICENSE REQUIRES MIN AGE 18'
                           TO WS-ELIG-FAIL-REASON
                   END-IF
           END-EVALUATE

      *    Upgrade path check for P and O
           IF LICENSE-TYPE OF DCLDLIS-LICENSE-APPL = 'P'
                           AND WS-FAIL-FLAG = 'N'
               EXEC SQL
                   SELECT COUNT(*) INTO :WS-PRIOR-COUNT
                   FROM   DLIS.ISSUED_LICENSE
                   WHERE  CANDIDATE_ID   = :CANDIDATE-ID
                                           OF DCLDLIS-LICENSE-APPL
                   AND    LICENSE_TYPE   = 'L'
                   AND    LICENSE_STATUS = 'A'
               END-EXEC
               IF WS-PRIOR-COUNT = 0
                   MOVE 'Y' TO WS-FAIL-FLAG
                   MOVE 'MUST HOLD ACTIVE LEARNER LICENSE FOR PROBATION'
                       TO WS-ELIG-FAIL-REASON
               END-IF
           END-IF

           IF LICENSE-TYPE OF DCLDLIS-LICENSE-APPL = 'O'
                           AND WS-FAIL-FLAG = 'N'
               EXEC SQL
                   SELECT COUNT(*) INTO :WS-PRIOR-COUNT
                   FROM   DLIS.ISSUED_LICENSE
                   WHERE  CANDIDATE_ID   = :CANDIDATE-ID
                                           OF DCLDLIS-LICENSE-APPL
                   AND    LICENSE_TYPE   = 'P'
                   AND    LICENSE_STATUS = 'A'
               END-EXEC
               IF WS-PRIOR-COUNT = 0
                   MOVE 'Y' TO WS-FAIL-FLAG
                   MOVE 'MUST HOLD ACTIVE PROBATION LICENSE FOR OPEN'
                       TO WS-ELIG-FAIL-REASON
               END-IF
           END-IF

      *    Record result
           IF WS-FAIL-FLAG = 'Y'
               MOVE 'F' TO WS-ELIGIBILITY-STATUS
               MOVE 'FAIL'             TO DECESTSO
               MOVE WS-ELIG-FAIL-REASON TO DECENTSO
               MOVE 'RE'              TO APPLICATION-STATUS
                                         OF DCLDLIS-LICENSE-APPL
           ELSE
               MOVE 'P' TO WS-ELIGIBILITY-STATUS
               MOVE 'PASS' TO DECESTSO
               MOVE SPACES TO DECENTSO
               MOVE 'EC'   TO APPLICATION-STATUS
                               OF DCLDLIS-LICENSE-APPL
           END-IF

           EXEC SQL
               UPDATE DLIS.LICENSE_APPLICATION SET
                   ELIG_CHECK_STATUS = :WS-ELIGIBILITY-STATUS,
                   ELIG_CHECK_DATE   = CURRENT DATE,
                   ELIG_CHECK_NOTES  = :WS-ELIG-FAIL-REASON,
                   APPLICATION_STATUS= :APPLICATION-STATUS
                                       OF DCLDLIS-LICENSE-APPL,
                   LAST_UPDATED_DATE = CURRENT DATE,
                   LAST_UPDATED_BY   = :DECCHKBYI
               WHERE APPLICATION_ID  = :APPLICATION-ID
                                       OF DCLDLIS-LICENSE-APPL
           END-EXEC

           IF WS-ELIGIBILITY-STATUS = 'P'
               MOVE 'ELIGIBILITY CHECK PASSED' TO DECMSG
           ELSE
               MOVE WS-ELIG-FAIL-REASON TO DECMSG
           END-IF.
       RUN-ELIG-EXIT. EXIT.
