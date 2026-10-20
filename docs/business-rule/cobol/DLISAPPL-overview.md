# Business rules: Overview

**Program:** DLISAPPL

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Function: Session Lifecycle Management](#2-function-session-lifecycle-management)
  - [2.1 SubFunction: Transaction Entry Point Control](#21-subfunction-transaction-entry-point-control)
  - [2.2 SubFunction: User Action Dispatch](#22-subfunction-user-action-dispatch)
- [3. Function: Candidate Validation and Lookup](#3-function-candidate-validation-and-lookup)
  - [3.1 SubFunction: Candidate Identity Verification](#31-subfunction-candidate-identity-verification)
- [4. Function: Fee Schedule Inquiry](#4-function-fee-schedule-inquiry)
  - [4.1 SubFunction: License Fee Retrieval and Display](#41-subfunction-license-fee-retrieval-and-display)
- [5. Function: License Application Submission](#5-function-license-application-submission)
  - [5.1 SubFunction: Pre-Submission Input Validation](#51-subfunction-pre-submission-input-validation)
  - [5.2 SubFunction: Duplicate Application Prevention](#52-subfunction-duplicate-application-prevention)
  - [5.3 SubFunction: Application Record Creation and Confirmation](#53-subfunction-application-record-creation-and-confirmation)

## 1. Purpose
This document presents a program-level functional view of the business logic in DLISAPPL. Business rules are organised into a Function → SubFunction → Business Rule hierarchy representing the business functions performed in the program. Semantically related rules are consolidated into named SubFunctions that group related business capabilities, and purely technical or setup logic is excluded. Each rule documents its purpose, ordered execution steps with conditions, actions, and outcomes, references to the contributing source paragraphs, and the business significance of each rule.

## 2. Function: Session Lifecycle Management

### 2.1 SubFunction: Transaction Entry Point Control

#### 2.1.1 Business Rule: Initial vs. Re-entry Session Routing

##### 2.1.1.1 Purpose
On every invocation of the transaction, the program determines whether it is being launched for the first time or returning from a prior pseudo-conversational cycle. A first-time launch requires the initial screen to be rendered with no pre-populated data. A re-entry restores the prior session's communication area so that context carried forward — such as transaction ID — is available during input processing.

##### 2.1.1.2 Rule Steps
1. **Detect first-time invocation using communication area length**
   - Conditions: `EIBCALEN = 0` (no communication area passed by CICS)
   - Actions: Route to initial screen display (`INIT-SCREEN`)
   - Outcomes: A blank application entry screen is presented to the user with no prior state.
   - Relevant Paragraphs: `MAIN-LOGIC`

2. **Restore prior session state on re-entry**
   - Conditions: `EIBCALEN > 0` (a communication area exists from the previous task invocation)
   - Actions: Copy `DFHCOMMAREA` into `DLIS-COMMAREA`; record current transaction identifier from `EIBTRNID` into `CA-TRANSACTION-ID`; route to input processing (`PROCESS-INPUT`)
   - Outcomes: Prior session context is fully available for input processing, and the running transaction is identified in the communication area.
   - Relevant Paragraphs: `MAIN-LOGIC`

##### 2.1.1.3 Business Significance
Incorrect session routing would cause either a blank screen to be re-displayed when user input exists (discarding user work) or an uninitialized screen to attempt input processing against empty fields, producing invalid validation results and potentially corrupt application records.

---

### 2.2 SubFunction: User Action Dispatch

#### 2.2.1 Business Rule: Function Key Routing to Business Operations

##### 2.2.1.1 Purpose
On each re-entry, the transaction interprets the user's function key selection to dispatch control to the appropriate business operation. Only a defined set of function keys carries business meaning; all others are rejected with guidance to the user.

##### 2.2.1.2 Rule Steps
1. **Dispatch based on selected function key**
   - Conditions: User has pressed a function key; session state is available in `DLIS-COMMAREA`
   - Actions:
     - F1 → route to application submission (`SUBMIT-APPLICATION`)
     - F3 → route to candidate lookup (`LOOKUP-CANDIDATE`)
     - F5 → route to fee calculation (`CALC-FEE`)
     - F12 → terminate the current transaction session
     - Any other key → display a message specifying the valid key options
   - Outcomes: The correct business process is invoked for the user's intent, or the user is informed of valid choices.
   - Relevant Paragraphs: `PROCESS-INPUT`

##### 2.2.1.3 Business Significance
Misrouting a function key would silently execute the wrong business operation — for example, triggering a submission when the user intended a lookup — leading to unintended application records being created or valid data being discarded.

---

## 3. Function: Candidate Validation and Lookup

### 3.1 SubFunction: Candidate Identity Verification

#### 3.1.1 Business Rule: Candidate ID Presence, Existence, and Active Status Enforcement

##### 3.1.1.1 Purpose
Before any candidate data is displayed or used downstream in an application submission, the system validates that the candidate ID has been entered, that a matching record exists in the database, and that the candidate's record is currently active. All three gates must be passed in sequence; failure at any point stops processing with a descriptive message.

##### 3.1.1.2 Rule Steps
1. **Enforce that a Candidate ID has been entered**
   - Conditions: `CANDIDATE-ID = 0` (field left blank by the user)
   - Actions: Display prompt to enter a candidate ID; halt lookup processing
   - Outcomes: User is informed of the missing required input; no database access occurs.
   - Relevant Paragraphs: `LOOKUP-CANDIDATE`

2. **Retrieve candidate record from the database**
   - Conditions: `CANDIDATE-ID` is non-zero
   - Actions: Execute database lookup using `CANDIDATE-ID` as the unique key; retrieve `FIRST-NAME`, `LAST-NAME`, and `RECORD-STATUS`
   - Outcomes: Candidate record fields are populated in working storage for subsequent validation and display.
   - Relevant Paragraphs: `LOOKUP-CANDIDATE`

3. **Reject lookup when no record exists for the Candidate ID**
   - Conditions: Database returns no row for the supplied `CANDIDATE-ID`
   - Actions: Display 'CANDIDATE NOT FOUND' message; halt lookup processing
   - Outcomes: User is informed the candidate does not exist; no further processing occurs.
   - Relevant Paragraphs: `LOOKUP-CANDIDATE`

4. **Reject lookup for inactive candidate records**
   - Conditions: `RECORD-STATUS = 'I'`
   - Actions: Display inactive candidate error message; halt lookup processing
   - Outcomes: Inactive candidates are blocked from any further processing in this transaction.
   - Relevant Paragraphs: `LOOKUP-CANDIDATE`

5. **Display confirmed active candidate name**
   - Conditions: Candidate record found and `RECORD-STATUS ≠ 'I'`
   - Actions: Concatenate `FIRST-NAME` + space + `LAST-NAME` into the display name field; display 'CANDIDATE FOUND' confirmation message
   - Outcomes: User sees the full candidate name and a confirmation that the candidate is active and eligible.
   - Relevant Paragraphs: `LOOKUP-CANDIDATE`

##### 3.1.1.3 Business Significance
Allowing a lookup to proceed for a non-existent or inactive candidate would permit application submissions against invalid candidate records, creating orphaned or invalid licensing data. The sequential gating ensures only verified, active candidates can advance to the submission stage.

---

## 4. Function: Fee Schedule Inquiry

### 4.1 SubFunction: License Fee Retrieval and Display

#### 4.1.1 Business Rule: Active Initial Fee Schedule Lookup by License Type

##### 4.1.1.1 Purpose
When the user requests a fee calculation, the system retrieves the current, active initial fee amount and its currency for the selected license type from the fee schedule table. The fee schedule entry must be of type 'IF' (initial fee), carry active status, and fall within a valid effective date range covering today's date. If no such entry exists, the user is informed and no fee is displayed.

##### 4.1.1.2 Rule Steps
1. **Enforce that a License Type has been selected**
   - Conditions: `LICENSE-TYPE` is blank or low-values
   - Actions: Display prompt to select a license type; halt fee retrieval
   - Outcomes: User is informed of the missing required selection; no database access occurs.
   - Relevant Paragraphs: `CALC-FEE`

2. **Query the active, currently effective initial fee schedule**
   - Conditions: `LICENSE-TYPE` is non-blank; query filters: fee type = 'IF', `ACTIVE_STATUS = 'A'`, effective date ≤ today, expiry date is null or ≥ today
   - Actions: Retrieve `FEE-AMOUNT` and `CURRENCY-CODE` from the first matching fee schedule row
   - Outcomes: Fee amount and currency code are populated in working storage for validation and display.
   - Relevant Paragraphs: `CALC-FEE`

3. **Reject fee display when no valid schedule entry exists**
   - Conditions: No fee schedule row matches the license type, fee type, active status, and date range criteria
   - Actions: Display message indicating no fee schedule exists for the selected license type; halt fee display
   - Outcomes: User is informed that the selected license type has no applicable fee schedule; no fee is shown.
   - Relevant Paragraphs: `CALC-FEE`

4. **Format and display fee amount with currency to the user**
   - Conditions: A valid fee schedule entry was retrieved
   - Actions: Move `FEE-AMOUNT` to `WS-FEE-AMOUNT`; convert to display format in `WS-FEE-AMOUNT-D`; move `WS-FEE-AMOUNT-D` to screen output field; move `CURRENCY-CODE` to screen currency field; display success confirmation message
   - Outcomes: User sees the correctly formatted fee amount and its currency denomination, confirming successful fee retrieval.
   - Relevant Paragraphs: `CALC-FEE`

##### 4.1.1.3 Business Significance
Displaying an incorrect, expired, or non-existent fee would mislead applicants about the cost of their license application, potentially causing payment discrepancies, disputes, or failed application processing downstream.

---

## 5. Function: License Application Submission

### 5.1 SubFunction: Pre-Submission Input Validation

#### 5.1.1 Business Rule: Mandatory Field and Domain Value Validation

##### 5.1.1.1 Purpose
Before a license application record is created, all required input fields must be present and contain only recognized values. Both the candidate ID and license type are mandatory. The license type is additionally validated against the set of permitted application codes. Any failure blocks the submission with a specific error message.

##### 5.1.1.2 Rule Steps
1. **Enforce presence of Candidate ID**
   - Conditions: `CANDIDATE-ID = 0`
   - Actions: Display error message indicating candidate ID is required; halt submission
   - Outcomes: Submission is blocked; user is prompted to provide a candidate ID.
   - Relevant Paragraphs: `SUBMIT-APPLICATION`

2. **Enforce presence of License Type**
   - Conditions: `LICENSE-TYPE` is blank or low-values
   - Actions: Display error message indicating license type is required; halt submission
   - Outcomes: Submission is blocked; user is prompted to select a license type.
   - Relevant Paragraphs: `SUBMIT-APPLICATION`

3. **Validate License Type against allowed domain values**
   - Conditions: `LICENSE-TYPE` is non-blank but not one of 'L', 'P', or 'O'
   - Actions: Display error message indicating the license type is invalid; halt submission
   - Outcomes: Submission is blocked; only the three recognized license type codes are accepted for new applications.
   - Relevant Paragraphs: `SUBMIT-APPLICATION`

##### 5.1.1.3 Business Significance
Accepting an application with a missing or unrecognized license type would create an unclassifiable licensing record, breaking downstream workflows such as examination scheduling, issuance, and fee processing that depend on a valid, known license category.

---

### 5.2 SubFunction: Duplicate Application Prevention

#### 5.2.1 Business Rule: Block Active Duplicate Application for Same Candidate and License Type

##### 5.2.1.1 Purpose
A candidate may not have more than one in-progress application for the same license type simultaneously. The system counts existing applications for the candidate and license type combination, excluding those with a terminal status of 'RE' (rejected) or 'IS' (issued). Any other status is treated as active, and a match blocks the new submission.

##### 5.2.1.2 Rule Steps
1. **Query existing applications for the candidate and license type**
   - Conditions: `CANDIDATE-ID` is valid and non-zero; `LICENSE-TYPE` is a permitted value
   - Actions: Query the application table filtering by `CANDIDATE-ID` and `LICENSE-TYPE`, excluding records with status 'RE' or 'IS'; store the count result in `APPLICATION-ID`
   - Outcomes: The number of currently active applications for the candidate-license type combination is determined.
   - Relevant Paragraphs: `SUBMIT-APPLICATION`

2. **Block submission when an active application already exists**
   - Conditions: Count in `APPLICATION-ID` > 0 (one or more active applications found)
   - Actions: Display duplicate application error message; halt submission
   - Outcomes: New application is rejected; candidate retains only their existing active application for that license type.
   - Relevant Paragraphs: `SUBMIT-APPLICATION`

##### 5.2.1.3 Business Significance
Without this control, a candidate could accumulate multiple concurrent pending applications for the same license type, creating duplicate processing, conflicting review outcomes, and potential double-issuance of licenses.

---

### 5.3 SubFunction: Application Record Creation and Confirmation

#### 5.3.1 Business Rule: Insert Application with Pending Status and Display System-Generated Reference

##### 5.3.1.1 Purpose
When all validations pass, a new license application record is inserted into the database with an initial status of 'PE' (pending). The terminal ID of the submitting session is captured as the audit creator. Immediately after insertion, the system retrieves the system-generated application identifier and displays it to the user along with the pending status and today's date as confirmation of successful submission.

##### 5.3.1.2 Rule Steps
1. **Insert the new application record**
   - Conditions: All prior validations have passed (valid candidate, valid license type, no active duplicate)
   - Actions: Insert record with `CANDIDATE-ID`, `LICENSE-TYPE`, application status = 'PE', `CREATED-BY` = `EIBTRMID` (terminal ID)
   - Outcomes: A new pending application record exists in the database with a full audit trail of its originating terminal.
   - Relevant Paragraphs: `SUBMIT-APPLICATION`

2. **Retrieve and display the system-generated Application ID**
   - Conditions: Insert has completed successfully
   - Actions: Retrieve the system-generated identity value into `APPLICATION-ID`; display `APPLICATION-ID`, status 'PE', and current date on screen; display success confirmation message
   - Outcomes: User receives their application reference number, the initial pending status, and the submission date as proof of successful registration.
   - Relevant Paragraphs: `SUBMIT-APPLICATION`

##### 5.3.1.3 Business Significance
Failure to display the system-generated application ID would leave the user without a reference number, preventing them from tracking, querying, or following up on their submission. An incorrect initial status would misrepresent the application's position in the review workflow to all downstream processing agents.

---

Generated by IBM Bob Premium Package for Z
