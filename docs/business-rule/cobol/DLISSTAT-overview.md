# Business rules: Overview

**Program:** DLISSTAT

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Function: License Application Status Inquiry Management](#2-function-license-application-status-inquiry-management)
  - [2.1 SubFunction: Inquiry Request Control and Input Validation](#21-subfunction-inquiry-request-control-and-input-validation)
  - [2.2 SubFunction: Application Workflow Status Tracking and Reporting](#22-subfunction-application-workflow-status-tracking-and-reporting)

## 1. Purpose
This document presents a program-level functional view of the business logic in DLISSTAT. Business rules are organised into a Function → SubFunction → Business Rule hierarchy representing the business functions performed in the program. Semantically related rules are consolidated into named SubFunctions that group related business capabilities, and purely technical or setup logic is excluded. Each rule documents its purpose, ordered execution steps with conditions, actions, and outcomes, references to the contributing source paragraphs, and the business significance of each rule.

## 2. Function: License Application Status Inquiry Management

### 2.1 SubFunction: Inquiry Request Control and Input Validation

#### 2.1.1 Business Rule: Status Inquiry Request and Key Validation
##### 2.1.1.1 Purpose
Controls transaction entry, user navigation flow, and validates that a valid Application ID is provided before attempting to retrieve workflow tracking records.

##### 2.1.1.2 Rule Steps
1. Determine session entry state
   - Conditions: Check the communication area length upon transaction invocation.
   - Actions: If the communication area length is zero, initialize the inquiry screen for a new session; if greater than zero, proceed to process the submitted user interaction.
   - Outcomes: Routes the user to screen initialization or input processing based on session context.
   - Relevant Paragraphs: `MAIN-LOGIC`
2. Evaluate user navigation command
   - Conditions: User submits an action key from the inquiry interface.
   - Actions: If the ENTER key is pressed, initiate application inquiry; if the F12 key is pressed, terminate and exit the transaction; if any other key is pressed, display an informative guidance message.
   - Outcomes: Governs user progression and guards against unauthorized or invalid navigation inputs.
   - Relevant Paragraphs: `PROCESS-INPUT`
3. Validate presence of mandatory Application ID
   - Conditions: User initiates status inquiry via the ENTER key.
   - Actions: Verify that an Application ID has been entered in the input field. If blank, halt execution and issue a validation prompt requesting the identifier.
   - Outcomes: Prevents downstream database query execution with null search criteria.
   - Relevant Paragraphs: `INQUIRE-STATUS`

##### 2.1.1.3 Business Significance
Prevents empty or invalid database operations, ensures predictable conversational navigation, and guarantees that downstream status evaluations are always grounded in a specific, identifiable application record.

---

### 2.2 SubFunction: Application Workflow Status Tracking and Reporting

#### 2.2.1 Business Rule: Application Lifecycle Progress and Stage Result Resolution
##### 2.2.1.1 Purpose
Retrieves and decodes the multi-stage operational status of a license application across eligibility verification, history background check, fee payment, and dual-authority approval milestones.

##### 2.2.1.2 Rule Steps
1. Query workflow status record
   - Conditions: Valid `APPLICATION-ID` is provided.
   - Actions: Query the database for the application record matching `APPLICATION-ID` to retrieve `LICENSE-TYPE`, `APPLICATION-STATUS`, `ELIG-CHECK-STATUS`, `ELIG-CHECK-DATE`, `HIST-CHECK-STATUS`, `HIST-CHECK-DATE`, `PAYMENT-STATUS`, `PAYMENT-REFERENCE`, `APPROVAL-1-STATUS`, `APPROVAL-1-AUTHORITY`, `APPROVAL-2-STATUS`, and `APPROVAL-2-AUTHORITY`.
   - Outcomes: Obtains comprehensive workflow audit history for the license application.
   - Relevant Paragraphs: `INQUIRE-STATUS`
2. Validate record existence
   - Conditions: Application search query returns no record for the supplied `APPLICATION-ID`.
   - Actions: Abort status compilation and present an "Application Not Found" notification to the user.
   - Outcomes: Terminates processing cleanly when an unknown application identifier is queried.
   - Relevant Paragraphs: `INQUIRE-STATUS`
3. Translate internal status codes to descriptive workflow stages
   - Conditions: Application record successfully retrieved.
   - Actions: Map `APPLICATION-STATUS` to human-readable milestone text:
     - `PE`: Pending Eligibility Check
     - `EC`: Eligibility Checked / Awaiting History Check
     - `HC`: History Checked / Awaiting Payment
     - `PA`: Payment Approved / Awaiting First Authority Approval
     - `A2`: Awaiting Second Authority Approval
     - `AP`: Fully Approved / Ready for Issuance
     - `IS`: License Issued
     - `RE`: Application Rejected
     - Any unrecognized code: Unknown Status
   - Outcomes: Generates a clear, standardized operational status description for external and internal stakeholders.
   - Relevant Paragraphs: `INQUIRE-STATUS`
4. Assemble multi-stage processing history
   - Conditions: Application record is active and resolved.
   - Actions: Move eligibility results (`ELIG-CHECK-STATUS`, `ELIG-CHECK-DATE`), background history checks (`HIST-CHECK-STATUS`, `HIST-CHECK-DATE`), financial reconciliation data (`PAYMENT-STATUS`, `PAYMENT-REFERENCE`), and dual approval determinations (`APPROVAL-1-STATUS`, `APPROVAL-1-AUTHORITY`, `APPROVAL-2-STATUS`, `APPROVAL-2-AUTHORITY`) into interface display fields.
   - Outcomes: Exposes end-to-end operational traceability across all application processing gates.
   - Relevant Paragraphs: `INQUIRE-STATUS`

##### 2.2.1.3 Business Significance
Ensures complete transparency of regulatory compliance and workflow progress across departmental boundaries, allowing service agents and applicants to identify bottlenecks, pending approvals, or rejection rationales accurately.

---

#### 2.2.2 Business Rule: Issued Credential Details Resolution
##### 2.2.2.1 Purpose
Determines whether an application has completed the full lifecycle to credential issuance, retrieving official license identification and expiration data when applicable.

##### 2.2.2.2 Rule Steps
1. Evaluate license issuance qualification
   - Conditions: Examine `APPLICATION-STATUS` on the retrieved record.
   - Actions: Check if `APPLICATION-STATUS` equals `IS` (License Issued). If it does not equal `IS`, set the issued license indicator to `NO` and bypass issued credential retrieval.
   - Outcomes: Prevents retrieval of non-existent credential records for applications still in progress or rejected.
   - Relevant Paragraphs: `INQUIRE-STATUS`
2. Retrieve issued license credentials
   - Conditions: `APPLICATION-STATUS` equals `IS`.
   - Actions: Query the issued license database using `APPLICATION-ID` to retrieve `LICENSE-NUMBER` and `EXPIRY-DATE`.
   - Outcomes: Obtains legal credential identifier and validity expiration date for fully issued licenses.
   - Relevant Paragraphs: `INQUIRE-STATUS`
3. Confirm issuance indicator
   - Conditions: Issued license record retrieval succeeds.
   - Actions: Set the issued license indicator to `YES` and map `LICENSE-NUMBER` and `EXPIRY-DATE` to screen display fields. If the record is missing despite status `IS`, maintain the indicator as `NO`.
   - Outcomes: Displays verified legal driver's license details on the user interface.
   - Relevant Paragraphs: `INQUIRE-STATUS`

##### 2.2.2.3 Business Significance
Prevents premature disclosure of license identifiers before all approvals are finalized, while guaranteeing that legally active credentials display verifiable license numbers and expiration dates for enforcement and compliance auditing.

---

Generated by IBM Bob Premium Package for Z
