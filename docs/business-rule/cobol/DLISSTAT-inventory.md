# Business rules: Inventory

**Program:** DLISSTAT

**Total rules extracted:** 8

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Rule Inventory](#2-rule-inventory)
  - [2.1 Paragraph: MAIN-LOGIC](#21-paragraph-main-logic)
  - [2.2 Paragraph: PROCESS-INPUT](#22-paragraph-process-input)
  - [2.3 Paragraph: INQUIRE-STATUS](#23-paragraph-inquire-status)

## 1. Purpose

This document is an inventory of all business rules extracted from DLISSTAT, organised at the Paragraph level. Each Paragraph contributes one or more named rule blocks, where each block captures a discrete business policy with its title, decision logic, conditions, actions, outcomes, and the exact source code that realises it. Key variables, when available, are annotated with their role (input or output) and their specific purpose within the rule. References to related Paragraphs called or invoked by each rule are also recorded.

## 2. Rule Inventory

### 2.1 Paragraph: MAIN-LOGIC

#### 2.1.1 Initial Screen vs. Returning User Routing

**Description:** Determines whether this is the first time the user has accessed the status inquiry transaction or a returning interaction. On first access, the screen is initialized; on subsequent interactions, the user's input is processed.

**Core decision logic:**
- If the communication area length is zero, this is a new session and the screen must be initialized
- If the communication area has data, the user has returned with input and processing must proceed

**Code:**
```cobol
           IF EIBCALEN = 0
               PERFORM INIT-SCREEN
           ELSE
               MOVE DFHCOMMAREA TO DLIS-COMMAREA
               PERFORM PROCESS-INPUT
           END-IF
```

**Paragraphs:**

* INIT-SCREEN
* PROCESS-INPUT
### 2.2 Paragraph: PROCESS-INPUT

#### 2.2.1 User Action Routing for Status Inquiry

**Description:** Routes the user's action based on which key was pressed. Pressing ENTER triggers the application status inquiry, pressing F12 exits the transaction, and any other key results in a guidance message instructing the user on valid actions.

**Core decision logic:**
- ENTER key triggers the status inquiry process
- F12 key causes an immediate exit from the transaction
- Any other key press results in a user guidance message rather than performing any action

**Code:**
```cobol
           EVALUATE TRUE
               WHEN EIBAID = DFHENTER  PERFORM INQUIRE-STATUS
               WHEN EIBAID = DFHPF12   EXEC CICS RETURN END-EXEC
               OTHER
                   MOVE 'PRESS ENTER TO INQUIRE OR F12 TO EXIT'
                       TO DSTMSG
           END-EVALUATE
```

**Paragraphs:**

* INQUIRE-STATUS
### 2.3 Paragraph: INQUIRE-STATUS

#### 2.3.1 Application ID Presence Validation

**Description:** Enforces that the user must supply an Application ID before a status inquiry can be performed. If no ID is provided, the user is prompted to enter one and further processing is halted.

**Core decision logic:**
- An Application ID is mandatory to perform a status inquiry; processing cannot continue without it

**Code:**
```cobol
           IF DSTAIDI = ZEROS
               MOVE 'ENTER APPLICATION ID' TO DSTMSG
               GO TO INQUIRE-EXIT
           END-IF
```

#### 2.3.2 License Application Status Data Retrieval

**Description:** Retrieves the complete workflow status record for a license application identified by the user-supplied Application ID. This covers all processing stages including eligibility check, history check, payment, and both approval authorities.

**Core decision logic:**
- The Application ID entered by the user is the sole search key for retrieving the application record
- All processing stage statuses, dates, notes, and authority details are retrieved in a single query to present a comprehensive application status

**Code:**
```cobol
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
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `APPLICATION-ID` | input | Used as the WHERE clause search key to identify which license application record to retrieve from the database |
| `LICENSE-TYPE` | output | Receives the classification of the license being applied for from the database query result |
| `APPLICATION-STATUS` | output | Receives the current workflow status code of the license application from the database query result |
| `ELIG-CHECK-STATUS` | output | Receives the result status of the eligibility verification stage from the database query result |
| `ELIG-CHECK-DATE` | output | Receives the date on which the eligibility verification was performed from the database query result |
| `HIST-CHECK-STATUS` | output | Receives the result status of the applicant history verification stage from the database query result |
| `HIST-CHECK-DATE` | output | Receives the date on which the history verification was performed from the database query result |
| `PAYMENT-STATUS` | output | Receives the fee payment status for the application from the database query result |
| `PAYMENT-REFERENCE` | output | Receives the payment reference identifier for the application from the database query result |
| `APPROVAL-1-STATUS` | output | Receives the first authority approval decision status from the database query result |
| `APPROVAL-1-AUTHORITY` | output | Receives the identity of the first approval authority from the database query result |
| `APPROVAL-2-STATUS` | output | Receives the second authority approval decision status from the database query result |
| `APPROVAL-2-AUTHORITY` | output | Receives the identity of the second approval authority from the database query result |

#### 2.3.3 Application Not Found Handling

**Description:** Enforces that a status inquiry can only proceed when the supplied Application ID matches an existing record. If no matching application is found, the user is informed and further processing is halted.

**Core decision logic:**
- If the database returns no row for the given Application ID, the inquiry is terminated with an informative message

**Code:**
```cobol
           IF SQLCODE = 100
               MOVE 'APPLICATION NOT FOUND' TO DSTMSG
               GO TO INQUIRE-EXIT
           END-IF
```

#### 2.3.4 Human-Readable Application Status Description

**Description:** Translates the internal application status code into a human-readable description that reflects the application's current position in the licensing workflow. Each code maps to a specific stage in the lifecycle from pending through to issued or rejected.

**Core decision logic:**
- PE indicates the application is pending and awaiting the eligibility check stage
- EC indicates eligibility has been checked and the application is awaiting history verification
- HC indicates history has been checked and the application is awaiting payment
- PA indicates payment is approved and the application is awaiting first authority approval
- A2 indicates the application is awaiting second authority approval
- AP indicates the application is fully approved and ready for license issuance
- IS indicates the license has been issued
- RE indicates the application has been rejected
- Any unrecognised status code is described as unknown

**Code:**
```cobol
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
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `APPLICATION-STATUS` | input | The status code read from the application record that is evaluated to determine which human-readable description to display |

#### 2.3.5 Display of All Application Processing Stage Details

**Description:** Populates the status inquiry screen with the detailed results of each processing stage of the license application workflow: eligibility check, history check, payment, and both authority approvals, including their statuses, dates, notes, references, and approver identities.

**Core decision logic:**
- All workflow stage details — eligibility, history, payment, and both approvals — are presented together on the inquiry screen to give a complete picture of the application's processing history

**Code:**
```cobol
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
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `ELIG-CHECK-STATUS` | input | The eligibility check result status moved to the screen output field for display |
| `ELIG-CHECK-DATE` | input | The date the eligibility check was performed, moved to the screen output field for display |
| `HIST-CHECK-STATUS` | input | The history check result status moved to the screen output field for display |
| `HIST-CHECK-DATE` | input | The date the history check was performed, moved to the screen output field for display |
| `PAYMENT-STATUS` | input | The payment stage status moved to the screen output field for display |
| `PAYMENT-REFERENCE` | input | The payment reference identifier moved to the screen output field so the payment can be traced |
| `APPROVAL-1-STATUS` | input | The first authority approval decision status moved to the screen output field for display |
| `APPROVAL-1-AUTHORITY` | input | The identity of the first approval authority moved to the screen output field for display |
| `APPROVAL-2-STATUS` | input | The second authority approval decision status moved to the screen output field for display |
| `APPROVAL-2-AUTHORITY` | input | The identity of the second approval authority moved to the screen output field for display |

#### 2.3.6 Issued License Details Retrieval and Display

**Description:** When the application status indicates a license has been issued ('IS'), retrieves the issued license number and expiry date and presents them on the inquiry screen. For applications not yet at the issued stage, the issued license section is flagged as not applicable.

**Core decision logic:**
- Issued license details (license number and expiry date) are only retrieved and displayed when the application status is 'IS' (license issued)
- The issued license flag is set to 'YES' only when the issued license record is successfully found in the database
- For applications that have not reached the issued status, the issued license flag is set to 'NO' indicating no issued license exists

**Code:**
```cobol
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
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `APPLICATION-STATUS` | input | Checked to determine whether the application has reached the issued stage, gating the retrieval of issued license details |
| `APPLICATION-ID` | input | Used as the WHERE clause search key to retrieve the issued license record matching the application |
| `LICENSE-NUMBER` | output | Receives the assigned license number from the issued license table and is moved to the screen display field |
| `EXPIRY-DATE` | output | Receives the license expiry date from the issued license table and is moved to the screen display field |

---

Generated by IBM Bob Premium Package for Z
