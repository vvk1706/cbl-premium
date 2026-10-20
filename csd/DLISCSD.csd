*================================================================*
* CICS CSD Resource Definitions                                  *
* System  : DLIS - Driver License Issuance System                *
* Desc    : Define all CICS resources: Programs, Mapsets,        *
*           Transactions and Transaction Lists                    *
*================================================================*
* DFHCSDUP batch input - run with DFHCSDUP utility               *
*================================================================*

*----------------------------------------------------------------*
* PROGRAMS
*----------------------------------------------------------------*
 DEFINE PROGRAM(DLISMENU) GROUP(DLISGRP)
        DESCRIPTION(DLIS Main Menu Program)
        LANGUAGE(COBOL)
        RELOAD(NO)
        RESIDENT(NO)
        USAGE(NORMAL)
        USELPACOPY(NO)
        STATUS(ENABLED)
        REMOTESYSTEM()
        EXECKEY(USER)
        CONCURRENCY(QUASIRENT)
        DATALOCATION(ANY)
        STORAGE(SHARED)

 DEFINE PROGRAM(DLISCAND) GROUP(DLISGRP)
        DESCRIPTION(DLIS Candidate Maintenance)
        LANGUAGE(COBOL)
        STATUS(ENABLED)
        EXECKEY(USER)
        CONCURRENCY(QUASIRENT)

 DEFINE PROGRAM(DLISAPPL) GROUP(DLISGRP)
        DESCRIPTION(DLIS License Application Entry)
        LANGUAGE(COBOL)
        STATUS(ENABLED)
        EXECKEY(USER)
        CONCURRENCY(QUASIRENT)

 DEFINE PROGRAM(DLISSTAT) GROUP(DLISGRP)
        DESCRIPTION(DLIS Application Status Inquiry)
        LANGUAGE(COBOL)
        STATUS(ENABLED)
        EXECKEY(USER)
        CONCURRENCY(QUASIRENT)

 DEFINE PROGRAM(DLISELIG) GROUP(DLISGRP)
        DESCRIPTION(DLIS Eligibility Check)
        LANGUAGE(COBOL)
        STATUS(ENABLED)
        EXECKEY(USER)
        CONCURRENCY(QUASIRENT)

 DEFINE PROGRAM(DLISHIST) GROUP(DLISGRP)
        DESCRIPTION(DLIS Driving History Check)
        LANGUAGE(COBOL)
        STATUS(ENABLED)
        EXECKEY(USER)
        CONCURRENCY(QUASIRENT)

 DEFINE PROGRAM(DLISPAY)  GROUP(DLISGRP)
        DESCRIPTION(DLIS Payment Entry)
        LANGUAGE(COBOL)
        STATUS(ENABLED)
        EXECKEY(USER)
        CONCURRENCY(QUASIRENT)

 DEFINE PROGRAM(DLISAP1)  GROUP(DLISGRP)
        DESCRIPTION(DLIS First Authority Approval)
        LANGUAGE(COBOL)
        STATUS(ENABLED)
        EXECKEY(USER)
        CONCURRENCY(QUASIRENT)

 DEFINE PROGRAM(DLISAP2)  GROUP(DLISGRP)
        DESCRIPTION(DLIS Second Authority Approval)
        LANGUAGE(COBOL)
        STATUS(ENABLED)
        EXECKEY(USER)
        CONCURRENCY(QUASIRENT)

 DEFINE PROGRAM(DLISISSU) GROUP(DLISGRP)
        DESCRIPTION(DLIS License Issuance)
        LANGUAGE(COBOL)
        STATUS(ENABLED)
        EXECKEY(USER)
        CONCURRENCY(QUASIRENT)

 DEFINE PROGRAM(DLISRPRT) GROUP(DLISGRP)
        DESCRIPTION(DLIS Receipt Print Stub)
        LANGUAGE(COBOL)
        STATUS(ENABLED)
        EXECKEY(USER)
        CONCURRENCY(QUASIRENT)

 DEFINE PROGRAM(DLISLPRT) GROUP(DLISGRP)
        DESCRIPTION(DLIS License Print Stub)
        LANGUAGE(COBOL)
        STATUS(ENABLED)
        EXECKEY(USER)
        CONCURRENCY(QUASIRENT)

*----------------------------------------------------------------*
* MAPSETS
*----------------------------------------------------------------*
 DEFINE MAPSET(DLISMM)   GROUP(DLISGRP)
        DESCRIPTION(DLIS Main Menu Mapset)
        STATUS(ENABLED)
        RESIDENT(NO)

 DEFINE MAPSET(DLISCM)   GROUP(DLISGRP)
        DESCRIPTION(DLIS Candidate Maintenance Mapset)
        STATUS(ENABLED)
        RESIDENT(NO)

 DEFINE MAPSET(DLISAE)   GROUP(DLISGRP)
        DESCRIPTION(DLIS Application Entry Mapset)
        STATUS(ENABLED)
        RESIDENT(NO)

 DEFINE MAPSET(DLISEC)   GROUP(DLISGRP)
        DESCRIPTION(DLIS Eligibility Check Mapset)
        STATUS(ENABLED)
        RESIDENT(NO)

 DEFINE MAPSET(DLISHC)   GROUP(DLISGRP)
        DESCRIPTION(DLIS History Check Mapset)
        STATUS(ENABLED)
        RESIDENT(NO)

 DEFINE MAPSET(DLISPE)   GROUP(DLISGRP)
        DESCRIPTION(DLIS Payment Entry Mapset)
        STATUS(ENABLED)
        RESIDENT(NO)

 DEFINE MAPSET(DLISA1)   GROUP(DLISGRP)
        DESCRIPTION(DLIS First Approval Mapset)
        STATUS(ENABLED)
        RESIDENT(NO)

 DEFINE MAPSET(DLISA2)   GROUP(DLISGRP)
        DESCRIPTION(DLIS Second Approval Mapset)
        STATUS(ENABLED)
        RESIDENT(NO)

 DEFINE MAPSET(DLISLI)   GROUP(DLISGRP)
        DESCRIPTION(DLIS License Issue Mapset)
        STATUS(ENABLED)
        RESIDENT(NO)

 DEFINE MAPSET(DLISST)   GROUP(DLISGRP)
        DESCRIPTION(DLIS Status Inquiry Mapset)
        STATUS(ENABLED)
        RESIDENT(NO)

