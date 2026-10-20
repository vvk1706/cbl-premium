# Business rules: Inventory

**Program:** DLISAPPL

**Total rules extracted:** 16

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Rule Inventory](#2-rule-inventory)
  - [2.1 Paragraph: PROCESS-INPUT](#21-paragraph-process-input)
  - [2.2 Paragraph: MAIN-LOGIC](#22-paragraph-main-logic)
  - [2.3 Paragraph: LOOKUP-CANDIDATE](#23-paragraph-lookup-candidate)
  - [2.4 Paragraph: CALC-FEE](#24-paragraph-calc-fee)
  - [2.5 Paragraph: SUBMIT-APPLICATION](#25-paragraph-submit-application)

## 1. Purpose

This document is an inventory of all business rules extracted from DLISAPPL, organised at the Paragraph level. Each Paragraph contributes one or more named rule blocks, where each block captures a discrete business policy with its title, decision logic, conditions, actions, outcomes, and the exact source code that realises it. Key variables, when available, are annotated with their role (input or output) and their specific purpose within the rule. References to related Paragraphs called or invoked by each rule are also recorded.

## 2. Rule Inventory

### 2.1 Paragraph: PROCESS-INPUT

#### 2.1.1 Route User Action to Business Function Based on Function Key

**Description:** Interprets the user's function key selection and routes the transaction to the appropriate business operation: submitting an application (F1), looking up a candidate (F3), calculating the fee (F5), exiting the transaction (F12), or notifying the user of an invalid key choice.

**Core decision logic:**
- F1 triggers the license application submission process
- F3 triggers the candidate lookup process
- F5 triggers the fee calculation process
- F12 terminates the current transaction session
- Any other key results in a user guidance message specifying valid key options

**Code:**
```cobol
           EVALUATE TRUE
               WHEN EIBAID = DFHPF1   PERFORM SUBMIT-APPLICATION
               WHEN EIBAID = DFHPF3   PERFORM LOOKUP-CANDIDATE
               WHEN EIBAID = DFHPF5   PERFORM CALC-FEE
               WHEN EIBAID = DFHPF12  EXEC CICS RETURN END-EXEC
               OTHER
                   MOVE 'USE F1 F3 F5 OR F12' TO DAEMSG
           END-EVALUATE
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `DLIS-COMMAREA` | input | Holds session state passed between pseudo-conversational task invocations, available to the business functions invoked from this routing block |

**Paragraphs:**

* SUBMIT-APPLICATION
* LOOKUP-CANDIDATE
* CALC-FEE
### 2.2 Paragraph: MAIN-LOGIC

#### 2.2.1 Determine Initial Screen Display vs. Input Processing Based on Communication Area Presence

**Description:** Determines whether this is the first invocation of the transaction (no communication area present) requiring screen initialization, or a return invocation with user input to process. On re-entry, the prior session's communication area is restored before processing user input.

**Core decision logic:**
- If no communication area exists (EIBCALEN = 0), the transaction is new and the initial screen must be displayed
- If a communication area exists, the session is a continuation and user input must be processed
- Prior session state is restored from DFHCOMMAREA into DLIS-COMMAREA before processing input on re-entry

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
| `DLIS-COMMAREA` | output | Receives the restored session state from DFHCOMMAREA on re-entry so that prior transaction context is available during input processing |
| `DFHCOMMAREA` | input | Supplies the communication area data passed from the previous task invocation, which is copied into the program's own communication area on re-entry |
| `CA-TRANSACTION-ID` | output | Receives the current CICS transaction identifier from EIBTRNID to record which transaction is running in the communication area |

**Paragraphs:**

* INIT-SCREEN
* PROCESS-INPUT
### 2.3 Paragraph: LOOKUP-CANDIDATE

#### 2.3.1 Validate Candidate ID Entry

**Description:** Enforces that a candidate ID must be entered before a lookup can be performed. If the candidate ID field is blank (zeros), the user is prompted to enter one and processing stops.

**Core decision logic:**
- A candidate ID of zero is treated as not entered and the lookup is blocked
- User is notified to enter a candidate ID before proceeding

**Code:**
```cobol
           IF DAECIDI = ZEROS
               MOVE 'ENTER CANDIDATE ID' TO DAEMSG
               GO TO LOOKUP-CANDIDATE-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CANDIDATE-ID` | input | The candidate identifier entered on the screen, tested to ensure it has been provided before attempting the database lookup |

#### 2.3.2 Retrieve Candidate Record from Database

**Description:** Retrieves the candidate's first name, last name, and record status from the DLIS candidate table using the entered candidate ID as the lookup key.

**Core decision logic:**
- The candidate record is located using the candidate ID as the unique key
- First name, last name, and record status are the data points retrieved to validate and identify the candidate

**Code:**
```cobol
           MOVE DAECIDI TO CANDIDATE-ID OF DCLDLIS-CANDIDATE
           EXEC SQL
               SELECT FIRST_NAME, LAST_NAME, RECORD_STATUS
               INTO   :FIRST-NAME, :LAST-NAME, :RECORD-STATUS
               OF DCLDLIS-CANDIDATE
               FROM   DLIS.CANDIDATE
               WHERE  CANDIDATE_ID = :CANDIDATE-ID OF DCLDLIS-CANDIDATE
           END-EXEC
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CANDIDATE-ID` | input | Used as the WHERE clause key to identify the specific candidate record to retrieve from the database |
| `FIRST-NAME` | output | Receives the candidate's given name from the database for display to the user |
| `LAST-NAME` | output | Receives the candidate's family name from the database for display to the user |
| `RECORD-STATUS` | output | Receives the candidate record's status indicator from the database, used subsequently to check whether the candidate is active |

#### 2.3.3 Reject Lookup for Non-Existent Candidate

**Description:** Enforces that only candidates with existing records can be processed. If the database returns no row for the given candidate ID, the user is informed that the candidate was not found and lookup processing stops.

**Core decision logic:**
- A candidate ID that does not match any record in the database is rejected
- User receives a 'CANDIDATE NOT FOUND' message when no matching record exists

**Code:**
```cobol
           IF SQLCODE = 100
               MOVE 'CANDIDATE NOT FOUND' TO DAEMSG
               GO TO LOOKUP-CANDIDATE-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CANDIDATE-ID` | input | The candidate identifier whose absence in the database triggers the not-found rejection |

#### 2.3.4 Reject Inactive Candidate Record

**Description:** Enforces that only active candidates are eligible for further processing. If the candidate's record status is 'I' (inactive), the user is notified and the lookup is rejected.

**Core decision logic:**
- A candidate with record status 'I' is considered inactive and ineligible for license application processing
- Inactive candidates are blocked from proceeding with a descriptive error message

**Code:**
```cobol
           IF RECORD-STATUS OF DCLDLIS-CANDIDATE = 'I'
               MOVE 'CANDIDATE RECORD IS INACTIVE' TO DAEMSG
               GO TO LOOKUP-CANDIDATE-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `RECORD-STATUS` | input | The candidate record status value retrieved from the database, tested to enforce the rule that inactive candidates cannot proceed |

#### 2.3.5 Display Found Candidate Name

**Description:** Combines the candidate's first and last names into a single display name field on the screen and confirms to the user that the candidate was found and is active.

**Core decision logic:**
- First name and last name are concatenated with a space separator to form the display name
- A 'CANDIDATE FOUND' confirmation message is presented to the user on successful lookup

**Code:**
```cobol
           STRING FIRST-NAME OF DCLDLIS-CANDIDATE DELIMITED SPACE
                  ' '        DELIMITED SIZE
                  LAST-NAME  OF DCLDLIS-CANDIDATE DELIMITED SPACE
               INTO DAECNAMO
           MOVE 'CANDIDATE FOUND' TO DAEMSG.
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `FIRST-NAME` | input | The candidate's given name, combined with the last name to form the full display name shown on screen |
| `LAST-NAME` | input | The candidate's family name, combined with the first name to form the full display name shown on screen |

### 2.4 Paragraph: CALC-FEE

#### 2.4.1 Validate License Type Selection Before Fee Retrieval

**Description:** Enforces that a license type must be selected before a fee can be calculated. If the license type field is blank, the user is prompted to select one and fee retrieval is blocked.

**Core decision logic:**
- Fee calculation cannot proceed without a license type selection
- A blank or low-values license type field is treated as no selection made

**Code:**
```cobol
           IF DAELTYPI = SPACES OR DAELTYPI = LOW-VALUES
               MOVE 'SELECT LICENSE TYPE FIRST' TO DAEMSG
               GO TO CALC-FEE-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `LICENSE-TYPE` | input | The license type entered on screen, tested to confirm it has been provided before attempting fee schedule lookup |

#### 2.4.2 Retrieve Active Initial Fee Schedule for License Type

**Description:** Retrieves the fee amount and currency code from the active, currently effective initial fee schedule entry for the selected license type. Only records of fee type 'IF' (initial fee), with active status and a valid date range covering today are considered.

**Core decision logic:**
- Only fee schedule entries of type 'IF' (initial fee) are applicable
- Only active fee schedule entries (ACTIVE_STATUS = 'A') are considered
- The fee schedule entry must be currently effective: effective date must be on or before today and expiry date must be null or on or after today
- When multiple matching records exist, only the first row is used

**Code:**
```cobol
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
               AND    (EXPIRY_DATE IS NULL OR EXPIRY_DATE >= CURRENT DAT        
               FETCH FIRST 1 ROW ONLY
           END-EXEC
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `LICENSE-TYPE` | input | Used as the primary filter in the fee schedule query to retrieve the fee applicable to the selected license type |
| `FEE-AMOUNT` | output | Receives the monetary fee value from the active fee schedule entry retrieved for the license type |
| `CURRENCY-CODE` | output | Receives the currency denomination of the retrieved fee from the fee schedule for display alongside the fee amount |

#### 2.4.3 Reject Fee Retrieval When No Schedule Exists for License Type

**Description:** Enforces that a fee can only be displayed when an active, currently effective fee schedule exists for the chosen license type. If no matching schedule is found, the user is informed and fee display is blocked.

**Core decision logic:**
- A license type with no active or currently effective fee schedule entry cannot have a fee displayed
- User receives a specific message indicating no fee schedule exists for the selected license type

**Code:**
```cobol
           IF SQLCODE = 100
               MOVE 'NO FEE SCHEDULE FOR THIS LICENSE TYPE' TO DAEMSG
               GO TO CALC-FEE-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `LICENSE-TYPE` | input | The license type for which no fee schedule was found, leading to the rejection of the fee retrieval |

#### 2.4.4 Display Retrieved Fee Amount and Currency to User

**Description:** Formats the retrieved fee amount for display and presents it along with the currency code to the user on the screen, confirming successful fee retrieval.

**Core decision logic:**
- The fee amount is formatted into a display value before being placed on the output screen field
- The currency code is shown alongside the fee amount to provide full fee denomination information
- A success message confirms the fee was retrieved and displayed

**Code:**
```cobol
           MOVE FEE-AMOUNT    OF DCLDLIS-FEE-SCHED TO WS-FEE-AMOUNT
           MOVE WS-FEE-AMOUNT TO WS-FEE-AMOUNT-D
           MOVE WS-FEE-AMOUNT-D TO DAEFEEO
           MOVE CURRENCY-CODE OF DCLDLIS-FEE-SCHED TO DAECURRO
           MOVE 'FEE RETRIEVED SUCCESSFULLY' TO DAEMSG.
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `FEE-AMOUNT` | input | The raw monetary fee value from the fee schedule, moved to working storage for formatting before display |
| `WS-FEE-AMOUNT` | output | Intermediate working-storage holding of the fee amount before it is converted to display format |
| `WS-FEE-AMOUNT-D` | output | Display-formatted version of the fee amount that is moved to the output screen field for presentation to the user |
| `CURRENCY-CODE` | input | The currency denomination of the fee, moved directly to the screen output field to show the user the fee currency |

### 2.5 Paragraph: SUBMIT-APPLICATION

#### 2.5.1 Validate Required Fields Before Application Submission

**Description:** Enforces that both a candidate ID and a license type must be provided before a license application can be submitted. Missing either field results in a descriptive error message and the submission is blocked.

**Core decision logic:**
- A candidate ID of zero is treated as not entered and blocks submission
- A blank or low-values license type is treated as not selected and blocks submission
- Both fields are mandatory for a license application to be accepted

**Code:**
```cobol
           IF DAECIDI = ZEROS
               MOVE 'CANDIDATE ID IS REQUIRED' TO DAEMSG
               GO TO SUBMIT-APPLICATION-EXIT
           END-IF
           IF DAELTYPI = SPACES OR DAELTYPI = LOW-VALUES
               MOVE 'LICENSE TYPE IS REQUIRED' TO DAEMSG
               GO TO SUBMIT-APPLICATION-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CANDIDATE-ID` | input | The candidate identifier entered on screen, validated to be non-zero as a prerequisite for application submission |
| `LICENSE-TYPE` | input | The license type entered on screen, validated to be non-blank as a prerequisite for application submission |

#### 2.5.2 Validate License Type Is an Allowed Value

**Description:** Enforces the business rule that only recognized license types 'L', 'P', and 'O' are valid for a license application. Any other value is rejected with a descriptive error message.

**Core decision logic:**
- Only license types 'L', 'P', and 'O' are accepted for license applications
- Any license type value outside these three codes is invalid and blocks submission

**Code:**
```cobol
           IF DAELTYPI NOT = 'L' AND DAELTYPI NOT = 'P'
                               AND DAELTYPI NOT = 'O'
               MOVE 'LICENSE TYPE MUST BE L P OR O' TO DAEMSG
               GO TO SUBMIT-APPLICATION-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `LICENSE-TYPE` | input | The license type value entered by the user, tested against the three valid application codes to enforce domain-allowed values |

#### 2.5.3 Block Duplicate Active Application for Same Candidate and License Type

**Description:** Prevents a candidate from having more than one active license application for the same license type at the same time. Applications with status 'RE' (rejected) or 'IS' (issued) are excluded from the active count, meaning only in-progress applications block new submissions.

**Core decision logic:**
- A candidate cannot have more than one active application for the same license type
- Applications with status 'RE' (rejected) or 'IS' (issued) are not considered active and do not block new applications
- Any other application status is treated as active and blocks a new submission for the same candidate and license type

**Code:**
```cobol
      *    Check no active application already exists
           MOVE DAECIDI  TO CANDIDATE-ID  OF DCLDLIS-LICENSE-APPL
           MOVE DAELTYPI TO LICENSE-TYPE  OF DCLDLIS-LICENSE-APPL
           EXEC SQL
               SELECT COUNT(*) INTO :APPLICATION-ID OF DCLDLIS-LICENSE-A        
               FROM   DLIS.LICENSE_APPLICATION
               WHERE  CANDIDATE_ID   = :CANDIDATE-ID   OF DCLDLIS-LICENS        
               AND    LICENSE_TYPE   = :LICENSE-TYPE   OF DCLDLIS-LICENS        
               AND    APPLICATION_STATUS NOT IN ('RE','IS')
           END-EXEC
           IF APPLICATION-ID OF DCLDLIS-LICENSE-APPL > 0
               MOVE 'ACTIVE APPLICATION ALREADY EXISTS FOR THIS TYPE'
                   TO DAEMSG
               GO TO SUBMIT-APPLICATION-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CANDIDATE-ID` | input | Used to filter existing applications to only those belonging to the candidate attempting to submit a new application |
| `LICENSE-TYPE` | input | Used to filter existing applications to only those of the same license type as the new application being submitted |
| `APPLICATION-ID` | output | Receives the count of existing active applications for the candidate and license type, used to determine whether a duplicate exists |

#### 2.5.4 Insert New License Application Record with Pending Status

**Description:** Creates a new license application record in the database for the candidate and license type, setting the initial application status to 'PE' (pending) and recording the terminal ID as the creator for audit purposes.

**Core decision logic:**
- New license applications are created with an initial status of 'PE' (pending)
- The terminal ID of the submitting session is recorded as both the creator and last updater of the application for audit trail purposes

**Code:**
```cobol
      *    Insert application
           MOVE EIBTRMID TO CREATED-BY    OF DCLDLIS-LICENSE-APPL
           EXEC SQL
               INSERT INTO DLIS.LICENSE_APPLICATION
                  (CANDIDATE_ID, LICENSE_TYPE, APPLICATION_STATUS, CREAT        
                   LAST_UPDATED_BY)
               VALUES
                  (:CANDIDATE-ID, :LICENSE-TYPE, 'PE', :CREATED-BY, :CRE        
               OF DCLDLIS-LICENSE-APPL
           END-EXEC
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CANDIDATE-ID` | input | Stored on the new application record to associate the application with the candidate |
| `LICENSE-TYPE` | input | Stored on the new application record to identify the type of license being applied for |
| `CREATED-BY` | output | Receives the terminal ID from EIBTRMID and is stored on the application record as the audit field identifying who created the application |

#### 2.5.5 Retrieve and Display System-Generated Application ID After Successful Insert

**Description:** Retrieves the system-generated identifier assigned to the newly inserted application and presents it to the user along with the initial pending status and today's application date, confirming successful submission.

**Core decision logic:**
- The system-generated application ID is retrieved immediately after insert and shown to the user as confirmation
- The initial application status 'PE' (pending) is displayed to the user
- The current date is displayed as the application date
- A success message confirms the application was submitted

**Code:**
```cobol
           EXEC SQL
               SELECT IDENTITY_VAL_LOCAL()
               INTO   :APPLICATION-ID OF DCLDLIS-LICENSE-APPL
               FROM   SYSIBM.SYSDUMMY1
           END-EXEC
           MOVE APPLICATION-ID OF DCLDLIS-LICENSE-APPL TO DAEAIDO
           MOVE 'PE'           TO DAEASTTO
           MOVE CURRENT-DATE(1:10) TO DAEADATO
           MOVE 'APPLICATION SUBMITTED SUCCESSFULLY' TO DAEMSG.
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `APPLICATION-ID` | output | Receives the system-generated identity value of the newly inserted application, which is then displayed to the user as their application reference |

---

Generated by IBM Bob Premium Package for Z
