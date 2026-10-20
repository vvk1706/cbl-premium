# Business rules: Inventory

**Program:** DLISPAY

**Total rules extracted:** 6

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Rule Inventory](#2-rule-inventory)
  - [2.1 Paragraph: LOAD-APPLICATION](#21-paragraph-load-application)
  - [2.2 Paragraph: PROCESS-PAYMENT](#22-paragraph-process-payment)

## 1. Purpose

This document is an inventory of all business rules extracted from DLISPAY, organised at the Paragraph level. Each Paragraph contributes one or more named rule blocks, where each block captures a discrete business policy with its title, decision logic, conditions, actions, outcomes, and the exact source code that realises it. Key variables, when available, are annotated with their role (input or output) and their specific purpose within the rule. References to related Paragraphs called or invoked by each rule are also recorded.

## 2. Rule Inventory

### 2.1 Paragraph: LOAD-APPLICATION

#### 2.1.1 Derive License Type Description

**Description:** Translates the single-character license type code into its full descriptive name: 'LEARNER' for 'L', 'PROBATION' for 'P', and 'OPEN' for 'O'.

**Core decision logic:**
- If the license type is 'L', classify description as 'LEARNER'.
- If the license type is 'P', classify description as 'PROBATION'.
- If the license type is 'O', classify description as 'OPEN'.

**Code:**
```cobol
           EVALUATE LICENSE-TYPE OF DCLDLIS-LICENSE-APPL
               WHEN 'L' MOVE 'LEARNER'   TO DPELDSO
               WHEN 'P' MOVE 'PROBATION' TO DPELDSO
               WHEN 'O' MOVE 'OPEN'      TO DPELDSO
           END-EVALUATE
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `LICENSE-TYPE` | input | Evaluated to determine the descriptive name of the license type category. |

### 2.2 Paragraph: PROCESS-PAYMENT

#### 2.2.1 Validate Background History Check Prerequisite

**Description:** Enforces the prerequisite policy that an applicant's background history check must be marked as passed ('P') before any payment can be processed.

**Core decision logic:**
- Payment is blocked if the background history check status is not 'P' (Passed).

**Code:**
```cobol
           IF HIST-CHECK-STATUS OF DCLDLIS-LICENSE-APPL NOT = 'P'
               MOVE 'HISTORY CHECK MUST BE PASSED BEFORE PAYMENT'
                   TO DPEMSG
               GO TO PROCESS-PAY-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `HIST-CHECK-STATUS` | input | Evaluated to verify whether the mandatory background check has been passed. |

#### 2.2.2 Prevent Duplicate Payment Recording

**Description:** Checks the current payment status of the application to prevent recording duplicate payments for an application that is already marked as paid ('P').

**Core decision logic:**
- Payment processing is halted if the application's payment status is already 'P' (Paid).

**Code:**
```cobol
           IF PAYMENT-STATUS OF DCLDLIS-LICENSE-APPL = 'P'
               MOVE 'PAYMENT ALREADY RECORDED FOR THIS APPLICATION'
                   TO DPEMSG
               GO TO PROCESS-PAY-EXIT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `PAYMENT-STATUS` | input | Evaluated to prevent processing if payment has already been recorded. |

#### 2.2.3 Generate Payment Receipt Number

**Description:** Constructs a standardized business receipt number by prefixing 'RCP' to the current 8-digit date and the application ID.

**Core decision logic:**
- Receipt number format is constructed by concatenating 'RCP', current date (YYYYMMDD), and application ID.

**Code:**
```cobol
      *    Generate receipt number
           MOVE CURRENT-DATE(1:8)  TO WS-RECEIPT-DATE
           STRING 'RCP' WS-RECEIPT-DATE DPEAIDI
               INTO WS-RECEIPT-NUMBER
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `WS-RECEIPT-DATE` | output | Receives the current 8-digit date used as part of the receipt number format. |
| `WS-RECEIPT-NUMBER` | output | Receives the generated receipt identifier for payment tracking. |

#### 2.2.4 Record Payment Transaction

**Description:** Creates a new payment record in the PAYMENT table with payment status 'S' (Successful), fee type 'IF' (Initial Fee), and all transaction details including amount, method, reference, receipt number, and processing operator.

**Core decision logic:**
- Creates a domain payment record initialized with status 'S' and fee type 'IF'.

**Code:**
```cobol
      *    Insert payment
           MOVE DPEMETHI TO PAYMENT-METHOD    OF DCLDLIS-PAYMENT
           MOVE DPEREFI  TO PAYMENT-REFERENCE OF DCLDLIS-PAYMENT
           MOVE DPEAIDI  TO APPLICATION-ID    OF DCLDLIS-PAYMENT
           MOVE CANDIDATE-ID OF DCLDLIS-LICENSE-APPL
                         TO CANDIDATE-ID      OF DCLDLIS-PAYMENT
           MOVE LICENSE-TYPE OF DCLDLIS-LICENSE-APPL
                         TO LICENSE-TYPE      OF DCLDLIS-PAYMENT
           MOVE WS-FEE-AMOUNT TO PAYMENT-AMOUNT OF DCLDLIS-PAYMENT
           MOVE WS-RECEIPT-NUMBER TO RECEIPT-NUMBER OF DCLDLIS-PAYMENT
           MOVE DPEPRCBYI TO PROCESSED-BY OF DCLDLIS-PAYMENT
           EXEC SQL
               INSERT INTO DLIS.PAYMENT
                  (APPLICATION_ID, CANDIDATE_ID, PAYMENT_AMOUNT,
                   PAYMENT_METHOD, PAYMENT_REFERENCE, PAYMENT_STATUS,
                   LICENSE_TYPE, FEE_TYPE, RECEIPT_NUMBER, PROCESSED_BY)        
               VALUES
                  (:APPLICATION-ID, :CANDIDATE-ID, :PAYMENT-AMOUNT,
                   :PAYMENT-METHOD, :PAYMENT-REFERENCE, 'S',
                   :LICENSE-TYPE, 'IF', :RECEIPT-NUMBER, :PROCESSED-BY)
               OF DCLDLIS-PAYMENT
           END-EXEC
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `PAYMENT-METHOD` | input | Supplies the method of payment to be persisted. |
| `PAYMENT-REFERENCE` | input | Supplies the transaction reference to be persisted. |
| `APPLICATION-ID` | input | Links the payment record to the specific license application. |
| `CANDIDATE-ID` | input | Associates the candidate with the payment record. |
| `LICENSE-TYPE` | input | Specifies the license category being paid for. |
| `WS-FEE-AMOUNT` | input | Provides the fee amount to populate the payment amount host variable. |
| `PAYMENT-AMOUNT` | output | Stores the monetary amount inserted into the payment table. |
| `WS-RECEIPT-NUMBER` | input | Provides the generated receipt number for the payment insert. |
| `PROCESSED-BY` | input | Identifies the operator who processed the payment. |

#### 2.2.5 Update Application Payment and Processing Status

**Description:** Updates the license application domain state to reflect payment completion: sets PAYMENT_STATUS to 'P' (Paid), records the payment reference, advances APPLICATION_STATUS to 'PA' (Payment Approved), and updates the audit timestamp and operator ID.

**Core decision logic:**
- Sets application payment status to 'P' (Paid) and application status to 'PA' upon successful payment.

**Code:**
```cobol
      *    Update application
           EXEC SQL
               UPDATE DLIS.LICENSE_APPLICATION SET
                   PAYMENT_STATUS    = 'P',
                   PAYMENT_REFERENCE = :PAYMENT-REFERENCE
                                       OF DCLDLIS-PAYMENT,
                   APPLICATION_STATUS= 'PA',
                   LAST_UPDATED_DATE = CURRENT DATE,
                   LAST_UPDATED_BY   = :PROCESSED-BY OF DCLDLIS-PAYMENT
               WHERE APPLICATION_ID  = :APPLICATION-ID
                                       OF DCLDLIS-PAYMENT
           END-EXEC
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `PAYMENT-REFERENCE` | input | Supplies the external payment reference to update on the application record. |
| `PROCESSED-BY` | input | Identifies the operator updating the application record. |
| `APPLICATION-ID` | input | Identifies the application record to be updated. |

---

Generated by IBM Bob Premium Package for Z
