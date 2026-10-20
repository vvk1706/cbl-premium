# Business rules: Overview

**Program:** DLISMENU

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Function: Menu Session Management](#2-function-menu-session-management)
  - [2.1 SubFunction: Session Entry and Context Continuity](#21-subfunction-session-entry-and-context-continuity)
- [3. Function: Menu Input Validation](#3-function-menu-input-validation)
  - [3.1 SubFunction: Attention Key Validation](#31-subfunction-attention-key-validation)
  - [3.2 SubFunction: Menu Option Entry Validation](#32-subfunction-menu-option-entry-validation)
- [4. Function: Business Function Navigation](#4-function-business-function-navigation)
  - [4.1 SubFunction: Menu Option Routing](#41-subfunction-menu-option-routing)

## 1. Purpose
This document presents a program-level functional view of the business logic in DLISMENU. Business rules are organised into a Function → SubFunction → Business Rule hierarchy representing the business functions performed in the program. Semantically related rules are consolidated into named SubFunctions that group related business capabilities, and purely technical or setup logic is excluded. Each rule documents its purpose, ordered execution steps with conditions, actions, and outcomes, references to the contributing source paragraphs, and the business significance of each rule.

## 2. Function: Menu Session Management

### 2.1 SubFunction: Session Entry and Context Continuity

#### 2.1.1 Business Rule: Initial Session Detection and Communication Area Restoration

##### 2.1.1.1 Purpose
Decides whether the user is entering the DLIS menu transaction for the first time or returning to it. This determines whether a fresh menu is presented or the user's input is processed with the session context carried over from the earlier interaction. It keeps session state intact across pseudo-conversational interactions.

##### 2.1.1.2 Rule Steps
1. Detect new versus returning session
   - Conditions: Communication area length (EIBCALEN) equals 0 means a new session. A non-zero value means a returning session.
   - Actions: On a new session, initialize and display the menu screen. On a returning session, continue to input processing.
   - Outcomes: The user sees a fresh menu on first entry, or the transaction continues from the prior interaction on re-entry.
   - Relevant Paragraphs: MAIN-LOGIC, INIT-SCREEN, PROCESS-INPUT

2. Restore session context on re-entry
   - Conditions: EIBCALEN is non-zero.
   - Actions: Copy the passed context (DFHCOMMAREA) into the working-storage communication area (DLIS-COMMAREA) before the user's input is evaluated.
   - Outcomes: Session and context data is available to the input validation and routing logic, so continuity is preserved.
   - Relevant Paragraphs: MAIN-LOGIC, PROCESS-INPUT

##### 2.1.1.3 Business Significance
If a first-time entry is mistaken for a re-entry, the user would be processed against missing or empty context. If context is not restored on re-entry, downstream programs would receive lost or corrupted session state. Users could then lose their place in the workflow or act with the wrong context.

## 3. Function: Menu Input Validation

### 3.1 SubFunction: Attention Key Validation

#### 3.1.1 Business Rule: Invalid Key Press Validation — Require ENTER or PF12

##### 3.1.1.1 Purpose
Restricts the menu screen to two valid user actions, ENTER (submit selection) and PF12. Any other attention key is rejected, so the user cannot trigger unintended navigation or processing from the menu.

##### 3.1.1.2 Rule Steps
1. Check the attention key pressed
   - Conditions: The key pressed is neither ENTER nor PF12.
   - Actions: Set a guidance message telling the user which keys are valid, then redisplay the menu.
   - Outcomes: Invalid keys are rejected without processing the option field or routing the user. Valid keys move on to option validation.
   - Relevant Paragraphs: PROCESS-INPUT, REDISPLAY-MENU

##### 3.1.1.3 Business Significance
Without this control, stray function keys could cause unintended transfers, abnormal terminations, or processing of incomplete input. This would disrupt the user experience and risk the integrity of the transaction flow.

### 3.2 SubFunction: Menu Option Entry Validation

#### 3.2.1 Business Rule: Mandatory Option Selection Validation

##### 3.2.1.1 Purpose
Requires the user to enter a menu option before the transaction can proceed. An empty selection is treated as an error, and the user is told to choose a value from 1 to 10.

##### 3.2.1.2 Rule Steps
1. Verify that an option was entered
   - Conditions: The option field is blank (spaces) or contains low-values, meaning nothing was entered.
   - Actions: Set a message prompting the user to select an option between 1 and 10, then redisplay the menu.
   - Outcomes: Empty submissions are blocked and no routing occurs. Populated selections proceed to routing.
   - Relevant Paragraphs: PROCESS-INPUT, REDISPLAY-MENU

##### 3.2.1.3 Business Significance
Without this check, empty submissions would fall through to routing and produce misleading invalid-option errors or undefined behavior. Users would get unclear guidance and the number of unproductive transactions would rise.

## 4. Function: Business Function Navigation

### 4.1 SubFunction: Menu Option Routing

#### 4.1.1 Business Rule: Menu Option Routing to Business Functions

##### 4.1.1.1 Purpose
Maps each valid menu selection (1–10) to the DLIS business program that handles it, and transfers control to that program with the current session context. This makes the menu the single entry point to candidate management, application processing, status inquiry, eligibility, history, payments, appeals, and issuance. Unrecognized selections are rejected with an error.

##### 4.1.1.2 Rule Steps
1. Map the selected option to the target program
   - Conditions: The option value matches one of the supported selections:
     - 1 or 2 → DLISCAND (candidate)
     - 3 → DLISAPPL (application)
     - 4 → DLISSTAT (status)
     - 5 → DLISELIG (eligibility)
     - 6 → DLISHIST (history)
     - 7 → DLISPAY (payments)
     - 8 → DLISAP1 (first appeals)
     - 9 → DLISAP2 (second appeals)
     - 10 → DLISISSU (issuance)
   - Actions: Select the program that corresponds to the option.
   - Outcomes: Each valid option resolves to exactly one business function program. Options 1 and 2 both resolve to the candidate program.
   - Relevant Paragraphs: PROCESS-INPUT

2. Transfer control with session context
   - Conditions: A valid option has been mapped to a target program.
   - Actions: Pass the 350-byte communication area (DLIS-COMMAREA) to the selected program when control is transferred.
   - Outcomes: The target program receives the session state and can continue the user's workflow.
   - Relevant Paragraphs: PROCESS-INPUT

3. Reject unrecognized options
   - Conditions: The option value is outside 1–10.
   - Actions: Set an error message indicating an invalid option and redisplay the menu.
   - Outcomes: No transfer occurs and the user can correct the selection.
   - Relevant Paragraphs: PROCESS-INPUT, REDISPLAY-MENU

##### 4.1.1.3 Business Significance
Incorrect mapping would send users to the wrong business function. For example, a payment request could land in appeals or issuance, which creates operational and compliance risk. Failing to pass the communication area would break session continuity in the target program. Failing to reject invalid options could cause transfer failures or abends.

---

Generated by IBM Bob Premium Package for Z
