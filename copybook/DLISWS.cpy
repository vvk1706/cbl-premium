      *================================================================*
      * COBOL Copybook                                                *
      * Member  : DLISWS                                             *
      * Desc    : Common working storage - return codes, messages,   *
      *           work areas shared across all DLIS programs         *
      *================================================================*

      *----------------------------------------------------------------*
      * Common Return Code and Message Area                            *
      *----------------------------------------------------------------*
       01  WS-COMMON-AREA.
           10 WS-RETURN-CODE          PIC S9(4)   COMP  VALUE 0.
           10 WS-RETURN-MSG           PIC X(100)  VALUE SPACES.
           10 WS-USER-ID              PIC X(8).
           10 WS-CURRENT-DATE.
              15 WS-CURR-YYYY         PIC 9(4).
              15 WS-CURR-MM           PIC 9(2).
              15 WS-CURR-DD           PIC 9(2).
           10 WS-CURRENT-DATE-X       PIC X(10).
           10 WS-MSG-COLOR            PIC X(5)    VALUE 'GREEN'.

      *----------------------------------------------------------------*
      * Candidate Working Storage                                      *
      *----------------------------------------------------------------*
       01  WS-CANDIDATE.
           10 WS-CANDIDATE-ID         PIC S9(10)  COMP-3.
           10 WS-FIRST-NAME           PIC X(30).
           10 WS-LAST-NAME            PIC X(30).
           10 WS-DATE-OF-BIRTH        PIC X(10).
           10 WS-ID-NUMBER            PIC X(20).
           10 WS-ADDRESS-LINE-1       PIC X(50).
           10 WS-ADDRESS-LINE-2       PIC X(50).
           10 WS-CITY                 PIC X(30).
           10 WS-STATE-PROVINCE       PIC X(30).
           10 WS-POSTAL-CODE          PIC X(10).
           10 WS-COUNTRY              PIC X(30).
           10 WS-PHONE-NUMBER         PIC X(15).
           10 WS-EMAIL-ADDRESS        PIC X(60).
           10 WS-RECORD-STATUS        PIC X(1).
           10 WS-CAND-FULL-NAME       PIC X(61).

      *----------------------------------------------------------------*
      * Application Working Storage                                    *
      *----------------------------------------------------------------*
       01  WS-APPLICATION.
           10 WS-APPLICATION-ID       PIC S9(10)  COMP-3.
           10 WS-LICENSE-TYPE         PIC X(1).
           10 WS-APP-STATUS           PIC X(2).
           10 WS-APP-STATUS-DESC      PIC X(50).
           10 WS-ELIG-STATUS          PIC X(1).
           10 WS-HIST-STATUS          PIC X(1).
           10 WS-PAY-STATUS           PIC X(1).
           10 WS-APP1-STATUS          PIC X(1).
           10 WS-APP2-STATUS          PIC X(1).
           10 WS-CREATED-BY           PIC X(20).

      *----------------------------------------------------------------*
      * Payment Working Storage                                        *
      *----------------------------------------------------------------*
       01  WS-PAYMENT.
           10 WS-PAYMENT-ID           PIC S9(10)  COMP-3.
           10 WS-PAYMENT-METHOD       PIC X(2).
           10 WS-PAYMENT-REFERENCE    PIC X(30).
           10 WS-FEE-AMOUNT           PIC S9(10)V99 COMP-3.
           10 WS-FEE-AMOUNT-D         PIC ZZZ,ZZ9.99.
           10 WS-RECEIPT-NUMBER       PIC X(20).
           10 WS-CURRENCY-CODE        PIC X(3).
           10 WS-PROCESSED-BY         PIC X(20).

      *----------------------------------------------------------------*
      * Eligibility Working Storage                                    *
      *----------------------------------------------------------------*
       01  WS-ELIGIBILITY.
           10 WS-ELIGIBILITY-STATUS   PIC X(1).
           10 WS-CHECKED-BY           PIC X(20).
           10 WS-CANDIDATE-AGE        PIC S9(3)   COMP-3.
           10 WS-MIN-AGE-REQUIRED     PIC S9(3)   COMP-3.
           10 WS-PRIOR-LIC-TYPE       PIC X(1).
           10 WS-PRIOR-LIC-STATUS     PIC X(30).
           10 WS-ELIG-FAIL-REASON     PIC X(200).
           10 WS-FAIL-FLAG            PIC X(1).

      *----------------------------------------------------------------*
      * History Working Storage                                        *
      *----------------------------------------------------------------*
       01  WS-HISTORY.
           10 WS-HISTORY-STATUS       PIC X(1).
           10 WS-TOTAL-DEMERIT        PIC S9(5)   COMP-3.
           10 WS-ACTIVE-SUSP-FLAG     PIC X(1).
           10 WS-UNPAID-FINE-FLAG     PIC X(1).
           10 WS-HIST-FAIL-REASON     PIC X(200).

      *----------------------------------------------------------------*
      * Approval Working Storage                                       *
      *----------------------------------------------------------------*
       01  WS-APPROVAL.
           10 WS-AUTH-USER-CODE       PIC X(20).
           10 WS-AUTH-USER-NAME       PIC X(60).
           10 WS-AUTH-NAME            PIC X(50).
           10 WS-DECISION             PIC X(1).
           10 WS-DECISION-NOTES       PIC X(200).

      *----------------------------------------------------------------*
      * License Issuance Working Storage                               *
      *----------------------------------------------------------------*
       01  WS-LICENSE.
           10 WS-LICENSE-ID           PIC S9(10)  COMP-3.
           10 WS-LICENSE-NUMBER       PIC X(20).
           10 WS-VEHICLE-CLASS        PIC X(2).
           10 WS-RESTRICTIONS         PIC X(200).
           10 WS-ISSUED-BY-OFFICER    PIC X(50).
           10 WS-ISSUED-BY-AUTH       PIC X(50).
           10 WS-EXPIRY-DATE          PIC X(10).
           10 WS-YEARS-VALID          PIC S9(2)   COMP-3.
           10 WS-LIC-PREFIX           PIC X(3).

      *----------------------------------------------------------------*
      * SQL Communication Area                                         *
      *----------------------------------------------------------------*
           EXEC SQL INCLUDE SQLCA END-EXEC.

      *----------------------------------------------------------------*
      * Null Indicators                                                *
      *----------------------------------------------------------------*
       01  WS-NULL-INDICATORS.
           10 NI-ADDR2                PIC S9(4)   COMP  VALUE 0.
           10 NI-ELIG-DATE            PIC S9(4)   COMP  VALUE 0.
           10 NI-HIST-DATE            PIC S9(4)   COMP  VALUE 0.
           10 NI-PAY-REF              PIC S9(4)   COMP  VALUE 0.
           10 NI-A1-DATE              PIC S9(4)   COMP  VALUE 0.
           10 NI-A2-DATE              PIC S9(4)   COMP  VALUE 0.
           10 NI-SUSP-END             PIC S9(4)   COMP  VALUE 0.
           10 NI-EXPIRY               PIC S9(4)   COMP  VALUE 0.
           10 NI-PREV-LIC             PIC S9(4)   COMP  VALUE 0.
