# DLISAPPL – License Application Entry

## Business Purpose
DLISAPPL is the data-entry screen that licensing office staff use to start a new license application for a candidate. The program runs under CICS as transaction **DL03**. It lets a clerk:
- check who a candidate is,
- see what the license will cost,
- file the application.

It is the entry point of the license application workflow. Every later step starts from the application record it creates. Those steps are the eligibility check, the driving-history check, payment, the two approvals, and issuing the license.

## How Users Interact With It
The program is a single screen with function keys. After each key press the program gives control back, and the next key press picks up where the user left off.

| Key | What it does for the user |
|---|---|
| **F3 – Lookup Candidate** | The clerk enters a Candidate ID. The program shows the candidate's full name. It reports "Candidate not found" or "Candidate record is inactive" when the person can't be used. |
| **F5 – Calc Fee** | The clerk selects a license type. The program shows the current fee and its currency. If no fee is defined for that type, it says so. |
| **F1 – Submit** | The program checks the entries and creates the application. It then shows the new application number, the status "PE" (Pending) and the application date. |
| **F12** | Leaves the transaction. |
| Any other key | Prompts the user to use F1, F3, F5 or F12. |

On first entry the screen is shown blank except for today's date.

## Business Decisions and Actions It Supports
- **Confirming the applicant.** Staff can verify the candidate's identity and active standing before taking an application. This guards against applications for unknown or deactivated people.
- **Fee transparency.** The fee comes from the official fee schedule. It uses the initial-fee ("IF") entry that is active and in effect today. The clerk can quote the exact cost before committing.
- **Validating the request.** Submission is refused unless both a Candidate ID and a license type are given. The type must be **L**, **P** or **O**.
- **Preventing duplicates.** An applicant cannot hold two live applications of the same license type. An application counts as live unless it is Rejected ("RE") or Issued ("IS"). A repeat attempt is stopped with a clear message.
- **Starting the application.** The program creates the application with status "Pending". It records the terminal that created it for audit purposes, and the database assigns the application number.

## Business Domain
Government or regulatory **license administration** (driver or vehicle licensing). The supporting data covers candidates, license applications, fee schedules, driving history, payments, approving authorities and issued licenses.

## Criticality
This is a **core operational, front-line program**. It is not a back-office utility. It is the only point where new applications enter the system, so if it is unavailable, no new applications can be taken. It also enforces key intake rules: valid candidate, valid license type and no duplicate live application. These rules protect the quality of data for every later step. It does not itself approve anything, take payment or issue a license, so its direct business impact is limited to intake.

## Observations for Stakeholders
- The program does not check eligibility, driving history or payment at intake. Other steps in the workflow handle those.
- The submit step does not require that the candidate was looked up or is active. It checks only that an ID and a valid type were entered.
- The program does not confirm the database save beyond reporting an error. A change of mind after saving is not supported by this screen.

# DLISAPPL — Program Flow Diagram

