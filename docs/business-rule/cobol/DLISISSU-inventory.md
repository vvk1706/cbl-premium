# Business rules: Inventory

**Program:** DLISISSU

**Total rules extracted:** 11

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Rule Inventory](#2-rule-inventory)
  - [2.1 Paragraph: PROCESS-INPUT](#21-paragraph-process-input)
  - [2.2 Paragraph: MAIN-LOGIC](#22-paragraph-main-logic)
  - [2.3 Paragraph: LOAD-APPLICATION](#23-paragraph-load-application)
  - [2.4 Paragraph: ISSUE-LICENSE](#24-paragraph-issue-license)
  - [2.5 Paragraph: PRINT-LICENSE](#25-paragraph-print-license)

## 1. Purpose

This document is an inventory of all business rules extracted from DLISISSU, organised at the Paragraph level. Each Paragraph contributes one or more named rule blocks, where each block captures a discrete business policy with its title, decision logic, conditions, actions, outcomes, and the exact source code that realises it. Key variables, when available, are annotated with their role (input or output) and their specific purpose within the rule. References to related Paragraphs called or invoked by each rule are also recorded.

## 2. Rule Inventory

### 2.1 Paragraph: PROCESS-INPUT

#### 2.1.1 Function Key Routing for License Issuance Workflow

**Description:** Routes the officer's action to the appropriate business function based on the function key pressed: F1 triggers license issuance, F3 loads an application, F6 prints the license, F12 exits the transaction, and any other key displays a guidance message enforcing the allowed interaction model.

**Core decision logic:**
- F1 invokes the license issuance process
- F3 invokes the application loading process
- F6 invokes the license printing process
- F12 terminates the transaction
- Any unrecognised key results in a user guidance message restricting actions to the defined function keys

**Code:**
```cobol
           EVALUATE TRUE
               WHEN EIBAID = DFHPF1   PERFORM ISSUE-LICENSE
               WHEN EIBAID = DFHPF3   PERFORM LOAD-APPLICATION
               WHEN EIBAID = DFHPF6   PERFORM PRINT-LICENSE
               WHEN EIBAID = DFHPF12  EXEC CICS RETURN END-EXEC
               OTHER
                   MOVE 'USE F1 F3 F6 OR F12' TO DLIMSG
           END-EVALUATE
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `DLIS-COMMAREA` | output | Passed back to CICS via EXEC CICS RETURN to maintain transaction state across the license issuance workflow after the selected business action is performed. |

**Paragraphs:**

* ISSUE-LICENSE
* LOAD-APPLICATION
* PRINT-LICENSE
### 2.2 Paragraph: MAIN-LOGIC

#### 2.2.1 First-Entry vs. Returning Transaction Routing

**Description:** Determines whether the transaction is being entered for the first time or returning with an existing communication area. On first entry (no commarea), the screen is initialised for the officer. On a subsequent entry, the saved commarea is restored and user input is processed, preserving state across the license issuance workflow.

**Core decision logic:**
- If EIBCALEN is zero, this is a fresh transaction entry and the screen must be initialised
- If EIBCALEN is non-zero, the commarea from the previous transaction cycle is restored and input processing proceeds

**Code:**
```cobol
           IF EIBCALEN = 0
               PERFORM INIT-SCREEN
           ELSE
               MOVE DFHCOMMAREA TO DLIS-COMMAREA
               PERFORM PROCESS-INPUT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `DLIS-COMMAREA` | output | Populated from DFHCOMMAREA when returning to the transaction, restoring the prior workflow state before input processing begins. |

**Paragraphs:**

* INIT-SCREEN
* PROCESS-INPUT
### 2.3 Paragraph: LOAD-APPLICATION

#### 2.3.1 Application ID Presence Validation

**Description:** Enforces that an Application ID must be provided before any application can be loaded. If the field is blank or zero, the officer is prompted to enter it and further processing is halted.

**Core decision logic:**
- An Application ID is mandatory before an application can be loaded; absence halts the process

**Code:**
```cobol
           IF DLIAIDI = ZEROS
               MOVE 'ENTER APPLICATION ID' TO DLIMSG
               GO TO LOAD-APP-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `APPLICATION-ID` | input | The field being validated for presence; the process is blocked if no Application ID has been entered. |

#### 2.3.2 Display Application Eligibility Gate Statuses to Officer

**Description:** Presents the full set of pre-issuance eligibility gate statuses — license type, eligibility check, history check, payment, and both approval levels — on the CICS map so that the issuing officer can assess whether all mandatory conditions are satisfied before proceeding to issue the license.

**Core decision logic:**
- The candidate's full name, license type, eligibility check status, history check status, payment status, first-level approval status, and second-level approval status must all be visible to the officer before issuance
- A successful load is confirmed by setting the message to 'APPLICATION LOADED', which downstream logic (ISSUE-LICENSE) checks as a gate condition

**Code:**
```cobol
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
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `LICENSE-TYPE` | input | Displayed on the map to inform the officer of the classification of the license application being reviewed. |
| `ELIG-CHECK-STATUS` | input | Displayed on the map as one of the mandatory eligibility gate statuses the officer must review before issuing a license. |
| `HIST-CHECK-STATUS` | input | Displayed on the map to show whether the driving history background check has been satisfied as a pre-issuance gate. |
| `PAYMENT-STATUS` | input | Displayed on the map to indicate whether the required fees have been settled as part of the pre-issuance eligibility gates. |
| `APPROVAL-1-STATUS` | input | Displayed on the map to show the first-level approval gate status within the dual-approval workflow. |
| `APPROVAL-2-STATUS` | input | Displayed on the map to show the second-level approval gate status within the dual-approval workflow. |

### 2.4 Paragraph: ISSUE-LICENSE

#### 2.4.1 Mandatory Input Field Validation for License Issuance

**Description:** Enforces that all mandatory inputs required to issue a license are present and valid before proceeding: the Application ID must be supplied, the vehicle class must be one of the permitted values (A, B, C, or D), the issuing officer must be identified, and the issuing authority must be provided. Failure on any gate halts the issuance with a descriptive message.

**Core decision logic:**
- Application ID is mandatory; absence blocks issuance
- Vehicle class must be one of the four permitted values A, B, C, or D; any other value or blank blocks issuance
- Issuing officer identity is mandatory; absence blocks issuance
- Issuing authority identity is mandatory; absence blocks issuance

**Code:**
```cobol
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
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `APPLICATION-ID` | input | Validated for presence; the issuance process is blocked if no Application ID has been entered. |
| `VEHICLE-CLASS` | input | Validated against the permitted set of vehicle classes (A, B, C, D); an invalid or missing value blocks issuance. |
| `ISSUED-BY-OFFICER` | input | Validated for presence to ensure accountability for the issuance action is recorded. |
| `ISSUED-BY-AUTH` | input | Validated for presence to ensure the issuing authority is identified before the license can be created. |

#### 2.4.2 Application Status Eligibility Gate Before License Issuance

**Description:** Enforces that a license can only be issued when the application has reached the fully-approved status ('AP'). Any application that has not attained this status is ineligible for issuance, blocking the process and informing the officer.

**Core decision logic:**
- The application status must be 'AP' (Approved) for license issuance to proceed; any other status is a disqualifying condition

**Code:**
```cobol
      *    All five gates must be fully satisfied
           IF APPLICATION-STATUS OF DCLDLIS-LICENSE-APPL NOT = 'AP'
               MOVE 'APPLICATION STATUS MUST BE AP BEFORE ISSUE'
                   TO DLIMSG
               GO TO ISSUE-LIC-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `APPLICATION-STATUS` | input | Checked against the required 'AP' value to enforce that only fully-approved applications can proceed to license issuance. |

#### 2.4.3 License Expiry Date Calculation and Prefix Assignment by License Type

**Description:** Calculates the expiry date and assigns the license number prefix based on license type: Learner licenses expire in 1 year with prefix 'LRN', Probationary licenses expire in 2 years with prefix 'PRB', and Open/Full licenses expire in 5 years with prefix 'OPN'. The expiry date is assembled by combining the computed year with the current month and day.

**Core decision logic:**
- Learner ('L') licenses have a validity period of 1 year and carry the prefix 'LRN'
- Probationary ('P') licenses have a validity period of 2 years and carry the prefix 'PRB'
- Open/Full ('O') licenses have a validity period of 5 years and carry the prefix 'OPN'
- Expiry date is constructed by appending the current month and day to the calculated expiry year

**Code:**
```cobol
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
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `LICENSE-TYPE` | input | Drives the selection of validity period and license number prefix; each type maps to a distinct expiry duration and prefix code. |
| `WS-EXPIRY-DATE` | output | Receives the fully assembled expiry date constructed from the calculated expiry year and current month/day. |

#### 2.4.4 License Number Generation

**Description:** Constructs a unique license number by concatenating the license type prefix, vehicle class, candidate identifier, and application identifier. This number serves as the definitive identifier for the issued license.

**Core decision logic:**
- The license number is composed of four parts: the license type prefix, vehicle class, candidate ID, and application ID in sequence
- Each component contributes to uniqueness and encodes key attributes of the license and its holder

**Code:**
```cobol
      *    Generate license number
           STRING WS-LIC-PREFIX DLIVCLSI
                  CANDIDATE-ID OF DCLDLIS-LICENSE-APPL
                  APPLICATION-ID OF DCLDLIS-LICENSE-APPL
               INTO WS-LICENSE-NUMBER
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CANDIDATE-ID` | input | Incorporated into the generated license number to associate the license with the specific candidate. |
| `APPLICATION-ID` | input | Incorporated into the generated license number to tie it back to the originating application record. |
| `VEHICLE-CLASS` | input | Incorporated into the generated license number to encode the vehicle classification into the license identifier. |
| `WS-LICENSE-NUMBER` | output | Receives the fully assembled unique license number constructed from the prefix, vehicle class, candidate ID, and application ID. |

#### 2.4.5 Insert Issued License Record into Database

**Description:** Creates the official issued license domain record in DLIS.ISSUED_LICENSE, capturing all defining attributes: the linked application and candidate, the generated license number, license type, issue and expiry dates, an initial active status ('A'), vehicle class, any restrictions, a starting demerit balance of 12, and the issuing officer and authority. This is the core business event that formally brings the license into existence.

**Core decision logic:**
- The license is created with an initial status of 'A' (Active)
- The demerit balance is initialised to 12 at the point of issuance
- All key issuance attributes — officer, authority, vehicle class, restrictions, expiry date, and license number — are permanently recorded against the issued license

**Code:**
```cobol
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
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `APPLICATION-ID` | input | Inserted as a foreign key linking the issued license back to the originating application record. |
| `CANDIDATE-ID` | input | Inserted to associate the issued license with the correct candidate individual. |
| `WS-LICENSE-NUMBER` | input | Inserted as the unique identifier of the newly issued license. |
| `LICENSE-TYPE` | input | Inserted to record the classification of the issued license (Learner, Probationary, or Open). |
| `WS-EXPIRY-DATE` | input | Inserted as the computed expiry date determining when the issued license ceases to be valid. |
| `VEHICLE-CLASS` | input | Inserted to record the vehicle classification for which the license is authorised. |
| `ISSUED-BY-OFFICER` | input | Inserted to record the officer who authorised and issued the license for accountability purposes. |
| `ISSUED-BY-AUTH` | input | Inserted to record the issuing authority organisation responsible for the license. |

#### 2.4.6 Update Application Status to Issued

**Description:** Marks the license application as issued ('IS') in the LICENSE_APPLICATION table, recording the date and the officer responsible for the update. Simultaneously, the generated license number and expiry date are displayed on the CICS map and a success confirmation message is set, completing the license issuance business event.

**Core decision logic:**
- The application status is transitioned to 'IS' (Issued) upon successful license creation, closing the application workflow
- The issuing officer is recorded as the last updater on the application record for audit purposes
- The generated license number and expiry date are presented to the officer to confirm the outcome

**Code:**
```cobol
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
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `APPLICATION-ID` | input | Used as the WHERE clause key to identify which application record must be updated to 'IS' status. |
| `APPLICATION-STATUS` | output | Updated to 'IS' to formally mark the application as having resulted in an issued license. |
| `WS-LICENSE-NUMBER` | input | Moved to the map output field to display the newly issued license number to the officer. |
| `WS-EXPIRY-DATE` | input | Moved to the map output field to display the expiry date of the newly issued license to the officer. |

### 2.5 Paragraph: PRINT-LICENSE

#### 2.5.1 License Print Eligibility Gate and Print Invocation

**Description:** Enforces that a license must have been successfully issued (indicated by the presence of a license number on screen) before it can be printed. If this gate is passed, the print program DLISLPRT is invoked via CICS LINK with the current commarea, and a confirmation message is set.

**Core decision logic:**
- Printing is blocked if no license number is present on the screen, enforcing the business rule that issuance must precede printing
- Upon successful gate passage, the license print program is invoked to produce the physical or electronic license document

**Code:**
```cobol
           IF DLIILNUMO = SPACES
               MOVE 'ISSUE LICENSE FIRST BEFORE PRINTING' TO DLIMSG
               GO TO PRINT-LIC-EXIT
           END-IF
           EXEC CICS LINK PROGRAM('DLISLPRT')
               COMMAREA(DLIS-COMMAREA) LENGTH(350)
           END-EXEC
           MOVE 'LICENSE SENT TO PRINTER' TO DLIMSG.
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `DLIS-COMMAREA` | input | Passed to the DLISLPRT print program via CICS LINK to provide the full license issuance context needed for printing. |

---

Generated by IBM Bob Premium Package for Z
