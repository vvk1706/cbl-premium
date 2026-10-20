      *================================================================*
      * CICS/COBOL Program                                           *
      * Program : DLISAPPL                                           *
      * Trans   : DL03                                              *
      * Map     : DLISAE / DLISAE01                                 *
      * Desc    : License Application Entry                          *
      *           F1=Submit  F3=Lookup Candidate  F5=Calc Fee       *
      *================================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. DLISAPPL.

       ENVIRONMENT DIVISION.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
           COPY DLISWS.
           COPY DLISCSEC.
           COPY DLISDCLG.

       EXEC SQL INCLUDE SQLCA END-EXEC.

       LINKAGE SECTION.
       01  DFHCOMMAREA                PIC X(350).

       PROCEDURE DIVISION.
       MAIN-LOGIC.
           MOVE EIBTRNID TO CA-TRANSACTION-ID
           IF EIBCALEN = 0
               PERFORM INIT-SCREEN
           ELSE
               MOVE DFHCOMMAREA TO DLIS-COMMAREA
               PERFORM PROCESS-INPUT
           END-IF
           STOP RUN.

       INIT-SCREEN.
           MOVE CURRENT-DATE(1:10) TO DAEDATE
           EXEC CICS SEND MAP('DLISAE01') MAPSET('DLISAE')
               ERASE FREEKB RESP(WS-RESP1)
           END-EXEC
           EXEC CICS RETURN TRANSID('DL03')
               COMMAREA(DLIS-COMMAREA) LENGTH(350)
           END-EXEC.

       PROCESS-INPUT.
           EXEC CICS RECEIVE MAP('DLISAE01') MAPSET('DLISAE')
               RESP(WS-RESP1)
           END-EXEC
           EVALUATE TRUE
               WHEN EIBAID = DFHPF1   PERFORM SUBMIT-APPLICATION
               WHEN EIBAID = DFHPF3   PERFORM LOOKUP-CANDIDATE
               WHEN EIBAID = DFHPF5   PERFORM CALC-FEE
               WHEN EIBAID = DFHPF12  EXEC CICS RETURN END-EXEC
               OTHER
                   MOVE 'USE F1 F3 F5 OR F12' TO DAEMSG
           END-EVALUATE
           EXEC CICS SEND MAP('DLISAE01') MAPSET('DLISAE')
               DATAONLY FREEKB RESP(WS-RESP1)
           END-EXEC
           EXEC CICS RETURN TRANSID('DL03')
               COMMAREA(DLIS-COMMAREA) LENGTH(350)
           END-EXEC.

       LOOKUP-CANDIDATE.
           IF DAECIDI = ZEROS
               MOVE 'ENTER CANDIDATE ID' TO DAEMSG
               GO TO LOOKUP-CANDIDATE-EXIT
           END-IF
           MOVE DAECIDI TO CANDIDATE-ID OF DCLDLIS-CANDIDATE
           EXEC SQL
               SELECT FIRST_NAME, LAST_NAME, RECORD_STATUS
               INTO   :FIRST-NAME, :LAST-NAME, :RECORD-STATUS
               OF DCLDLIS-CANDIDATE
               FROM   DLIS.CANDIDATE
               WHERE  CANDIDATE_ID = :CANDIDATE-ID OF DCLDLIS-CANDIDATE
           END-EXEC
           IF SQLCODE = 100
               MOVE 'CANDIDATE NOT FOUND' TO DAEMSG
               GO TO LOOKUP-CANDIDATE-EXIT
           END-IF
           IF RECORD-STATUS OF DCLDLIS-CANDIDATE = 'I'
               MOVE 'CANDIDATE RECORD IS INACTIVE' TO DAEMSG
               GO TO LOOKUP-CANDIDATE-EXIT
           END-IF
           STRING FIRST-NAME OF DCLDLIS-CANDIDATE DELIMITED SPACE
                  ' '        DELIMITED SIZE
                  LAST-NAME  OF DCLDLIS-CANDIDATE DELIMITED SPACE
               INTO DAECNAMO
           MOVE 'CANDIDATE FOUND' TO DAEMSG.
       LOOKUP-CANDIDATE-EXIT. EXIT.

       CALC-FEE.
           IF DAELTYPI = SPACES OR DAELTYPI = LOW-VALUES
               MOVE 'SELECT LICENSE TYPE FIRST' TO DAEMSG
               GO TO CALC-FEE-EXIT
           END-IF
           MOVE DAELTYPI TO LICENSE-TYPE OF DCLDLIS-FEE-SCHED
           EXEC SQL
               SELECT FEE_AMOUNT, CURRENCY_CODE
               INTO   :FEE-AMOUNT, :CURRENCY-CODE
               OF DCLDLIS-FEE-SCHED
               FROM   DLIS.LICENSE_FEE_SCHEDULE
               WHERE  LICENSE_TYPE  = :LICENSE-TYPE OF DCLDLIS-FEE-SCHED
               AND    FEE_TYPE      = 'IF'
               AND    ACTIVE_STATUS = 'A'
               AND    EFFECTIVE_DATE <= CURRENT DATE
               AND    (EXPIRY_DATE IS NULL OR EXPIRY_DATE >= CURRENT DATE)
               FETCH FIRST 1 ROW ONLY
           END-EXEC
           IF SQLCODE = 100
               MOVE 'NO FEE SCHEDULE FOR THIS LICENSE TYPE' TO DAEMSG
               GO TO CALC-FEE-EXIT
           END-IF
           MOVE FEE-AMOUNT    OF DCLDLIS-FEE-SCHED TO WS-FEE-AMOUNT
           MOVE WS-FEE-AMOUNT TO WS-FEE-AMOUNT-D
           MOVE WS-FEE-AMOUNT-D TO DAEFEEO
           MOVE CURRENCY-CODE OF DCLDLIS-FEE-SCHED TO DAECURRO
           MOVE 'FEE RETRIEVED SUCCESSFULLY' TO DAEMSG.
       CALC-FEE-EXIT. EXIT.

       SUBMIT-APPLICATION.
           IF DAECIDI = ZEROS
               MOVE 'CANDIDATE ID IS REQUIRED' TO DAEMSG
               GO TO SUBMIT-APPLICATION-EXIT
           END-IF
           IF DAELTYPI = SPACES OR DAELTYPI = LOW-VALUES
               MOVE 'LICENSE TYPE IS REQUIRED' TO DAEMSG
               GO TO SUBMIT-APPLICATION-EXIT
           END-IF
           IF DAELTYPI NOT = 'L' AND DAELTYPI NOT = 'P'
                               AND DAELTYPI NOT = 'O'
               MOVE 'LICENSE TYPE MUST BE L P OR O' TO DAEMSG
               GO TO SUBMIT-APPLICATION-EXIT
           END-IF
      *    Check no active application already exists
           MOVE DAECIDI  TO CANDIDATE-ID  OF DCLDLIS-LICENSE-APPL
           MOVE DAELTYPI TO LICENSE-TYPE  OF DCLDLIS-LICENSE-APPL
           EXEC SQL
               SELECT COUNT(*) INTO :APPLICATION-ID OF DCLDLIS-LICENSE-APPL
               FROM   DLIS.LICENSE_APPLICATION
               WHERE  CANDIDATE_ID   = :CANDIDATE-ID   OF DCLDLIS-LICENSE-APPL
               AND    LICENSE_TYPE   = :LICENSE-TYPE   OF DCLDLIS-LICENSE-APPL
               AND    APPLICATION_STATUS NOT IN ('RE','IS')
           END-EXEC
           IF APPLICATION-ID OF DCLDLIS-LICENSE-APPL > 0
               MOVE 'ACTIVE APPLICATION ALREADY EXISTS FOR THIS TYPE'
                   TO DAEMSG
               GO TO SUBMIT-APPLICATION-EXIT
           END-IF
      *    Insert application
           MOVE EIBTRMID TO CREATED-BY    OF DCLDLIS-LICENSE-APPL
           EXEC SQL
               INSERT INTO DLIS.LICENSE_APPLICATION
                  (CANDIDATE_ID, LICENSE_TYPE, APPLICATION_STATUS, CREATED_BY,
                   LAST_UPDATED_BY)
               VALUES
                  (:CANDIDATE-ID, :LICENSE-TYPE, 'PE', :CREATED-BY, :CREATED-BY)
               OF DCLDLIS-LICENSE-APPL
           END-EXEC
           IF SQLCODE NOT = 0
               MOVE 'DATABASE ERROR ON APPLICATION INSERT' TO DAEMSG
               GO TO SUBMIT-APPLICATION-EXIT
           END-IF
           EXEC SQL
               SELECT IDENTITY_VAL_LOCAL()
               INTO   :APPLICATION-ID OF DCLDLIS-LICENSE-APPL
               FROM   SYSIBM.SYSDUMMY1
           END-EXEC
           MOVE APPLICATION-ID OF DCLDLIS-LICENSE-APPL TO DAEAIDO
           MOVE 'PE'           TO DAEASTTO
           MOVE CURRENT-DATE(1:10) TO DAEADATO
           MOVE 'APPLICATION SUBMITTED SUCCESSFULLY' TO DAEMSG.
       SUBMIT-APPLICATION-EXIT. EXIT.
