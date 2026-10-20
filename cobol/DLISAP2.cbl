      *================================================================*
      * CICS/COBOL Program                                           *
      * Program : DLISAP2                                            *
      * Trans   : DL09                                              *
      * Map     : DLISA2 / DLISA2M01                                *
      * Desc    : Second Authority Approval                          *
      *           Enforces different authority from first approver   *
      *           F1=Submit  F3=Load App  F4=Validate Auth  F12=Exit*
      *================================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. DLISAP2.

       ENVIRONMENT DIVISION.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
           COPY DLISWS.
           COPY DLISCSEC.
           COPY DLISDCLG.

       01  WS-APPROVAL1-AUTH      PIC X(50).

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
           MOVE CURRENT-DATE(1:10) TO DA2DATE
           EXEC CICS SEND MAP('DLISA2M01') MAPSET('DLISA2')
               ERASE FREEKB RESP(WS-RESP1)
           END-EXEC
           EXEC CICS RETURN TRANSID('DL09')
               COMMAREA(DLIS-COMMAREA) LENGTH(350)
           END-EXEC.

       PROCESS-INPUT.
           EXEC CICS RECEIVE MAP('DLISA2M01') MAPSET('DLISA2')
               RESP(WS-RESP1)
           END-EXEC
           EVALUATE TRUE
               WHEN EIBAID = DFHPF1   PERFORM SUBMIT-APPROVAL2
               WHEN EIBAID = DFHPF3   PERFORM LOAD-APPLICATION
               WHEN EIBAID = DFHPF4   PERFORM VALIDATE-AUTHORITY
               WHEN EIBAID = DFHPF12  EXEC CICS RETURN END-EXEC
               OTHER
                   MOVE 'USE F1 F3 F4 OR F12' TO DA2MSG
           END-EVALUATE
           EXEC CICS SEND MAP('DLISA2M01') MAPSET('DLISA2')
               DATAONLY FREEKB RESP(WS-RESP1)
           END-EXEC
           EXEC CICS RETURN TRANSID('DL09')
               COMMAREA(DLIS-COMMAREA) LENGTH(350)
           END-EXEC.

       LOAD-APPLICATION.
           IF DA2AIDI = ZEROS
               MOVE 'ENTER APPLICATION ID' TO DA2MSG
               GO TO LOAD-APP-EXIT
           END-IF
           MOVE DA2AIDI TO APPLICATION-ID OF DCLDLIS-LICENSE-APPL
           EXEC SQL
               SELECT A.LICENSE_TYPE, A.APPLICATION_STATUS,
                      A.ELIG_CHECK_STATUS, A.HIST_CHECK_STATUS,
                      A.PAYMENT_STATUS, A.APPROVAL_1_STATUS,
                      A.APPROVAL_1_AUTHORITY,
                      C.FIRST_NAME, C.LAST_NAME
               INTO   :LICENSE-TYPE, :APPLICATION-STATUS,
                      :ELIG-CHECK-STATUS, :HIST-CHECK-STATUS,
                      :PAYMENT-STATUS, :APPROVAL-1-STATUS,
                      :APPROVAL-1-AUTHORITY
                      OF DCLDLIS-LICENSE-APPL,
                      :FIRST-NAME, :LAST-NAME OF DCLDLIS-CANDIDATE
               FROM   DLIS.LICENSE_APPLICATION A
               JOIN   DLIS.CANDIDATE C ON A.CANDIDATE_ID = C.CANDIDATE_ID
               WHERE  A.APPLICATION_ID = :APPLICATION-ID
                                         OF DCLDLIS-LICENSE-APPL
           END-EXEC
           IF SQLCODE = 100
               MOVE 'APPLICATION NOT FOUND' TO DA2MSG
               GO TO LOAD-APP-EXIT
           END-IF
           STRING FIRST-NAME OF DCLDLIS-CANDIDATE DELIMITED SPACE
                  ' ' DELIMITED SIZE
                  LAST-NAME  OF DCLDLIS-CANDIDATE DELIMITED SPACE
               INTO DA2CNAMO
           MOVE LICENSE-TYPE       OF DCLDLIS-LICENSE-APPL TO DA2LTYO
           MOVE ELIG-CHECK-STATUS  OF DCLDLIS-LICENSE-APPL TO DA2ELIGO
           MOVE HIST-CHECK-STATUS  OF DCLDLIS-LICENSE-APPL TO DA2HISTO
           MOVE PAYMENT-STATUS     OF DCLDLIS-LICENSE-APPL TO DA2PAYO
           MOVE APPROVAL-1-STATUS  OF DCLDLIS-LICENSE-APPL TO DA2A1STO
           MOVE APPROVAL-1-AUTHORITY OF DCLDLIS-LICENSE-APPL TO DA2A1NMO
           MOVE APPROVAL-1-AUTHORITY OF DCLDLIS-LICENSE-APPL
               TO WS-APPROVAL1-AUTH
           MOVE 'APPLICATION LOADED' TO DA2MSG.
       LOAD-APP-EXIT. EXIT.

       VALIDATE-AUTHORITY.
           IF DA2AUCOI = SPACES
               MOVE 'ENTER AUTHORITY USER CODE' TO DA2MSG
               GO TO VALIDATE-AUTH-EXIT
           END-IF
           MOVE DA2AUCOI TO USER-CODE OF DCLDLIS-AUTH-USER
           EXEC SQL
               SELECT USER_NAME, AUTHORITY_NAME, AUTHORITY_LEVEL,
                      LIC_TYPES_AUTH
               INTO   :USER-NAME, :AUTHORITY-NAME, :AUTHORITY-LEVEL,
                      :LIC-TYPES-AUTH OF DCLDLIS-AUTH-USER
               FROM   DLIS.AUTHORITY_USER
               WHERE  USER_CODE       = :USER-CODE OF DCLDLIS-AUTH-USER
               AND    ACTIVE_STATUS   = 'A'
               AND    AUTHORITY_LEVEL = '2'
           END-EXEC
           IF SQLCODE = 100
               MOVE 'AUTHORITY USER NOT FOUND OR NOT ACTIVE AT LEVEL 2'
                   TO DA2MSG
               GO TO VALIDATE-AUTH-EXIT
           END-IF
           MOVE AUTHORITY-NAME OF DCLDLIS-AUTH-USER TO DA2AUNMO
           MOVE 'AUTHORITY USER VALIDATED' TO DA2MSG.
       VALIDATE-AUTH-EXIT. EXIT.

       SUBMIT-APPROVAL2.
           IF DA2AIDI = ZEROS
               MOVE 'ENTER APPLICATION ID' TO DA2MSG
               GO TO SUBMIT-A2-EXIT
           END-IF
           IF DA2AUCOI = SPACES
               MOVE 'AUTHORITY USER CODE IS REQUIRED' TO DA2MSG
               GO TO SUBMIT-A2-EXIT
           END-IF
           IF DA2DECI = SPACES OR DA2DECI NOT IN ('A','R')
               MOVE 'DECISION MUST BE A=APPROVE OR R=REJECT' TO DA2MSG
               GO TO SUBMIT-A2-EXIT
           END-IF
           PERFORM LOAD-APPLICATION
           IF DA2MSG NOT = 'APPLICATION LOADED'
               GO TO SUBMIT-A2-EXIT
           END-IF
           IF APPROVAL-1-STATUS OF DCLDLIS-LICENSE-APPL NOT = 'A'
               MOVE 'FIRST APPROVAL MUST BE GRANTED BEFORE SECOND'
                   TO DA2MSG
               GO TO SUBMIT-A2-EXIT
           END-IF
           PERFORM VALIDATE-AUTHORITY
           IF DA2MSG NOT = 'AUTHORITY USER VALIDATED'
               GO TO SUBMIT-A2-EXIT
           END-IF
      *    Segregation: second approver must differ from first
           IF AUTHORITY-NAME OF DCLDLIS-AUTH-USER = WS-APPROVAL1-AUTH
               MOVE 'SECOND APPROVER MUST BE FROM DIFFERENT AUTHORITY'
                   TO DA2MSG
               GO TO SUBMIT-A2-EXIT
           END-IF
      *    Check license type authorisation
           IF DA2LTYO NOT IN LIC-TYPES-AUTH OF DCLDLIS-AUTH-USER
               MOVE 'AUTHORITY NOT AUTHORISED FOR THIS LICENSE TYPE'
                   TO DA2MSG
               GO TO SUBMIT-A2-EXIT
           END-IF
           MOVE DA2DECI TO WS-DECISION
           IF WS-DECISION = 'A'
               MOVE 'AP' TO APPLICATION-STATUS OF DCLDLIS-LICENSE-APPL
           ELSE
               MOVE 'RE' TO APPLICATION-STATUS OF DCLDLIS-LICENSE-APPL
           END-IF
           EXEC SQL
               UPDATE DLIS.LICENSE_APPLICATION SET
                   APPROVAL_2_STATUS    = :WS-DECISION,
                   APPROVAL_2_AUTHORITY = :AUTHORITY-NAME
                                          OF DCLDLIS-AUTH-USER,
                   APPROVAL_2_DATE      = CURRENT DATE,
                   APPROVAL_2_NOTES     = :DA2DCNTI,
                   APPLICATION_STATUS   = :APPLICATION-STATUS
                                          OF DCLDLIS-LICENSE-APPL,
                   LAST_UPDATED_DATE    = CURRENT DATE,
                   LAST_UPDATED_BY      = :DA2AUCOI
               WHERE APPLICATION_ID     = :APPLICATION-ID
                                          OF DCLDLIS-LICENSE-APPL
           END-EXEC
           IF WS-DECISION = 'A'
               MOVE 'SECOND APPROVAL GRANTED - READY FOR LICENSE ISSUE'
                   TO DA2MSG
           ELSE
               MOVE 'SECOND APPROVAL REJECTED - APPLICATION CLOSED'
                   TO DA2MSG
           END-IF.
       SUBMIT-A2-EXIT. EXIT.
