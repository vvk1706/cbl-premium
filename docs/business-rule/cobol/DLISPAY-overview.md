# Business rules: Overview

**Program:** DLISPAY

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Function: License Application Classification](#2-function-license-application-classification)
  - [2.1 SubFunction: License Category Identification](#21-subfunction-license-category-identification)
- [3. Function: License Fee Payment Processing](#3-function-license-fee-payment-processing)
  - [3.1 SubFunction: Payment Eligibility Control](#31-subfunction-payment-eligibility-control)
  - [3.2 SubFunction: Payment Recording and Receipting](#32-subfunction-payment-recording-and-receipting)
  - [3.3 SubFunction: Application Status Advancement](#33-subfunction-application-status-advancement)

## 1. Purpose
This document presents a program-level functional view of the business logic in DLISPAY. Business rules are organised into a Function → SubFunction → Business Rule hierarchy representing the business functions performed in the program. Semantically related rules are consolidated into named SubFunctions that group related business capabilities, and purely technical or setup logic is excluded. Each rule documents its purpose, ordered execution steps with conditions, actions, and outcomes, references to the contributing source paragraphs, and the business significance of each rule.

## 2. Function: License Application Classification

### 2.1 SubFunction: License Category Identification

#### 2.1.1 Business Rule: Derive License Type Description

##### 2.1.1.1 Purpose
Translates the single-character license type code held on the application into its business-facing category name. This lets the application and downstream processing refer to the license category (Learner, Probation or Open) in consistent, readable terms rather than by internal code.

##### 2.1.1.2 Rule Steps
1. Classify the license type code into its descriptive category name
   - Conditions: `LICENSE-TYPE` = 'L' → LEARNER; `LICENSE-TYPE` = 'P' → PROBATION; `LICENSE-TYPE` = 'O' → OPEN. The input does not define any behavior for other values.
   - Actions: Assign the matching description (LEARNER, PROBATION or OPEN) to the application's license type description.
   - Outcomes: The application carries a human-readable license category aligned with its type code.
   - Relevant Paragraphs: LOAD-APPLICATION (variable: `LICENSE-TYPE`)

##### 2.1.1.3 Business Significance
If the mapping is wrong or incomplete, the application can be shown or treated under the wrong license category. That can lead to wrong fee or eligibility interpretation, misleading information for operators and applicants, and an unlabeled category when an unrecognized code is encountered, since no fallback is defined.

---

## 3. Function: License Fee Payment Processing

### 3.1 SubFunction: Payment Eligibility Control

#### 3.1.1 Business Rule: Enforce Payment Preconditions

##### 3.1.1.1 Purpose
Ensures a payment is accepted only when the applicant is eligible to pay and the application has not already been paid. This combines the mandatory background-check prerequisite with duplicate-payment protection so that fees are collected only once, and only for applicants who have cleared screening.

##### 3.1.1.2 Rule Steps
1. Verify the background history check has been passed
   - Conditions: `HIST-CHECK-STATUS` must equal 'P' (Passed); any other status fails the check.
   - Actions: Block payment processing when the status is not 'P'.
   - Outcomes: Applicants who have not passed the background check cannot pay.
   - Relevant Paragraphs: PROCESS-PAYMENT (variable: `HIST-CHECK-STATUS`)
2. Prevent payment on an application already paid
   - Conditions: `PAYMENT-STATUS` = 'P' (Paid) means a payment is already recorded.
   - Actions: Halt payment processing so no second payment is recorded.
   - Outcomes: Each application can have only one initial fee payment recorded.
   - Relevant Paragraphs: PROCESS-PAYMENT (variable: `PAYMENT-STATUS`)

##### 3.1.1.3 Business Significance
Skipping the background-check prerequisite would let applicants progress, and pay, before required screening is complete, which is a compliance and regulatory risk. Skipping the duplicate check could produce double charges, duplicate receipts, revenue and reconciliation errors, and refund handling.

### 3.2 SubFunction: Payment Recording and Receipting

#### 3.2.1 Business Rule: Issue Standardized Payment Receipt Number

##### 3.2.1.1 Purpose
Creates a unique, traceable receipt identifier for each accepted payment, built from a fixed prefix, the processing date and the application ID.

##### 3.2.1.2 Rule Steps
1. Build the receipt number
   - Conditions: Applies once the payment passes the eligibility checks.
   - Actions: Concatenate the literal 'RCP', the current 8-digit date (YYYYMMDD, `WS-RECEIPT-DATE`) and the application ID, and store the result in `WS-RECEIPT-NUMBER`.
   - Outcomes: A standardized receipt number that ties the payment to its date and application.
   - Relevant Paragraphs: PROCESS-PAYMENT (variables: `WS-RECEIPT-DATE`, `WS-RECEIPT-NUMBER`, `APPLICATION-ID`)

##### 3.2.1.3 Business Significance
The receipt number is the customer-facing and audit reference for the payment. A malformed or non-unique value undermines proof of payment, reconciliation with finance, and dispute resolution.

#### 3.2.2 Business Rule: Record Initial Fee Payment Transaction

##### 3.2.2.1 Purpose
Persists a payment record for the application's initial license fee, capturing who paid, how, how much, and who processed it, so the financial transaction has a permanent audit trail.

##### 3.2.2.2 Rule Steps
1. Create the payment record with successful initial-fee attributes
   - Conditions: Payment passed the eligibility checks and a receipt number has been generated.
   - Actions: Insert a PAYMENT row with status 'S' (Successful) and fee type 'IF' (Initial Fee). Populate it with `APPLICATION-ID`, `CANDIDATE-ID`, `LICENSE-TYPE`, `PAYMENT-AMOUNT` (from `WS-FEE-AMOUNT`), `PAYMENT-METHOD`, `PAYMENT-REFERENCE`, `WS-RECEIPT-NUMBER` and `PROCESSED-BY`.
   - Outcomes: A complete, auditable record of the initial fee payment exists, linked to the application, candidate and operator.
   - Relevant Paragraphs: PROCESS-PAYMENT

##### 3.2.2.3 Business Significance
This record is the financial source of truth for the fee. Missing or incorrect amount, fee type, status or operator data affects revenue reporting, reconciliation, audit and refund handling.

### 3.3 SubFunction: Application Status Advancement

#### 3.3.1 Business Rule: Mark Application as Paid and Payment Approved

##### 3.3.1.1 Purpose
Moves the license application forward in its lifecycle once the payment is recorded, keeping the application state consistent with the payment record and enabling later processing stages.

##### 3.3.1.2 Rule Steps
1. Update application payment and processing status
   - Conditions: The payment has been successfully recorded.
   - Actions: Set `PAYMENT_STATUS` to 'P' (Paid); store `PAYMENT-REFERENCE`; advance `APPLICATION_STATUS` to 'PA' (Payment Approved); update the audit timestamp and operator ID (`PROCESSED-BY`) on the record identified by `APPLICATION-ID`.
   - Outcomes: The application is flagged paid, advances to Payment Approved, and carries audit details of the update.
   - Relevant Paragraphs: PROCESS-PAYMENT (variables: `PAYMENT-REFERENCE`, `PROCESSED-BY`, `APPLICATION-ID`)

##### 3.3.1.3 Business Significance
If the application is not updated consistently with the payment record, a paid application could stay unprocessed, stalling the applicant. Conversely, the duplicate-payment check (rule 2.1.1) relies on `PAYMENT_STATUS` being set, so a failed update could allow a second payment. A missing audit stamp weakens accountability for the status change.

---

Generated by IBM Bob Premium Package for Z