```mermaid
flowchart TD
    classDef startEnd fill:#b5ead7,stroke:#5a9e82,color:#000
    classDef decision fill:#ffd6a5,stroke:#c8874a,color:#000
    classDef process fill:#c7ceea,stroke:#6272b0,color:#000
    classDef ioStep fill:#fff1ba,stroke:#b8960c,color:#000
    classDef dbStep fill:#d4f1f9,stroke:#3a8fb5,color:#000
    classDef errorStep fill:#ffb3ba,stroke:#c0394b,color:#000
    classDef exitStep fill:#e2d9f3,stroke:#7c5cbf,color:#000

    A([Transaction DL03 Invoked]):::startEnd
    B{First invocation?\nEIBCALEN = 0}:::decision
    C[Display blank License\nApplication Entry screen]:::ioStep
    D[Await next user input\nReturn with TRANSID DL03]:::exitStep

    E[Receive input from\nLicense Application screen]:::ioStep
    F{Which function\nkey was pressed?}:::decision

    G[Lookup Candidate — F3]:::process
    H[Calculate Fee — F5]:::process
    I[Submit Application — F1]:::process
    J[Exit — F12]:::exitStep
    K[Show 'Use F1 F3 F5 or F12'\nhint message]:::errorStep

    %% LOOKUP CANDIDATE
    G1{Candidate ID\nentered?}:::decision
    G2[Query DB2 CANDIDATE\ntable by Candidate ID]:::dbStep
    G3{Candidate\nfound?}:::decision
    G4{Candidate\nrecord active?}:::decision
    G5[Display candidate full\nname on screen]:::ioStep
    GE1[Show 'Enter Candidate ID'\nerror message]:::errorStep
    GE2[Show 'Candidate Not Found'\nerror message]:::errorStep
    GE3[Show 'Candidate Record\nIs Inactive' error message]:::errorStep

    %% CALC FEE
    H1{License type\nselected?}:::decision
    H2[Query DB2 LICENSE_FEE_SCHEDULE\nfor active initial fee]:::dbStep
    H3{Fee schedule\nfound?}:::decision
    H4[Display fee amount\nand currency on screen]:::ioStep
    HE1[Show 'Select License\nType First' error message]:::errorStep
    HE2[Show 'No Fee Schedule\nfor This Type' error message]:::errorStep

    %% SUBMIT APPLICATION
    I1{Candidate ID\nprovided?}:::decision
    I2{License type\nprovided?}:::decision
    I3{License type is\nL, P, or O?}:::decision
    I4[Check DB2 for existing\nactive application of same type]:::dbStep
    I5{Active application\nalready exists?}:::decision
    I6[Insert new application\nrecord into DB2\nwith status 'PE' — Pending]:::dbStep
    I7{DB2 insert\nsuccessful?}:::decision
    I8[Retrieve new Application ID\nvia IDENTITY_VAL_LOCAL]:::dbStep
    I9[Display Application ID,\nstatus and date on screen]:::ioStep
    IE1[Show 'Candidate ID\nRequired' error message]:::errorStep
    IE2[Show 'License Type\nRequired' error message]:::errorStep
    IE3[Show 'License Type Must\nBe L P or O' error message]:::errorStep
    IE4[Show 'Active Application\nAlready Exists' error message]:::errorStep
    IE5[Show 'Database Error\non Application Insert']:::errorStep

    %% RETURN
    R[Refresh screen with\nupdated data and messages]:::ioStep
    S([Suspend and await\nnext user action — Return DL03]):::startEnd

    A --> B
    B -- Yes, first invocation --> C
    C --> D

    B -- No, returning invocation --> E
    E --> F

    F -- F3 --> G
    F -- F5 --> H
    F -- F1 --> I
    F -- F12 --> J
    F -- Other key --> K

    %% LOOKUP CANDIDATE flow
    G --> G1
    G1 -- No --> GE1
    G1 -- Yes --> G2
    G2 --> G3
    G3 -- Not Found --> GE2
    G3 -- Found --> G4
    G4 -- Inactive --> GE3
    G4 -- Active --> G5

    %% CALC FEE flow
    H --> H1
    H1 -- No --> HE1
    H1 -- Yes --> H2
    H2 --> H3
    H3 -- Not Found --> HE2
    H3 -- Found --> H4

    %% SUBMIT APPLICATION flow
    I --> I1
    I1 -- No --> IE1
    I1 -- Yes --> I2
    I2 -- No --> IE2
    I2 -- Yes --> I3
    I3 -- Invalid type --> IE3
    I3 -- Valid type --> I4
    I4 --> I5
    I5 -- Yes --> IE4
    I5 -- No --> I6
    I6 --> I7
    I7 -- Failed --> IE5
    I7 -- Success --> I8
    I8 --> I9

    %% All paths converge back to refresh & return
    G5 --> R
    GE1 --> R
    GE2 --> R
    GE3 --> R
    H4 --> R
    HE1 --> R
    HE2 --> R
    I9 --> R
    IE1 --> R
    IE2 --> R
    IE3 --> R
    IE4 --> R
    IE5 --> R
    K --> R

    R --> S
    J --> S
```

---

Generated by IBM Bob Premium Package for Z
