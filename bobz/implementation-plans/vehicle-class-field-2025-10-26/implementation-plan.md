# Implementation Plan: Add Vehicle Class to License Application Flow

**Created**: 2025-10-26T00:00:00Z
**Author**: IBM Bob Premium Package for Z AI Assistant
**Analysis Method**: Local Workspace
**Workspace Alignment**: Fully Aligned
**Data Dictionary Coverage**: None — data dictionary generation recommended as prerequisite

---

## 1. Executive Summary

**Change Description**: Add a Vehicle Class field (values: A=Motorcycle, B=Light, C=Heavy, D=Bus) to the license application process. Currently Vehicle Class is entered only at issuance time (DLISISSU). This change captures it at application entry (DLISAPPL), stores it in the LICENSE_APPLICATION DB2 table, flows it through the COMMAREA to all downstream programs, and retains it at issuance in ISSUED_LICENSE.

**Business Value**: Regulatory compliance requires vehicle class to be declared and validated at application time, not only at issuance. Early capture allows eligibility and approval reviewers to see the intended class, ensures the fee schedule can be differentiated per vehicle class in future, and eliminates the risk of a class mismatch between application and issued license.

**Key Risks**:
1. COMMAREA expansion requires simultaneous recompile and deployment of all 7 CICS programs
2. Existing in-flight applications in the DB2 table will have NULL in the new VEHICLE_CLASS column and require a migration default
3. The APPL_VC CHECK constraint on ISSUED_LICENSE already enforces `IN ('A','B','C','D')` — the same constraint must be added on LICENSE_APPLICATION

---

## 2. Prerequisites

### Data Dictionary Generation (Recommended)

**Programs Recommended for Data Dictionary Entries**:
- `cobol/DLISAPPL.cbl`
- `cobol/DLISISSU.cbl`
- `copybook/DLISCSEC.cpy`
- `copybook/DLISDCLG.cpy`

**Rationale**: No data dictionary exists for this workspace. Generating entries before coding preserves variable context and enables richer plan validation.

**Execution Method**: Complete in a new subtask using Z-Code mode before implementation.

---

## 3. Requirements

### Functional Requirements

- **FR1**: Vehicle Class must be captured at application entry via the DLISAE BMS screen (DLISAPPL / DL03)
- **FR2**: Vehicle Class must be persisted in DLIS.LICENSE_APPLICATION as a new `VEHICLE_CLASS CHAR(2)` column
- **FR3**: Vehicle Class must be propagated through the DLIS-APPL-COMMAREA to all downstream programs
- **FR4**: DLISISSU must read Vehicle Class from the COMMAREA (not only from the screen field) to ensure consistency
- **FR5**: Vehicle Class values must be validated at entry: A, B, C, or D only
- **FR6**: All programs sharing DLISCSEC copybook must be recompiled and deployed as a single coordinated release

### Non-Functional Requirements

- **NFR1**: COMMAREA expansion must remain within the 32,763-byte CICS limit (current 350B + 2B = 352B — compliant)
- **NFR2**: New DB2 column must be nullable to avoid breaking existing in-flight application rows
- **NFR3**: All DB2 DDL changes must be reversible — use ALTER TABLE ADD COLUMN approach
- **NFR4**: No changes to the CSD resource definitions (transaction IDs and mapsets remain unchanged)

### Business Requirements

- **BR1**: Vehicle Class determines the physical license category — this must match between application and issued license
- **BR2**: Reviewers at approval stages (DLISAP1, DLISAP2) must be able to see the declared vehicle class without re-querying DB2

---

## 4. Goals and Non-Goals

### Goals

1. Add `VEHICLE_CLASS CHAR(2) NULLABLE` column to `DLIS.LICENSE_APPLICATION`
2. Add `CA-VEHICLE-CLASS PIC X(2)` field to `DLIS-APPL-COMMAREA` in `DLISCSEC.cpy` (append to end, preserve offsets)
3. Add `VEHICLE-CLASS PIC X(2)` host variable to `DCLDLIS-LICENSE-APPL` in `DLISDCLG.cpy`
4. Add a Vehicle Class input field to the DLISAE01 BMS map
5. Modify DLISAPPL to validate, capture, and store Vehicle Class at application submission
6. Propagate Vehicle Class through COMMAREA in DLISELIG, DLISHIST, DLISPAY, DLISAP1, DLISAP2 (read-only display)
7. Modify DLISISSU to prefer COMMAREA Vehicle Class over the screen input field
8. Recompile and deploy all 7 affected COBOL programs as a single release

