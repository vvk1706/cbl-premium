# Business rules: Inventory

**Program:** DLISMENU

**Total rules extracted:** 4

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Rule Inventory](#2-rule-inventory)
  - [2.1 Paragraph: MAIN-LOGIC](#21-paragraph-main-logic)
  - [2.2 Paragraph: PROCESS-INPUT](#22-paragraph-process-input)

## 1. Purpose

This document is an inventory of all business rules extracted from DLISMENU, organised at the Paragraph level. Each Paragraph contributes one or more named rule blocks, where each block captures a discrete business policy with its title, decision logic, conditions, actions, outcomes, and the exact source code that realises it. Key variables, when available, are annotated with their role (input or output) and their specific purpose within the rule. References to related Paragraphs called or invoked by each rule are also recorded.

## 2. Rule Inventory

### 2.1 Paragraph: MAIN-LOGIC

#### 2.1.1 Initial Session Detection and Communication Area Loading

**Description:** Determines whether this is the first entry into the DLIS menu transaction or a re-entry. On first entry (communication area length is zero), the menu screen is initialized and displayed. On re-entry, the previously passed session and context data is restored from the CICS communication area into the working-storage DLIS communication area before processing user input.

**Core decision logic:**
- If EIBCALEN equals 0, this is a new session — initialize and display the menu screen
- If EIBCALEN is non-zero, this is a returning session — restore communication area and process user input

**Code:**
```cobol
           IF EIBCALEN = 0
               PERFORM INIT-SCREEN
           ELSE
               MOVE DFHCOMMAREA TO DLIS-COMMAREA
               PERFORM PROCESS-INPUT
           END-IF
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `DFHCOMMAREA` | input | Provides the session and context data passed in from the previous invocation, which is copied into the working-storage DLIS communication area for use during input processing. |
| `DLIS-COMMAREA` | output | Receives the contents of DFHCOMMAREA so that session and context data is available to the input processing logic on re-entry. |

**Paragraphs:**

* INIT-SCREEN
* PROCESS-INPUT
### 2.2 Paragraph: PROCESS-INPUT

#### 2.2.1 Invalid Key Press Validation — Require ENTER or PF12

**Description:** Enforces the rule that only the ENTER key or PF12 are valid actions on the menu screen. If any other attention identifier key is pressed, a guidance message is set and the menu is redisplayed, preventing unintended navigation.

**Core decision logic:**
- Only ENTER or PF12 are accepted as valid keys on the menu; all other keys are rejected with a user message

**Code:**
```cobol
           IF EIBAID NOT = DFHENTER
               MOVE 'PRESS ENTER TO SELECT OR F12 TO EXIT' TO DMMMSG
               PERFORM REDISPLAY-MENU
           END-IF
```

**Paragraphs:**

* REDISPLAY-MENU
#### 2.2.2 Mandatory Option Selection Validation

**Description:** Enforces the business rule that the user must select a menu option before proceeding. If the option field is blank or contains low-values (i.e., nothing was entered), a message prompting the user to select an option between 1 and 10 is displayed and the menu is redisplayed.

**Core decision logic:**
- A blank or empty option field is not permitted — the user must explicitly select an option numbered 1 through 10

**Code:**
```cobol
           IF DMMOPTI = SPACES OR DMMOPTI = LOW-VALUES
               MOVE 'PLEASE SELECT AN OPTION (1-10)' TO DMMMSG
               PERFORM REDISPLAY-MENU
           END-IF
```

**Paragraphs:**

* REDISPLAY-MENU
#### 2.2.3 Menu Option Routing to Business Functions

**Description:** Routes the user to the appropriate DLIS business function program based on the menu option selected. Each valid option (1–10) transfers control to a specific program — such as candidate management, application processing, status inquiry, eligibility checking, history, payments, or issuance — passing the current session context via the communication area. An unrecognized option displays an error message and redisplays the menu.

**Core decision logic:**
- Option 1 and 2 route to the candidate program (DLISCAND)
- Option 3 routes to the application program (DLISAPPL)
- Option 4 routes to the status program (DLISSTAT)
- Option 5 routes to the eligibility program (DLISELIG)
- Option 6 routes to the history program (DLISHIST)
- Option 7 routes to the payments program (DLISPAY)
- Option 8 routes to the first appeals program (DLISAP1)
- Option 9 routes to the second appeals program (DLISAP2)
- Option 10 routes to the issuance program (DLISISSU)
- Any value outside 1–10 is invalid and triggers an error message with menu redisplay
- Session and context data is passed to the selected program via a 350-byte communication area

**Code:**
```cobol
           EVALUATE DMMOPTI
               WHEN '1'  EXEC CICS XCTL PROGRAM('DLISCAND')
                             COMMAREA(DLIS-COMMAREA) LENGTH(350)
                         END-EXEC
               WHEN '2'  EXEC CICS XCTL PROGRAM('DLISCAND')
                             COMMAREA(DLIS-COMMAREA) LENGTH(350)
                         END-EXEC
               WHEN '3'  EXEC CICS XCTL PROGRAM('DLISAPPL')
                             COMMAREA(DLIS-COMMAREA) LENGTH(350)
                         END-EXEC
               WHEN '4'  EXEC CICS XCTL PROGRAM('DLISSTAT')
                             COMMAREA(DLIS-COMMAREA) LENGTH(350)
                         END-EXEC
               WHEN '5'  EXEC CICS XCTL PROGRAM('DLISELIG')
                             COMMAREA(DLIS-COMMAREA) LENGTH(350)
                         END-EXEC
               WHEN '6'  EXEC CICS XCTL PROGRAM('DLISHIST')
                             COMMAREA(DLIS-COMMAREA) LENGTH(350)
                         END-EXEC
               WHEN '7'  EXEC CICS XCTL PROGRAM('DLISPAY')
                             COMMAREA(DLIS-COMMAREA) LENGTH(350)
                         END-EXEC
               WHEN '8'  EXEC CICS XCTL PROGRAM('DLISAP1')
                             COMMAREA(DLIS-COMMAREA) LENGTH(350)
                         END-EXEC
               WHEN '9'  EXEC CICS XCTL PROGRAM('DLISAP2')
                             COMMAREA(DLIS-COMMAREA) LENGTH(350)
                         END-EXEC
               WHEN '10' EXEC CICS XCTL PROGRAM('DLISISSU')
                             COMMAREA(DLIS-COMMAREA) LENGTH(350)
                         END-EXEC
               OTHER
                   MOVE 'INVALID OPTION. PLEASE SELECT 1-10' TO DMMMSG
                   PERFORM REDISPLAY-MENU
           END-EVALUATE
```

**Variables:**

| Variable name | Role | Purpose |
|---|---|---|
| `DLIS-COMMAREA` | input | Carries the current session and context data that is passed to whichever business function program the user selects, ensuring continuity of session state across program transfers. |

**Paragraphs:**

* REDISPLAY-MENU

---

Generated by IBM Bob Premium Package for Z
