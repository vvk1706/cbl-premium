//DLISCSD  JOB (DLIS),'DLIS CSD INSTALL',CLASS=A,
//         MSGCLASS=X,NOTIFY=&SYSUID
//*================================================================*
//* JOB   : DLISCSD                                                *
//* Desc  : Run DFHCSDUP to install DLIS CSD resource definitions  *
//*================================================================*
//STEP010  EXEC PGM=DFHCSDUP,REGION=1M
//STEPLIB  DD DSN=CICSTS.SDFHLOAD,DISP=SHR
//DFHCSD   DD DSN=CICSTS.DFHCSD,DISP=SHR
//SYSPRINT DD SYSOUT=*
//SYSIN    DD DSN=DLIS.CSD(DLISCSD),DISP=SHR
//*================================================================*
//STEP020  EXEC PGM=DFHCSDUP,REGION=1M,COND=(4,LT,STEP010)
//STEPLIB  DD DSN=CICSTS.SDFHLOAD,DISP=SHR
//DFHCSD   DD DSN=CICSTS.DFHCSD,DISP=SHR
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
  INSTALL GROUP(DLISGRP)