### Non-Goals

1. Fee schedule differentiation by Vehicle Class — not in this phase
2. Changes to DLISCAND (candidate maintenance) — no vehicle class at candidate level
3. Changes to DLISMENU (main menu routing) — not impacted
4. Migration of historical data in ISSUED_LICENSE — already has valid data
5. Changes to the CICS CSD group DLISGRP — transaction IDs and program names unchanged

---

## 5. Current State Analysis

### System Context

**Programs Analyzed**: 10 programs

**Key Programs**:
- `DLISAPPL.cbl`: Application Entry (DL03) — captures Candidate ID and License Type; no Vehicle Class today
- `DLISELIG.cbl`: Eligibility Check (DL04) — reads application from DB2; passes COMMAREA through
- `DLISHIST.cbl`: Driving History Check (DL05) — reads driving history; passes COMMAREA through
- `DLISPAY.cbl`: Payment Entry (DL06) — processes fee payment; passes COMMAREA through
- `DLISAP1.cbl`: First Authority Approval (DL07) — approval decision; passes COMMAREA through
- `DLISAP2.cbl`: Second Authority Approval (DL08) — approval decision; passes COMMAREA through
- `DLISISSU.cbl`: License Issuance (DL09) — currently reads Vehicle Class from BMS screen field `DLIVCLSI`
- `DLISSTAT.cbl`: Status Inquiry (DL10) — read-only inquiry; not impacted by this change

**Database Tables**:
- `DLIS.LICENSE_APPLICATION`: Missing `VEHICLE_CLASS` column — new column required
- `DLIS.ISSUED_LICENSE`: Already has `VEHICLE_CLASS CHAR(2) NOT NULL` with CHECK constraint `IN ('A','B','C','D')`

**Key Findings**:
- `DLISISSU.cbl` already validates `DLIVCLSI NOT IN ('A','B','C','D')` at issuance — this validation should also exist at DLISAPPL
- `DLIS-APPL-COMMAREA` in `DLISCSEC.cpy` currently ends at `CA-LICENSE-NUMBER PIC X(20)` — appending `CA-VEHICLE-CLASS PIC X(2)` is safe and will not shift any existing field offsets
- `DCLDLIS-LICENSE-APPL` in `DLISDCLG.cpy` must gain a `VEHICLE-CLASS PIC X(2)` host variable to support the new DB2 column
- BMS map `DLISAE01` (DLISAE.bms) has no Vehicle Class field — a new DFHMDF entry is required
- The ISSUED_LICENSE table already enforces `VEHICLE_CLASS NOT NULL` — so the application-level Vehicle Class must be not null before the INSERT in DLISISSU can succeed

### Assumptions

- Vehicle Class captured at application will always match the class stored in ISSUED_LICENSE — DLISISSU will use COMMAREA value, making screen input a default pre-fill only
- Existing in-flight applications will receive a default Vehicle Class of 'C' (Heavy/standard) via SQL UPDATE migration script before go-live
- The new COMMAREA field is appended at end of `DLIS-APPL-COMMAREA` — no COMMAREA length change needed in `EXEC CICS RETURN LENGTH(350)` calls since 350 bytes are still the declared COMMAREA size; the new field is within the unused padding

### Constraints

- All 7 COBOL programs and both copybooks must compile and deploy together — partial deployment will cause layout misalignment
- The COMMAREA passed via `EXEC CICS RETURN LENGTH(350)` currently uses a hardcoded literal — developers must verify actual byte count of DLIS-APPL-COMMAREA after expansion does not exceed 350 bytes, or update the LENGTH parameter
- DB2 Bind step must be rerun after DBRM changes in DLISAPPL and DLISISSU

---

## 6. Implementation Design

### Workstreams

#### Workstream A: Database Schema

**Purpose**: Add Vehicle Class column to LICENSE_APPLICATION and update the DCLGEN copybook

**Tasks**:
1. Add `ALTER TABLE DLIS.LICENSE_APPLICATION ADD COLUMN VEHICLE_CLASS CHAR(2)` (nullable, no default)
2. Add CHECK constraint `APPL_VC CHECK (VEHICLE_CLASS IN ('A','B','C','D'))` via separate ALTER
3. Execute migration UPDATE: `UPDATE DLIS.LICENSE_APPLICATION SET VEHICLE_CLASS = 'C' WHERE VEHICLE_CLASS IS NULL AND APPLICATION_STATUS NOT IN ('IS','RE')`
4. Update `DCLDLIS-LICENSE-APPL` in `DLISDCLG.cpy` — add `10 VEHICLE-CLASS PIC X(2).` after `LICENSE-TYPE`
5. Add a new SQL script `db2/DLIS0004-ALTER-VEHICLE-CLASS.sql` for the DDL

