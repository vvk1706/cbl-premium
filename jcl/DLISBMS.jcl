//DLISBMS  JOB (DLIS),'DLIS BMS ASSEMBLY',CLASS=A,
//         MSGCLASS=X,NOTIFY=&SYSUID
//*================================================================*
//* JOB   : DLISBMS                                                *
//* Desc  : Assemble all DLIS BMS map sources                      *
//*================================================================*

//DLISMM   EXEC DLISBASM,
//         MEMBER=DLISMM
//*
//DLISCM   EXEC DLISBASM,COND=(4,LT),
//         MEMBER=DLISCM
//*
//DLISAE   EXEC DLISBASM,COND=(4,LT),
//         MEMBER=DLISAE
//*
//DLISEC   EXEC DLISBASM,COND=(4,LT),
//         MEMBER=DLISEC
//*
//DLISHC   EXEC DLISBASM,COND=(4,LT),
//         MEMBER=DLISHC
//*
//DLISPE   EXEC DLISBASM,COND=(4,LT),
//         MEMBER=DLISPE
//*
//DLISA1   EXEC DLISBASM,COND=(4,LT),
//         MEMBER=DLISA1
//*
//DLISA2   EXEC DLISBASM,COND=(4,LT),
//         MEMBER=DLISA2
//*
//DLISLI   EXEC DLISBASM,COND=(4,LT),
//         MEMBER=DLISLI
//*
//DLISST   EXEC DLISBASM,COND=(4,LT),
//         MEMBER=DLISST
