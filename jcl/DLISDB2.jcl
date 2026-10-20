//DLISDB2  JOB (DLIS),'DLIS DB2 CREATE',CLASS=A,
//         MSGCLASS=X,NOTIFY=&SYSUID
//*================================================================*
//* JOB   : DLISDB2                                                *
//* Desc  : Execute DB2 DDL to create DLIS database objects        *
//*         Run in sequence: tables -> indexes -> grants            *
//*================================================================*
//STEP010  EXEC PGM=IKJEFT01
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD *
  DSN SYSTEM(DSN1)
  RUN  PROGRAM(DSNTEP2) PLAN(DSNTEP2) -
       LIB('DSN.SDSNEXIT')
  END
//*
//INPUT    DD DSN=DLIS.DDL(DLIS0001),DISP=SHR
//OUTPUT   DD SYSOUT=*
//*================================================================*
//STEP020  EXEC PGM=IKJEFT01,COND=(4,LT,STEP010)
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD *
  DSN SYSTEM(DSN1)
  RUN  PROGRAM(DSNTEP2) PLAN(DSNTEP2) -
       LIB('DSN.SDSNEXIT')
  END
//*
//INPUT    DD DSN=DLIS.DDL(DLIS0002),DISP=SHR
//OUTPUT   DD SYSOUT=*
//*================================================================*
//STEP030  EXEC PGM=IKJEFT01,COND=(4,LT,STEP020)
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD *
  DSN SYSTEM(DSN1)
  RUN  PROGRAM(DSNTEP2) PLAN(DSNTEP2) -
       LIB('DSN.SDSNEXIT')
  END
//*
//INPUT    DD DSN=DLIS.DDL(DLIS0003),DISP=SHR
//OUTPUT   DD SYSOUT=*
