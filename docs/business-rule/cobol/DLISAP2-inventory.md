# Business rules: Inventory

**Program:** DLISAP2

**Total rules extracted:** 8

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Rule Inventory](#2-rule-inventory)
  - [2.1 Paragraph: VALIDATE-AUTHORITY](#21-paragraph-validate-authority)
  - [2.2 Paragraph: SUBMIT-APPROVAL2](#22-paragraph-submit-approval2)

## 1. Purpose

This document is an inventory of all business rules extracted from DLISAP2, organised at the Paragraph level. Each Paragraph contributes one or more named rule blocks, where each block captures a discrete business policy with its title, decision logic, conditions, actions, outcomes, and the exact source code that realises it. Key variables, when available, are annotated with their role (input or output) and their specific purpose within the rule. References to related Paragraphs called or invoked by each rule are also recorded.

## 2. Rule Inventory

### 2.1 Paragraph: VALIDATE-AUTHORITY

#### 2.1.1 Authority user must be active at level 2

**Description:** Looks up the authority user and accepts only users that are active and hold second-level approval authority. If no such user exists, the validation is rejected with a message.

**Core decision logic:**
- Only users with active status 'A' are eligible as second approver
- Only users with authority level '2' are eligible as second approver
- If no matching user is found, the authority is rejected

**Code:**
```cobol
           EXEC SQL
               SELECT USER_NAME, AUTHORITY_NAME, AUTHORITY_LEVEL,
                      LIC_TYPES_AUTH
               INTO   :USER-NAME, :AUTHORITY-NAME, :AUTHORITY-LEVEL,
                      :LIC-TYPES-AUTH OF DCLDLIS-AUTH-USER
               FROM   DLIS.AUTHORITY_USER
               WHERE  USER_CODE       = :USER-CODE OF DCLDLIS-AUTH-USER
               AND    ACTIVE_STATUS   = 'A'
               AND    AUTHORITY_LEVEL = '2'
           END-EXEC
           IF SQLCODE = 100
               MOVE 'AUTHORITY USER NOT FOUND OR NOT ACTIVE AT LEVEL 2'
                   TO DA2MSG
               GO TO VALIDATE-AUTH-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `USER-CODE` | input | Key used to look up the authority user. |
| `AUTHORITY-NAME` | output | Receives the authority name of the approving user. |
| `AUTHORITY-LEVEL` | output | Receives the approval level, which is restricted to '2' in the query. |
| `LIC-TYPES-AUTH` | output | Receives the license types the authority is permitted to approve. |

### 2.2 Paragraph: SUBMIT-APPROVAL2

#### 2.2.1 Decision must be Approve or Reject

**Description:** Ensures the second approver's decision is either Approve or Reject before the approval is processed.

**Core decision logic:**
- Decision must be 'A' (approve) or 'R' (reject)
- Blank or other values block the submission

**Code:**
```cobol
           IF DA2DECI = SPACES OR DA2DECI NOT IN ('A','R')
               MOVE 'DECISION MUST BE A=APPROVE OR R=REJECT' TO DA2MSG
               GO TO SUBMIT-A2-EXIT
           END-IF
```

#### 2.2.2 First approval must be granted before second approval

**Description:** Enforces the sequence of the two-level approval process: the second approval can only be submitted when the first approval has been granted.

**Core decision logic:**
- Second approval is blocked unless first approval status is 'A'

**Code:**
```cobol
           IF APPROVAL-1-STATUS OF DCLDLIS-LICENSE-APPL NOT = 'A'
               MOVE 'FIRST APPROVAL MUST BE GRANTED BEFORE SECOND'
                   TO DA2MSG
               GO TO SUBMIT-A2-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `APPROVAL-1-STATUS` | input | Outcome of the first approval that must be 'A' to proceed. |

#### 2.2.3 Second approver must be from a different authority

**Description:** Enforces segregation of duties by rejecting a second approver who belongs to the same authority as the first approver.

**Core decision logic:**
- Second approver's authority must differ from the first approver's authority

**Code:**
```cobol
      *    Segregation: second approver must differ from first
           IF AUTHORITY-NAME OF DCLDLIS-AUTH-USER = WS-APPROVAL1-AUTH
               MOVE 'SECOND APPROVER MUST BE FROM DIFFERENT AUTHORITY'
                   TO DA2MSG
               GO TO SUBMIT-A2-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `AUTHORITY-NAME` | input | Authority of the second approver compared against the first approver's authority. |

#### 2.2.4 Authority must be authorised for the license type

**Description:** Checks that the application's license type is among the types the approving authority may approve, blocking the approval otherwise.

**Core decision logic:**
- Approval is blocked if the license type is not covered by the authority's authorised license types

**Code:**
```cobol
      *    Check license type authorisation
           IF DA2LTYO NOT IN LIC-TYPES-AUTH OF DCLDLIS-AUTH-USER
               MOVE 'AUTHORITY NOT AUTHORISED FOR THIS LICENSE TYPE'
                   TO DA2MSG
               GO TO SUBMIT-A2-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `LIC-TYPES-AUTH` | input | List of license types the authority is permitted to approve. |

#### 2.2.5 Derive application status from decision

**Description:** Translates the second approver's decision into the overall application status: approved or rejected.

**Core decision logic:**
- Decision 'A' sets application status to 'AP' (approved)
- Any other decision sets application status to 'RE' (rejected)

**Code:**
```cobol
           MOVE DA2DECI TO WS-DECISION
           IF WS-DECISION = 'A'
               MOVE 'AP' TO APPLICATION-STATUS OF DCLDLIS-LICENSE-APPL
           ELSE
               MOVE 'RE' TO APPLICATION-STATUS OF DCLDLIS-LICENSE-APPL
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `WS-DECISION` | input | Second approver's decision that determines the resulting status. |
| `APPLICATION-STATUS` | output | Receives 'AP' or 'RE' based on the decision. |

#### 2.2.6 Record second approval on the application

**Description:** Persists the second approval decision, approving authority, date, notes, and the new overall application status on the license application record.

**Core decision logic:**
- Second approval outcome and the resulting application status are recorded on the application

**Code:**
```cobol
           EXEC SQL
               UPDATE DLIS.LICENSE_APPLICATION SET
                   APPROVAL_2_STATUS    = :WS-DECISION,
                   APPROVAL_2_AUTHORITY = :AUTHORITY-NAME
                                          OF DCLDLIS-AUTH-USER,
                   APPROVAL_2_DATE      = CURRENT DATE,
                   APPROVAL_2_NOTES     = :DA2DCNTI,
                   APPLICATION_STATUS   = :APPLICATION-STATUS
                                          OF DCLDLIS-LICENSE-APPL,
                   LAST_UPDATED_DATE    = CURRENT DATE,
                   LAST_UPDATED_BY      = :DA2AUCOI
               WHERE APPLICATION_ID     = :APPLICATION-ID
                                          OF DCLDLIS-LICENSE-APPL
           END-EXEC
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `WS-DECISION` | input | Stored as the second approval status. |
| `AUTHORITY-NAME` | input | Recorded as the second approval authority. |
| `APPLICATION-STATUS` | input | New overall application status written to the record. |
| `APPLICATION-ID` | input | Identifies the application record being updated. |

#### 2.2.7 Select confirmation message by decision

**Description:** Communicates the business outcome of the second approval: granted and ready for license issue, or rejected and closed.

**Core decision logic:**
- Approval leads to a 'ready for license issue' message
- Rejection leads to an 'application closed' message

**Code:**
```cobol
           IF WS-DECISION = 'A'
               MOVE 'SECOND APPROVAL GRANTED - READY FOR LICENSE ISSUE'
                   TO DA2MSG
           ELSE
               MOVE 'SECOND APPROVAL REJECTED - APPLICATION CLOSED'
                   TO DA2MSG
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `WS-DECISION` | input | Decision that selects the outcome message. |

---

Generated by IBM Bob Premium Package for Z
