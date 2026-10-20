      *================================================================*
      * COBOL Copybook                                                *
      * Member  : DLISCSEC                                           *
      * Desc    : CICS COMMAREA layouts for inter-program            *
      *           communication across all DLIS transactions         *
      *================================================================*

      *----------------------------------------------------------------*
      * COMMAREA - Main navigation commarea                            *
      *----------------------------------------------------------------*
       01  DLIS-COMMAREA.
           10 CA-TRANSACTION-ID       PIC X(4).
           10 CA-RETURN-SCREEN        PIC X(8).
           10 CA-CANDIDATE-ID         PIC S9(10)  COMP-3.
           10 CA-APPLICATION-ID       PIC S9(10)  COMP-3.
           10 CA-LICENSE-ID           PIC S9(10)  COMP-3.
           10 CA-PAYMENT-ID           PIC S9(10)  COMP-3.
           10 CA-USER-ID              PIC X(8).
           10 CA-RETURN-CODE          PIC S9(4)   COMP.
           10 CA-MSG-TEXT             PIC X(78).
           10 CA-MSG-COLOR            PIC X(5).
           10 CA-ACTION               PIC X(1).

      *----------------------------------------------------------------*
      * COMMAREA - Candidate screen data                               *
      *----------------------------------------------------------------*
       01  DLIS-CAND-COMMAREA.
           10 CA-CAND-ID              PIC S9(10)  COMP-3.
           10 CA-FIRST-NAME           PIC X(30).
           10 CA-LAST-NAME            PIC X(30).
           10 CA-DATE-OF-BIRTH        PIC X(10).
           10 CA-ID-NUMBER            PIC X(20).
           10 CA-ADDRESS-LINE-1       PIC X(50).
           10 CA-ADDRESS-LINE-2       PIC X(50).
           10 CA-CITY                 PIC X(30).
           10 CA-STATE-PROVINCE       PIC X(30).
           10 CA-POSTAL-CODE          PIC X(10).
           10 CA-COUNTRY              PIC X(30).
           10 CA-PHONE-NUMBER         PIC X(15).
           10 CA-EMAIL-ADDRESS        PIC X(60).
           10 CA-RECORD-STATUS        PIC X(1).

      *----------------------------------------------------------------*
      * COMMAREA - Application status data                             *
      *----------------------------------------------------------------*
       01  DLIS-APPL-COMMAREA.
           10 CA-APPLICATION-ID       PIC S9(10)  COMP-3.
           10 CA-CANDIDATE-ID         PIC S9(10)  COMP-3.
           10 CA-LICENSE-TYPE         PIC X(1).
           10 CA-APP-STATUS           PIC X(2).
           10 CA-APP-STATUS-DESC      PIC X(50).
           10 CA-ELIG-STATUS          PIC X(1).
           10 CA-HIST-STATUS          PIC X(1).
           10 CA-PAY-STATUS           PIC X(1).
           10 CA-APP1-STATUS          PIC X(1).
           10 CA-APP2-STATUS          PIC X(1).
           10 CA-LICENSE-NUMBER       PIC X(20).

      *----------------------------------------------------------------*
      * CICS ABEND / Response codes working storage                    *
      *----------------------------------------------------------------*
       01  WS-CICS-RESPONSE.
           10 WS-RESP1                PIC S9(8)   COMP  VALUE 0.
           10 WS-RESP2                PIC S9(8)   COMP  VALUE 0.
           10 WS-EIBRESP-SAVE         PIC S9(8)   COMP  VALUE 0.
           10 WS-EIBCALEN-SAVE        PIC S9(8)   COMP  VALUE 0.
