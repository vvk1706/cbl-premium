# Business rules: Overview

**Program:** DLISELIG

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Function: License Eligibility Determination](#2-function-license-eligibility-determination)
  - [2.1 SubFunction: Applicant Age Verification](#21-subfunction-applicant-age-verification)
  - [2.2 SubFunction: License Progression Prerequisite Verification](#22-subfunction-license-progression-prerequisite-verification)
  - [2.3 SubFunction: Eligibility Outcome Determination and Application Status Update](#23-subfunction-eligibility-outcome-determination-and-application-status-update)

## 1. Purpose
This document presents a program-level functional view of the business logic in DLISELIG. Business rules are organised into a Function → SubFunction → Business Rule hierarchy representing the business functions performed in the program. Semantically related rules are consolidated into named SubFunctions that group related business capabilities, and purely technical or setup logic is excluded. Each rule documents its purpose, ordered execution steps with conditions, actions, and outcomes, references to the contributing source paragraphs, and the business significance of each rule.

## 2. Function: License Eligibility Determination

### 2.1 SubFunction: Applicant Age Verification

#### 2.1.1 Business Rule: Age Calculation and Minimum Age Enforcement by License Type

##### 2.1.1.1 Purpose
Before any license application can progress, the system determines the applicant's age and enforces a license-type-specific minimum age threshold. Age is derived by subtracting the birth year from the current year. If the applicant falls below the required minimum for the requested license type, the application is immediately flagged as ineligible with a descriptive failure reason. The minimum thresholds are: 16 years for a Learner license, 17 years for a Probation license, and 18 years for an Open license.

##### 2.1.1.2 Rule Steps
1. **Derive applicant age from date of birth**
   - Conditions: Always performed at the start of the eligibility check.
   - Actions: Extract the birth year from `DATE-OF-BIRTH` into `WS-DOB-YEAR`; extract the current year into `WS-CURR-YEAR`; compute `WS-CALC-AGE` = `WS-CURR-YEAR` − `WS-DOB-YEAR`. Initialize `WS-FAIL-FLAG` to 'N' and `WS-ELIG-FAIL-REASON` to spaces.
   - Outcomes: A whole-year age value is available for all downstream threshold comparisons.
   - Relevant Paragraphs: RUN-ELIGIBILITY-CHECK

2. **Enforce minimum age for Learner license**
   - Conditions: `LICENSE-TYPE` = Learner AND `WS-CALC-AGE` < 16.
   - Actions: Set `WS-FAIL-FLAG` = 'Y'; populate `WS-ELIG-FAIL-REASON` with the age failure reason for Learner.
   - Outcomes: Applicant is disqualified from obtaining a Learner license due to insufficient age.
   - Relevant Paragraphs: RUN-ELIGIBILITY-CHECK

3. **Enforce minimum age for Probation license**
   - Conditions: `LICENSE-TYPE` = Probation AND `WS-CALC-AGE` < 17.
   - Actions: Set `WS-FAIL-FLAG` = 'Y'; populate `WS-ELIG-FAIL-REASON` with the age failure reason for Probation.
   - Outcomes: Applicant is disqualified from obtaining a Probation license due to insufficient age.
   - Relevant Paragraphs: RUN-ELIGIBILITY-CHECK

4. **Enforce minimum age for Open license**
   - Conditions: `LICENSE-TYPE` = Open AND `WS-CALC-AGE` < 18.
   - Actions: Set `WS-FAIL-FLAG` = 'Y'; populate `WS-ELIG-FAIL-REASON` with the age failure reason for Open.
   - Outcomes: Applicant is disqualified from obtaining an Open license due to insufficient age.
   - Relevant Paragraphs: RUN-ELIGIBILITY-CHECK

##### 2.1.1.3 Business Significance
Incorrect age calculation or misconfigured thresholds would allow under-age individuals to obtain licenses for which they are legally ineligible, representing a direct regulatory compliance breach. Conversely, an overstated age could wrongly exclude eligible applicants, creating administrative liability.

---

### 2.2 SubFunction: License Progression Prerequisite Verification

#### 2.2.1 Business Rule: Prior License Holding Requirement for Advanced License Types

##### 2.2.1.1 Purpose
The licensing framework enforces a graduated progression model: an applicant may only advance to a higher-tier license if they already hold an active license at the immediately preceding tier. This check is only evaluated for applicants who have already passed the age verification (i.e., `WS-FAIL-FLAG` = 'N'), ensuring prerequisite checks are not redundantly applied to already-disqualified applicants. For a Probation license application, the candidate must hold at least one active Learner license. For an Open license application, the candidate must hold at least one active Probation license.

##### 2.2.1.2 Rule Steps
1. **Verify active Learner license for Probation applicants**
   - Conditions: `LICENSE-TYPE` = Probation AND `WS-FAIL-FLAG` = 'N'.
   - Actions: Query the license records for `CANDIDATE-ID` to count active Learner licenses into `WS-PRIOR-COUNT`; if `WS-PRIOR-COUNT` < 1, set `WS-FAIL-FLAG` = 'Y' and populate `WS-ELIG-FAIL-REASON` with the missing-learner-license reason.
   - Outcomes: Probation applicants without a current active Learner license are disqualified.
   - Relevant Paragraphs: RUN-ELIGIBILITY-CHECK

2. **Verify active Probation license for Open applicants**
   - Conditions: `LICENSE-TYPE` = Open AND `WS-FAIL-FLAG` = 'N'.
   - Actions: Query the license records for `CANDIDATE-ID` to count active Probation licenses into `WS-PRIOR-COUNT`; if `WS-PRIOR-COUNT` < 1, set `WS-FAIL-FLAG` = 'Y' and populate `WS-ELIG-FAIL-REASON` with the missing-probation-license reason.
   - Outcomes: Open applicants without a current active Probation license are disqualified.
   - Relevant Paragraphs: RUN-ELIGIBILITY-CHECK

##### 2.2.1.3 Business Significance
Bypassing the prerequisite check would allow applicants to skip mandatory intermediate licensing stages, violating the graduated licensing scheme. This could result in unlicensed or insufficiently experienced drivers holding higher-tier licenses, with direct road safety and regulatory consequences.

---

### 2.3 SubFunction: Eligibility Outcome Determination and Application Status Update

#### 2.3.1 Business Rule: Consolidate Check Results into Eligibility Status and Persist to Application Record

##### 2.3.1.1 Purpose
Once all individual eligibility checks have been evaluated, the accumulated result (captured in `WS-FAIL-FLAG`) is translated into a definitive eligibility status and a corresponding application lifecycle status. A single failure on any check is sufficient to reject the application. The outcome — including the eligibility status, failure reason, new application status, check date, and the identity of the processing user — is then persisted to the license application record, completing the eligibility workflow.

##### 2.3.1.2 Rule Steps
1. **Determine pass or fail outcome**
   - Conditions: Evaluate `WS-FAIL-FLAG` after all checks have been applied.
   - Actions: If `WS-FAIL-FLAG` = 'Y', set `WS-ELIGIBILITY-STATUS` = 'F' (Fail) and `APPLICATION-STATUS` = 'RE' (Rejected); if `WS-FAIL-FLAG` = 'N', set `WS-ELIGIBILITY-STATUS` = 'P' (Pass) and `APPLICATION-STATUS` = 'EC' (Eligibility Cleared).
   - Outcomes: The application is definitively classified as either rejected or cleared for the next processing stage.
   - Relevant Paragraphs: RUN-ELIGIBILITY-CHECK

2. **Persist eligibility result to the application record**
   - Conditions: Always executed after the outcome is determined.
   - Actions: Update the license application identified by `APPLICATION-ID` with `WS-ELIGIBILITY-STATUS`, `WS-ELIG-FAIL-REASON` (stored as eligibility check notes), `APPLICATION-STATUS`, the eligibility check date, and the processing user identifier.
   - Outcomes: The application record reflects the definitive eligibility decision as a durable domain state change, enabling downstream workflow steps to act on the result.
   - Relevant Paragraphs: RUN-ELIGIBILITY-CHECK

##### 2.3.1.3 Business Significance
Failure to correctly persist the eligibility outcome would leave the application in an indeterminate state, breaking downstream processing steps such as testing scheduling or license issuance. Incorrectly setting the application status (e.g., marking a failed applicant as 'EC') would allow ineligible candidates to advance through the licensing pipeline, creating both regulatory and audit risk.

---

Generated by IBM Bob Premium Package for Z
