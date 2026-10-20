      *================================================================*
      * CICS/COBOL Program                                           *
      * Program : DLISPAY                                            *
      * Trans   : DL07                                              *
      * Map     : DLISPE / DLISPE01                                 *
      * Desc    : Payment Entry and Processing                       *
      *           F1=Process Payment  F3=Lookup  F5=Print Receipt   *
      *================================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. DLISPAY.

       ENVIRONMENT DIVISION.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
           COPY DLISWS.
           COPY DLISCSEC.
           COPY DLISDCLG.

       01  WS-RECEIPT-DATE        PIC X(8).

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
           MOVE CURRENT-DATE(1:10) TO DPEDATE
           EXEC CICS SEND MAP('DLISPE01') MAPSET('DLISPE')
               ERASE FREEKB RESP(WS-RESP1)
           END-EXEC
           EXEC CICS RETURN TRANSID('DL07')
               COMMAREA(DLIS-COMMAREA) LENGTH(350)
           END-EXEC.

       PROCESS-INPUT.
           EXEC CICS RECEIVE MAP('DLISPE01') MAPSET('DLISPE')
               RESP(WS-RESP1)
           END-EXEC
           EVALUATE TRUE
               WHEN EIBAID = DFHPF1   PERFORM PROCESS-PAYMENT
               WHEN EIBAID = DFHPF3   PERFORM LOAD-APPLICATION
               WHEN EIBAID = DFHPF5   PERFORM PRINT-RECEIPT
               WHEN EIBAID = DFHPF12  EXEC CICS RETURN END-EXEC
               OTHER
                   MOVE 'USE F1 F3 F5 OR F12' TO DPEMSG
           END-EVALUATE
           EXEC CICS SEND MAP('DLISPE01') MAPSET('DLISPE')
               DATAONLY FREEKB RESP(WS-RESP1)
           END-EXEC
           EXEC CICS RETURN TRANSID('DL07')
               COMMAREA(DLIS-COMMAREA) LENGTH(350)
           END-EXEC.

       LOAD-APPLICATION.
           IF DPEAIDI = ZEROS
               MOVE 'ENTER APPLICATION ID' TO DPEMSG
               GO TO LOAD-APP-EXIT
           END-IF
           MOVE DPEAIDI TO APPLICATION-ID OF DCLDLIS-LICENSE-APPL
           EXEC SQL
               SELECT A.CANDIDATE_ID, A.LICENSE_TYPE,
                      A.HIST_CHECK_STATUS, A.PAYMENT_STATUS,
                      C.FIRST_NAME, C.LAST_NAME
               INTO   :CANDIDATE-ID, :LICENSE-TYPE,
                      :HIST-CHECK-STATUS, :PAYMENT-STATUS
                      OF DCLDLIS-LICENSE-APPL,
                      :FIRST-NAME, :LAST-NAME OF DCLDLIS-CANDIDATE
               FROM   DLIS.LICENSE_APPLICATION A
               JOIN   DLIS.CANDIDATE C ON A.CANDIDATE_ID = C.CANDIDATE_ID
               WHERE  A.APPLICATION_ID = :APPLICATION-ID
                                         OF DCLDLIS-LICENSE-APPL
           END-EXEC
           IF SQLCODE = 100
               MOVE 'APPLICATION NOT FOUND' TO DPEMSG
               GO TO LOAD-APP-EXIT
           END-IF
           STRING FIRST-NAME OF DCLDLIS-CANDIDATE DELIMITED SPACE
                  ' ' DELIMITED SIZE
                  LAST-NAME  OF DCLDLIS-CANDIDATE DELIMITED SPACE
               INTO DPECNAMO
           MOVE LICENSE-TYPE OF DCLDLIS-LICENSE-APPL TO DPELTYO
           EVALUATE LICENSE-TYPE OF DCLDLIS-LICENSE-APPL
               WHEN 'L' MOVE 'LEARNER'   TO DPELDSO
               WHEN 'P' MOVE 'PROBATION' TO DPELDSO
               WHEN 'O' MOVE 'OPEN'      TO DPELDSO
           END-EVALUATE
      *    Retrieve fee
           EXEC SQL
               SELECT FEE_AMOUNT, CURRENCY_CODE
               INTO   :FEE-AMOUNT, :CURRENCY-CODE OF DCLDLIS-FEE-SCHED
               FROM   DLIS.LICENSE_FEE_SCHEDULE
               WHERE  LICENSE_TYPE  = :LICENSE-TYPE OF DCLDLIS-LICENSE-APPL
               AND    FEE_TYPE      = 'IF'
               AND    ACTIVE_STATUS = 'A'
               AND    EFFECTIVE_DATE <= CURRENT DATE
               FETCH FIRST 1 ROW ONLY
           END-EXEC
           IF SQLCODE = 0
               MOVE FEE-AMOUNT    OF DCLDLIS-FEE-SCHED TO WS-FEE-AMOUNT
               MOVE WS-FEE-AMOUNT TO WS-FEE-AMOUNT-D
               MOVE WS-FEE-AMOUNT-D TO DPEFEEO
               MOVE CURRENCY-CODE OF DCLDLIS-FEE-SCHED TO DPECURRO
           END-IF
           MOVE 'APPLICATION LOADED' TO DPEMSG.
       LOAD-APP-EXIT. EXIT.

       PROCESS-PAYMENT.
           IF DPEAIDI = ZEROS
               MOVE 'ENTER APPLICATION ID' TO DPEMSG
               GO TO PROCESS-PAY-EXIT
           END-IF
           IF DPEMETHI = SPACES
               MOVE 'PAYMENT METHOD IS REQUIRED' TO DPEMSG
               GO TO PROCESS-PAY-EXIT
           END-IF
           IF DPEMETHI NOT IN ('CC','DC','EF','CS','CH')
               MOVE 'INVALID PAYMENT METHOD' TO DPEMSG
               GO TO PROCESS-PAY-EXIT
           END-IF
           IF DPEREFI = SPACES
               MOVE 'PAYMENT REFERENCE IS REQUIRED' TO DPEMSG
               GO TO PROCESS-PAY-EXIT
           END-IF
           PERFORM LOAD-APPLICATION
           IF DPEMSG NOT = 'APPLICATION LOADED'
               GO TO PROCESS-PAY-EXIT
           END-IF
           IF HIST-CHECK-STATUS OF DCLDLIS-LICENSE-APPL NOT = 'P'
               MOVE 'HISTORY CHECK MUST BE PASSED BEFORE PAYMENT'
                   TO DPEMSG
               GO TO PROCESS-PAY-EXIT
           END-IF
           IF PAYMENT-STATUS OF DCLDLIS-LICENSE-APPL = 'P'
               MOVE 'PAYMENT ALREADY RECORDED FOR THIS APPLICATION'
                   TO DPEMSG
               GO TO PROCESS-PAY-EXIT
           END-IF
      *    Generate receipt number
           MOVE CURRENT-DATE(1:8)  TO WS-RECEIPT-DATE
           STRING 'RCP' WS-RECEIPT-DATE DPEAIDI
               INTO WS-RECEIPT-NUMBER
      *    Insert payment
           MOVE DPEMETHI TO PAYMENT-METHOD    OF DCLDLIS-PAYMENT
           MOVE DPEREFI  TO PAYMENT-REFERENCE OF DCLDLIS-PAYMENT
           MOVE DPEAIDI  TO APPLICATION-ID    OF DCLDLIS-PAYMENT
           MOVE CANDIDATE-ID OF DCLDLIS-LICENSE-APPL
                         TO CANDIDATE-ID      OF DCLDLIS-PAYMENT
           MOVE LICENSE-TYPE OF DCLDLIS-LICENSE-APPL
                         TO LICENSE-TYPE      OF DCLDLIS-PAYMENT
           MOVE WS-FEE-AMOUNT TO PAYMENT-AMOUNT OF DCLDLIS-PAYMENT
           MOVE WS-RECEIPT-NUMBER TO RECEIPT-NUMBER OF DCLDLIS-PAYMENT
           MOVE DPEPRCBYI TO PROCESSED-BY OF DCLDLIS-PAYMENT
           EXEC SQL
               INSERT INTO DLIS.PAYMENT
                  (APPLICATION_ID, CANDIDATE_ID, PAYMENT_AMOUNT,
                   PAYMENT_METHOD, PAYMENT_REFERENCE, PAYMENT_STATUS,
                   LICENSE_TYPE, FEE_TYPE, RECEIPT_NUMBER, PROCESSED_BY)
               VALUES
                  (:APPLICATION-ID, :CANDIDATE-ID, :PAYMENT-AMOUNT,
                   :PAYMENT-METHOD, :PAYMENT-REFERENCE, 'S',
                   :LICENSE-TYPE, 'IF', :RECEIPT-NUMBER, :PROCESSED-BY)
               OF DCLDLIS-PAYMENT
           END-EXEC
           IF SQLCODE NOT = 0
               MOVE 'DATABASE ERROR ON PAYMENT INSERT' TO DPEMSG
               GO TO PROCESS-PAY-EXIT
           END-IF
           EXEC SQL
               SELECT IDENTITY_VAL_LOCAL()
               INTO   :PAYMENT-ID OF DCLDLIS-PAYMENT
               FROM   SYSIBM.SYSDUMMY1
           END-EXEC
      *    Update application
           EXEC SQL
               UPDATE DLIS.LICENSE_APPLICATION SET
                   PAYMENT_STATUS    = 'P',
                   PAYMENT_REFERENCE = :PAYMENT-REFERENCE
                                       OF DCLDLIS-PAYMENT,
                   APPLICATION_STATUS= 'PA',
                   LAST_UPDATED_DATE = CURRENT DATE,
                   LAST_UPDATED_BY   = :PROCESSED-BY OF DCLDLIS-PAYMENT
               WHERE APPLICATION_ID  = :APPLICATION-ID
                                       OF DCLDLIS-PAYMENT
           END-EXEC
           MOVE PAYMENT-ID   OF DCLDLIS-PAYMENT TO DPEPIDO
           MOVE WS-RECEIPT-NUMBER TO DPERCTO
           MOVE 'S'               TO DPEPSTSO
           MOVE 'PAYMENT RECORDED SUCCESSFULLY' TO DPEMSG.
       PROCESS-PAY-EXIT. EXIT.

       PRINT-RECEIPT.
           IF DPERCTO = SPACES
               MOVE 'PROCESS PAYMENT FIRST BEFORE PRINTING' TO DPEMSG
               GO TO PRINT-RECEIPT-EXIT
           END-IF
           EXEC CICS LINK PROGRAM('DLISRPRT')
               COMMAREA(DLIS-COMMAREA) LENGTH(350)
           END-EXEC
           MOVE 'RECEIPT SENT TO PRINTER' TO DPEMSG.
       PRINT-RECEIPT-EXIT. EXIT.
