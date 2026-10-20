# Business rules: Inventory

**Program:** DLISELIG

**Total rules extracted:** 6

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Rule Inventory](#2-rule-inventory)
  - [2.1 Paragraph: RUN-ELIGIBILITY-CHECK](#21-paragraph-run-eligibility-check)

## 1. Purpose

This document is an inventory of all business rules extracted from DLISELIG, organised at the Paragraph level. Each Paragraph contributes one or more named rule blocks, where each block captures a discrete business policy with its title, decision logic, conditions, actions, outcomes, and the exact source code that realises it. Key variables, when available, are annotated with their role (input or output) and their specific purpose within the rule. References to related Paragraphs called or invoked by each rule are also recorded.

## 2. Rule Inventory

### 2.1 Paragraph: RUN-ELIGIBILITY-CHECK

#### 2.1.1 Calculate applicant age

**Description:** Derives the applicant's age in years by subtracting the birth year from the current year. The result is used for the minimum-age eligibility rules and displayed on the screen.

**Core decision logic:**
- Age is computed as the difference between the current year and the birth year, ignoring month and day

**Code:**
```cobol
           MOVE DATE-OF-BIRTH OF DCLDLIS-CANDIDATE(1:4)
               TO WS-DOB-YEAR
           MOVE CURRENT-DATE(1:4) TO WS-CURR-YEAR
           COMPUTE WS-CALC-AGE = WS-CURR-YEAR - WS-DOB-YEAR
           MOVE WS-CALC-AGE TO DECAGEO
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `DATE-OF-BIRTH` | input | Source of the birth year used in the age calculation. |
| `WS-DOB-YEAR` | output | Holds the extracted birth year. |
| `WS-CURR-YEAR` | output | Holds the current year extracted from the current date. |
| `WS-CALC-AGE` | output | Receives the calculated age in years. |

#### 2.1.2 Minimum age check by license type

**Description:** Enforces the minimum age for each license type. The applicant is flagged as failing, with a reason, if below the required age.

**Core decision logic:**
- Learner license requires minimum age 16
- Probation license requires minimum age 17
- Open license requires minimum age 18
- Failure flag and reason are set when the age requirement is not met

**Code:**
```cobol
           MOVE 'N' TO WS-FAIL-FLAG
           MOVE SPACES TO WS-ELIG-FAIL-REASON

      *    Age check
           EVALUATE LICENSE-TYPE OF DCLDLIS-LICENSE-APPL
               WHEN 'L'
                   IF WS-CALC-AGE < 16
                       MOVE 'Y' TO WS-FAIL-FLAG
                       MOVE 'AGE BELOW 16 - LEARNER LICENSE REQUIRES MIN        
                           TO WS-ELIG-FAIL-REASON
                   END-IF
               WHEN 'P'
                   IF WS-CALC-AGE < 17
                       MOVE 'Y' TO WS-FAIL-FLAG
                       MOVE 'AGE BELOW 17 - PROBATION LICENSE REQUIRES M        
                           TO WS-ELIG-FAIL-REASON
                   END-IF
               WHEN 'O'
                   IF WS-CALC-AGE < 18
                       MOVE 'Y' TO WS-FAIL-FLAG
                       MOVE 'AGE BELOW 18 - OPEN LICENSE REQUIRES MIN AG        
                           TO WS-ELIG-FAIL-REASON
                   END-IF
           END-EVALUATE
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `LICENSE-TYPE` | input | Selects which minimum age rule applies. |
| `WS-CALC-AGE` | input | Applicant age compared against the minimum. |
| `WS-FAIL-FLAG` | output | Initialized to 'N' and set to 'Y' when the age check fails. |
| `WS-ELIG-FAIL-REASON` | output | Initialized to spaces and receives the age failure reason. |

#### 2.1.3 Probation license prerequisite check

**Description:** For a probation license applicant who passed the age check, verifies the candidate holds an active learner license. The applicant fails eligibility otherwise.

**Core decision logic:**
- Only evaluated for Probation applications not already failed
- Applicant must have at least one active Learner license
- Absence of an active learner license sets failure flag and reason

**Code:**
```cobol
           IF LICENSE-TYPE OF DCLDLIS-LICENSE-APPL = 'P'
                           AND WS-FAIL-FLAG = 'N'
               EXEC SQL
                   SELECT COUNT(*) INTO :WS-PRIOR-COUNT
                   FROM   DLIS.ISSUED_LICENSE
                   WHERE  CANDIDATE_ID   = :CANDIDATE-ID
                                           OF DCLDLIS-LICENSE-APPL
                   AND    LICENSE_TYPE   = 'L'
                   AND    LICENSE_STATUS = 'A'
               END-EXEC
               IF WS-PRIOR-COUNT = 0
                   MOVE 'Y' TO WS-FAIL-FLAG
                   MOVE 'MUST HOLD ACTIVE LEARNER LICENSE FOR PROBATION'        
                       TO WS-ELIG-FAIL-REASON
               END-IF
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `LICENSE-TYPE` | input | Determines that the probation prerequisite rule applies. |
| `WS-FAIL-FLAG` | input | Gates the check to applicants not already failed, and is set to 'Y' on failure. |
| `WS-PRIOR-COUNT` | output | Receives the count of active learner licenses. |
| `CANDIDATE-ID` | input | Identifies the candidate whose licenses are counted. |
| `WS-ELIG-FAIL-REASON` | output | Receives the missing-learner-license reason. |

#### 2.1.4 Open license prerequisite check

**Description:** For an open license applicant who passed the age check, verifies the candidate holds an active probation license. The applicant fails eligibility otherwise.

**Core decision logic:**
- Only evaluated for Open applications not already failed
- Applicant must have at least one active Probation license
- Absence of an active probation license sets failure flag and reason

**Code:**
```cobol
           IF LICENSE-TYPE OF DCLDLIS-LICENSE-APPL = 'O'
                           AND WS-FAIL-FLAG = 'N'
               EXEC SQL
                   SELECT COUNT(*) INTO :WS-PRIOR-COUNT
                   FROM   DLIS.ISSUED_LICENSE
                   WHERE  CANDIDATE_ID   = :CANDIDATE-ID
                                           OF DCLDLIS-LICENSE-APPL
                   AND    LICENSE_TYPE   = 'P'
                   AND    LICENSE_STATUS = 'A'
               END-EXEC
               IF WS-PRIOR-COUNT = 0
                   MOVE 'Y' TO WS-FAIL-FLAG
                   MOVE 'MUST HOLD ACTIVE PROBATION LICENSE FOR OPEN'
                       TO WS-ELIG-FAIL-REASON
               END-IF
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `LICENSE-TYPE` | input | Determines that the open prerequisite rule applies. |
| `WS-FAIL-FLAG` | input | Gates the check to applicants not already failed, and is set to 'Y' on failure. |
| `WS-PRIOR-COUNT` | output | Receives the count of active probation licenses. |
| `CANDIDATE-ID` | input | Identifies the candidate whose licenses are counted. |
| `WS-ELIG-FAIL-REASON` | output | Receives the missing-probation-license reason. |

#### 2.1.5 Determine eligibility outcome and application status

**Description:** Translates the accumulated check results into an eligibility status and a new application status. Failed applicants are rejected ('RE'), passing applicants are cleared ('EC').

**Core decision logic:**
- Any failure marks eligibility as Fail and application status as Rejected (RE)
- No failure marks eligibility as Pass and application status as Eligibility Cleared (EC)

**Code:**
```cobol
           IF WS-FAIL-FLAG = 'Y'
               MOVE 'F' TO WS-ELIGIBILITY-STATUS
               MOVE 'FAIL'             TO DECESTSO
               MOVE WS-ELIG-FAIL-REASON TO DECENTSO
               MOVE 'RE'              TO APPLICATION-STATUS
                                         OF DCLDLIS-LICENSE-APPL
           ELSE
               MOVE 'P' TO WS-ELIGIBILITY-STATUS
               MOVE 'PASS' TO DECESTSO
               MOVE SPACES TO DECENTSO
               MOVE 'EC'   TO APPLICATION-STATUS
                               OF DCLDLIS-LICENSE-APPL
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `WS-FAIL-FLAG` | input | Determines pass or fail outcome. |
| `WS-ELIGIBILITY-STATUS` | output | Set to 'F' or 'P' reflecting the result. |
| `WS-ELIG-FAIL-REASON` | input | Failure reason displayed on fail. |
| `APPLICATION-STATUS` | output | Set to 'RE' or 'EC' per outcome. |

#### 2.1.6 Persist eligibility result to license application

**Description:** Updates the license application record with the eligibility check status, date, notes, new application status, and the user who performed the check.

**Core decision logic:**
- Application status and eligibility results are recorded as a domain state change on the application

**Code:**
```cobol
           EXEC SQL
               UPDATE DLIS.LICENSE_APPLICATION SET
                   ELIG_CHECK_STATUS = :WS-ELIGIBILITY-STATUS,
                   ELIG_CHECK_DATE   = CURRENT DATE,
                   ELIG_CHECK_NOTES  = :WS-ELIG-FAIL-REASON,
                   APPLICATION_STATUS= :APPLICATION-STATUS
                                       OF DCLDLIS-LICENSE-APPL,
                   LAST_UPDATED_DATE = CURRENT DATE,
                   LAST_UPDATED_BY   = :DECCHKBYI
               WHERE APPLICATION_ID  = :APPLICATION-ID
                                       OF DCLDLIS-LICENSE-APPL
           END-EXEC
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `WS-ELIGIBILITY-STATUS` | input | Eligibility result stored on the application. |
| `WS-ELIG-FAIL-REASON` | input | Stored as eligibility check notes. |
| `APPLICATION-STATUS` | input | New application status stored. |
| `APPLICATION-ID` | input | Identifies the application to update. |

---

Generated by IBM Bob Premium Package for Z
