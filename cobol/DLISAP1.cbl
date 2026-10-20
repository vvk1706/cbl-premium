      *================================================================*
      * CICS/COBOL Program                                           *
      * Program : DLISAP1                                            *
      * Trans   : DL08                                              *
      * Map     : DLISA1 / DLISA1M01                                *
      * Desc    : First Authority Approval                           *
      *           F1=Submit  F3=Load App  F4=Validate Auth  F12=Exit*
      *================================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. DLISAP1.

       ENVIRONMENT DIVISION.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
           COPY DLISWS.
           COPY DLISCSEC.
           COPY DLISDCLG.

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
           MOVE CURRENT-DATE(1:10) TO DA1DATE
           EXEC CICS SEND MAP('DLISA1M01') MAPSET('DLISA1')
               ERASE FREEKB RESP(WS-RESP1)
           END-EXEC
           EXEC CICS RETURN TRANSID('DL08')
               COMMAREA(DLIS-COMMAREA) LENGTH(350)
           END-EXEC.

       PROCESS-INPUT.
           EXEC CICS RECEIVE MAP('DLISA1M01') MAPSET('DLISA1')
               RESP(WS-RESP1)
           END-EXEC
           EVALUATE TRUE
               WHEN EIBAID = DFHPF1   PERFORM SUBMIT-APPROVAL1
               WHEN EIBAID = DFHPF3   PERFORM LOAD-APPLICATION
               WHEN EIBAID = DFHPF4   PERFORM VALIDATE-AUTHORITY
               WHEN EIBAID = DFHPF12  EXEC CICS RETURN END-EXEC
               OTHER
                   MOVE 'USE F1 F3 F4 OR F12' TO DA1MSG
           END-EVALUATE
           EXEC CICS SEND MAP('DLISA1M01') MAPSET('DLISA1')
               DATAONLY FREEKB RESP(WS-RESP1)
           END-EXEC
           EXEC CICS RETURN TRANSID('DL08')
               COMMAREA(DLIS-COMMAREA) LENGTH(350)
           END-EXEC.

       LOAD-APPLICATION.
           IF DA1AIDI = ZEROS
               MOVE 'ENTER APPLICATION ID' TO DA1MSG
               GO TO LOAD-APP-EXIT
           END-IF
           MOVE DA1AIDI TO APPLICATION-ID OF DCLDLIS-LICENSE-APPL
           EXEC SQL
               SELECT A.LICENSE_TYPE, A.APPLICATION_STATUS,
                      A.ELIG_CHECK_STATUS, A.HIST_CHECK_STATUS,
                      A.PAYMENT_STATUS,    A.PAYMENT_REFERENCE,
                      A.ELIG_CHECK_NOTES,  A.HIST_CHECK_NOTES,
                      C.FIRST_NAME, C.LAST_NAME
               INTO   :LICENSE-TYPE, :APPLICATION-STATUS,
                      :ELIG-CHECK-STATUS, :HIST-CHECK-STATUS,
                      :PAYMENT-STATUS, :PAYMENT-REFERENCE
                      OF DCLDLIS-LICENSE-APPL,
                      :ELIG-CHECK-NOTES, :HIST-CHECK-NOTES
                      OF DCLDLIS-LICENSE-APPL,
                      :FIRST-NAME, :LAST-NAME OF DCLDLIS-CANDIDATE
               FROM   DLIS.LICENSE_APPLICATION A
               JOIN   DLIS.CANDIDATE C ON A.CANDIDATE_ID = C.CANDIDATE_ID
               WHERE  A.APPLICATION_ID = :APPLICATION-ID
                                         OF DCLDLIS-LICENSE-APPL
           END-EXEC
           IF SQLCODE = 100
               MOVE 'APPLICATION NOT FOUND' TO DA1MSG
               GO TO LOAD-APP-EXIT
           END-IF
           STRING FIRST-NAME OF DCLDLIS-CANDIDATE DELIMITED SPACE
                  ' ' DELIMITED SIZE
                  LAST-NAME  OF DCLDLIS-CANDIDATE DELIMITED SPACE
               INTO DA1CNAMO
           MOVE LICENSE-TYPE       OF DCLDLIS-LICENSE-APPL TO DA1LTYO
           MOVE APPLICATION-STATUS OF DCLDLIS-LICENSE-APPL TO DA1ASTTO
           MOVE ELIG-CHECK-STATUS  OF DCLDLIS-LICENSE-APPL TO DA1ELIGO
           MOVE HIST-CHECK-STATUS  OF DCLDLIS-LICENSE-APPL TO DA1HISTO
           MOVE PAYMENT-STATUS     OF DCLDLIS-LICENSE-APPL TO DA1PAYO
           MOVE PAYMENT-REFERENCE  OF DCLDLIS-LICENSE-APPL TO DA1PYRFO
           MOVE ELIG-CHECK-NOTES   OF DCLDLIS-LICENSE-APPL TO DA1ELNTO
           MOVE HIST-CHECK-NOTES   OF DCLDLIS-LICENSE-APPL TO DA1HSNTO
           MOVE 'APPLICATION LOADED' TO DA1MSG.
       LOAD-APP-EXIT. EXIT.

       VALIDATE-AUTHORITY.
           IF DA1AUCOI = SPACES
               MOVE 'ENTER AUTHORITY USER CODE' TO DA1MSG
               GO TO VALIDATE-AUTH-EXIT
           END-IF
           MOVE DA1AUCOI TO USER-CODE OF DCLDLIS-AUTH-USER
           EXEC SQL
               SELECT USER_NAME, AUTHORITY_NAME, AUTHORITY_LEVEL,
                      LIC_TYPES_AUTH
               INTO   :USER-NAME, :AUTHORITY-NAME, :AUTHORITY-LEVEL,
                      :LIC-TYPES-AUTH OF DCLDLIS-AUTH-USER
               FROM   DLIS.AUTHORITY_USER
               WHERE  USER_CODE       = :USER-CODE OF DCLDLIS-AUTH-USER
               AND    ACTIVE_STATUS   = 'A'
               AND    AUTHORITY_LEVEL = '1'
           END-EXEC
           IF SQLCODE = 100
               MOVE 'AUTHORITY USER NOT FOUND OR NOT ACTIVE AT LEVEL 1'
                   TO DA1MSG
               GO TO VALIDATE-AUTH-EXIT
           END-IF
           MOVE USER-NAME      OF DCLDLIS-AUTH-USER TO DA1AUNMO
           MOVE AUTHORITY-NAME OF DCLDLIS-AUTH-USER TO DA1AUNMO
           MOVE 'AUTHORITY USER VALIDATED' TO DA1MSG.
       VALIDATE-AUTH-EXIT. EXIT.

       SUBMIT-APPROVAL1.
           IF DA1AIDI = ZEROS
               MOVE 'ENTER APPLICATION ID' TO DA1MSG
               GO TO SUBMIT-A1-EXIT
           END-IF
           IF DA1AUCOI = SPACES
               MOVE 'AUTHORITY USER CODE IS REQUIRED' TO DA1MSG
               GO TO SUBMIT-A1-EXIT
           END-IF
           IF DA1DECI = SPACES OR DA1DECI NOT IN ('A','R')
               MOVE 'DECISION MUST BE A=APPROVE OR R=REJECT' TO DA1MSG
               GO TO SUBMIT-A1-EXIT
           END-IF
           PERFORM LOAD-APPLICATION
           IF DA1MSG NOT = 'APPLICATION LOADED'
               GO TO SUBMIT-A1-EXIT
           END-IF
           IF PAYMENT-STATUS OF DCLDLIS-LICENSE-APPL NOT = 'P'
               MOVE 'PAYMENT MUST BE COMPLETED BEFORE FIRST APPROVAL'
                   TO DA1MSG
               GO TO SUBMIT-A1-EXIT
           END-IF
           PERFORM VALIDATE-AUTHORITY
           IF DA1MSG NOT = 'AUTHORITY USER VALIDATED'
               GO TO SUBMIT-A1-EXIT
           END-IF
      *    Check license type authorisation
           IF DA1LTYO NOT IN LIC-TYPES-AUTH OF DCLDLIS-AUTH-USER
               MOVE 'AUTHORITY NOT AUTHORISED FOR THIS LICENSE TYPE'
                   TO DA1MSG
               GO TO SUBMIT-A1-EXIT
           END-IF
           MOVE DA1DECI TO WS-DECISION
           IF WS-DECISION = 'A'
               MOVE 'A2' TO APPLICATION-STATUS OF DCLDLIS-LICENSE-APPL
           ELSE
               MOVE 'RE' TO APPLICATION-STATUS OF DCLDLIS-LICENSE-APPL
           END-IF
           EXEC SQL
               UPDATE DLIS.LICENSE_APPLICATION SET
                   APPROVAL_1_STATUS    = :WS-DECISION,
                   APPROVAL_1_AUTHORITY = :AUTHORITY-NAME
                                          OF DCLDLIS-AUTH-USER,
                   APPROVAL_1_DATE      = CURRENT DATE,
                   APPROVAL_1_NOTES     = :DA1DCNTI,
                   APPLICATION_STATUS   = :APPLICATION-STATUS
                                          OF DCLDLIS-LICENSE-APPL,
                   LAST_UPDATED_DATE    = CURRENT DATE,
                   LAST_UPDATED_BY      = :DA1AUCOI
               WHERE APPLICATION_ID     = :APPLICATION-ID
                                          OF DCLDLIS-LICENSE-APPL
           END-EXEC
           IF WS-DECISION = 'A'
               MOVE 'FIRST APPROVAL RECORDED - FORWARDED FOR 2ND APPROVAL'
                   TO DA1MSG
           ELSE
               MOVE 'FIRST APPROVAL REJECTED - APPLICATION CLOSED'
                   TO DA1MSG
           END-IF.
       SUBMIT-A1-EXIT. EXIT.
