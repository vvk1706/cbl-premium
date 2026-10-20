      *================================================================*
      * CICS/COBOL Program                                           *
      * Program : DLISISSU                                           *
      * Trans   : DL10                                              *
      * Map     : DLISLI / DLISLIM01                                *
      * Desc    : License Issuance                                   *
      *           F1=Issue License  F3=Load App  F6=Print  F12=Exit *
      *================================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. DLISISSU.

       ENVIRONMENT DIVISION.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
           COPY DLISWS.
           COPY DLISCSEC.
           COPY DLISDCLG.

       01  WS-ISSUE-DATE          PIC X(10).
       01  WS-EXPIRY-YYYY         PIC 9(4).
       01  WS-EXPIRY-MMDD         PIC X(6).

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
           MOVE CURRENT-DATE(1:10) TO DLIDATE
           EXEC CICS SEND MAP('DLISLIM01') MAPSET('DLISLI')
               ERASE FREEKB RESP(WS-RESP1)
           END-EXEC
           EXEC CICS RETURN TRANSID('DL10')
               COMMAREA(DLIS-COMMAREA) LENGTH(350)
           END-EXEC.

       PROCESS-INPUT.
           EXEC CICS RECEIVE MAP('DLISLIM01') MAPSET('DLISLI')
               RESP(WS-RESP1)
           END-EXEC
           EVALUATE TRUE
               WHEN EIBAID = DFHPF1   PERFORM ISSUE-LICENSE
               WHEN EIBAID = DFHPF3   PERFORM LOAD-APPLICATION
               WHEN EIBAID = DFHPF6   PERFORM PRINT-LICENSE
               WHEN EIBAID = DFHPF12  EXEC CICS RETURN END-EXEC
               OTHER
                   MOVE 'USE F1 F3 F6 OR F12' TO DLIMSG
           END-EVALUATE
           EXEC CICS SEND MAP('DLISLIM01') MAPSET('DLISLI')
               DATAONLY FREEKB RESP(WS-RESP1)
           END-EXEC
           EXEC CICS RETURN TRANSID('DL10')
               COMMAREA(DLIS-COMMAREA) LENGTH(350)
           END-EXEC.

       LOAD-APPLICATION.
           IF DLIAIDI = ZEROS
               MOVE 'ENTER APPLICATION ID' TO DLIMSG
               GO TO LOAD-APP-EXIT
           END-IF
           MOVE DLIAIDI TO APPLICATION-ID OF DCLDLIS-LICENSE-APPL
           EXEC SQL
               SELECT A.CANDIDATE_ID, A.LICENSE_TYPE,
                      A.APPLICATION_STATUS, A.ELIG_CHECK_STATUS,
                      A.HIST_CHECK_STATUS,  A.PAYMENT_STATUS,
                      A.APPROVAL_1_STATUS,  A.APPROVAL_2_STATUS,
                      C.FIRST_NAME, C.LAST_NAME
               INTO   :CANDIDATE-ID, :LICENSE-TYPE,
                      :APPLICATION-STATUS, :ELIG-CHECK-STATUS,
                      :HIST-CHECK-STATUS,  :PAYMENT-STATUS,
                      :APPROVAL-1-STATUS,  :APPROVAL-2-STATUS
                      OF DCLDLIS-LICENSE-APPL,
                      :FIRST-NAME, :LAST-NAME OF DCLDLIS-CANDIDATE
               FROM   DLIS.LICENSE_APPLICATION A
               JOIN   DLIS.CANDIDATE C ON A.CANDIDATE_ID = C.CANDIDATE_ID
               WHERE  A.APPLICATION_ID = :APPLICATION-ID
                                         OF DCLDLIS-LICENSE-APPL
           END-EXEC
           IF SQLCODE = 100
               MOVE 'APPLICATION NOT FOUND' TO DLIMSG
               GO TO LOAD-APP-EXIT
           END-IF
           STRING FIRST-NAME OF DCLDLIS-CANDIDATE DELIMITED SPACE
                  ' ' DELIMITED SIZE
                  LAST-NAME  OF DCLDLIS-CANDIDATE DELIMITED SPACE
               INTO DLICNAMO
           MOVE LICENSE-TYPE      OF DCLDLIS-LICENSE-APPL TO DLILTYO
           MOVE ELIG-CHECK-STATUS OF DCLDLIS-LICENSE-APPL TO DLIELIG0
           MOVE HIST-CHECK-STATUS OF DCLDLIS-LICENSE-APPL TO DLIHISTO
           MOVE PAYMENT-STATUS    OF DCLDLIS-LICENSE-APPL TO DLIPAYO
           MOVE APPROVAL-1-STATUS OF DCLDLIS-LICENSE-APPL TO DLIAU1O
           MOVE APPROVAL-2-STATUS OF DCLDLIS-LICENSE-APPL TO DLIAU2O
           MOVE 'APPLICATION LOADED' TO DLIMSG.
       LOAD-APP-EXIT. EXIT.

       ISSUE-LICENSE.
           IF DLIAIDI = ZEROS
               MOVE 'ENTER APPLICATION ID' TO DLIMSG
               GO TO ISSUE-LIC-EXIT
           END-IF
           IF DLIVCLSI = SPACES OR DLIVCLSI NOT IN ('A','B','C','D')
               MOVE 'VEHICLE CLASS MUST BE A B C OR D' TO DLIMSG
               GO TO ISSUE-LIC-EXIT
           END-IF
           IF DLIOFCRI = SPACES
               MOVE 'ISSUING OFFICER IS REQUIRED' TO DLIMSG
               GO TO ISSUE-LIC-EXIT
           END-IF
           IF DLIAUTHI = SPACES
               MOVE 'ISSUING AUTHORITY IS REQUIRED' TO DLIMSG
               GO TO ISSUE-LIC-EXIT
           END-IF
           PERFORM LOAD-APPLICATION
           IF DLIMSG NOT = 'APPLICATION LOADED'
               GO TO ISSUE-LIC-EXIT
           END-IF
      *    All five gates must be fully satisfied
           IF APPLICATION-STATUS OF DCLDLIS-LICENSE-APPL NOT = 'AP'
               MOVE 'APPLICATION STATUS MUST BE AP BEFORE ISSUE'
                   TO DLIMSG
               GO TO ISSUE-LIC-EXIT
           END-IF
      *    Calculate expiry date
           MOVE CURRENT-DATE(1:10) TO WS-ISSUE-DATE
           MOVE CURRENT-DATE(1:4)  TO WS-EXPIRY-YYYY
           MOVE CURRENT-DATE(5:6)  TO WS-EXPIRY-MMDD
           EVALUATE LICENSE-TYPE OF DCLDLIS-LICENSE-APPL
               WHEN 'L'
                   ADD 1 TO WS-EXPIRY-YYYY
                   MOVE 'LRN' TO WS-LIC-PREFIX
               WHEN 'P'
                   ADD 2 TO WS-EXPIRY-YYYY
                   MOVE 'PRB' TO WS-LIC-PREFIX
               WHEN 'O'
                   ADD 5 TO WS-EXPIRY-YYYY
                   MOVE 'OPN' TO WS-LIC-PREFIX
           END-EVALUATE
           STRING WS-EXPIRY-YYYY WS-EXPIRY-MMDD
               INTO WS-EXPIRY-DATE
      *    Generate license number
           STRING WS-LIC-PREFIX DLIVCLSI
                  CANDIDATE-ID OF DCLDLIS-LICENSE-APPL
                  APPLICATION-ID OF DCLDLIS-LICENSE-APPL
               INTO WS-LICENSE-NUMBER
      *    Insert issued license
           MOVE DLIVCLSI  TO VEHICLE-CLASS    OF DCLDLIS-ISSUED-LIC
           MOVE DLIOFCRI  TO ISSUED-BY-OFFICER OF DCLDLIS-ISSUED-LIC
           MOVE DLIAUTHI  TO ISSUED-BY-AUTH   OF DCLDLIS-ISSUED-LIC
           MOVE DLIRSTI   TO RESTRICTIONS     OF DCLDLIS-ISSUED-LIC
           EXEC SQL
               INSERT INTO DLIS.ISSUED_LICENSE
                  (APPLICATION_ID, CANDIDATE_ID, LICENSE_NUMBER,
                   LICENSE_TYPE, ISSUE_DATE, EXPIRY_DATE,
                   LICENSE_STATUS, VEHICLE_CLASS, RESTRICTIONS,
                   DEMERIT_BALANCE, ISSUED_BY_AUTH, ISSUED_BY_OFFICER)
               VALUES
                  (:APPLICATION-ID, :CANDIDATE-ID, :WS-LICENSE-NUMBER,
                   :LICENSE-TYPE, CURRENT DATE, :WS-EXPIRY-DATE,
                   'A', :VEHICLE-CLASS, :RESTRICTIONS,
                   12, :ISSUED-BY-AUTH, :ISSUED-BY-OFFICER)
               OF DCLDLIS-ISSUED-LIC
           END-EXEC
           IF SQLCODE NOT = 0
               MOVE 'DATABASE ERROR ON LICENSE INSERT' TO DLIMSG
               GO TO ISSUE-LIC-EXIT
           END-IF
      *    Update application to IS=Issued
           EXEC SQL
               UPDATE DLIS.LICENSE_APPLICATION SET
                   APPLICATION_STATUS = 'IS',
                   LAST_UPDATED_DATE  = CURRENT DATE,
                   LAST_UPDATED_BY    = :DLIOFCRI
               WHERE APPLICATION_ID   = :APPLICATION-ID
                                        OF DCLDLIS-LICENSE-APPL
           END-EXEC
           MOVE WS-LICENSE-NUMBER TO DLIILNUMO
           MOVE WS-EXPIRY-DATE    TO DLIEXPO
           MOVE 'DRIVER LICENSE ISSUED SUCCESSFULLY' TO DLIMSG.
       ISSUE-LIC-EXIT. EXIT.

       PRINT-LICENSE.
           IF DLIILNUMO = SPACES
               MOVE 'ISSUE LICENSE FIRST BEFORE PRINTING' TO DLIMSG
               GO TO PRINT-LIC-EXIT
           END-IF
           EXEC CICS LINK PROGRAM('DLISLPRT')
               COMMAREA(DLIS-COMMAREA) LENGTH(350)
           END-EXEC
           MOVE 'LICENSE SENT TO PRINTER' TO DLIMSG.
       PRINT-LIC-EXIT. EXIT.