**Dependencies**: Must complete before any COBOL recompilation

#### Workstream B: COMMAREA Expansion

**Purpose**: Add Vehicle Class carrier field to the shared COMMAREA copybook

**Tasks**:
1. Open `copybook/DLISCSEC.cpy`
2. In `DLIS-APPL-COMMAREA`, append `10 CA-VEHICLE-CLASS PIC X(2) VALUE SPACES.` after `CA-LICENSE-NUMBER`
3. Verify total byte count of DLIS-APPL-COMMAREA remains within 350-byte constraint
4. Confirm the `EXEC CICS RETURN LENGTH(350)` literals in all 7 programs still cover the full COMMAREA

**Dependencies**: Must complete before Workstreams C, D, and E

#### Workstream C: BMS Map Update

**Purpose**: Add Vehicle Class input field to the Application Entry screen

**Tasks**:
1. Open `bms/DLISAE.bms`
2. Add `DFHMDF` field `DAEVCLS` at row 9, col 20 — LENGTH=2, ATTRB=(UNPROT) for Vehicle Class input
3. Add static label `DFHMDF` at row 9, col 2: `INITIAL='VEHICLE CLASS   : '`
4. Add legend `DFHMDF` at row 9, col 23: `INITIAL='(A=MOTO  B=LIGHT  C=HEAVY  D=BUS)'`
5. Reassemble BMS mapset and install updated DSECT copybook in DLIS.COPYBOOK via `jcl/DLISBMS.jcl`

**Dependencies**: Must complete before Workstream D (DLISAPPL changes)

#### Workstream D: DLISAPPL Modifications

**Purpose**: Capture and persist Vehicle Class at application entry

**Tasks**:
1. Add Vehicle Class validation to `SUBMIT-APPLICATION` paragraph:
   - `IF DAEVCLSI = SPACES MOVE 'VEHICLE CLASS IS REQUIRED' TO DAEMSG GO TO SUBMIT-APPLICATION-EXIT`
   - `IF DAEVCLSI NOT IN ('A' 'B' 'C' 'D') MOVE 'VEHICLE CLASS MUST BE A B C OR D' TO DAEMSG GO TO SUBMIT-APPLICATION-EXIT`
2. Modify the `INSERT INTO DLIS.LICENSE_APPLICATION` to include `VEHICLE_CLASS` column and `:VEHICLE-CLASS` host variable
3. Move `DAEVCLSI` to `VEHICLE-CLASS OF DCLDLIS-LICENSE-APPL` before the INSERT
4. After successful INSERT, move `DAEVCLSI` to `CA-VEHICLE-CLASS OF DLIS-APPL-COMMAREA`

**Dependencies**: Workstreams A, B, C must be complete

#### Workstream E: Downstream Program Updates

**Purpose**: Carry Vehicle Class through COMMAREA in intermediate programs and surface it on approval screens

**Tasks (per program)**:

DLISELIG, DLISHIST, DLISPAY (read/carry only):
1. No code logic changes required — COMMAREA is passed through unchanged
2. Verify each program's `EXEC CICS RETURN LENGTH(350)` covers the expanded COMMAREA
3. Recompile and rebind as part of the coordinated release

DLISAP1, DLISAP2 (display on approval screen — optional enhancement):
1. Optionally add a display field to DLISAPPR.bms showing Vehicle Class from COMMAREA
2. Move `CA-VEHICLE-CLASS` to the BMS output field in the LOAD-APPLICATION paragraphs
3. Recompile

DLISISSU (use COMMAREA value):
1. Modify `ISSUE-LICENSE` paragraph: MOVE `CA-VEHICLE-CLASS OF DLIS-APPL-COMMAREA` TO `VEHICLE-CLASS OF DCLDLIS-ISSUED-LIC` instead of using `DLIVCLSI` directly
2. Retain `DLIVCLSI` validation as a fallback if COMMAREA is empty
3. Recompile and rebind

**Dependencies**: Workstreams A, B must be complete

### Execution Sequence

