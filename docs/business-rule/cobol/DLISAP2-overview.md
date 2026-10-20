# Business rules: Overview

**Program:** DLISAP2

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Function: Second-Level Approval Authorization and Eligibility Control](#2-function-second-level-approval-authorization-and-eligibility-control)
  - [2.1 SubFunction: Approving Authority Qualification](#21-subfunction-approving-authority-qualification)
  - [2.2 SubFunction: Authority Scope and Segregation of Duties](#22-subfunction-authority-scope-and-segregation-of-duties)
- [3. Function: Second Approval Submission and Decision Processing](#3-function-second-approval-submission-and-decision-processing)
  - [3.1 SubFunction: Approval Request Validation](#31-subfunction-approval-request-validation)
  - [3.2 SubFunction: Application Outcome Determination and Recording](#32-subfunction-application-outcome-determination-and-recording)
  - [3.3 SubFunction: Outcome Communication](#33-subfunction-outcome-communication)

## 1. Purpose
This document presents a program-level functional view of the business logic in DLISAP2. Business rules are organised into a Function → SubFunction → Business Rule hierarchy representing the business functions performed in the program. Semantically related rules are consolidated into named SubFunctions that group related business capabilities, and purely technical or setup logic is excluded. Each rule documents its purpose, ordered execution steps with conditions, actions, and outcomes, references to the contributing source paragraphs, and the business significance of each rule.

## 2. Function: Second-Level Approval Authorization and Eligibility Control

### 2.1 SubFunction: Approving Authority Qualification

#### 2.1.1 Business Rule: Second-Level Authority Eligibility
##### 2.1.1.1 Purpose
Establishes who may act as the second approver of a license application. The approving user must be a known, active user who holds second-level approval authority. The lookup also provides the approver's authority name and the license types that authority may approve. Later checks in the approval flow depend on these values.

##### 2.1.1.2 Rule Steps
1. Look up the approving user and restrict eligibility to active, level-2 users
   - Conditions: User identified by `USER-CODE` must have status 'A' (active) and `AUTHORITY-LEVEL` = '2'.
   - Actions: Retrieve `AUTHORITY-NAME`, `AUTHORITY-LEVEL` and `LIC-TYPES-AUTH` for the matching user.
   - Outcomes: An eligible second approver is identified and their authority profile is made available for later checks.
   - Relevant Paragraphs: VALIDATE-AUTHORITY
2. Reject when no qualifying user exists
   - Conditions: No user matches the code with active status and level 2.
   - Actions: Reject the validation and issue a message.
   - Outcomes: Approval processing cannot continue for an unqualified or unknown user.
   - Relevant Paragraphs: VALIDATE-AUTHORITY

##### 2.1.1.3 Business Significance
If this check is weakened, inactive users or first-level approvers could grant final approval. That would undermine the approval hierarchy, and licenses could be issued without proper authorization.

### 2.2 SubFunction: Authority Scope and Segregation of Duties

#### 2.2.1 Business Rule: Authority Independence from First Approver
##### 2.2.1.1 Purpose
Enforces segregation of duties. The second approval must come from an authority different from the one that gave the first approval, so that the two levels of review are independent.

##### 2.2.1.2 Rule Steps
1. Compare the second approver's authority with the first approver's authority
   - Conditions: `AUTHORITY-NAME` of the second approver must differ from the first approver's authority.
   - Actions: Block the submission if both authorities are the same.
   - Outcomes: Only an independent authority can complete the second approval.
   - Relevant Paragraphs: SUBMIT-APPROVAL2

##### 2.2.1.3 Business Significance
If this check fails, one authority could approve at both levels. That removes the dual-control safeguard and creates audit and compliance exposure.

#### 2.2.2 Business Rule: License Type Authorization Scope
##### 2.2.2.1 Purpose
Restricts an approving authority to the license types it is permitted to approve. This prevents approvals outside the authority's jurisdiction or mandate.

##### 2.2.2.2 Rule Steps
1. Verify the application's license type is covered by the authority
   - Conditions: The application's license type must be included in `LIC-TYPES-AUTH` (populated during authority validation).
   - Actions: Block the approval if the license type is not covered.
   - Outcomes: The second approval proceeds only when the authority is competent for that license type.
   - Relevant Paragraphs: SUBMIT-APPROVAL2, VALIDATE-AUTHORITY

##### 2.2.2.3 Business Significance
Without this check, an authority could approve license types outside its remit. The resulting licenses could be invalid or open to challenge.

## 3. Function: Second Approval Submission and Decision Processing

### 3.1 SubFunction: Approval Request Validation

#### 3.1.1 Business Rule: Valid Decision Required
##### 3.1.1.1 Purpose
Ensures the second approver has made an explicit decision before any processing begins. Only an approval or a rejection is acceptable.

##### 3.1.1.2 Rule Steps
1. Validate the decision value
   - Conditions: `WS-DECISION` must be 'A' (approve) or 'R' (reject).
   - Actions: Block the submission if the value is blank or anything else.
   - Outcomes: Only unambiguous decisions are processed.
   - Relevant Paragraphs: SUBMIT-APPROVAL2

##### 3.1.1.3 Business Significance
An ambiguous or missing decision could leave the application in an undefined state. It could also be misread as a rejection, or as an approval, without an authoritative decision behind it.

#### 3.1.2 Business Rule: Two-Level Approval Sequencing
##### 3.1.2.1 Purpose
Enforces the order of the two-level approval workflow. The second approval is allowed only after the first approval has been granted.

##### 3.1.2.2 Rule Steps
1. Check the first approval outcome
   - Conditions: `APPROVAL-1-STATUS` must be 'A'.
   - Actions: Block the second approval submission if the first approval is not granted.
   - Outcomes: Second-level review occurs only for applications that passed first-level review.
   - Relevant Paragraphs: SUBMIT-APPROVAL2

##### 3.1.2.3 Business Significance
If this check is skipped, applications that were never approved, or were rejected, at the first level could be approved at the second level. That would bypass the first level of the workflow.

### 3.2 SubFunction: Application Outcome Determination and Recording

#### 3.2.1 Business Rule: Application Status Derivation from Second Decision
##### 3.2.1.1 Purpose
Translates the second approver's decision into the overall application status, which determines whether the application proceeds to licensing or is closed.

##### 3.2.1.2 Rule Steps
1. Map the decision to the application status
   - Conditions: `WS-DECISION` = 'A' versus any other value.
   - Actions: Set `APPLICATION-STATUS` to 'AP' (approved) for 'A'; otherwise set it to 'RE' (rejected).
   - Outcomes: The application has a definitive final status.
   - Relevant Paragraphs: SUBMIT-APPROVAL2

##### 3.2.1.3 Business Significance
An incorrect mapping would send rejected applications to license issuance, or close approved ones. Either error has direct customer and regulatory impact.

#### 3.2.2 Business Rule: Persist Second Approval Record
##### 3.2.2.1 Purpose
Creates the auditable record of the second approval on the license application. It captures the decision, the approving authority, the date and notes, and the new overall status.

##### 3.2.2.2 Rule Steps
1. Update the application with the second approval details
   - Conditions: All prior validations passed (decision, sequencing, authority independence, license type scope).
   - Actions: For the application identified by `APPLICATION-ID`, store `WS-DECISION` as the second approval status, `AUTHORITY-NAME` as the second approval authority, along with the approval date and notes, and set `APPLICATION-STATUS`.
   - Outcomes: The application record shows the second approval and its resulting status.
   - Relevant Paragraphs: SUBMIT-APPROVAL2

##### 3.2.2.3 Business Significance
Failure to record the approval leaves the audit trail incomplete. Downstream license issuance and closure processes would then work from stale status data.

### 3.3 SubFunction: Outcome Communication

#### 3.3.1 Business Rule: Outcome Message Selection
##### 3.3.1.1 Purpose
Tells the user the business result of the second approval: either that the license can now be issued or that the application has been rejected and closed.

##### 3.3.1.2 Rule Steps
1. Choose the confirmation message based on the decision
   - Conditions: `WS-DECISION` = 'A' versus 'R'.
   - Actions: For approval, show a "ready for license issue" message. For rejection, show an "application closed" message.
   - Outcomes: The user receives clear guidance on the next step for the application.
   - Relevant Paragraphs: SUBMIT-APPROVAL2

##### 3.3.1.3 Business Significance
A wrong message could prompt users to start license issuance for a closed application. It could also lead them to abandon an approved one, causing operational errors and applicant confusion.

---

Generated by IBM Bob Premium Package for Z
