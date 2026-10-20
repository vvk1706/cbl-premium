# Business rules: Overview

**Program:** DLISAP1

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Function: Transaction Session and Operator Navigation](#2-function-transaction-session-and-operator-navigation)
  - [2.1 SubFunction: Session Entry and Action Routing](#21-subfunction-session-entry-and-action-routing)
- [3. Function: Application Retrieval and Review](#3-function-application-retrieval-and-review)
  - [3.1 SubFunction: Application Lookup](#31-subfunction-application-lookup)
  - [3.2 SubFunction: Approver Review Presentation](#32-subfunction-approver-review-presentation)
- [4. Function: Authority User Verification](#4-function-authority-user-verification)
  - [4.1 SubFunction: First-Approval Authority Eligibility](#41-subfunction-first-approval-authority-eligibility)
- [5. Function: First Approval Decision Processing](#5-function-first-approval-decision-processing)
  - [5.1 SubFunction: Pre-Approval Eligibility Controls](#51-subfunction-pre-approval-eligibility-controls)
  - [5.2 SubFunction: Decision Outcome and Recording](#52-subfunction-decision-outcome-and-recording)

## 1. Purpose
This document presents a program-level functional view of the business logic in DLISAP1. Business rules are organised into a Function → SubFunction → Business Rule hierarchy representing the business functions performed in the program. Semantically related rules are consolidated into named SubFunctions that group related business capabilities, and purely technical or setup logic is excluded. Each rule documents its purpose, ordered execution steps with conditions, actions, and outcomes, references to the contributing source paragraphs, and the business significance of each rule.

## 2. Function: Transaction Session and Operator Navigation

### 2.1 SubFunction: Session Entry and Action Routing

#### 2.1.1 Business Rule: New vs. Returning Session Handling
##### 2.1.1.1 Purpose
Determines whether the first-approval transaction is being started fresh or is a continuation of an existing conversation, so the operator either sees a clean screen or has the prior working state restored before input is handled.

##### 2.1.1.2 Rule Steps
1. Distinguish a fresh session from a returning session
   - Conditions: Saved session data length is zero (fresh) versus non-zero (returning).
   - Actions: For a fresh session, initialise the screen. For a returning session, restore the saved session data and process the operator's input.
   - Outcomes: The operator starts with a clean screen on first entry and resumes with preserved context on later interactions.
   - Relevant Paragraphs: MAIN-LOGIC, INIT-SCREEN, PROCESS-INPUT

##### 2.1.1.3 Business Significance
If the session is misclassified, the operator can lose already-loaded application and authority context, or stale data can be reused for a new approval. This can lead to approvals being applied to the wrong application or user.

#### 2.1.2 Business Rule: Function Key Routing to Approval Actions
##### 2.1.2.1 Purpose
Maps each operator function key to a specific business action in the first-approval workflow and gives guidance when an unsupported key is pressed.

##### 2.1.2.2 Rule Steps
1. Route the key press to the matching business action
   - Conditions: F1 pressed; F3 pressed; F4 pressed; F12 pressed; any other key.
   - Actions: F1 submits the first approval. F3 loads the application. F4 validates the authority user. F12 exits the transaction immediately. Any other key displays an instructional message and performs no business action.
   - Outcomes: Only deliberate, recognised key presses trigger approval-related actions; invalid keys are harmlessly redirected.
   - Relevant Paragraphs: PROCESS-INPUT, SUBMIT-APPROVAL1, LOAD-APPLICATION, VALIDATE-AUTHORITY

##### 2.1.2.3 Business Significance
Incorrect routing could trigger an approval submission or authority validation unintentionally, or leave operators unable to exit. Because F1 commits a decision to the license record, accidental invocation has direct business impact.

## 3. Function: Application Retrieval and Review

### 3.1 SubFunction: Application Lookup

#### 3.1.1 Business Rule: Application Identification and Retrieval
##### 3.1.1.1 Purpose
Ensures an application is identified before it is loaded, then retrieves the license application and its candidate details so the approver can review them. Handles the case where the application does not exist.

##### 3.1.1.2 Rule Steps
1. Require an Application ID
   - Conditions: APPLICATION-ID is zero or blank.
   - Actions: Prompt the user to supply an Application ID and stop processing.
   - Outcomes: No lookup is attempted without an identified application.
   - Relevant Paragraphs: LOAD-APPLICATION
2. Retrieve application and candidate details
   - Conditions: APPLICATION-ID supplied.
   - Actions: Read the license application joined to the candidate record by APPLICATION-ID, obtaining APPLICATION-STATUS, LICENSE-TYPE, PAYMENT-STATUS, PAYMENT-REFERENCE, ELIG-CHECK-STATUS, HIST-CHECK-STATUS, FIRST-NAME and LAST-NAME.
   - Outcomes: The full application context is available for review and later approval checks.
   - Relevant Paragraphs: LOAD-APPLICATION
3. Guard against a non-existent application
   - Conditions: No record matches APPLICATION-ID.
   - Actions: Display a not-found message and abort the load.
   - Outcomes: Processing never continues against a non-existent application.
   - Relevant Paragraphs: LOAD-APPLICATION

##### 3.1.1.3 Business Significance
Without these guards, approvers could act on blank or incorrect application data. Retrieved status, payment and license-type values also drive the later approval gates, so incorrect retrieval would corrupt those decisions.

### 3.2 SubFunction: Approver Review Presentation

#### 3.2.1 Business Rule: Display Application Details for Approver Decision
##### 3.2.1.1 Purpose
Presents the information an approving authority needs to make an informed first-approval decision, covering the candidate, license, check outcomes and payment status.

##### 3.2.1.2 Rule Steps
1. Compose and show the review information
   - Conditions: Application successfully retrieved.
   - Actions: Combine FIRST-NAME and LAST-NAME into a single candidate name. Display LICENSE-TYPE, APPLICATION-STATUS, ELIG-CHECK-STATUS, HIST-CHECK-STATUS, PAYMENT-STATUS and PAYMENT-REFERENCE.
   - Outcomes: The approver can see the candidate identity, eligibility and history results, and payment traceability before deciding.
   - Relevant Paragraphs: LOAD-APPLICATION

##### 3.2.1.3 Business Significance
Incomplete or misleading display undermines the quality of the approval decision and the ability to trace payments. This weakens the oversight the approval process is meant to provide.

## 4. Function: Authority User Verification

### 4.1 SubFunction: First-Approval Authority Eligibility

#### 4.1.1 Business Rule: Active Level-1 Authority Validation
##### 4.1.1.1 Purpose
Ensures only a recognised, active, first-level authority user can be used to record a first approval, and confirms the accepted approver's identity to the operator.

##### 4.1.1.2 Rule Steps
1. Require an authority user code
   - Conditions: USER-CODE is blank.
   - Actions: Prompt the operator for a user code and stop validation.
   - Outcomes: Validation is only attempted for an identified user.
   - Relevant Paragraphs: VALIDATE-AUTHORITY
2. Look up an eligible authority user
   - Conditions: Authority user matching USER-CODE must have active status 'A' and AUTHORITY-LEVEL '1'.
   - Actions: Retrieve USER-NAME, AUTHORITY-NAME, AUTHORITY-LEVEL and LIC-TYPES-AUTH (permitted license types) for later checks.
   - Outcomes: Only active level-1 authorities qualify for first-approval rights.
   - Relevant Paragraphs: VALIDATE-AUTHORITY
3. Reject unknown or ineligible users
   - Conditions: No active level-1 authority is found for USER-CODE.
   - Actions: Display an ineligibility message and block validation and approval.
   - Outcomes: Unqualified users cannot proceed with an approval.
   - Relevant Paragraphs: VALIDATE-AUTHORITY
4. Confirm the validated approver on screen
   - Conditions: Validation succeeded.
   - Actions: Display USER-NAME and AUTHORITY-NAME.
   - Outcomes: The operator can verify which approver was accepted.
   - Relevant Paragraphs: VALIDATE-AUTHORITY

##### 4.1.1.3 Business Significance
This is the primary control over who may grant a first approval. A failure allows inactive, wrong-level or unknown users to approve license applications, creating segregation-of-duties and compliance exposure.

## 5. Function: First Approval Decision Processing

### 5.1 SubFunction: Pre-Approval Eligibility Controls

#### 5.1.1 Business Rule: Mandatory Input Validation
##### 5.1.1.1 Purpose
Ensures the approval submission is complete and unambiguous before any further approval checks or updates are made.

##### 5.1.1.2 Rule Steps
1. Validate required inputs
   - Conditions: APPLICATION-ID must be non-zero; USER-CODE must be non-blank; WS-DECISION must be 'A' (approve) or 'R' (reject).
   - Actions: Refuse submission with a message if any condition fails.
   - Outcomes: Only complete submissions with an explicit approve or reject decision continue.
   - Relevant Paragraphs: SUBMIT-APPROVAL1

##### 5.1.1.3 Business Significance
Submitting without a target application, approver or valid decision could record meaningless or incorrect approvals on the license record.

#### 5.1.2 Business Rule: Payment Completion Gate
##### 5.1.2.1 Purpose
Prevents first approval from being granted on an application for which payment has not been completed.

##### 5.1.2.2 Rule Steps
1. Verify payment status
   - Conditions: PAYMENT-STATUS must equal 'P' (paid).
   - Actions: If not paid, block the approval submission and notify the operator.
   - Outcomes: Only paid applications can proceed to first approval.
   - Relevant Paragraphs: SUBMIT-APPROVAL1

##### 5.1.2.3 Business Significance
Bypassing this gate could advance or approve applications without fee collection, causing revenue loss and inconsistent application records.

#### 5.1.3 Business Rule: License Type Authorization
##### 5.1.3.1 Purpose
Ensures an authority can approve only those license types within its remit.

##### 5.1.3.2 Rule Steps
1. Check license type against authority scope
   - Conditions: The application's LICENSE-TYPE must appear in the authority's LIC-TYPES-AUTH.
   - Actions: If it is outside the permitted list, refuse the approval.
   - Outcomes: Approvals are limited to license categories the authority is authorised to handle.
   - Relevant Paragraphs: SUBMIT-APPROVAL1

##### 5.1.3.3 Business Significance
Failure permits approvals outside an authority's jurisdiction, creating regulatory and audit risk.

### 5.2 SubFunction: Decision Outcome and Recording

#### 5.2.1 Business Rule: Application Status Determination from Decision
##### 5.2.1.1 Purpose
Translates the first authority's decision into the next lifecycle state of the application.

##### 5.2.1.2 Rule Steps
1. Map decision to status
   - Conditions: WS-DECISION is 'A' or 'R'.
   - Actions: 'A' sets APPLICATION-STATUS to 'A2' (forwarded for second approval). 'R' sets it to 'RE' (rejected/closed).
   - Outcomes: The application either moves on to second approval or is closed.
   - Relevant Paragraphs: SUBMIT-APPROVAL1

##### 5.2.1.3 Business Significance
An incorrect mapping would send rejected applications on for further approval or close approved ones, directly altering license outcomes.

#### 5.2.2 Business Rule: First Approval Persistence and Audit Trail
##### 5.2.2.1 Purpose
Permanently records the first approval decision, the deciding authority and the resulting application status, along with audit information.

##### 5.2.2.2 Rule Steps
1. Update the application record
   - Conditions: All validations and authorization checks passed.
   - Actions: For the record identified by APPLICATION-ID, write WS-DECISION to APPROVAL_1_STATUS, AUTHORITY-NAME to APPROVAL_1_AUTHORITY, the approval date and decision notes, and the new APPLICATION-STATUS.
   - Outcomes: The decision and new lifecycle state are durably stored.
   - Relevant Paragraphs: SUBMIT-APPROVAL1
2. Stamp audit fields
   - Conditions: Update is being made.
   - Actions: Set last-updated date to the current date and LAST_UPDATED_BY to USER-CODE.
   - Outcomes: Each decision is attributable to a specific user and time.
   - Relevant Paragraphs: SUBMIT-APPROVAL1

##### 5.2.2.3 Business Significance
Failure to persist accurately breaks the approval chain and the audit trail required for accountability and compliance review.

#### 5.2.3 Business Rule: Approval Outcome Confirmation
##### 5.2.3.1 Purpose
Tells the operator the result of the submission so they know whether the application was forwarded or closed.

##### 5.2.3.2 Rule Steps
1. Show outcome message
   - Conditions: Approval saved; WS-DECISION is 'A' or 'R'.
   - Actions: 'A' shows confirmation that the application is forwarded for second approval. 'R' shows confirmation that it has been rejected and closed.
   - Outcomes: The operator receives clear feedback on the decision's effect.
   - Relevant Paragraphs: SUBMIT-APPROVAL1

##### 5.2.3.3 Business Significance
Unclear or wrong confirmation could cause the operator to believe an application is progressing when it is closed (or vice versa), leading to repeated submissions or missed follow-up.

---

Generated by IBM Bob Premium Package for Z