```
graph TD
    A[Workstream A: DB Schema DDL] --> B[Workstream B: COMMAREA Copybook]
    B --> C[Workstream C: BMS Map Assembly]
    B --> D[Workstream D: DLISAPPL Changes]
    C --> D
    B --> E[Workstream E: Downstream Programs]
    D --> F[Coordinated Recompile All 7 Programs]
    E --> F
    F --> G[DB2 Bind DLISPKG/DLISPLAN]
    G --> H[CSD No-op - no changes needed]
    H --> I[Integration Test]
    I --> J[Production Deployment]
```

**Critical Path**:
1. DB Schema DDL (Workstream A) — gate for everything
2. COMMAREA expansion (Workstream B) — gate for all COBOL changes
3. BMS assembly (Workstream C) — gate for DLISAPPL compilation
4. DLISAPPL + downstream recompile together (Workstreams D + E)
5. DB2 Bind
6. Integration testing

**Parallel Work Opportunities**:
- Workstream C (BMS) can proceed in parallel with Workstream D/E COBOL changes after Workstream B is done
- DLISAP1 and DLISAP2 BMS optional enhancements can proceed in parallel with DLISAPPL changes

---

## 7. Affected Components

### Programs

| Program Name | Change Type | Reason | Workspace Status |
|---|---|---|---|
| DLISAPPL.cbl | Modify | Add Vehicle Class input capture, validation, and DB2 INSERT | Available |
| DLISISSU.cbl | Modify | Read Vehicle Class from COMMAREA instead of screen only | Available |
| DLISELIG.cbl | Recompile | COMMAREA copybook changed — must recompile for layout sync | Available |
| DLISHIST.cbl | Recompile | COMMAREA copybook changed — must recompile for layout sync | Available |
| DLISPAY.cbl  | Recompile | COMMAREA copybook changed — must recompile for layout sync | Available |
| DLISAP1.cbl  | Recompile + optional modify | COMMAREA copybook changed; optional Vehicle Class display | Available |
| DLISAP2.cbl  | Recompile + optional modify | COMMAREA copybook changed; optional Vehicle Class display | Available |

### Database Tables/Files

| Table/File Name | Change Type | Reason |
|---|---|---|
| DLIS.LICENSE_APPLICATION | Modify | Add VEHICLE_CLASS CHAR(2) nullable column + CHECK constraint |
| DLIS.ISSUED_LICENSE | No change | Already has VEHICLE_CLASS CHAR(2) NOT NULL |

### Copybooks/Includes

| Copybook Name | Change Type | Reason | Workspace Status |
|---|---|---|---|
| DLISCSEC.cpy | Modify | Add CA-VEHICLE-CLASS PIC X(2) to DLIS-APPL-COMMAREA | Available |
| DLISDCLG.cpy | Modify | Add VEHICLE-CLASS PIC X(2) host variable to DCLDLIS-LICENSE-APPL | Available |

### BMS Maps

| BMS Mapset | Change Type | Reason |
|---|---|---|
| DLISAE.bms (DLISAE01) | Modify | Add DAEVCLS input field for Vehicle Class at application entry |
| DLISAPPR.bms (optional) | Optional Modify | Add Vehicle Class display on approval screens (DLISA1M01, DLISA2M01) |

### JCL / DB2

| Artifact | Change Type | Reason |
|---|---|---|
| db2/DLIS0004-ALTER-VEHICLE-CLASS.sql | Add | New ALTER TABLE and CHECK DDL |
| jcl/DLISBMS.jcl | Execute | Re-assemble BMS maps after DLISAE.bms change |
| jcl/DLISCOMP.jcl | Execute | Recompile all 7 affected programs |
| jcl/DLISBIND.jcl | Execute | Rebind DBRM for DLISAPPL and DLISISSU |

---

## 8. Data Model Changes

### DATABASE SCHEMA CHANGES

#### DLIS.LICENSE_APPLICATION

**Changes**:
- Add column: `VEHICLE_CLASS CHAR(2)` (nullable — no default, migration UPDATE will fill in-flight rows)
- Add constraint: `CONSTRAINT APPL_VC CHECK (VEHICLE_CLASS IN ('A','B','C','D'))`

**Migration Requirements**:
- Run migration UPDATE after ALTER: `UPDATE DLIS.LICENSE_APPLICATION SET VEHICLE_CLASS = 'C' WHERE VEHICLE_CLASS IS NULL AND APPLICATION_STATUS NOT IN ('IS','RE')`
- Historical IS/RE rows left NULL (they have already been processed)

**Backward Compatibility**: Partial
- New column is nullable so existing rows are not broken
- The CHECK constraint only applies to non-NULL values
- Programs that do not reference the new column will continue to work unmodified

