# Business rules: Overview

**Program:** DLISCAND

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Function: Transaction Entry and Request Routing](#2-function-transaction-entry-and-request-routing)
  - [2.1 SubFunction: Session Entry Handling](#21-subfunction-session-entry-handling)
  - [2.2 SubFunction: Function Key Dispatch](#22-subfunction-function-key-dispatch)
- [3. Function: Candidate Registration](#3-function-candidate-registration)
  - [3.1 SubFunction: Pre-Creation Validation](#31-subfunction-pre-creation-validation)
  - [3.2 SubFunction: Candidate Record Creation](#32-subfunction-candidate-record-creation)
- [4. Function: Candidate Maintenance](#4-function-candidate-maintenance)
  - [4.1 SubFunction: Candidate Update](#41-subfunction-candidate-update)
  - [4.2 SubFunction: Candidate Deactivation](#42-subfunction-candidate-deactivation)
- [5. Function: Candidate Inquiry](#5-function-candidate-inquiry)
  - [5.1 SubFunction: Candidate Lookup and Display](#51-subfunction-candidate-lookup-and-display)

## 1. Purpose
This document presents a program-level functional view of the business logic in DLISCAND. Business rules are organised into a Function → SubFunction → Business Rule hierarchy representing the business functions performed in the program. Semantically related rules are consolidated into named SubFunctions that group related business capabilities, and purely technical or setup logic is excluded. Each rule documents its purpose, ordered execution steps with conditions, actions, and outcomes, references to the contributing source paragraphs, and the business significance of each rule.

## 2. Function: Transaction Entry and Request Routing

### 2.1 SubFunction: Session Entry Handling

#### 2.1.1 Business Rule: First-Time vs. Return Entry Determination

##### 2.1.1.1 Purpose
Determines whether the user is starting a new candidate-maintenance session or continuing an existing conversation. A fresh session presents a blank screen. A returning session restores the saved context and processes what the user entered.

##### 2.1.1.2 Rule Steps
1. Detect a fresh session.
   - Conditions: Commarea length is zero.
   - Actions: Initialise the candidate maintenance screen for new input.
   - Outcomes: The user sees a clean screen and no input is processed.
   - Relevant Paragraphs: MAIN-LOGIC, INIT-SCREEN
2. Detect a returning session.
   - Conditions: Commarea length is non-zero.
   - Actions: Restore the saved commarea data and pass control to user input processing.
   - Outcomes: The user's request is processed with the prior context preserved.
   - Relevant Paragraphs: MAIN-LOGIC, PROCESS-INPUT

##### 2.1.1.3 Business Significance
If the two entry modes are confused, users could see stale data from a prior interaction, or their input could be discarded. Either error can cause candidate records to be maintained against the wrong context.

### 2.2 SubFunction: Function Key Dispatch

#### 2.2.1 Business Rule: Function Key to Candidate Operation Mapping

##### 2.2.1.1 Purpose
Maps each function key to one candidate lifecycle operation, giving users a fixed set of actions: create, update, inquire, deactivate and exit. Any other key is rejected.

##### 2.2.1.2 Rule Steps
1. Route a recognised function key to its operation.
   - Conditions: F1 creates, F2 updates, F3 inquires, F4 deactivates.
   - Actions: Invoke the matching candidate operation.
   - Outcomes: The requested candidate operation runs.
   - Relevant Paragraphs: PROCESS-INPUT, CREATE-CANDIDATE, UPDATE-CANDIDATE, INQUIRE-CANDIDATE, DEACTIVATE-CANDIDATE
2. Handle exit.
   - Conditions: F12 is pressed.
   - Actions: End the transaction.
   - Outcomes: The user leaves the candidate maintenance session.
   - Relevant Paragraphs: PROCESS-INPUT
3. Reject unsupported keys.
   - Conditions: Any key other than F1, F2, F3, F4 or F12.
   - Actions: Display an invalid key message.
   - Outcomes: No operation runs and the user is told to choose a valid key.
   - Relevant Paragraphs: PROCESS-INPUT

##### 2.2.1.3 Business Significance
Incorrect routing could trigger the wrong operation, for example deactivating a candidate when an inquiry was intended. This would change candidate data unintentionally.

## 3. Function: Candidate Registration

### 3.1 SubFunction: Pre-Creation Validation

#### 3.1.1 Business Rule: Mandatory Identity Fields for New Candidates

##### 3.1.1.1 Purpose
Ensures every new candidate has a first name, last name and National ID, so each record can be identified and matched to a real person.

##### 3.1.1.2 Rule Steps
1. Check the mandatory fields.
   - Conditions: FIRST-NAME, LAST-NAME or ID-NUMBER is missing.
   - Actions: Stop processing and show the error message specific to the missing field.
   - Outcomes: No candidate is created until all three fields are supplied.
   - Relevant Paragraphs: CREATE-CANDIDATE

##### 3.1.1.3 Business Significance
Without these checks, incomplete candidate records would enter the database. This would hamper later identification, duplicate detection and National ID lookups.

#### 3.1.2 Business Rule: Duplicate Active Candidate Prevention

##### 3.1.2.1 Purpose
Prevents the same person from being registered twice while an active record already exists under the same National ID. Only active records count, so a person with an inactive record can be registered again.

##### 3.1.2.2 Rule Steps
1. Search for an existing active candidate.
   - Conditions: A record exists with ID-NUMBER equal to the entered value and RECORD-STATUS = 'A'.
   - Actions: Look up CANDIDATE-ID for the matching record.
   - Outcomes: A match identifies a duplicate.
   - Relevant Paragraphs: CREATE-CANDIDATE
2. Block creation if a duplicate exists.
   - Conditions: An active match was found.
   - Actions: Halt creation and inform the user.
   - Outcomes: No second active record is created for the same National ID.
   - Relevant Paragraphs: CREATE-CANDIDATE
3. Allow creation if the match is inactive or absent.
   - Conditions: No active record has the same ID-NUMBER.
   - Actions: Continue to record insertion.
   - Outcomes: Registration may proceed.
   - Relevant Paragraphs: CREATE-CANDIDATE

##### 3.1.2.3 Business Significance
Failing to prevent duplicates would create conflicting candidate profiles for one person. This undermines the integrity of National ID lookups and of any downstream use of the records.

### 3.2 SubFunction: Candidate Record Creation

#### 3.2.1 Business Rule: Create Active Candidate with Audit Stamp

##### 3.2.1.1 Purpose
Persists a new candidate with full personal, address and contact details. The record starts as active and is stamped with the creating terminal for audit purposes.

##### 3.2.1.2 Rule Steps
1. Insert the candidate record.
   - Conditions: Mandatory field and duplicate checks have passed.
   - Actions: Store FIRST-NAME, LAST-NAME, DATE-OF-BIRTH, ID-NUMBER, ADDRESS-LINE-1, ADDRESS-LINE-2, CITY, STATE-PROVINCE, POSTAL-CODE, COUNTRY, PHONE-NUMBER and EMAIL-ADDRESS. Set RECORD-STATUS to 'A' and set CREATED-BY to the terminal identifier.
   - Outcomes: A new active candidate exists, traceable to its originating terminal.
   - Relevant Paragraphs: CREATE-CANDIDATE
2. Return the generated ID and confirm.
   - Conditions: The insert succeeded.
   - Actions: Retrieve the system-generated CANDIDATE-ID, show it on the screen and display a success message.
   - Outcomes: The user receives the new identifier for later update, inquiry or deactivation.
   - Relevant Paragraphs: CREATE-CANDIDATE

##### 3.2.1.3 Business Significance
An incorrect initial status or a missing audit stamp would leave records invisible to duplicate checks or untraceable to their creator. If the generated ID is not shown, the user cannot easily find the record for subsequent maintenance.

## 4. Function: Candidate Maintenance

### 4.1 SubFunction: Candidate Update

#### 4.1.1 Business Rule: Candidate Update with Mandatory Target Identification

##### 4.1.1.1 Purpose
Allows changes to an existing candidate's name, address, contact details and status, and only when the target record is explicitly identified by Candidate ID.

##### 4.1.1.2 Rule Steps
1. Validate that the target is identified.
   - Conditions: CANDIDATE-ID is not provided.
   - Actions: Stop the update and return an error message.
   - Outcomes: No update is attempted without a target.
   - Relevant Paragraphs: UPDATE-CANDIDATE
2. Apply the update.
   - Conditions: CANDIDATE-ID is present.
   - Actions: Modify FIRST-NAME, LAST-NAME, ADDRESS-LINE-1, ADDRESS-LINE-2, CITY, STATE-PROVINCE, POSTAL-CODE, COUNTRY, PHONE-NUMBER, EMAIL-ADDRESS and RECORD-STATUS in one operation.
   - Outcomes: The record reflects the new values.
   - Relevant Paragraphs: UPDATE-CANDIDATE
3. Communicate the result.
   - Conditions: The update finds no matching candidate, succeeds, or fails with a database error.
   - Actions: Show a "not found" message, a success confirmation, or a database error message accordingly.
   - Outcomes: The user knows whether the change was applied.
   - Relevant Paragraphs: UPDATE-CANDIDATE

##### 4.1.1.3 Business Significance
Updating without a valid target risks changing the wrong record or none at all. Because RECORD-STATUS is updatable here, an error could also reactivate or deactivate a candidate unintentionally. Misleading result messages could lead users to believe a change was saved when it was not.

### 4.2 SubFunction: Candidate Deactivation

#### 4.2.1 Business Rule: Logical Deactivation of a Candidate

##### 4.2.1.1 Purpose
Retires a candidate without deleting data by setting its status to inactive ('I'). The record is retained for history, and inactive candidates no longer block re-registration under the same National ID.

##### 4.2.1.2 Rule Steps
1. Validate that the target is identified.
   - Conditions: CANDIDATE-ID is not provided.
   - Actions: Stop the operation and prompt the user.
   - Outcomes: Deactivation is not attempted without a target.
   - Relevant Paragraphs: DEACTIVATE-CANDIDATE
2. Set the candidate inactive.
   - Conditions: CANDIDATE-ID is present.
   - Actions: Set RECORD-STATUS to 'I' for the matching record.
   - Outcomes: The candidate becomes inactive.
   - Relevant Paragraphs: DEACTIVATE-CANDIDATE
3. Communicate the result.
   - Conditions: No matching candidate is found, the deactivation succeeds, or a database error occurs.
   - Actions: Show a "not found" message, or on success update the screen status field to 'I' with a confirmation message, or show a database error message.
   - Outcomes: The user sees the outcome and the screen reflects the new status.
   - Relevant Paragraphs: DEACTIVATE-CANDIDATE

##### 4.2.1.3 Business Significance
Deactivating the wrong candidate, or failing to deactivate one, affects the candidate's eligibility. It also affects whether the active-duplicate check blocks later registrations. Using a logical rather than a physical removal preserves history for audit and recovery.

## 5. Function: Candidate Inquiry

### 5.1 SubFunction: Candidate Lookup and Display

#### 5.1.1 Business Rule: Search Key Requirement for Inquiry

##### 5.1.1.1 Purpose
Requires the user to supply at least one search key, either Candidate ID or National ID, so that inquiries are directed at a specific person and not a broad scan.

##### 5.1.1.2 Rule Steps
1. Verify that a search key is present.
   - Conditions: Both CANDIDATE-ID and ID-NUMBER are missing.
   - Actions: Halt the inquiry and prompt the user to supply a key.
   - Outcomes: No lookup runs without a key.
   - Relevant Paragraphs: INQUIRE-CANDIDATE

##### 5.1.1.3 Business Significance
Without this rule, an inquiry with no criteria could return arbitrary data or fail unpredictably. That would expose personal information about the wrong candidate.

#### 5.1.2 Business Rule: Candidate Retrieval and Profile Presentation

##### 5.1.2.1 Purpose
Finds a candidate by Candidate ID or by National ID. It then presents the full profile, including the current active or inactive status, so the user can verify the candidate's details and standing.

##### 5.1.2.2 Rule Steps
1. Locate the candidate record.
   - Conditions: CANDIDATE-ID or ID-NUMBER is provided. ID-NUMBER serves as the alternate key when CANDIDATE-ID is absent.
   - Actions: Read the matching record, including FIRST-NAME, LAST-NAME, DATE-OF-BIRTH, address fields, PHONE-NUMBER, EMAIL-ADDRESS and RECORD-STATUS.
   - Outcomes: The candidate data is available for display.
   - Relevant Paragraphs: INQUIRE-CANDIDATE
2. Handle a missing candidate.
   - Conditions: No record matches the supplied key.
   - Actions: Display a "not found" message and end the inquiry.
   - Outcomes: The user knows no such candidate exists.
   - Relevant Paragraphs: INQUIRE-CANDIDATE
3. Display the candidate profile.
   - Conditions: A matching record was retrieved.
   - Actions: Move CANDIDATE-ID, names, DATE-OF-BIRTH, ID-NUMBER, address fields, PHONE-NUMBER, EMAIL-ADDRESS and RECORD-STATUS to the screen, then show a success message.
   - Outcomes: The user sees the complete candidate profile and can tell whether the candidate is active or inactive.
   - Relevant Paragraphs: INQUIRE-CANDIDATE

##### 5.1.2.3 Business Significance
Incorrect retrieval or display could show details of the wrong person or a misleading status. The user would then base update or deactivation decisions on inaccurate information.

---

Generated by IBM Bob Premium Package for Z
