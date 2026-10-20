# Business rules: Inventory

**Program:** DLISHIST

**Total rules extracted:** 14

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Rule Inventory](#2-rule-inventory)
  - [2.1 Paragraph: PROCESS-INPUT](#21-paragraph-process-input)
  - [2.2 Paragraph: MAIN-LOGIC](#22-paragraph-main-logic)
  - [2.3 Paragraph: LOAD-APPLICATION](#23-paragraph-load-application)
  - [2.4 Paragraph: LOAD-HISTORY-TABLE](#24-paragraph-load-history-table)
  - [2.5 Paragraph: RUN-HISTORY-CHECK](#25-paragraph-run-history-check)

## 1. Purpose

This document is an inventory of all business rules extracted from DLISHIST, organised at the Paragraph level. Each Paragraph contributes one or more named rule blocks, where each block captures a discrete business policy with its title, decision logic, conditions, actions, outcomes, and the exact source code that realises it. Key variables, when available, are annotated with their role (input or output) and their specific purpose within the rule. References to related Paragraphs called or invoked by each rule are also recorded.

## 2. Rule Inventory

### 2.1 Paragraph: PROCESS-INPUT

#### 2.1.1 Function Key Routing for History Check Actions

**Description:** Routes the user's key press to the appropriate business action. F1 triggers the history check, F3 loads an application, F7 scrolls the history list backward by 7 rows (with a floor of 1), F8 scrolls forward by 7 rows, F12 exits the transaction, and any other key presents a usage guidance message.

**Core decision logic:**
- F1 initiates the driving history check process
- F3 loads an application and its driving history for review
- F7 scrolls backward through the history list by 7 rows, preventing scroll position below 1
- F8 scrolls forward through the history list by 7 rows
- F12 exits the transaction
- Any unrecognised key results in a user guidance message

**Code:**
```cobol
           EVALUATE TRUE
               WHEN EIBAID = DFHPF1   PERFORM RUN-HISTORY-CHECK
               WHEN EIBAID = DFHPF3   PERFORM LOAD-APPLICATION
               WHEN EIBAID = DFHPF7
                   SUBTRACT 7 FROM WS-SCROLL-TOP
                   IF WS-SCROLL-TOP < 1 MOVE 1 TO WS-SCROLL-TOP
                   PERFORM DISPLAY-HISTORY
               WHEN EIBAID = DFHPF8
                   ADD 7 TO WS-SCROLL-TOP
                   PERFORM DISPLAY-HISTORY
               WHEN EIBAID = DFHPF12
                   EXEC CICS RETURN END-EXEC
               OTHER
                   MOVE 'USE F1 F3 F7 F8 OR F12' TO DHCMSG
           END-EVALUATE
```

**Paragraphs:**

* RUN-HISTORY-CHECK
* LOAD-APPLICATION
* DISPLAY-HISTORY
### 2.2 Paragraph: MAIN-LOGIC

#### 2.2.1 Initial Session vs. Returning Session Routing

**Description:** Determines whether this is the first invocation of the transaction or a subsequent one. A zero commarea length means no prior session state exists, so the screen is initialised fresh. Otherwise, the commarea is restored and the user's input is processed, enabling stateful multi-turn interaction.

**Core decision logic:**
- If no commarea is present (EIBCALEN = 0), the transaction is starting fresh and the screen must be initialised
- If a commarea exists, prior session state is restored and user input is processed

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

**Description:** Enforces that an application ID must be entered before the application can be loaded. If no ID is provided, the user is prompted to supply one and processing stops.

**Core decision logic:**
- An application ID of zero is treated as absent; the user is prompted to enter one and no further processing occurs

**Code:**
```cobol
           IF DHCAIDI = ZEROS
               MOVE 'ENTER APPLICATION ID' TO DHCMSG
               GO TO LOAD-APP-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `APPLICATION-ID` | input | Checked for a zero value to determine whether the user has supplied an application ID before attempting to load the application record |

#### 2.3.2 Retrieve Application and Candidate Details

**Description:** Retrieves the candidate ID, license type, and candidate name for the entered application ID by joining the license application and candidate tables. If no matching application is found, the user is informed and processing stops.

**Core decision logic:**
- The application ID entered on screen is used as the key to retrieve application and candidate details
- If no application exists for the given ID, the user is notified and no further processing occurs

**Code:**
```cobol
           MOVE DHCAIDI TO APPLICATION-ID OF DCLDLIS-LICENSE-APPL
           EXEC SQL
               SELECT A.CANDIDATE_ID, A.LICENSE_TYPE,
                      C.FIRST_NAME, C.LAST_NAME
               INTO   :CANDIDATE-ID OF DCLDLIS-LICENSE-APPL,
                      :LICENSE-TYPE OF DCLDLIS-LICENSE-APPL,
                      :FIRST-NAME, :LAST-NAME OF DCLDLIS-CANDIDATE
               FROM   DLIS.LICENSE_APPLICATION A
               JOIN   DLIS.CANDIDATE C
                  ON  A.CANDIDATE_ID = C.CANDIDATE_ID
               WHERE  A.APPLICATION_ID = :APPLICATION-ID
                                         OF DCLDLIS-LICENSE-APPL
           END-EXEC
           IF SQLCODE = 100
               MOVE 'APPLICATION NOT FOUND' TO DHCMSG
               GO TO LOAD-APP-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `APPLICATION-ID` | input | Used as the WHERE clause key to locate the matching license application and joined candidate record |
| `CANDIDATE-ID` | output | Populated with the candidate identifier retrieved from the license application record |
| `LICENSE-TYPE` | output | Populated with the license category retrieved from the license application record and subsequently shown on screen |

#### 2.3.3 Display Candidate Name and License Type on Screen

**Description:** Formats the candidate's full name by concatenating first name and last name with a space delimiter, and copies the license type to the corresponding screen output fields, making the applicant's identity and license category visible to the user.

**Core decision logic:**
- First name and last name are concatenated with a single space to form the displayed candidate name
- License type is copied directly to the screen output field

**Code:**
```cobol
           STRING FIRST-NAME OF DCLDLIS-CANDIDATE DELIMITED SPACE
                  ' ' DELIMITED SIZE
                  LAST-NAME  OF DCLDLIS-CANDIDATE DELIMITED SPACE
               INTO DHCCNAMO
           MOVE LICENSE-TYPE OF DCLDLIS-LICENSE-APPL TO DHCLTYO
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `LICENSE-TYPE` | input | Read from the application record and moved to the screen output field to display the category of license applied for |

### 2.4 Paragraph: LOAD-HISTORY-TABLE

#### 2.4.1 Accumulate Demerit Points Across All History Incidents

**Description:** For each successfully fetched driving history incident, the incident details (date, type, description, demerit points) are stored in the display table up to a maximum of 50 rows, and the demerit points are cumulatively added to the running total used for the threshold check.

**Core decision logic:**
- Up to 50 history incidents are retained in the display table for scrollable presentation
- Demerit points from every fetched incident are accumulated into a running total for the history check threshold evaluation

**Code:**
```cobol
               IF SQLCODE = 0
                   ADD 1 TO WS-ROW-COUNT
                   IF WS-ROW-COUNT <= 50
                       MOVE INCIDENT-DATE  OF DCLDLIS-DRIVING-HIST
                           TO WS-HR-DATE(WS-ROW-COUNT)
                       MOVE INCIDENT-TYPE  OF DCLDLIS-DRIVING-HIST
                           TO WS-HR-TYPE(WS-ROW-COUNT)
                       MOVE INCIDENT-DESC  OF DCLDLIS-DRIVING-HIST
                           TO WS-HR-DESC(WS-ROW-COUNT)
                       MOVE DEMERIT-POINTS OF DCLDLIS-DRIVING-HIST
                           TO WS-HR-DMRT(WS-ROW-COUNT)
                       ADD DEMERIT-POINTS  OF DCLDLIS-DRIVING-HIST
                           TO WS-DEMERIT-TOTAL
                   END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `DEMERIT-POINTS` | input | Read from each fetched history incident and added to the cumulative demerit total used to evaluate the threshold check |
| `INCIDENT-DATE` | input | Stored in the history display table row for presentation in the scrollable incident list |
| `INCIDENT-TYPE` | input | Stored in the history display table row and used to identify suspension or disqualification incidents |
| `WS-DEMERIT-TOTAL` | output | Accumulates the total demerit points across all fetched incidents, used later in the history check threshold decision |

#### 2.4.2 Detect Active Suspension or Disqualification

**Description:** For each incident of type suspension ('SU') or disqualification ('DQ'), checks whether the suspension is still active by testing if the end date is today or later, or is blank. If active, sets the suspension flag to 'Y', which will cause the history check to fail.

**Core decision logic:**
- Only incidents of type 'SU' (suspension) or 'DQ' (disqualification) are evaluated for active status
- A suspension or disqualification is considered active if its end date is on or after today, or if the end date is blank
- An active suspension or disqualification sets the suspension flag to 'Y', which will cause the history check to fail

**Code:**
```cobol
                   IF INCIDENT-TYPE OF DCLDLIS-DRIVING-HIST
                                    IN ('SU','DQ')
                       IF SUSP-END-DATE OF DCLDLIS-DRIVING-HIST >= CURRE        
                          OR SUSP-END-DATE OF DCLDLIS-DRIVING-HIST = SPA        
                           MOVE 'Y' TO WS-SUSP-FLAG
                       END-IF
                   END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `INCIDENT-TYPE` | input | Checked against values 'SU' and 'DQ' to identify incidents that may represent an active suspension or disqualification |
| `SUSP-END-DATE` | input | Evaluated to determine whether a suspension or disqualification is still active based on comparison to the current date or blank value |
| `WS-SUSP-FLAG` | output | Set to 'Y' when an active suspension or disqualification is found, flagging the candidate for a history check failure |

#### 2.4.3 Detect Outstanding Unpaid Fines

**Description:** For each incident with a fine amount greater than zero, checks whether the fine is unpaid. If both conditions are met, sets the outstanding fine flag to 'Y', which will cause the history check to fail.

**Core decision logic:**
- An incident is only assessed for outstanding fines when its fine amount is greater than zero
- A fine is considered unpaid when the paid status is 'N'
- An unpaid fine sets the outstanding fine flag to 'Y', which will cause the history check to fail

**Code:**
```cobol
                   IF FINE-AMOUNT OF DCLDLIS-DRIVING-HIST > 0
                       IF FINE-PAID-STATUS OF DCLDLIS-DRIVING-HIST = 'N'        
                           MOVE 'Y' TO WS-FINE-FLAG
                       END-IF
                   END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `FINE-AMOUNT` | input | Checked to be greater than zero before evaluating payment status, ensuring only fined incidents trigger the unpaid fine check |
| `FINE-PAID-STATUS` | input | Checked for value 'N' to determine whether a non-zero fine remains unpaid |
| `WS-FINE-FLAG` | output | Set to 'Y' when an incident has a positive fine amount that is unpaid, flagging the candidate for a history check failure |

#### 2.4.4 Propagate Summary Check Indicators to Screen

**Description:** Copies the accumulated demerit total, suspension flag, and fine flag to the corresponding screen output fields, making the driving history summary visible to the user for review before the formal check is executed.

**Core decision logic:**
- The total demerit points, suspension status, and outstanding fine status are all surfaced on screen after history loading

**Code:**
```cobol
           MOVE WS-DEMERIT-TOTAL TO DHCDMRTO
           MOVE WS-SUSP-FLAG     TO DHCSUSPO
           MOVE WS-FINE-FLAG     TO DHCFINEO.
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `WS-DEMERIT-TOTAL` | input | Moved to the screen output field to display the candidate's accumulated demerit points |
| `WS-SUSP-FLAG` | input | Moved to the screen output field to indicate whether an active suspension or disqualification was detected |
| `WS-FINE-FLAG` | input | Moved to the screen output field to indicate whether outstanding unpaid fines were detected |

### 2.5 Paragraph: RUN-HISTORY-CHECK

#### 2.5.1 Application ID Presence Validation for History Check

**Description:** Enforces that an application ID must be entered before the history check can be run. If none is provided, the user is prompted and the check is aborted.

**Core decision logic:**
- The history check cannot proceed without an application ID; a zero value is treated as absent and processing stops

**Code:**
```cobol
           IF DHCAIDI = ZEROS
               MOVE 'ENTER APPLICATION ID FIRST' TO DHCMSG
               GO TO RUN-HIST-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `APPLICATION-ID` | input | Checked for a zero value to enforce that the user has supplied an application ID before attempting to run the history check |

#### 2.5.2 Eligibility Check Must Be Passed Before History Check

**Description:** Enforces the business policy that the driving history check can only be executed after the eligibility check has been passed. The eligibility check status is retrieved from the application record, and if it is not 'P' (passed), the history check is blocked with an explanatory message.

**Core decision logic:**
- The driving history check is only permitted when the eligibility check status on the application is 'P' (passed)
- Any other eligibility status blocks the history check and requires the user to complete eligibility first

**Code:**
```cobol
      *    Check eligibility was passed first
           EXEC SQL
               SELECT ELIG_CHECK_STATUS
               INTO   :ELIG-CHECK-STATUS OF DCLDLIS-LICENSE-APPL
               FROM   DLIS.LICENSE_APPLICATION
               WHERE  APPLICATION_ID = :APPLICATION-ID
                                       OF DCLDLIS-LICENSE-APPL
           END-EXEC
           IF ELIG-CHECK-STATUS OF DCLDLIS-LICENSE-APPL NOT = 'P'
               MOVE 'ELIGIBILITY CHECK MUST BE PASSED FIRST' TO DHCMSG
               GO TO RUN-HIST-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `APPLICATION-ID` | input | Used as the WHERE clause key to retrieve the eligibility check status from the license application record |
| `ELIG-CHECK-STATUS` | input | Retrieved from the database and tested against 'P' to enforce the prerequisite that eligibility must be passed before the history check can run |

#### 2.5.3 Evaluate Driving History Failure Conditions

**Description:** Applies the three driving history failure criteria in priority order: (1) active suspension or disqualification, (2) total demerit points exceeding 12, and (3) outstanding unpaid fines. The first failing condition sets the fail flag and records the reason message; subsequent conditions are only checked if no prior failure was detected.

**Core decision logic:**
- An active suspension or disqualification is the highest-priority failure condition
- Demerit points exceeding 12 is the second failure condition, checked only if no suspension failure was found
- Outstanding unpaid fines is the third failure condition, checked only if neither prior condition failed
- Only the first detected failure reason is recorded as the history check failure message

**Code:**
```cobol
           MOVE SPACES TO WS-HIST-FAIL-MSG
           MOVE 'N'    TO WS-FAIL-FLAG
           IF WS-SUSP-FLAG = 'Y'
               MOVE 'Y' TO WS-FAIL-FLAG
               MOVE 'ACTIVE SUSPENSION OR DISQUALIFICATION ON FILE'
                   TO WS-HIST-FAIL-MSG
           END-IF
           IF WS-DEMERIT-TOTAL > 12 AND WS-FAIL-FLAG = 'N'
               MOVE 'Y' TO WS-FAIL-FLAG
               MOVE 'TOTAL DEMERIT POINTS EXCEED THRESHOLD OF 12'
                   TO WS-HIST-FAIL-MSG
           END-IF
           IF WS-FINE-FLAG = 'Y' AND WS-FAIL-FLAG = 'N'
               MOVE 'Y' TO WS-FAIL-FLAG
               MOVE 'OUTSTANDING UNPAID FINES ON FILE'
                   TO WS-HIST-FAIL-MSG
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `WS-SUSP-FLAG` | input | Tested as the first and highest-priority failure condition; a value of 'Y' immediately sets the fail flag and records the suspension failure message |
| `WS-DEMERIT-TOTAL` | input | Compared against the threshold of 12 as the second failure condition to determine whether accumulated demerit points cause a history check failure |
| `WS-FINE-FLAG` | input | Tested as the third failure condition; a value of 'Y' sets the fail flag and records the unpaid fines failure message if no prior failure was detected |

#### 2.5.4 Assign History Check Outcome and Update Application Status

**Description:** Sets the history check result to 'F' (fail) or 'P' (pass) and advances the application lifecycle status accordingly: 'RE' (referred/rejected) on failure or 'HC' (history check complete) on pass. The outcome, date, notes, and updated application status are then written back to the license application record.

**Core decision logic:**
- A failed history check sets the history status to 'F' and advances application status to 'RE' (referred)
- A passed history check sets the history status to 'P' and advances application status to 'HC' (history check complete)
- The outcome, check date, failure notes, and new application status are persisted to the license application record

**Code:**
```cobol
           IF WS-FAIL-FLAG = 'Y'
               MOVE 'F'  TO WS-HISTORY-STATUS
               MOVE 'FAIL' TO DHCHSTSO
               MOVE WS-HIST-FAIL-MSG TO DHCHSDSO
               MOVE 'RE' TO APPLICATION-STATUS OF DCLDLIS-LICENSE-APPL
           ELSE
               MOVE 'P'  TO WS-HISTORY-STATUS
               MOVE 'PASS' TO DHCHSTSO
               MOVE SPACES  TO DHCHSDSO
               MOVE 'HC' TO APPLICATION-STATUS OF DCLDLIS-LICENSE-APPL
           END-IF

           EXEC SQL
               UPDATE DLIS.LICENSE_APPLICATION SET
                   HIST_CHECK_STATUS  = :WS-HISTORY-STATUS,
                   HIST_CHECK_DATE    = CURRENT DATE,
                   HIST_CHECK_NOTES   = :WS-HIST-FAIL-MSG,
                   APPLICATION_STATUS = :APPLICATION-STATUS
                                        OF DCLDLIS-LICENSE-APPL,
                   LAST_UPDATED_DATE  = CURRENT DATE,
                   LAST_UPDATED_BY    = EIBTRMID
               WHERE APPLICATION_ID   = :APPLICATION-ID
                                        OF DCLDLIS-LICENSE-APPL
           END-EXEC
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `WS-HISTORY-STATUS` | output | Set to 'F' or 'P' based on the overall history check outcome and written to the application record as the history check result |
| `APPLICATION-STATUS` | output | Set to 'RE' on failure or 'HC' on pass to advance the application's processing lifecycle status, then written back to the database |
| `APPLICATION-ID` | input | Used as the WHERE clause key to identify the correct application record to update with the history check outcome |

#### 2.5.5 Display Final History Check Result Message

**Description:** Presents the final outcome of the history check to the user. A passed check shows a generic success message, while a failed check shows the specific failure reason previously determined.

**Core decision logic:**
- A passed history check displays the message 'HISTORY CHECK PASSED'
- A failed history check displays the specific failure reason message on screen

**Code:**
```cobol
           IF WS-HISTORY-STATUS = 'P'
               MOVE 'HISTORY CHECK PASSED' TO DHCMSG
           ELSE
               MOVE WS-HIST-FAIL-MSG TO DHCMSG
           END-IF.
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `WS-HISTORY-STATUS` | input | Tested against 'P' to choose between displaying the pass confirmation message or the failure reason |

---

Generated by IBM Bob Premium Package for Z
