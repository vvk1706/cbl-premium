      *================================================================*
      * CICS/COBOL Program                                           *
      * Program : DLISSTAT                                           *
      * Trans   : DL04                                              *
      * Map     : DLISST / DLISST01                                 *
      * Desc    : Application Status Inquiry                         *
      *           ENTER=Inquire  F12=Exit                            *
      *================================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. DLISSTAT.

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
           MOVE CURRENT-DATE(1:10) TO DSTDATE
           EXEC CICS SEND MAP('DLISST01') MAPSET('DLISST')
               ERASE FREEKB RESP(WS-RESP1)
           END-EXEC
           EXEC CICS RETURN TRANSID('DL04')
               COMMAREA(DLIS-COMMAREA) LENGTH(350)
           END-EXEC.

       PROCESS-INPUT.
           EXEC CICS RECEIVE MAP('DLISST01') MAPSET('DLISST')
               RESP(WS-RESP1)
           END-EXEC
           EVALUATE TRUE
               WHEN EIBAID = DFHENTER  PERFORM INQUIRE-STATUS
               WHEN EIBAID = DFHPF12   EXEC CICS RETURN END-EXEC
               OTHER
                   MOVE 'PRESS ENTER TO INQUIRE OR F12 TO EXIT'
                       TO DSTMSG
           END-EVALUATE
           EXEC CICS SEND MAP('DLISST01') MAPSET('DLISST')
               DATAONLY FREEKB RESP(WS-RESP1)
           END-EXEC
           EXEC CICS RETURN TRANSID('DL04')
               COMMAREA(DLIS-COMMAREA) LENGTH(350)
           END-EXEC.

       INQUIRE-STATUS.
           IF DSTAIDI = ZEROS
               MOVE 'ENTER APPLICATION ID' TO DSTMSG
               GO TO INQUIRE-EXIT
           END-IF
           MOVE DSTAIDI TO APPLICATION-ID OF DCLDLIS-LICENSE-APPL
           EXEC SQL
               SELECT LICENSE_TYPE, APPLICATION_STATUS,
                      ELIG_CHECK_STATUS, ELIG_CHECK_DATE,
                      ELIG_CHECK_NOTES,
                      HIST_CHECK_STATUS, HIST_CHECK_DATE,
                      HIST_CHECK_NOTES,
                      PAYMENT_STATUS,    PAYMENT_REFERENCE,
                      APPROVAL_1_STATUS, APPROVAL_1_DATE,
                      APPROVAL_1_AUTHORITY,
                      APPROVAL_2_STATUS, APPROVAL_2_DATE,
                      APPROVAL_2_AUTHORITY
               INTO   :LICENSE-TYPE, :APPLICATION-STATUS,
                      :ELIG-CHECK-STATUS, :ELIG-CHECK-DATE,
                      :ELIG-CHECK-NOTES,
                      :HIST-CHECK-STATUS, :HIST-CHECK-DATE,
                      :HIST-CHECK-NOTES,
                      :PAYMENT-STATUS, :PAYMENT-REFERENCE,
                      :APPROVAL-1-STATUS, :APPROVAL-1-DATE,
                      :APPROVAL-1-AUTHORITY,
                      :APPROVAL-2-STATUS, :APPROVAL-2-DATE,
                      :APPROVAL-2-AUTHORITY
               OF DCLDLIS-LICENSE-APPL
               FROM   DLIS.LICENSE_APPLICATION
               WHERE  APPLICATION_ID = :APPLICATION-ID
                                       OF DCLDLIS-LICENSE-APPL
           END-EXEC
           IF SQLCODE = 100
               MOVE 'APPLICATION NOT FOUND' TO DSTMSG
               GO TO INQUIRE-EXIT
           END-IF

           MOVE LICENSE-TYPE       OF DCLDLIS-LICENSE-APPL TO DSTLTYO
           MOVE APPLICATION-STATUS OF DCLDLIS-LICENSE-APPL TO DSTASTTO

      *    Human-readable status description
           EVALUATE APPLICATION-STATUS OF DCLDLIS-LICENSE-APPL
               WHEN 'PE' MOVE 'PENDING - AWAITING ELIGIBILITY CHECK'
                             TO DSTADSO
               WHEN 'EC' MOVE 'ELIGIBILITY CHECKED - AWAITING HISTORY'
                             TO DSTADSO
               WHEN 'HC' MOVE 'HISTORY CHECKED - AWAITING PAYMENT'
                             TO DSTADSO
               WHEN 'PA' MOVE 'PAYMENT APPROVED - AWAITING AUTH 1'
                             TO DSTADSO
               WHEN 'A2' MOVE 'AWAITING SECOND AUTHORITY APPROVAL'
                             TO DSTADSO
               WHEN 'AP' MOVE 'FULLY APPROVED - READY FOR ISSUE'
                             TO DSTADSO
               WHEN 'IS' MOVE 'LICENSE ISSUED'                TO DSTADSO
               WHEN 'RE' MOVE 'REJECTED'                      TO DSTADSO
               OTHER          MOVE 'UNKNOWN STATUS'           TO DSTADSO
           END-EVALUATE

           MOVE ELIG-CHECK-STATUS  OF DCLDLIS-LICENSE-APPL TO DST1STSO
           MOVE ELIG-CHECK-DATE    OF DCLDLIS-LICENSE-APPL TO DST1DATO
           MOVE ELIG-CHECK-NOTES   OF DCLDLIS-LICENSE-APPL TO DST1NTSO
           MOVE HIST-CHECK-STATUS  OF DCLDLIS-LICENSE-APPL TO DST2STSO
           MOVE HIST-CHECK-DATE    OF DCLDLIS-LICENSE-APPL TO DST2DATO
           MOVE HIST-CHECK-NOTES   OF DCLDLIS-LICENSE-APPL TO DST2NTSO
           MOVE PAYMENT-STATUS     OF DCLDLIS-LICENSE-APPL TO DST3STSO
           MOVE PAYMENT-REFERENCE  OF DCLDLIS-LICENSE-APPL TO DST3REFO
           MOVE APPROVAL-1-STATUS  OF DCLDLIS-LICENSE-APPL TO DST4STSO
           MOVE APPROVAL-1-DATE    OF DCLDLIS-LICENSE-APPL TO DST4DATO
           MOVE APPROVAL-1-AUTHORITY OF DCLDLIS-LICENSE-APPL TO DST4AUTO
           MOVE APPROVAL-2-STATUS  OF DCLDLIS-LICENSE-APPL TO DST5STSO
           MOVE APPROVAL-2-DATE    OF DCLDLIS-LICENSE-APPL TO DST5DATO
           MOVE APPROVAL-2-AUTHORITY OF DCLDLIS-LICENSE-APPL TO DST5AUTO

      *    If issued, retrieve license number
           IF APPLICATION-STATUS OF DCLDLIS-LICENSE-APPL = 'IS'
               EXEC SQL
                   SELECT LICENSE_NUMBER, EXPIRY_DATE
                   INTO   :LICENSE-NUMBER, :EXPIRY-DATE
                          OF DCLDLIS-ISSUED-LIC
                   FROM   DLIS.ISSUED_LICENSE
                   WHERE  APPLICATION_ID = :APPLICATION-ID
                                           OF DCLDLIS-LICENSE-APPL
               END-EXEC
               IF SQLCODE = 0
                   MOVE LICENSE-NUMBER OF DCLDLIS-ISSUED-LIC TO DST6NUMO
                   MOVE EXPIRY-DATE    OF DCLDLIS-ISSUED-LIC TO DST6EXPO
                   MOVE 'YES'   TO DST6FLGO
               END-IF
           ELSE
               MOVE 'NO'  TO DST6FLGO
           END-IF
           MOVE 'INQUIRY SUCCESSFUL' TO DSTMSG.
       INQUIRE-EXIT. EXIT.
