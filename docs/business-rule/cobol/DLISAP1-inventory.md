# Business rules: Inventory

**Program:** DLISAP1

**Total rules extracted:** 16

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Rule Inventory](#2-rule-inventory)
  - [2.1 Paragraph: PROCESS-INPUT](#21-paragraph-process-input)
  - [2.2 Paragraph: MAIN-LOGIC](#22-paragraph-main-logic)
  - [2.3 Paragraph: LOAD-APPLICATION](#23-paragraph-load-application)
  - [2.4 Paragraph: VALIDATE-AUTHORITY](#24-paragraph-validate-authority)
  - [2.5 Paragraph: SUBMIT-APPROVAL1](#25-paragraph-submit-approval1)

## 1. Purpose

This document is an inventory of all business rules extracted from DLISAP1, organised at the Paragraph level. Each Paragraph contributes one or more named rule blocks, where each block captures a discrete business policy with its title, decision logic, conditions, actions, outcomes, and the exact source code that realises it. Key variables, when available, are annotated with their role (input or output) and their specific purpose within the rule. References to related Paragraphs called or invoked by each rule are also recorded.

## 2. Rule Inventory

### 2.1 Paragraph: PROCESS-INPUT

#### 2.1.1 Function Key Routing to Business Actions

**Description:** Routes the user's function key press to the appropriate business action: F1 submits the first approval, F3 loads an application, F4 validates the authority user, F12 exits the transaction, and any other key produces an instructional message.

**Core decision logic:**
- F1 triggers the first approval submission workflow
- F3 triggers loading of an application record
- F4 triggers authority user validation
- F12 exits the transaction immediately
- Any unrecognised key results in a guidance message rather than an action

**Code:**
```cobol
           EVALUATE TRUE
               WHEN EIBAID = DFHPF1   PERFORM SUBMIT-APPROVAL1
               WHEN EIBAID = DFHPF3   PERFORM LOAD-APPLICATION
               WHEN EIBAID = DFHPF4   PERFORM VALIDATE-AUTHORITY
               WHEN EIBAID = DFHPF12  EXEC CICS RETURN END-EXEC
               OTHER
                   MOVE 'USE F1 F3 F4 OR F12' TO DA1MSG
           END-EVALUATE
```

**Paragraphs:**

* SUBMIT-APPROVAL1
* LOAD-APPLICATION
* VALIDATE-AUTHORITY
### 2.2 Paragraph: MAIN-LOGIC

#### 2.2.1 New Session vs. Returning Session Routing

**Description:** Determines whether the transaction is being started for the first time (no commarea) or is a returning interaction. On first entry the screen is initialised; on subsequent entries the saved commarea is restored and user input is processed.

**Core decision logic:**
- A commarea length of zero means a fresh session — initialise the screen
- A non-zero commarea length means a returning session — restore state and process the user's input

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
### 2.3 Paragraph: LOAD-APPLICATION

#### 2.3.1 Application ID Presence Validation

**Description:** Enforces that an Application ID must be supplied before an application can be loaded. If the field is blank or zero, the user is prompted and processing stops.

**Core decision logic:**
- An Application ID of zero is treated as absent — the user must supply a valid value before proceeding

**Code:**
```cobol
           IF DA1AIDI = ZEROS
               MOVE 'ENTER APPLICATION ID' TO DA1MSG
               GO TO LOAD-APP-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `APPLICATION-ID` | input | The value entered by the user that must be non-zero for application retrieval to proceed |

#### 2.3.2 Retrieve Application and Candidate Details

**Description:** Retrieves the full set of business details for a license application — including its type, lifecycle status, eligibility and history check results, payment information, and the candidate's name — by joining the license application and candidate tables on the supplied Application ID.

**Core decision logic:**
- Application details are fetched using the user-supplied Application ID as the lookup key
- The candidate's name is resolved by joining the candidate table to the application record

**Code:**
```cobol
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
               JOIN   DLIS.CANDIDATE C ON A.CANDIDATE_ID = C.CANDIDATE_I        
               WHERE  A.APPLICATION_ID = :APPLICATION-ID
                                         OF DCLDLIS-LICENSE-APPL
           END-EXEC
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `APPLICATION-ID` | input | Used as the WHERE clause key to identify the specific application record to retrieve |
| `APPLICATION-STATUS` | output | Receives the current lifecycle status of the application from the database |
| `LICENSE-TYPE` | output | Receives the category of license applied for from the database |
| `PAYMENT-STATUS` | output | Receives the payment completion status of the application from the database |
| `PAYMENT-REFERENCE` | output | Receives the payment reference identifier from the database for display |
| `ELIG-CHECK-STATUS` | output | Receives the eligibility check result from the database for display to the approver |
| `HIST-CHECK-STATUS` | output | Receives the history check result from the database for display to the approver |
| `FIRST-NAME` | output | Receives the candidate's given name from the candidate table for display |
| `LAST-NAME` | output | Receives the candidate's family name from the candidate table for display |

#### 2.3.3 Application Not Found Guard

**Description:** Detects when the supplied Application ID does not match any record in the database and informs the user, preventing further processing on a non-existent application.

**Core decision logic:**
- If the database returns no rows for the given Application ID the load operation is aborted with a descriptive message

**Code:**
```cobol
           IF SQLCODE = 100
               MOVE 'APPLICATION NOT FOUND' TO DA1MSG
               GO TO LOAD-APP-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `APPLICATION-ID` | input | The key that was used in the query; its absence in the result set triggers the not-found message |

#### 2.3.4 Populate Screen with Application Business Data

**Description:** Presents all retrieved application and candidate information on the screen for the approving authority to review, including the candidate's full name, license type, application status, eligibility and history check outcomes, and payment details.

**Core decision logic:**
- The candidate's first and last names are combined into a single display field
- All key business attributes of the application are surfaced to support the approver's decision

**Code:**
```cobol
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
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `FIRST-NAME` | input | Combined with the last name to form the candidate's full name for screen display |
| `LAST-NAME` | input | Combined with the first name to form the candidate's full name for screen display |
| `LICENSE-TYPE` | input | Displayed to show the category of license being applied for |
| `APPLICATION-STATUS` | input | Displayed to show the current lifecycle status of the application |
| `ELIG-CHECK-STATUS` | input | Displayed as supporting information for the approver's eligibility assessment |
| `HIST-CHECK-STATUS` | input | Displayed as supporting information for the approver's history assessment |
| `PAYMENT-STATUS` | input | Displayed to confirm whether payment has been completed |
| `PAYMENT-REFERENCE` | input | Displayed so the approver can trace the associated payment transaction |

### 2.4 Paragraph: VALIDATE-AUTHORITY

#### 2.4.1 Authority User Code Presence Validation

**Description:** Enforces that an authority user code must be provided before validation can proceed. If the field is blank, the user is prompted and processing stops.

**Core decision logic:**
- A blank authority user code is treated as absent — the user must supply a value before authority validation can proceed

**Code:**
```cobol
           IF DA1AUCOI = SPACES
               MOVE 'ENTER AUTHORITY USER CODE' TO DA1MSG
               GO TO VALIDATE-AUTH-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `USER-CODE` | input | The value checked for presence; if blank, validation is refused |

#### 2.4.2 Lookup Active Level-1 Authority User

**Description:** Retrieves the authority user's details from the database, enforcing that the user must be active and hold authority level 1. Only users meeting both criteria are returned, making this the primary eligibility gate for first-approval rights.

**Core decision logic:**
- Only authority users with an active status of 'A' are permitted to perform first approvals
- Only authority users at level '1' are eligible for first approval — users at other levels are rejected
- The lookup retrieves the user's name, authority name, and permitted license types for subsequent checks

**Code:**
```cobol
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
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `USER-CODE` | input | Used as the primary lookup key to identify the authority user in the database |
| `USER-NAME` | output | Receives the authority user's display name from the database |
| `AUTHORITY-NAME` | output | Receives the authority's formal name from the database for display and recording |
| `AUTHORITY-LEVEL` | output | Receives the authority tier; the query constrains this to '1' so only level-1 approvers are returned |
| `LIC-TYPES-AUTH` | output | Receives the list of license types the authority is permitted to approve, used in subsequent authorization checks |

#### 2.4.3 Authority User Not Found or Ineligible Guard

**Description:** Detects when the supplied user code does not correspond to an active level-1 authority user and informs the operator, preventing the approval from proceeding with an unqualified user.

**Core decision logic:**
- If no active level-1 authority user is found for the given code, validation fails and the approval is blocked

**Code:**
```cobol
           IF SQLCODE = 100
               MOVE 'AUTHORITY USER NOT FOUND OR NOT ACTIVE AT LEVEL 1'
                   TO DA1MSG
               GO TO VALIDATE-AUTH-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `USER-CODE` | input | The code that was used in the failed lookup, whose absence from results triggers the ineligibility message |

#### 2.4.4 Display Validated Authority User on Screen

**Description:** Presents the validated authority user's name and authority name on the screen to confirm to the operator which approver has been recognised and accepted.

**Core decision logic:**
- The authority user's name and authority name are shown on screen upon successful validation to confirm the approver's identity

**Code:**
```cobol
           MOVE USER-NAME      OF DCLDLIS-AUTH-USER TO DA1AUNMO
           MOVE AUTHORITY-NAME OF DCLDLIS-AUTH-USER TO DA1AUNMO
           MOVE 'AUTHORITY USER VALIDATED' TO DA1MSG.
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `USER-NAME` | input | Displayed on screen to identify the validated approver by name |
| `AUTHORITY-NAME` | input | Displayed on screen to confirm the authority designation of the validated approver |

### 2.5 Paragraph: SUBMIT-APPROVAL1

#### 2.5.1 Mandatory Input Validation Before Approval Submission

**Description:** Enforces that all three mandatory business inputs — Application ID, authority user code, and a valid decision — must be present and valid before the first approval can be submitted. Only 'A' (approve) or 'R' (reject) are accepted as decisions.

**Core decision logic:**
- Application ID must be non-zero to proceed
- Authority user code must be non-blank to proceed
- Decision must be explicitly 'A' (approve) or 'R' (reject) — blank or any other value is rejected

**Code:**
```cobol
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
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `APPLICATION-ID` | input | Must be non-zero to confirm the target application has been identified |
| `USER-CODE` | input | Must be non-blank to confirm that an authority user has been identified for the approval |
| `WS-DECISION` | input | Must be 'A' or 'R' to represent a valid first-approval decision |

#### 2.5.2 Payment Completion Gate for First Approval

**Description:** Enforces the business rule that payment must be fully completed before a first approval can be recorded. If the payment status is not 'P' (paid), the approval submission is blocked.

**Core decision logic:**
- Payment status must be 'P' (paid) before the first approval is permitted — any other payment status blocks the approval

**Code:**
```cobol
           IF PAYMENT-STATUS OF DCLDLIS-LICENSE-APPL NOT = 'P'
               MOVE 'PAYMENT MUST BE COMPLETED BEFORE FIRST APPROVAL'
                   TO DA1MSG
               GO TO SUBMIT-A1-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `PAYMENT-STATUS` | input | Acts as a business gate — must equal 'P' for the first approval to be allowed to proceed |

#### 2.5.3 License Type Authorization Check for Authority

**Description:** Verifies that the validated authority user is permitted to approve the specific license type of the application. If the application's license type is not within the authority's authorised list, the approval is refused.

**Core decision logic:**
- The authority user must be explicitly authorized for the application's license type — approval is blocked if the license type is outside their permitted scope

**Code:**
```cobol
      *    Check license type authorisation
           IF DA1LTYO NOT IN LIC-TYPES-AUTH OF DCLDLIS-AUTH-USER
               MOVE 'AUTHORITY NOT AUTHORISED FOR THIS LICENSE TYPE'
                   TO DA1MSG
               GO TO SUBMIT-A1-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `LIC-TYPES-AUTH` | input | Contains the list of license types the authority is permitted to approve; the application's type must be found within this list |
| `LICENSE-TYPE` | input | The application's license category that is checked against the authority's permitted license types |

#### 2.5.4 Determine New Application Status from Decision

**Description:** Translates the first authority's decision into the new application lifecycle status. An approval decision advances the application to 'A2' (forwarded for second approval), while a rejection sets it to 'RE' (rejected).

**Core decision logic:**
- A decision of 'A' (approve) advances the application status to 'A2' — forwarded for second approval
- A decision of 'R' (reject) sets the application status to 'RE' — application closed as rejected

**Code:**
```cobol
           MOVE DA1DECI TO WS-DECISION
           IF WS-DECISION = 'A'
               MOVE 'A2' TO APPLICATION-STATUS OF DCLDLIS-LICENSE-APPL
           ELSE
               MOVE 'RE' TO APPLICATION-STATUS OF DCLDLIS-LICENSE-APPL
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `WS-DECISION` | input | Holds the first authority's decision ('A' or 'R') that determines which new application status is applied |
| `APPLICATION-STATUS` | output | Receives the new lifecycle status derived from the approval decision — 'A2' for approval or 'RE' for rejection |

#### 2.5.5 Persist First Approval Decision to Database

**Description:** Records the first approval decision permanently in the license application database record, capturing the approval status, the authority who made the decision, the date, any decision notes, the updated application lifecycle status, and the audit trail of who last updated the record.

**Core decision logic:**
- The first approval status, authority name, date, and notes are recorded against the application
- The application's lifecycle status is updated to reflect the approval or rejection outcome
- The last-updated audit fields are stamped with the current date and the authority user's code

**Code:**
```cobol
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
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `WS-DECISION` | input | Written to APPROVAL_1_STATUS to record whether the first authority approved or rejected |
| `AUTHORITY-NAME` | input | Written to APPROVAL_1_AUTHORITY to record the identity of the approving authority |
| `APPLICATION-STATUS` | input | Written to APPLICATION_STATUS to persist the new lifecycle status determined by the decision |
| `APPLICATION-ID` | input | Used in the WHERE clause to target the correct application record for the update |
| `USER-CODE` | input | Written to LAST_UPDATED_BY as the audit trail identifier of the person who submitted the approval |

#### 2.5.6 Approval Outcome Confirmation Message

**Description:** Informs the operator of the outcome of the first approval submission. An approval confirms that the application has been forwarded for second approval; a rejection confirms that the application has been closed.

**Core decision logic:**
- An 'A' decision produces a confirmation that the application is forwarded for second approval
- An 'R' decision produces a confirmation that the application has been rejected and closed

**Code:**
```cobol
           IF WS-DECISION = 'A'
               MOVE 'FIRST APPROVAL RECORDED - FORWARDED FOR 2ND APPROVA        
                   TO DA1MSG
           ELSE
               MOVE 'FIRST APPROVAL REJECTED - APPLICATION CLOSED'
                   TO DA1MSG
           END-IF.
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `WS-DECISION` | input | Determines which outcome message is displayed to the operator after the approval is saved |

---

Generated by IBM Bob Premium Package for Z
