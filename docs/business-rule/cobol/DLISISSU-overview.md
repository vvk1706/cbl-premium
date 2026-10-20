# Business rules: Overview

**Program:** DLISISSU

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Function: Issuance Workflow Control](#2-function-issuance-workflow-control)
  - [2.1 SubFunction: Transaction Entry and Action Routing](#21-subfunction-transaction-entry-and-action-routing)
- [3. Function: Application Retrieval and Eligibility Review](#3-function-application-retrieval-and-eligibility-review)
  - [3.1 SubFunction: Application Loading](#31-subfunction-application-loading)
- [4. Function: License Issuance](#4-function-license-issuance)
  - [4.1 SubFunction: Issuance Pre-Conditions](#41-subfunction-issuance-pre-conditions)
  - [4.2 SubFunction: License Attribute Derivation](#42-subfunction-license-attribute-derivation)
  - [4.3 SubFunction: License Record Creation](#43-subfunction-license-record-creation)
- [5. Function: License Printing](#5-function-license-printing)
  - [5.1 SubFunction: Print Authorisation and Invocation](#51-subfunction-print-authorisation-and-invocation)

## 1. Purpose
This document presents a program-level functional view of the business logic in DLISISSU. Business rules are organised into a Function → SubFunction → Business Rule hierarchy representing the business functions performed in the program. Semantically related rules are consolidated into named SubFunctions that group related business capabilities, and purely technical or setup logic is excluded. Each rule documents its purpose, ordered execution steps with conditions, actions, and outcomes, references to the contributing source paragraphs, and the business significance of each rule.

## 2. Function: Issuance Workflow Control

### 2.1 SubFunction: Transaction Entry and Action Routing

#### 2.1.1 Business Rule: First-Entry vs. Returning Transaction Handling
##### 2.1.1.1 Purpose
Determines whether the officer is starting a new license issuance session or continuing an existing one. State is preserved across the multi-step workflow (load application, issue license, print license) by saving and restoring the communication area. A fresh session starts from a clean screen, and a returning session restores prior state before any input is processed.
##### 2.1.1.2 Rule Steps
1. Detect a fresh transaction entry
   - Conditions: The communication area length (EIBCALEN) is zero.
   - Actions: Initialise the screen for the officer.
   - Outcomes: A new session starts with a clean, initialised screen.
   - Relevant Paragraphs: MAIN-LOGIC (INIT-SCREEN)
2. Restore workflow state on a returning transaction
   - Conditions: EIBCALEN is non-zero.
   - Actions: Restore DLIS-COMMAREA from DFHCOMMAREA, then process the officer's input.
   - Outcomes: Prior workflow state is carried forward into input processing.
   - Relevant Paragraphs: MAIN-LOGIC (PROCESS-INPUT)
##### 2.1.1.3 Business Significance
If state restoration fails, the officer loses the loaded application context between interactions. This can cause issuance against the wrong or an empty application, or force repeated data entry. Re-initialising a screen mid-session would discard validated data.

#### 2.1.2 Business Rule: Function Key Routing for License Issuance Workflow
##### 2.1.2.1 Purpose
Restricts the officer to a defined set of actions and routes each one to the matching business function. Any other key triggers guidance, which enforces the allowed interaction model.
##### 2.1.2.2 Rule Steps
1. Route a recognised function key to its business action
   - Conditions: The key pressed is F1, F3, F6 or F12.
   - Actions:
     - F1 invokes license issuance (ISSUE-LICENSE).
     - F3 invokes application loading (LOAD-APPLICATION).
     - F6 invokes license printing (PRINT-LICENSE).
     - F12 terminates the transaction.
   - Outcomes: The selected business operation is executed or the session ends.
   - Relevant Paragraphs: PROCESS-INPUT
2. Reject an unrecognised key
   - Conditions: The key pressed is none of F1, F3, F6 or F12.
   - Actions: Display a guidance message restricting the officer to the defined function keys.
   - Outcomes: No business action is taken and the officer is told which keys are valid.
   - Relevant Paragraphs: PROCESS-INPUT
3. Preserve the workflow state after the action
   - Conditions: The transaction continues after a non-exit action.
   - Actions: Return control to CICS with DLIS-COMMAREA to maintain state for the next cycle.
   - Outcomes: The workflow continues in a pseudo-conversational manner.
   - Relevant Paragraphs: PROCESS-INPUT
##### 2.1.2.3 Business Significance
Incorrect routing could trigger issuance or printing unintentionally. Uncontrolled keys could bypass the intended sequence of load, issue and print, which compromises control over a regulated document.

## 3. Function: Application Retrieval and Eligibility Review

### 3.1 SubFunction: Application Loading

#### 3.1.1 Business Rule: Application ID Presence Validation
##### 3.1.1.1 Purpose
An Application ID is required before any application can be retrieved. This prevents lookups without a defined target.
##### 3.1.1.2 Rule Steps
1. Verify that an Application ID is provided
   - Conditions: APPLICATION-ID is blank or zero.
   - Actions: Prompt the officer to enter the Application ID and halt further processing.
   - Outcomes: The load is blocked until a valid identifier is supplied.
   - Relevant Paragraphs: LOAD-APPLICATION
##### 3.1.1.3 Business Significance
Without this check, the lookup may fail ambiguously or return unintended data. The officer would then make issuance decisions on missing or wrong application information.

#### 3.1.2 Business Rule: Display of Pre-Issuance Eligibility Gate Statuses
##### 3.1.2.1 Purpose
Shows the officer every gate that must be satisfied before issuance, so they can judge readiness. These are the candidate's name, license type, eligibility check, history check, payment, and first- and second-level approvals. A successful load also sets the "APPLICATION LOADED" message, which the issuance function uses as a gate.
##### 3.1.2.2 Rule Steps
1. Present the candidate and gate statuses on the map
   - Conditions: The application has been found for the supplied APPLICATION-ID.
   - Actions: Display the candidate's full name, LICENSE-TYPE, ELIG-CHECK-STATUS, HIST-CHECK-STATUS, PAYMENT-STATUS, APPROVAL-1-STATUS and APPROVAL-2-STATUS.
   - Outcomes: The officer can see whether eligibility, history, payment and dual approval requirements are met.
   - Relevant Paragraphs: LOAD-APPLICATION
2. Confirm a successful load
   - Conditions: The application data was displayed successfully.
   - Actions: Set the message to "APPLICATION LOADED".
   - Outcomes: The issuance process can recognise that an application has been reviewed.
   - Relevant Paragraphs: LOAD-APPLICATION (consumed by ISSUE-LICENSE)
##### 3.1.2.3 Business Significance
If statuses are shown incompletely or incorrectly, the officer may approve an application with unmet prerequisites. This weakens the dual-approval, payment and background-check controls.

## 4. Function: License Issuance

### 4.1 SubFunction: Issuance Pre-Conditions

#### 4.1.1 Business Rule: Mandatory Input Validation for Issuance
##### 4.1.1.1 Purpose
Ensures every mandatory input is present and valid before a license is created. This guarantees the license has a traceable source application, a valid vehicle class, and a named officer and authority.
##### 4.1.1.2 Rule Steps
1. Require an Application ID
   - Conditions: APPLICATION-ID is absent.
   - Actions: Halt issuance with a descriptive message.
   - Outcomes: Issuance is blocked.
   - Relevant Paragraphs: ISSUE-LICENSE
2. Validate the vehicle class
   - Conditions: VEHICLE-CLASS is not one of A, B, C or D, or is blank.
   - Actions: Halt issuance with a descriptive message.
   - Outcomes: Only permitted vehicle classes proceed.
   - Relevant Paragraphs: ISSUE-LICENSE
3. Require the issuing officer
   - Conditions: ISSUED-BY-OFFICER is absent.
   - Actions: Halt issuance with a descriptive message.
   - Outcomes: Accountability for the issuance is guaranteed.
   - Relevant Paragraphs: ISSUE-LICENSE
4. Require the issuing authority
   - Conditions: ISSUED-BY-AUTH is absent.
   - Actions: Halt issuance with a descriptive message.
   - Outcomes: The issuing organisation is always identified.
   - Relevant Paragraphs: ISSUE-LICENSE
##### 4.1.1.3 Business Significance
Missing or invalid inputs would yield licenses with an invalid vehicle class, no accountable officer, or no issuing authority. This creates audit and legal exposure for an official document.

#### 4.1.2 Business Rule: Approved-Status Eligibility Gate
##### 4.1.2.1 Purpose
Allows a license to be issued only when the application has reached the fully approved status. This enforces completion of all upstream checks and approvals.
##### 4.1.2.2 Rule Steps
1. Check the application status
   - Conditions: APPLICATION-STATUS is not 'AP' (Approved).
   - Actions: Block issuance and inform the officer that the application is ineligible.
   - Outcomes: Only fully approved applications proceed to license creation.
   - Relevant Paragraphs: ISSUE-LICENSE
##### 4.1.2.3 Business Significance
Bypassing this gate could produce licenses for applications that have not passed the eligibility, history, payment or dual-approval controls. This is a regulatory and fraud risk. It also allows reissuance of applications already issued ('IS').

### 4.2 SubFunction: License Attribute Derivation

#### 4.2.1 Business Rule: Expiry Date and Number Prefix Assignment by License Type
##### 4.2.1.1 Purpose
Sets the validity period and the number prefix that distinguish Learner, Probationary and Open licenses.
##### 4.2.1.2 Rule Steps
1. Assign validity and prefix by license type
   - Conditions: LICENSE-TYPE is 'L', 'P' or 'O'.
   - Actions:
     - 'L' (Learner): 1-year validity, prefix 'LRN'.
     - 'P' (Probationary): 2-year validity, prefix 'PRB'.
     - 'O' (Open/Full): 5-year validity, prefix 'OPN'.
   - Outcomes: The expiry year and prefix are determined.
   - Relevant Paragraphs: ISSUE-LICENSE
2. Assemble the expiry date
   - Conditions: The expiry year has been calculated.
   - Actions: Combine the expiry year with the current month and day into WS-EXPIRY-DATE.
   - Outcomes: The expiry date falls on the anniversary of issue.
   - Relevant Paragraphs: ISSUE-LICENSE
##### 4.2.1.3 Business Significance
An incorrect validity period lets licenses remain valid longer or expire sooner than the law allows. A wrong prefix mislabels the license class.

#### 4.2.2 Business Rule: License Number Generation
##### 4.2.2.1 Purpose
Builds a unique, meaningful identifier for each license. It encodes the license type, vehicle class, candidate and originating application.
##### 4.2.2.2 Rule Steps
1. Concatenate the identifier components
   - Conditions: The prefix, VEHICLE-CLASS, CANDIDATE-ID and APPLICATION-ID are available.
   - Actions: Build WS-LICENSE-NUMBER as prefix + vehicle class + candidate ID + application ID, in that order.
   - Outcomes: A unique license number linking the license to its holder and source application.
   - Relevant Paragraphs: ISSUE-LICENSE
##### 4.2.2.3 Business Significance
A non-unique or malformed number would break lookup, printing, enforcement and demerit tracking. It could also cause identity confusion between holders.

### 4.3 SubFunction: License Record Creation

#### 4.3.1 Business Rule: Issued License Record Creation
##### 4.3.1.1 Purpose
Creates the official license record in DLIS.ISSUED_LICENSE. This is the core business event that brings the license into existence with full attribution.
##### 4.3.1.2 Rule Steps
1. Insert the issued license with initial state
   - Conditions: All validation and eligibility gates have passed, and the license number and expiry date have been derived.
   - Actions: Insert APPLICATION-ID, CANDIDATE-ID, WS-LICENSE-NUMBER, LICENSE-TYPE, issue and WS-EXPIRY-DATE, VEHICLE-CLASS, restrictions, ISSUED-BY-OFFICER and ISSUED-BY-AUTH. Set the status to 'A' (Active) and the demerit balance to 12.
   - Outcomes: An active license with a full demerit allowance is created and attributed to a named officer and authority.
   - Relevant Paragraphs: ISSUE-LICENSE
##### 4.3.1.3 Business Significance
A failed or partial insert leaves the candidate without a legal license, or leaves a license with wrong status or demerit balance. This distorts the later enforcement and suspension rules that depend on the starting balance.

#### 4.3.2 Business Rule: Application Closure and Issuance Confirmation
##### 4.3.2.1 Purpose
Closes the originating application by marking it as issued and confirms the outcome to the officer. This prevents the same application from being issued again.
##### 4.3.2.2 Rule Steps
1. Mark the application as issued
   - Conditions: The issued license record was created successfully.
   - Actions: Update LICENSE_APPLICATION for the matching APPLICATION-ID, setting APPLICATION-STATUS to 'IS' and recording the date and the officer as last updater.
   - Outcomes: The application workflow is closed with an audit trail.
   - Relevant Paragraphs: ISSUE-LICENSE
2. Confirm the result to the officer
   - Conditions: The status update completed.
   - Actions: Show WS-LICENSE-NUMBER and WS-EXPIRY-DATE on the map and set a success message.
   - Outcomes: The officer sees the license number and expiry, and the license becomes eligible for printing.
   - Relevant Paragraphs: ISSUE-LICENSE
##### 4.3.2.3 Business Significance
If the status is not updated, the same approved application could be used to issue duplicate licenses. If the license number is not displayed, the printing gate would block the follow-on step.

## 5. Function: License Printing

### 5.1 SubFunction: Print Authorisation and Invocation

#### 5.1.1 Business Rule: Print Eligibility Gate and Print Invocation
##### 5.1.1.1 Purpose
Ensures only a successfully issued license can be printed. Issuance is evidenced by a license number being present on screen. When the gate is passed, the print program is invoked.
##### 5.1.1.2 Rule Steps
1. Verify that the license has been issued
   - Conditions: No license number is present on the screen.
   - Actions: Block printing and inform the officer.
   - Outcomes: Printing cannot precede issuance.
   - Relevant Paragraphs: PRINT-LICENSE
2. Invoke the print program
   - Conditions: A license number is present.
   - Actions: Link to DLISLPRT with DLIS-COMMAREA and set a confirmation message.
   - Outcomes: The physical or electronic license document is produced and the officer is notified.
   - Relevant Paragraphs: PRINT-LICENSE
##### 5.1.1.3 Business Significance
Printing without an issued license could produce unauthorised or invalid documents. A missing commarea in the call would leave the print program without the issuance context, resulting in blank or wrong documents.

---

Generated by IBM Bob Premium Package for Z
