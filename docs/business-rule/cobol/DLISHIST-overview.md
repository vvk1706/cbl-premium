# Business rules: Overview

**Program:** DLISHIST

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Function: Transaction Session and User Interaction Control](#2-function-transaction-session-and-user-interaction-control)
  - [2.1 SubFunction: Session Navigation and Action Routing](#21-subfunction-session-navigation-and-action-routing)
- [3. Function: Application Intake and Candidate Identification](#3-function-application-intake-and-candidate-identification)
  - [3.1 SubFunction: Application Lookup and Presentation](#31-subfunction-application-lookup-and-presentation)
- [4. Function: Driving History Assessment](#4-function-driving-history-assessment)
  - [4.1 SubFunction: Incident Analysis and Risk Indicator Derivation](#41-subfunction-incident-analysis-and-risk-indicator-derivation)
- [5. Function: Driving History Check Decisioning and Application Status Management](#5-function-driving-history-check-decisioning-and-application-status-management)
  - [5.1 SubFunction: History Check Eligibility Gating](#51-subfunction-history-check-eligibility-gating)
  - [5.2 SubFunction: History Check Pass/Fail Determination](#52-subfunction-history-check-passfail-determination)
  - [5.3 SubFunction: Outcome Recording and Application Lifecycle Update](#53-subfunction-outcome-recording-and-application-lifecycle-update)

## 1. Purpose
This document presents a program-level functional view of the business logic in DLISHIST. Business rules are organised into a Function → SubFunction → Business Rule hierarchy representing the business functions performed in the program. Semantically related rules are consolidated into named SubFunctions that group related business capabilities, and purely technical or setup logic is excluded. Each rule documents its purpose, ordered execution steps with conditions, actions, and outcomes, references to the contributing source paragraphs, and the business significance of each rule.

## 2. Function: Transaction Session and User Interaction Control

### 2.1 SubFunction: Session Navigation and Action Routing

#### 2.1.1 Business Rule: Initial vs. Returning Session Handling
##### 2.1.1.1 Purpose
Determines whether the driving history transaction is being started for the first time or continued from a previous interaction. This keeps the multi-turn, stateful conversation coherent: a new session starts with a fresh screen, and a returning session restores prior state and processes the user's input.
##### 2.1.1.2 Rule Steps
1. Detect whether prior session state exists
   - Conditions: Session state area length is zero (EIBCALEN = 0) means a first-time invocation; otherwise state exists.
   - Actions: For a first invocation, initialise the screen. For a returning invocation, restore the saved state and process the user's input.
   - Outcomes: The user sees a clean initial screen on first entry, or continues the in-progress interaction on later entries.
   - Relevant Paragraphs: MAIN-LOGIC, PROCESS-INPUT
##### 2.1.1.3 Business Significance
If the session type is misidentified, the user could lose in-progress application and history context, or stale data could be displayed against a new request. This leads to incorrect or confusing history review.

#### 2.1.2 Business Rule: Function Key Action Routing
##### 2.1.2.1 Purpose
Maps each user key press to a specific business action in the driving history workflow. This gives users a controlled set of operations: run the check, load an application, scroll the history list, or exit.
##### 2.1.2.2 Rule Steps
1. Route the key press to the matching business action
   - Conditions: F1 = run history check; F3 = load application and its history; F7 = scroll backward; F8 = scroll forward; F12 = exit; any other key.
   - Actions: Invoke the history check, application load, or history display, or end the transaction. For an unrecognised key, show usage guidance.
   - Outcomes: Only supported operations are executed; invalid keys are redirected with guidance.
   - Relevant Paragraphs: PROCESS-INPUT, RUN-HISTORY-CHECK, LOAD-APPLICATION, DISPLAY-HISTORY
2. Apply scroll paging rules to the history list
   - Conditions: F7 scrolls back by 7 rows and cannot go below position 1. F8 scrolls forward by 7 rows.
   - Actions: Adjust the scroll position by 7 rows in the requested direction, applying a floor of 1 when scrolling backward, then redisplay the history.
   - Outcomes: Users can page through up to 50 retained incidents without moving to an invalid position.
   - Relevant Paragraphs: PROCESS-INPUT, DISPLAY-HISTORY
##### 2.1.2.3 Business Significance
Incorrect routing could trigger a history check or status update when the user intended only to browse, or could block users from reviewing the incident list that supports the decision. An invalid scroll position could cause display errors.

## 3. Function: Application Intake and Candidate Identification

### 3.1 SubFunction: Application Lookup and Presentation

#### 3.1.1 Business Rule: Application ID Required
##### 3.1.1.1 Purpose
Ensures that every load or history-check action targets a specific license application. An absent application ID (zero) cannot be used to identify a record, so processing is stopped and the user is prompted.
##### 3.1.1.2 Rule Steps
1. Validate that an application ID has been entered
   - Conditions: APPLICATION-ID equals zero.
   - Actions: Prompt the user to enter an application ID and stop processing for that request. This applies to both the load action and the history check action.
   - Outcomes: No database lookup or status change is attempted without an identifiable application.
   - Relevant Paragraphs: LOAD-APPLICATION, RUN-HISTORY-CHECK
##### 3.1.1.3 Business Significance
Without this guard, queries could return no or wrong records, and a history outcome could be recorded against the wrong or no application, undermining the licensing audit trail.

#### 3.1.2 Business Rule: Retrieve and Display Application and Candidate Details
##### 3.1.2.1 Purpose
Locates the license application and its candidate and shows the applicant's identity and license category, so the reviewer is confident which applicant's driving history is being assessed.
##### 3.1.2.2 Rule Steps
1. Retrieve the application and joined candidate record
   - Conditions: The application ID is used as the key to join the license application and candidate records. If no match exists, the application is not found.
   - Actions: Obtain CANDIDATE-ID, LICENSE-TYPE, and the candidate first and last name. If not found, notify the user and stop.
   - Outcomes: Application and candidate context is loaded, or the user is told the application does not exist.
   - Relevant Paragraphs: LOAD-APPLICATION
2. Format applicant identity for the screen
   - Conditions: Application and candidate data have been retrieved.
   - Actions: Build the candidate display name as first name, a single space, then last name. Copy LICENSE-TYPE to the screen output field.
   - Outcomes: The reviewer sees the applicant's full name and license category.
   - Relevant Paragraphs: LOAD-APPLICATION
##### 3.1.2.3 Business Significance
Misidentifying the applicant or license type could cause a history decision to be reviewed or applied to the wrong person or license category, creating compliance and customer-service risk.

## 4. Function: Driving History Assessment

### 4.1 SubFunction: Incident Analysis and Risk Indicator Derivation

#### 4.1.1 Business Rule: Demerit Point Accumulation and Incident Retention
##### 4.1.1.1 Purpose
Collects the candidate's driving incidents for review and totals demerit points across all of them, producing the figure used for the demerit threshold test.
##### 4.1.1.2 Rule Steps
1. Retain incidents for display
   - Conditions: Each fetched history incident, up to 50 rows.
   - Actions: Store INCIDENT-DATE, INCIDENT-TYPE, description, and DEMERIT-POINTS in the history display table.
   - Outcomes: A scrollable incident list is available to the reviewer.
   - Relevant Paragraphs: LOAD-HISTORY-TABLE
2. Accumulate demerit points
   - Conditions: Every fetched incident, including those beyond the 50 retained rows.
   - Actions: Add DEMERIT-POINTS to WS-DEMERIT-TOTAL.
   - Outcomes: A complete demerit total reflects the full driving record.
   - Relevant Paragraphs: LOAD-HISTORY-TABLE
##### 4.1.1.3 Business Significance
An understated demerit total could allow a candidate with excessive points to pass. Truncating the total at the 50-row display limit would have the same effect.

#### 4.1.2 Business Rule: Active Suspension or Disqualification Detection
##### 4.1.2.1 Purpose
Identifies candidates who are currently suspended or disqualified, which is a disqualifying condition for progressing the license application.
##### 4.1.2.2 Rule Steps
1. Restrict evaluation to suspension and disqualification incidents
   - Conditions: INCIDENT-TYPE is 'SU' or 'DQ'.
   - Actions: Evaluate only these incidents for active status.
   - Outcomes: Other incident types do not affect the suspension indicator.
   - Relevant Paragraphs: LOAD-HISTORY-TABLE
2. Determine whether the sanction is still active
   - Conditions: SUSP-END-DATE is on or after today's date, or is blank (open-ended).
   - Actions: Set WS-SUSP-FLAG to 'Y'.
   - Outcomes: The candidate is flagged for history check failure due to a current suspension or disqualification.
   - Relevant Paragraphs: LOAD-HISTORY-TABLE
##### 4.1.2.3 Business Significance
Missing an active suspension or disqualification (especially open-ended ones) could lead to licensing a person who is legally barred from driving.

#### 4.1.3 Business Rule: Outstanding Unpaid Fine Detection
##### 4.1.3.1 Purpose
Identifies candidates with fines still owing, which prevents the history check from passing.
##### 4.1.3.2 Rule Steps
1. Evaluate fined incidents for payment status
   - Conditions: FINE-AMOUNT is greater than zero and FINE-PAID-STATUS is 'N'.
   - Actions: Set WS-FINE-FLAG to 'Y'.
   - Outcomes: The candidate is flagged for history check failure due to unpaid fines.
   - Relevant Paragraphs: LOAD-HISTORY-TABLE
##### 4.1.3.3 Business Significance
Failing to detect unpaid fines allows candidates with outstanding financial obligations to progress, resulting in lost revenue and inconsistent enforcement.

#### 4.1.4 Business Rule: Summary Indicators Shown for Review
##### 4.1.4.1 Purpose
Presents the derived risk indicators to the reviewer before the formal check is run, supporting informed decisions.
##### 4.1.4.2 Rule Steps
1. Surface summary indicators on screen
   - Conditions: History loading has completed.
   - Actions: Move WS-DEMERIT-TOTAL, WS-SUSP-FLAG, and WS-FINE-FLAG to the screen output fields.
   - Outcomes: The reviewer sees total demerit points, suspension status, and outstanding fine status.
   - Relevant Paragraphs: LOAD-HISTORY-TABLE
##### 4.1.4.3 Business Significance
If indicators are missing or inconsistent with what the check uses, the reviewer cannot anticipate or verify the outcome, which weakens transparency and complicates dispute handling.

## 5. Function: Driving History Check Decisioning and Application Status Management

### 5.1 SubFunction: History Check Eligibility Gating

#### 5.1.1 Business Rule: Eligibility Must Be Passed Before History Check
##### 5.1.1.1 Purpose
Enforces the licensing process sequence: the driving history check may only run after the applicant has passed the eligibility check.
##### 5.1.1.2 Rule Steps
1. Retrieve eligibility status
   - Conditions: A valid APPLICATION-ID has been entered.
   - Actions: Read ELIG-CHECK-STATUS from the license application record.
   - Outcomes: The current eligibility result is available for the gate.
   - Relevant Paragraphs: RUN-HISTORY-CHECK
2. Block the check when eligibility has not been passed
   - Conditions: ELIG-CHECK-STATUS is not 'P'.
   - Actions: Stop the history check and show a message requiring eligibility to be completed first.
   - Outcomes: Only eligibility-passed applications proceed to history evaluation.
   - Relevant Paragraphs: RUN-HISTORY-CHECK
##### 5.1.1.3 Business Significance
Bypassing this gate could let ineligible applicants progress, breaking the prescribed workflow and producing application status inconsistencies.

### 5.2 SubFunction: History Check Pass/Fail Determination

#### 5.2.1 Business Rule: Prioritised Failure Condition Evaluation
##### 5.2.1.1 Purpose
Determines whether the driving history fails by applying three criteria in strict priority order, recording only the first failure reason for the user and the record.
##### 5.2.1.2 Rule Steps
1. Test for active suspension or disqualification (highest priority)
   - Conditions: WS-SUSP-FLAG = 'Y'.
   - Actions: Set the fail flag and record the suspension failure message.
   - Outcomes: History check fails with a suspension reason.
   - Relevant Paragraphs: RUN-HISTORY-CHECK
2. Test for excessive demerit points
   - Conditions: No prior failure and WS-DEMERIT-TOTAL > 12.
   - Actions: Set the fail flag and record the demerit failure message.
   - Outcomes: History check fails with a demerit reason.
   - Relevant Paragraphs: RUN-HISTORY-CHECK
3. Test for outstanding unpaid fines
   - Conditions: No prior failure and WS-FINE-FLAG = 'Y'.
   - Actions: Set the fail flag and record the unpaid fines failure message.
   - Outcomes: History check fails with an unpaid fines reason; if no condition triggers, the check passes.
   - Relevant Paragraphs: RUN-HISTORY-CHECK
##### 5.2.1.3 Business Significance
Incorrect thresholds or priority order would change who passes, and which reason is reported to the applicant, causing wrongful approvals or rejections and inconsistent explanations.

### 5.3 SubFunction: Outcome Recording and Application Lifecycle Update

#### 5.3.1 Business Rule: Assign Outcome and Advance Application Status
##### 5.3.1.1 Purpose
Converts the pass/fail decision into a persisted history result and moves the application to the next lifecycle state.
##### 5.3.1.2 Rule Steps
1. Assign history result and application status
   - Conditions: Failure results in WS-HISTORY-STATUS = 'F'; a pass results in 'P'.
   - Actions: Set APPLICATION-STATUS to 'RE' (referred) on failure or 'HC' (history check complete) on pass.
   - Outcomes: The application advances to the state corresponding to the result.
   - Relevant Paragraphs: RUN-HISTORY-CHECK
2. Persist the outcome
   - Conditions: The result and status have been determined for the APPLICATION-ID.
   - Actions: Update the license application with the history result, check date, failure notes, and new application status.
   - Outcomes: The decision and its reason are durably recorded for downstream processing and audit.
   - Relevant Paragraphs: RUN-HISTORY-CHECK
##### 5.3.1.3 Business Significance
A wrong or unrecorded status would stall or misroute the application, such as allowing a failed applicant to proceed or leaving a passed applicant stuck. It would also leave no audit trail.

#### 5.3.2 Business Rule: Present Final History Check Result
##### 5.3.2.1 Purpose
Informs the user of the outcome, showing a simple confirmation on a pass and the specific reason on a failure.
##### 5.3.2.2 Rule Steps
1. Select the message by outcome
   - Conditions: WS-HISTORY-STATUS = 'P' versus any other value.
   - Actions: Display 'HISTORY CHECK PASSED' for a pass; otherwise display the recorded failure reason.
   - Outcomes: The user understands the result and, if failed, the reason.
   - Relevant Paragraphs: RUN-HISTORY-CHECK
##### 5.3.2.3 Business Significance
Unclear or incorrect messages could mislead staff about the applicant's status and lead to incorrect communication with applicants or unnecessary escalations.

---

Generated by IBM Bob Premium Package for Z