**Rollback**:
- `ALTER TABLE DLIS.LICENSE_APPLICATION DROP COLUMN VEHICLE_CLASS` (DB2 for z/OS supports DROP COLUMN via REORG)
- Recompile all programs from pre-change copybooks

### COMMAREA LAYOUT CHANGES

#### DLIS-APPL-COMMAREA (DLISCSEC.cpy)

**Current layout ends at**: `CA-LICENSE-NUMBER PIC X(20)` — offset ~117 bytes
**New field appended**: `CA-VEHICLE-CLASS PIC X(2)` — offset ~119 bytes
**Total COMMAREA size**: Unchanged — 350 bytes declared in all `EXEC CICS RETURN LENGTH(350)` statements

---

## 9. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Partial deployment — only some programs compiled with new copybook | High | High | Enforce single coordinated release; use JCL DLISCOMP.jcl to compile all 7 programs in one run |
| In-flight applications have NULL VEHICLE_CLASS when migration UPDATE missed | Medium | High | Run migration UPDATE inside a DB2 unit of recovery before go-live; validate row count before cutover |
| BMS screen physical row position conflicts after adding DAEVCLS field | Medium | Medium | Test assembled BMS on a 3270 emulator before compiling COBOL; verify row 9 col 20 is free |
| DLISISSU ISSUED_LICENSE INSERT fails due to NOT NULL on VEHICLE_CLASS but COMMAREA is empty | Medium | High | Add null guard in DLISISSU: if CA-VEHICLE-CLASS = SPACES, use DLIVCLSI; fail if both are spaces |
| DB2 Bind fails after DBRM member updated but collection plan outdated | Low | Medium | Run DLISBIND.jcl immediately after recompile; verify plan name DLISPLAN is current |

### Critical Risks

**Risk**: Coordinated deployment failure — programs deployed at different times with mismatched COMMAREA layouts

- **Impact**: Storage overlay in CICS task storage; potential ASRA or AEIP abends
- **Mitigation**: Deploy all 7 load modules in a single CICS PHASEIN or bring-down/bring-up sequence; do not activate new load modules one by one
- **Contingency**: CICS NEWCOPY all old load modules if abends are detected; revert copybooks and recompile old versions

---

## 10. Testing Strategy

### Unit Tests

**Coverage Target**: 100% of modified paragraphs

**Key Test Cases**:

1. DLISAPPL — Vehicle Class required validation
   - **Requirement**: FR1, FR5
   - **Validation**: Submit with blank Vehicle Class → message 'VEHICLE CLASS IS REQUIRED'

2. DLISAPPL — Vehicle Class invalid value
   - **Requirement**: FR5
   - **Validation**: Submit with Vehicle Class 'E' → message 'VEHICLE CLASS MUST BE A B C OR D'

3. DLISAPPL — Vehicle Class stored in DB2
   - **Requirement**: FR2
   - **Validation**: Submit valid application with Vehicle Class 'B' → SELECT VEHICLE_CLASS from DLIS.LICENSE_APPLICATION = 'B'

4. DLISISSU — COMMAREA Vehicle Class used for license number generation
   - **Requirement**: FR4
   - **Validation**: Issue license with CA-VEHICLE-CLASS = 'A' in COMMAREA → ISSUED_LICENSE.VEHICLE_CLASS = 'A'

### Integration Tests

**Scope**: Full application workflow DL03 → DL04 → DL05 → DL06 → DL07 → DL08 → DL09

**Key Test Cases**:
1. End-to-end flow with Vehicle Class 'A' — verify class preserved from DLISAPPL through to ISSUED_LICENSE
2. End-to-end flow with Vehicle Class 'D' — verify license number prefix includes class

### Regression Tests

**Existing Functionality to Validate**:
- License Type validation in DLISAPPL (L/P/O) — unchanged, must still work
- Fee calculation (CALC-FEE) in DLISAPPL — unchanged, no impact
- Eligibility check logic in DLISELIG — COMMAREA passthrough only, verify no field shift
- Payment processing in DLISPAY — COMMAREA passthrough only
- Both approval programs — verify approval accept/reject still functions correctly

### Migration Tests

- Validate migration UPDATE count matches expected in-flight application count
- Verify no NULL VEHICLE_CLASS remains in active applications after migration
- Verify rolled-back applications (status = RE) tolerate NULL VEHICLE_CLASS

---

## 11. Rollout and Operational Plan

### Deployment Sequence

