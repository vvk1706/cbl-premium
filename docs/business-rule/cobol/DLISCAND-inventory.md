# Business rules: Inventory

**Program:** DLISCAND

**Total rules extracted:** 13

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Rule Inventory](#2-rule-inventory)
  - [2.1 Paragraph: PROCESS-INPUT](#21-paragraph-process-input)
  - [2.2 Paragraph: MAIN-LOGIC](#22-paragraph-main-logic)
  - [2.3 Paragraph: CREATE-CANDIDATE](#23-paragraph-create-candidate)
  - [2.4 Paragraph: UPDATE-CANDIDATE](#24-paragraph-update-candidate)
  - [2.5 Paragraph: INQUIRE-CANDIDATE](#25-paragraph-inquire-candidate)
  - [2.6 Paragraph: DEACTIVATE-CANDIDATE](#26-paragraph-deactivate-candidate)

## 1. Purpose

This document is an inventory of all business rules extracted from DLISCAND, organised at the Paragraph level. Each Paragraph contributes one or more named rule blocks, where each block captures a discrete business policy with its title, decision logic, conditions, actions, outcomes, and the exact source code that realises it. Key variables, when available, are annotated with their role (input or output) and their specific purpose within the rule. References to related Paragraphs called or invoked by each rule are also recorded.

## 2. Rule Inventory

### 2.1 Paragraph: PROCESS-INPUT

#### 2.1.1 Function Key Routing to Business Operations

**Description:** Routes user requests to the appropriate candidate management operation based on the function key pressed. F1 creates a candidate, F2 updates, F3 inquires, F4 deactivates, F12 exits the transaction, and any other key results in an invalid key message.

**Core decision logic:**
- F1 initiates candidate creation
- F2 initiates candidate update
- F3 initiates candidate inquiry
- F4 initiates candidate deactivation
- F12 terminates the transaction
- Any other key press is rejected with an invalid key message

**Code:**
```cobol
           EVALUATE TRUE
               WHEN EIBAID = DFHPF1
                   PERFORM CREATE-CANDIDATE
               WHEN EIBAID = DFHPF2
                   PERFORM UPDATE-CANDIDATE
               WHEN EIBAID = DFHPF3
                   PERFORM INQUIRE-CANDIDATE
               WHEN EIBAID = DFHPF4
                   PERFORM DEACTIVATE-CANDIDATE
               WHEN EIBAID = DFHPF12
                   EXEC CICS RETURN END-EXEC
               OTHER
                   MOVE 'INVALID KEY - USE F1-F4 OR F12' TO DCMMSG
           END-EVALUATE
```

**Paragraphs:**

* CREATE-CANDIDATE
* UPDATE-CANDIDATE
* INQUIRE-CANDIDATE
* DEACTIVATE-CANDIDATE
### 2.2 Paragraph: MAIN-LOGIC

#### 2.2.1 First-Time Entry vs. Return Entry Routing

**Description:** Determines whether the transaction is being entered for the first time or returning from a prior interaction. On first entry (no commarea), the screen is initialised. On subsequent entries, the commarea is restored and user input is processed.

**Core decision logic:**
- If commarea length is zero, the transaction is starting fresh and the screen is initialised
- If commarea length is non-zero, the existing commarea data is restored and input processing continues

**Code:**
```cobol
           IF EIBCALEN = 0
               PERFORM INIT-SCREEN
           ELSE
               MOVE DFHCOMMAREA  TO DLIS-COMMAREA
               PERFORM PROCESS-INPUT
           END-IF
```

**Paragraphs:**

* INIT-SCREEN
* PROCESS-INPUT
### 2.3 Paragraph: CREATE-CANDIDATE

#### 2.3.1 Required Field Validation for Candidate Creation

**Description:** Enforces that First Name, Last Name, and National ID are all mandatory fields before a candidate record can be created. If any of these fields is missing, processing is halted and an appropriate error message is returned to the user.

**Core decision logic:**
- First Name is a mandatory field for candidate creation
- Last Name is a mandatory field for candidate creation
- National ID is a mandatory field for candidate creation
- Any missing required field prevents creation and displays a specific error message

**Code:**
```cobol
           IF DCMFNAMI = SPACES OR DCMFNAMI = LOW-VALUES
               MOVE 'FIRST NAME IS REQUIRED' TO DCMMSG
               GO TO CREATE-CANDIDATE-EXIT
           END-IF
           IF DCMLNAMI = SPACES OR DCMLNAMI = LOW-VALUES
               MOVE 'LAST NAME IS REQUIRED' TO DCMMSG
               GO TO CREATE-CANDIDATE-EXIT
           END-IF
           IF DCMIDNOI = SPACES OR DCMIDNOI = LOW-VALUES
               MOVE 'NATIONAL ID IS REQUIRED' TO DCMMSG
               GO TO CREATE-CANDIDATE-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `FIRST-NAME` | output | Validated as a required field; creation is blocked if First Name is absent |
| `LAST-NAME` | output | Validated as a required field; creation is blocked if Last Name is absent |
| `ID-NUMBER` | output | Validated as a required field; creation is blocked if National ID is absent |

#### 2.3.2 Duplicate Active Candidate Check by National ID

**Description:** Prevents creation of a duplicate candidate by checking whether an active candidate record with the same National ID already exists in the database. If a match is found, creation is blocked and the user is informed.

**Core decision logic:**
- A candidate with the same National ID and an active status ('A') cannot be created again
- Duplicate detection is scoped to active records only; inactive records with the same ID do not block creation

**Code:**
```cobol
           MOVE DCMIDNOI TO ID-NUMBER OF DCLDLIS-CANDIDATE
           EXEC SQL
               SELECT CANDIDATE_ID INTO :CANDIDATE-ID OF DCLDLIS-CANDIDA        
               FROM DLIS.CANDIDATE
               WHERE ID_NUMBER = :ID-NUMBER OF DCLDLIS-CANDIDATE
               AND   RECORD_STATUS = 'A'
           END-EXEC
           IF SQLCODE = 0
               MOVE 'CANDIDATE WITH THIS ID NUMBER ALREADY EXISTS'
                   TO DCMMSG
               GO TO CREATE-CANDIDATE-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `ID-NUMBER` | input | Used as the search key to detect whether an active candidate with the same National ID already exists |
| `CANDIDATE-ID` | output | Retrieved from the database to confirm existence of a duplicate active candidate |
| `RECORD-STATUS` | input | Filtered to 'A' (active) to ensure only active duplicates block candidate creation |

#### 2.3.3 Insert New Candidate Record

**Description:** Creates a new candidate record in the database with all provided personal and contact details. The record is set to active status ('A') and stamped with the creating terminal identifier for audit purposes.

**Core decision logic:**
- A new candidate record is created with status 'A' (active)
- The creating terminal identifier is recorded as the audit creator
- All personal details including name, date of birth, National ID, address, phone, and email are persisted

**Code:**
```cobol
           MOVE DCMFNAMI  TO FIRST-NAME   OF DCLDLIS-CANDIDATE
           MOVE DCMLNAMI  TO LAST-NAME    OF DCLDLIS-CANDIDATE
           MOVE DCMDOBI   TO DATE-OF-BIRTH OF DCLDLIS-CANDIDATE
           MOVE DCMIDNOI  TO ID-NUMBER    OF DCLDLIS-CANDIDATE
           MOVE DCMADR1I  TO ADDRESS-LINE-1 OF DCLDLIS-CANDIDATE
           MOVE DCMADR2I  TO ADDRESS-LINE-2 OF DCLDLIS-CANDIDATE
           MOVE DCMCITYI  TO CITY         OF DCLDLIS-CANDIDATE
           MOVE DCMSTATI  TO STATE-PROVINCE OF DCLDLIS-CANDIDATE
           MOVE DCMPOSTI  TO POSTAL-CODE  OF DCLDLIS-CANDIDATE
           MOVE DCMCTRYI  TO COUNTRY      OF DCLDLIS-CANDIDATE
           MOVE DCMPHNI   TO PHONE-NUMBER OF DCLDLIS-CANDIDATE
           MOVE DCMEMLI   TO EMAIL-ADDRESS OF DCLDLIS-CANDIDATE
           MOVE 'A'       TO RECORD-STATUS OF DCLDLIS-CANDIDATE
           MOVE EIBTRMID  TO CREATED-BY   OF DCLDLIS-CANDIDATE
           EXEC SQL
               INSERT INTO DLIS.CANDIDATE
                  (FIRST_NAME, LAST_NAME, DATE_OF_BIRTH, ID_NUMBER,
                   ADDRESS_LINE_1, ADDRESS_LINE_2, CITY,
                   STATE_PROVINCE, POSTAL_CODE, COUNTRY,
                   PHONE_NUMBER, EMAIL_ADDRESS, RECORD_STATUS, CREATED_B        
               VALUES
                  (:FIRST-NAME, :LAST-NAME, :DATE-OF-BIRTH, :ID-NUMBER,
                   :ADDRESS-LINE-1, :ADDRESS-LINE-2, :CITY,
                   :STATE-PROVINCE, :POSTAL-CODE, :COUNTRY,
                   :PHONE-NUMBER, :EMAIL-ADDRESS, :RECORD-STATUS,
                   :CREATED-BY)
               OF DCLDLIS-CANDIDATE
           END-EXEC
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `FIRST-NAME` | output | Populated from the screen input and inserted into the candidate record as the given name |
| `LAST-NAME` | output | Populated from the screen input and inserted into the candidate record as the family name |
| `DATE-OF-BIRTH` | output | Populated from the screen input and stored as the candidate's birth date |
| `ID-NUMBER` | output | Populated from the screen input and stored as the candidate's National ID |
| `ADDRESS-LINE-1` | output | Populated from the screen input and stored as the first line of the candidate's address |
| `ADDRESS-LINE-2` | output | Populated from the screen input and stored as the second line of the candidate's address |
| `CITY` | output | Populated from the screen input and stored as the candidate's city |
| `STATE-PROVINCE` | output | Populated from the screen input and stored as the candidate's state or province |
| `POSTAL-CODE` | output | Populated from the screen input and stored as the candidate's postal code |
| `COUNTRY` | output | Populated from the screen input and stored as the candidate's country |
| `PHONE-NUMBER` | output | Populated from the screen input and stored as the candidate's telephone number |
| `EMAIL-ADDRESS` | output | Populated from the screen input and stored as the candidate's email address |
| `RECORD-STATUS` | output | Set to 'A' to mark the newly created candidate record as active |
| `CREATED-BY` | output | Set from the terminal identifier to record who created the candidate for audit purposes |

#### 2.3.4 Retrieve and Display System-Generated Candidate ID After Creation

**Description:** Retrieves the system-generated unique identifier assigned to the newly created candidate record and displays it on the screen along with a success confirmation message.

**Core decision logic:**
- The system-generated candidate ID is retrieved immediately after a successful insert and shown to the user
- A success message confirms the candidate was created

**Code:**
```cobol
           EXEC SQL
               SELECT IDENTITY_VAL_LOCAL()
               INTO :CANDIDATE-ID OF DCLDLIS-CANDIDATE
               FROM SYSIBM.SYSDUMMY1
           END-EXEC
           MOVE CANDIDATE-ID OF DCLDLIS-CANDIDATE TO DCMCIDO
           MOVE 'CANDIDATE CREATED SUCCESSFULLY' TO DCMMSG
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CANDIDATE-ID` | output | Receives the system-generated identifier of the newly inserted candidate record and is displayed on the screen |

### 2.4 Paragraph: UPDATE-CANDIDATE

#### 2.4.1 Candidate ID Required Validation for Update

**Description:** Enforces that a Candidate ID must be provided before an update operation can proceed. If the ID is absent, the update is blocked and an error message is returned.

**Core decision logic:**
- Candidate ID is mandatory to perform an update; absence blocks the operation

**Code:**
```cobol
           IF DCMCIDI = ZEROS OR DCMCIDI = LOW-VALUES
               MOVE 'CANDIDATE ID IS REQUIRED FOR UPDATE' TO DCMMSG
               GO TO UPDATE-CANDIDATE-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CANDIDATE-ID` | input | Checked for presence to ensure an update target is identified before proceeding |

#### 2.4.2 Update Candidate Record Details

**Description:** Updates personal and contact details for the identified candidate record, including name, address, phone, email, and record status. The outcome is communicated to the user: success, not found, or database error.

**Core decision logic:**
- All updatable candidate fields including name, address, contact details, and record status are modified in a single operation
- If no matching candidate is found, the user is notified with a 'not found' message
- A successful update is confirmed to the user

**Code:**
```cobol
           MOVE DCMCIDI TO CANDIDATE-ID OF DCLDLIS-CANDIDATE
           EXEC SQL
               UPDATE DLIS.CANDIDATE SET
                  FIRST_NAME       = :FIRST-NAME,
                  LAST_NAME        = :LAST-NAME,
                  ADDRESS_LINE_1   = :ADDRESS-LINE-1,
                  ADDRESS_LINE_2   = :ADDRESS-LINE-2,
                  CITY             = :CITY,
                  STATE_PROVINCE   = :STATE-PROVINCE,
                  POSTAL_CODE      = :POSTAL-CODE,
                  COUNTRY          = :COUNTRY,
                  PHONE_NUMBER     = :PHONE-NUMBER,
                  EMAIL_ADDRESS    = :EMAIL-ADDRESS,
                  RECORD_STATUS    = :RECORD-STATUS
               WHERE CANDIDATE_ID  = :CANDIDATE-ID
               OF DCLDLIS-CANDIDATE
           END-EXEC
           IF SQLCODE = 100
               MOVE 'CANDIDATE NOT FOUND' TO DCMMSG
           ELSE IF SQLCODE NOT = 0
               MOVE 'DATABASE ERROR ON UPDATE' TO DCMMSG
           ELSE
               MOVE 'CANDIDATE UPDATED SUCCESSFULLY' TO DCMMSG
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CANDIDATE-ID` | input | Used as the key to identify which candidate record to update |
| `FIRST-NAME` | output | Updated in the candidate record with the new first name value |
| `LAST-NAME` | output | Updated in the candidate record with the new last name value |
| `ADDRESS-LINE-1` | output | Updated in the candidate record with the new first address line |
| `ADDRESS-LINE-2` | output | Updated in the candidate record with the new second address line |
| `CITY` | output | Updated in the candidate record with the new city value |
| `STATE-PROVINCE` | output | Updated in the candidate record with the new state or province value |
| `POSTAL-CODE` | output | Updated in the candidate record with the new postal code |
| `COUNTRY` | output | Updated in the candidate record with the new country value |
| `PHONE-NUMBER` | output | Updated in the candidate record with the new telephone number |
| `EMAIL-ADDRESS` | output | Updated in the candidate record with the new email address |
| `RECORD-STATUS` | output | Updated in the candidate record to reflect the new lifecycle status |

### 2.5 Paragraph: INQUIRE-CANDIDATE

#### 2.5.1 Search Key Requirement Validation for Inquiry

**Description:** Enforces that at least one search key — either Candidate ID or National ID — must be provided before an inquiry can be performed. If neither is supplied, the inquiry is blocked and a prompt message is returned.

**Core decision logic:**
- At least one of Candidate ID or National ID must be provided to perform a candidate inquiry
- If neither search key is present, the operation is halted and the user is prompted to supply one

**Code:**
```cobol
           IF DCMCIDI = ZEROS AND DCMIDNOI = SPACES
               MOVE 'ENTER CANDIDATE ID OR NATIONAL ID' TO DCMMSG
               GO TO INQUIRE-CANDIDATE-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CANDIDATE-ID` | input | Checked for presence as one of two valid search keys for candidate inquiry |
| `ID-NUMBER` | input | Checked for presence as the alternate search key for candidate inquiry |

#### 2.5.2 Retrieve Candidate Record by ID or National ID

**Description:** Looks up a candidate record using either the Candidate ID or the National ID as alternative search keys. If no matching record is found, a 'not found' message is returned and inquiry processing ends.

**Core decision logic:**
- A candidate can be located by either their Candidate ID or their National ID
- If no record matches either key, the user is informed and inquiry is terminated

**Code:**
```cobol
           MOVE DCMCIDI  TO CANDIDATE-ID OF DCLDLIS-CANDIDATE
           MOVE DCMIDNOI TO ID-NUMBER    OF DCLDLIS-CANDIDATE
           EXEC SQL
               SELECT CANDIDATE_ID, FIRST_NAME, LAST_NAME,
                      DATE_OF_BIRTH, ID_NUMBER, ADDRESS_LINE_1,
                      ADDRESS_LINE_2, CITY, STATE_PROVINCE,
                      POSTAL_CODE, COUNTRY, PHONE_NUMBER,
                      EMAIL_ADDRESS, RECORD_STATUS
               INTO   :CANDIDATE-ID, :FIRST-NAME, :LAST-NAME,
                      :DATE-OF-BIRTH, :ID-NUMBER, :ADDRESS-LINE-1,
                      :ADDRESS-LINE-2, :CITY, :STATE-PROVINCE,
                      :POSTAL-CODE, :COUNTRY, :PHONE-NUMBER,
                      :EMAIL-ADDRESS, :RECORD-STATUS
               OF DCLDLIS-CANDIDATE
               FROM DLIS.CANDIDATE
               WHERE CANDIDATE_ID = :CANDIDATE-ID
                  OR ID_NUMBER    = :ID-NUMBER
               OF DCLDLIS-CANDIDATE
               FETCH FIRST 1 ROW ONLY
           END-EXEC
           IF SQLCODE = 100
               MOVE 'CANDIDATE NOT FOUND' TO DCMMSG
               GO TO INQUIRE-CANDIDATE-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CANDIDATE-ID` | input | Used as the primary search key to locate the candidate record |
| `ID-NUMBER` | input | Used as the alternate search key to locate the candidate record when Candidate ID is not provided |
| `FIRST-NAME` | output | Retrieved from the database as part of the candidate record returned by the inquiry |
| `LAST-NAME` | output | Retrieved from the database as part of the candidate record returned by the inquiry |
| `DATE-OF-BIRTH` | output | Retrieved from the database as part of the candidate record returned by the inquiry |
| `ADDRESS-LINE-1` | output | Retrieved from the database as the first address line of the candidate |
| `ADDRESS-LINE-2` | output | Retrieved from the database as the second address line of the candidate |
| `CITY` | output | Retrieved from the database as the candidate's city |
| `STATE-PROVINCE` | output | Retrieved from the database as the candidate's state or province |
| `POSTAL-CODE` | output | Retrieved from the database as the candidate's postal code |
| `COUNTRY` | output | Retrieved from the database as the candidate's country |
| `PHONE-NUMBER` | output | Retrieved from the database as the candidate's telephone number |
| `EMAIL-ADDRESS` | output | Retrieved from the database as the candidate's email address |
| `RECORD-STATUS` | output | Retrieved from the database to reflect the current lifecycle status of the candidate |

#### 2.5.3 Display Retrieved Candidate Details on Screen

**Description:** Populates all screen output fields with the retrieved candidate's full profile, including identity, contact, address details, and record status, and confirms a successful find with a message.

**Core decision logic:**
- All candidate profile fields are presented to the user upon a successful inquiry
- The current record status is displayed to indicate whether the candidate is active or inactive

**Code:**
```cobol
           MOVE CANDIDATE-ID   OF DCLDLIS-CANDIDATE TO DCMCIDO
           MOVE FIRST-NAME     OF DCLDLIS-CANDIDATE TO DCMFNAMO
           MOVE LAST-NAME      OF DCLDLIS-CANDIDATE TO DCMLNAMO
           MOVE DATE-OF-BIRTH  OF DCLDLIS-CANDIDATE TO DCMDOBO
           MOVE ID-NUMBER      OF DCLDLIS-CANDIDATE TO DCMIDNOO
           MOVE ADDRESS-LINE-1 OF DCLDLIS-CANDIDATE TO DCMADR1O
           MOVE ADDRESS-LINE-2 OF DCLDLIS-CANDIDATE TO DCMADR2O
           MOVE CITY           OF DCLDLIS-CANDIDATE TO DCMCITYO
           MOVE STATE-PROVINCE OF DCLDLIS-CANDIDATE TO DCMSTATO
           MOVE POSTAL-CODE    OF DCLDLIS-CANDIDATE TO DCMPOSTO
           MOVE COUNTRY        OF DCLDLIS-CANDIDATE TO DCMCTRYO
           MOVE PHONE-NUMBER   OF DCLDLIS-CANDIDATE TO DCMPHNO
           MOVE EMAIL-ADDRESS  OF DCLDLIS-CANDIDATE TO DCMEMLO
           MOVE RECORD-STATUS  OF DCLDLIS-CANDIDATE TO DCMSTSO
           MOVE 'CANDIDATE FOUND' TO DCMMSG
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CANDIDATE-ID` | input | Moved to the screen output field to display the candidate's unique identifier |
| `FIRST-NAME` | input | Moved to the screen output field to display the candidate's first name |
| `LAST-NAME` | input | Moved to the screen output field to display the candidate's last name |
| `DATE-OF-BIRTH` | input | Moved to the screen output field to display the candidate's date of birth |
| `ID-NUMBER` | input | Moved to the screen output field to display the candidate's National ID |
| `ADDRESS-LINE-1` | input | Moved to the screen output field to display the first line of the candidate's address |
| `ADDRESS-LINE-2` | input | Moved to the screen output field to display the second line of the candidate's address |
| `CITY` | input | Moved to the screen output field to display the candidate's city |
| `STATE-PROVINCE` | input | Moved to the screen output field to display the candidate's state or province |
| `POSTAL-CODE` | input | Moved to the screen output field to display the candidate's postal code |
| `COUNTRY` | input | Moved to the screen output field to display the candidate's country |
| `PHONE-NUMBER` | input | Moved to the screen output field to display the candidate's telephone number |
| `EMAIL-ADDRESS` | input | Moved to the screen output field to display the candidate's email address |
| `RECORD-STATUS` | input | Moved to the screen output field to display the candidate's current lifecycle status |

### 2.6 Paragraph: DEACTIVATE-CANDIDATE

#### 2.6.1 Candidate ID Required Validation for Deactivation

**Description:** Enforces that a Candidate ID must be supplied before a deactivation operation can proceed. If no ID is provided, the operation is blocked and the user is prompted.

**Core decision logic:**
- Candidate ID is mandatory to perform deactivation; absence prevents the operation

**Code:**
```cobol
           IF DCMCIDI = ZEROS
               MOVE 'CANDIDATE ID IS REQUIRED TO DEACTIVATE' TO DCMMSG
               GO TO DEACTIVATE-CANDIDATE-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CANDIDATE-ID` | input | Checked for presence to ensure a deactivation target is identified before proceeding |

#### 2.6.2 Deactivate Candidate by Setting Status to Inactive

**Description:** Sets the candidate's record status to 'I' (inactive) in the database, effectively deactivating the candidate. The outcome is communicated to the user: success with the updated status displayed, not found, or database error.

**Core decision logic:**
- Deactivation is achieved by setting record status to 'I' (inactive)
- If no matching candidate is found, the user is notified
- On successful deactivation, the screen status field is updated to 'I' and a confirmation message is shown

**Code:**
```cobol
           MOVE DCMCIDI TO CANDIDATE-ID OF DCLDLIS-CANDIDATE
           EXEC SQL
               UPDATE DLIS.CANDIDATE
               SET    RECORD_STATUS = 'I'
               WHERE  CANDIDATE_ID  = :CANDIDATE-ID OF DCLDLIS-CANDIDATE        
           END-EXEC
           IF SQLCODE = 100
               MOVE 'CANDIDATE NOT FOUND' TO DCMMSG
           ELSE IF SQLCODE NOT = 0
               MOVE 'DATABASE ERROR ON DEACTIVATE' TO DCMMSG
           ELSE
               MOVE 'I' TO DCMSTSO
               MOVE 'CANDIDATE DEACTIVATED' TO DCMMSG
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `CANDIDATE-ID` | input | Used as the key to identify which candidate record to deactivate |
| `RECORD-STATUS` | output | Set to 'I' in the database to mark the candidate as inactive |

---

Generated by IBM Bob Premium Package for Z