*----------------------------------------------------------------*
* TRANSACTIONS
*----------------------------------------------------------------*
 DEFINE TRANSACTION(DL01) GROUP(DLISGRP)
        DESCRIPTION(DLIS Main Menu)
        PROGRAM(DLISMENU)
        PROFILE(DFHCICST)
        STATUS(ENABLED)
        TASKDATAKEY(USER)
        STORAGECLEAR(NO)
        RUNAWAY(SYSTEM)
        SHUTDOWN(DISABLED)
        TWASIZE(0)
        PRIORITY(1)
        TRANCLASS(DFHTCL00)
        DTIMOUT(10)
        RESTART(NO)
        SPURGE(YES)
        TPURGE(NO)
        DUMP(YES)
        TRACE(YES)
        RESSEC(NO)

 DEFINE TRANSACTION(DL02) GROUP(DLISGRP)
        DESCRIPTION(DLIS Candidate Maintenance)
        PROGRAM(DLISCAND)
        PROFILE(DFHCICST)
        STATUS(ENABLED)
        TASKDATAKEY(USER)
        DTIMOUT(10)
        SPURGE(YES)

 DEFINE TRANSACTION(DL03) GROUP(DLISGRP)
        DESCRIPTION(DLIS License Application Entry)
        PROGRAM(DLISAPPL)
        PROFILE(DFHCICST)
        STATUS(ENABLED)
        TASKDATAKEY(USER)
        DTIMOUT(10)
        SPURGE(YES)

 DEFINE TRANSACTION(DL04) GROUP(DLISGRP)
        DESCRIPTION(DLIS Application Status Inquiry)
        PROGRAM(DLISSTAT)
        PROFILE(DFHCICST)
        STATUS(ENABLED)
        TASKDATAKEY(USER)
        DTIMOUT(10)
        SPURGE(YES)

 DEFINE TRANSACTION(DL05) GROUP(DLISGRP)
        DESCRIPTION(DLIS Eligibility Check)
        PROGRAM(DLISELIG)
        PROFILE(DFHCICST)
        STATUS(ENABLED)
        TASKDATAKEY(USER)
        DTIMOUT(10)
        SPURGE(YES)

 DEFINE TRANSACTION(DL06) GROUP(DLISGRP)
        DESCRIPTION(DLIS Driving History Check)
        PROGRAM(DLISHIST)
        PROFILE(DFHCICST)
        STATUS(ENABLED)
        TASKDATAKEY(USER)
        DTIMOUT(10)
        SPURGE(YES)

 DEFINE TRANSACTION(DL07) GROUP(DLISGRP)
        DESCRIPTION(DLIS Payment Entry)
        PROGRAM(DLISPAY)
        PROFILE(DFHCICST)
        STATUS(ENABLED)
        TASKDATAKEY(USER)
        DTIMOUT(10)
        SPURGE(YES)

 DEFINE TRANSACTION(DL08) GROUP(DLISGRP)
        DESCRIPTION(DLIS First Authority Approval)
        PROGRAM(DLISAP1)
        PROFILE(DFHCICST)
        STATUS(ENABLED)
        TASKDATAKEY(USER)
        DTIMOUT(30)
        SPURGE(YES)

 DEFINE TRANSACTION(DL09) GROUP(DLISGRP)
        DESCRIPTION(DLIS Second Authority Approval)
        PROGRAM(DLISAP2)
        PROFILE(DFHCICST)
        STATUS(ENABLED)
        TASKDATAKEY(USER)
        DTIMOUT(30)
        SPURGE(YES)

 DEFINE TRANSACTION(DL10) GROUP(DLISGRP)
        DESCRIPTION(DLIS License Issuance)
        PROGRAM(DLISISSU)
        PROFILE(DFHCICST)
        STATUS(ENABLED)
        TASKDATAKEY(USER)
        DTIMOUT(30)
        SPURGE(YES)

*----------------------------------------------------------------*
* DB2ENTRY - DB2 connection for the DLIS application plan
*----------------------------------------------------------------*
 DEFINE DB2ENTRY(DLISDB2E) GROUP(DLISGRP)
        DESCRIPTION(DLIS DB2 Entry)
        PLAN(DLISPLAN)
        PLANEXITNAME()
        ACCOUNTREC(TASK)
        AUTHTYPE(USERID)
        PRIORITY(HIGH)
        THREADLIMIT(10)
        THREADWAIT(YES)
        DROLLBACK(NO)

*----------------------------------------------------------------*
* TRANSLIST - add all DLIS transactions to a list
*----------------------------------------------------------------*
 DEFINE TRANSLIST(DLISLIST) GROUP(DLISGRP)
        DESCRIPTION(DLIS Transaction List)
        TRANSACTION(DL01)
        TRANSACTION(DL02)
        TRANSACTION(DL03)
        TRANSACTION(DL04)
        TRANSACTION(DL05)
        TRANSACTION(DL06)
        TRANSACTION(DL07)
        TRANSACTION(DL08)
        TRANSACTION(DL09)
        TRANSACTION(DL10)
