      *================================================================*
      * COBOL Copybook                                                *
      * Member  : DLISCAND                                           *
      * Desc    : CANDIDATE table host variables and DCLGEN layout   *
      *================================================================*
       01  DCLDLIS-CANDIDATE.
           10 CANDIDATE-ID            PIC S9(10)  COMP-3.
           10 FIRST-NAME              PIC X(30).
           10 LAST-NAME               PIC X(30).
           10 DATE-OF-BIRTH           PIC X(10).
           10 ID-NUMBER               PIC X(20).
           10 ADDRESS-LINE-1          PIC X(50).
           10 ADDRESS-LINE-2          PIC X(50).
           10 CITY                    PIC X(30).
           10 STATE-PROVINCE          PIC X(30).
           10 POSTAL-CODE             PIC X(10).
           10 COUNTRY                 PIC X(30).
           10 PHONE-NUMBER            PIC X(15).
           10 EMAIL-ADDRESS           PIC X(60).
           10 CREATED-DATE            PIC X(10).
           10 RECORD-STATUS           PIC X(1).

      *================================================================*
      * COBOL Copybook                                                *
      * Member  : DLISAPPL                                           *
      * Desc    : LICENSE_APPLICATION table host variables            *
      *================================================================*
       01  DCLDLIS-LICENSE-APPL.
           10 APPLICATION-ID          PIC S9(10)  COMP-3.
           10 CANDIDATE-ID            PIC S9(10)  COMP-3.
           10 LICENSE-TYPE            PIC X(1).
           10 APPLICATION-DATE        PIC X(10).
           10 APPLICATION-STATUS      PIC X(2).
           10 ELIG-CHECK-STATUS       PIC X(1).
           10 ELIG-CHECK-DATE         PIC X(10).
           10 ELIG-CHECK-NOTES        PIC X(200).
           10 HIST-CHECK-STATUS       PIC X(1).
           10 HIST-CHECK-DATE         PIC X(10).
           10 HIST-CHECK-NOTES        PIC X(200).
           10 PAYMENT-STATUS          PIC X(1).
           10 PAYMENT-REFERENCE       PIC X(20).
           10 APPROVAL-1-STATUS       PIC X(1).
           10 APPROVAL-1-AUTHORITY    PIC X(50).
           10 APPROVAL-1-DATE         PIC X(10).
           10 APPROVAL-1-NOTES        PIC X(200).
           10 APPROVAL-2-STATUS       PIC X(1).
           10 APPROVAL-2-AUTHORITY    PIC X(50).
           10 APPROVAL-2-DATE         PIC X(10).
           10 APPROVAL-2-NOTES        PIC X(200).
           10 REJECTION-REASON        PIC X(300).
           10 CREATED-DATE            PIC X(10).
           10 LAST-UPDATED-DATE       PIC X(10).
           10 CREATED-BY              PIC X(20).
           10 LAST-UPDATED-BY         PIC X(20).

      *================================================================*
      * COBOL Copybook                                                *
      * Member  : DLISHIST                                           *
      * Desc    : DRIVING_HISTORY table host variables                *
      *================================================================*
       01  DCLDLIS-DRIVING-HIST.
           10 HISTORY-ID              PIC S9(10)  COMP-3.
           10 CANDIDATE-ID            PIC S9(10)  COMP-3.
           10 INCIDENT-DATE           PIC X(10).
           10 INCIDENT-TYPE           PIC X(2).
           10 INCIDENT-DESC           PIC X(300).
           10 DEMERIT-POINTS          PIC S9(3)   COMP-3.
           10 FINE-AMOUNT             PIC S9(10)V99 COMP-3.
           10 FINE-PAID-STATUS        PIC X(1).
           10 SUSP-START-DATE         PIC X(10).
           10 SUSP-END-DATE           PIC X(10).
           10 COURT-CASE-NUMBER       PIC X(20).
           10 RECORDED-BY-AUTH        PIC X(50).
           10 RECORD-STATUS           PIC X(1).

      *================================================================*
      * COBOL Copybook                                                *
      * Member  : DLISPAY                                            *
      * Desc    : PAYMENT table host variables                        *
      *================================================================*
       01  DCLDLIS-PAYMENT.
           10 PAYMENT-ID              PIC S9(10)  COMP-3.
           10 APPLICATION-ID          PIC S9(10)  COMP-3.
           10 CANDIDATE-ID            PIC S9(10)  COMP-3.
           10 PAYMENT-DATE            PIC X(10).
           10 PAYMENT-AMOUNT          PIC S9(10)V99 COMP-3.
           10 PAYMENT-METHOD          PIC X(2).
           10 PAYMENT-REFERENCE       PIC X(30).
           10 PAYMENT-STATUS          PIC X(1).
           10 LICENSE-TYPE            PIC X(1).
           10 FEE-TYPE                PIC X(2).
           10 RECEIPT-NUMBER          PIC X(20).
           10 PROCESSED-BY            PIC X(20).
           10 NOTES                   PIC X(200).

      *================================================================*
      * COBOL Copybook                                                *
      * Member  : DLISLIC                                            *
      * Desc    : ISSUED_LICENSE table host variables                 *
      *================================================================*
       01  DCLDLIS-ISSUED-LIC.
           10 LICENSE-ID              PIC S9(10)  COMP-3.
           10 APPLICATION-ID          PIC S9(10)  COMP-3.
           10 CANDIDATE-ID            PIC S9(10)  COMP-3.
           10 LICENSE-NUMBER          PIC X(20).
           10 LICENSE-TYPE            PIC X(1).
           10 ISSUE-DATE              PIC X(10).
           10 EXPIRY-DATE             PIC X(10).
           10 LICENSE-STATUS          PIC X(1).
           10 VEHICLE-CLASS           PIC X(2).
           10 RESTRICTIONS            PIC X(200).
           10 DEMERIT-BALANCE         PIC S9(3)   COMP-3.
           10 ISSUED-BY-AUTH          PIC X(50).
           10 ISSUED-BY-OFFICER       PIC X(50).
           10 RENEWAL-COUNT           PIC S9(3)   COMP-3.
           10 PREV-LICENSE-ID         PIC S9(10)  COMP-3.
           10 NOTES                   PIC X(300).

      *================================================================*
      * COBOL Copybook                                                *
      * Member  : DLISAUTH                                           *
      * Desc    : AUTHORITY_USER table host variables                 *
      *================================================================*
       01  DCLDLIS-AUTH-USER.
           10 AUTHORITY-USER-ID       PIC S9(10)  COMP-3.
           10 USER-CODE               PIC X(20).
           10 USER-NAME               PIC X(60).
           10 AUTHORITY-NAME          PIC X(50).
           10 AUTHORITY-LEVEL         PIC X(1).
           10 DEPARTMENT              PIC X(50).
           10 PHONE-NUMBER            PIC X(15).
           10 EMAIL-ADDRESS           PIC X(60).
           10 ACTIVE-STATUS           PIC X(1).
           10 LIC-TYPES-AUTH          PIC X(3).

      *================================================================*
      * COBOL Copybook                                                *
      * Member  : DLISFEE                                            *
      * Desc    : LICENSE_FEE_SCHEDULE table host variables           *
      *================================================================*
       01  DCLDLIS-FEE-SCHED.
           10 FEE-SCHEDULE-ID         PIC S9(10)  COMP-3.
           10 LICENSE-TYPE            PIC X(1).
           10 FEE-TYPE                PIC X(2).
           10 FEE-AMOUNT              PIC S9(10)V99 COMP-3.
           10 EFFECTIVE-DATE          PIC X(10).
           10 EXPIRY-DATE             PIC X(10).
           10 CURRENCY-CODE           PIC X(3).
           10 DESCRIPTION             PIC X(200).
           10 ACTIVE-STATUS           PIC X(1).
