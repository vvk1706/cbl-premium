//DLISCOMP JOB (DLIS),'DLIS COBOL COMPILE',CLASS=A,
//         MSGCLASS=X,NOTIFY=&SYSUID
//*================================================================*
//* JOB   : DLISCOMP                                               *
//* Desc  : Compile all DLIS COBOL programs                        *
//*================================================================*

//DLISMENU EXEC DLISCLNK,
//         MEMBER=DLISMENU
//*
//DLISCAND EXEC DLISCLNK,COND=(4,LT),
//         MEMBER=DLISCAND
//*
//DLISAPPL EXEC DLISCLNK,COND=(4,LT),
//         MEMBER=DLISAPPL
//*
//DLISELIG EXEC DLISCLNK,COND=(4,LT),
//         MEMBER=DLISELIG
//*
//DLISHIST EXEC DLISCLNK,COND=(4,LT),
//         MEMBER=DLISHIST
//*
//DLISPAY  EXEC DLISCLNK,COND=(4,LT),
//         MEMBER=DLISPAY
//*
//DLISAP1  EXEC DLISCLNK,COND=(4,LT),
//         MEMBER=DLISAP1
//*
//DLISAP2  EXEC DLISCLNK,COND=(4,LT),
//         MEMBER=DLISAP2
//*
//DLISISSU EXEC DLISCLNK,COND=(4,LT),
//         MEMBER=DLISISSU
//*
//DLISSTAT EXEC DLISCLNK,COND=(4,LT),
//         MEMBER=DLISSTAT