1. **Prepare**: Commit all source changes to version control; review code
2. **DB2 DDL**: Execute `db2/DLIS0004-ALTER-VEHICLE-CLASS.sql` via `jcl/DLISDB2.jcl` equivalent
3. **Migration**: Run SQL UPDATE to fill in-flight application rows
4. **BMS**: Run `jcl/DLISBMS.jcl` to assemble updated DLISAE mapset; load updated DSECT to DLIS.COPYBOOK
5. **Compile**: Run `jcl/DLISCOMP.jcl` to compile all 7 programs simultaneously
6. **Bind**: Run `jcl/DLISBIND.jcl` to rebind DLISAPPL and DLISISSU DBRMs
7. **CICS**: CICS PHASEIN or controlled restart to activate all new load modules atomically
8. **Smoke Test**: DL03 → submit application with Vehicle Class → verify DB2 row → DL09 → issue license → verify ISSUED_LICENSE.VEHICLE_CLASS

### Rollback Plan

**Trigger Conditions**:
- ASRA or AEIP abends in any DLIS transaction after deployment
- DB2 INSERT failure due to Vehicle Class constraint

**Rollback Steps**:
1. CICS PHASEIN old load modules (restore from DLIS.LOADLIB backup)
2. Recompile all 7 programs from pre-change copybooks
3. Issue CICS PHASEIN to activate old load modules
4. Run `ALTER TABLE DLIS.LICENSE_APPLICATION DROP COLUMN VEHICLE_CLASS` if DB2 errors persist

---

## Appendix A: Analysis Data

### Programs Analyzed

| Program | Transaction | Map | Purpose |
|---|---|---|---|
| DLISAPPL | DL03 | DLISAE / DLISAE01 | Application Entry — primary change point |
| DLISELIG | DL04 | DLISECHPE | Eligibility Check — COMMAREA passthrough |
| DLISHIST | DL05 | DLISECHPE | History Check — COMMAREA passthrough |
| DLISPAY  | DL06 | DLISECHPE | Payment — COMMAREA passthrough |
| DLISAP1  | DL07 | DLISAPPR / DLISA1M01 | First Approval — optional display |
| DLISAP2  | DL08 | DLISAPPR / DLISA2M01 | Second Approval — optional display |
| DLISISSU | DL09 | DLISLI / DLISLIM01 | License Issuance — secondary change point |
| DLISSTAT | DL10 | DLISAPPR / DLISST01 | Status Inquiry — not impacted |

### Key Variables / Data Structures

| Variable | Location | Type | Purpose |
|---|---|---|---|
| DAEVCLS / DAEVCLSI / DAEVCLSO | DLISAE.bms (new) | BMS DFHMDF | New screen input for Vehicle Class |
| CA-VEHICLE-CLASS | DLISCSEC.cpy (new) | PIC X(2) | COMMAREA carrier field |
| VEHICLE-CLASS | DLISDCLG.cpy / DCLDLIS-LICENSE-APPL (new) | PIC X(2) | DB2 host variable for LICENSE_APPLICATION |
| VEHICLE-CLASS | DLISDCLG.cpy / DCLDLIS-ISSUED-LIC (existing) | PIC X(2) | DB2 host variable for ISSUED_LICENSE (no change) |
| DLIVCLSI | DLISAPPR.bms / DLISLIM01 (existing) | BMS DFHMDF | Existing issuance screen Vehicle Class input |

---

## Appendix B: Traceability Matrix

| Requirement ID | Requirement | Implementation Workstream | Test Case |
|---|---|---|---|
| FR1 | Vehicle Class captured at application entry | Workstream C + D | TC-1 DLISAPPL validation |
| FR2 | Vehicle Class persisted in LICENSE_APPLICATION | Workstream A + D | TC-3 DB2 insert verification |
| FR3 | Vehicle Class propagated through COMMAREA | Workstream B + E | Integration end-to-end |
| FR4 | DLISISSU uses COMMAREA Vehicle Class | Workstream E (DLISISSU) | TC-4 COMMAREA-driven issuance |
| FR5 | Vehicle Class validated A/B/C/D | Workstream D | TC-1, TC-2 |
| FR6 | All programs recompiled together | Build process | Deployment smoke test |
| NFR1 | COMMAREA within 32,763-byte CICS limit | Workstream B | Design-time verification |
| NFR2 | New DB2 column nullable for existing rows | Workstream A | Migration test |

---

**Last Updated**: 2025-10-26T00:00:00Z
**Next Review Date**: 2025-11-02
