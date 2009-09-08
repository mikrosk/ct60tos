
#define STACK_SIZE 10000

/*>>>>>> Export references <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/

        .global _app

/*>>>>>> Import references <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/

        .global _main

/*>>>>>> Data structures <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/

        .text

/*>>>>>>> Code segment <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< */

/* Setup pointer to base page */

Start:
        MOVE.L  A0,D0
        BNE.S   ACC
        MOVE.L  4(A7),A0    // BasePagePointer from Stack
        MOVEQ.L #1,D0       // Program is Application
        BRA.S   APP
ACC:
        CLR.W   D0          // Program is DeskAccessory
APP:
        MOVE.W  D0,_app

/* Compute size of required memory
* := text segment size + data segment size + bss segment size
*  + stack size + base page size
* (base page size includes stack size)
*/

        MOVE.L  0xC(A0),D0   // text size
        ADD.L   0x14(A0),D0  // data size
        ADD.L   0x1C(A0),D0  // bss  size
        ADD.L   #256,D0      // basepage
        BCLR    #0,D0
        LEA     stack+STACK_SIZE,SP
        TST.W   _app
        BEQ.S   CALL_MAIN
        MOVE.L  D0,-(SP)
        PEA     (A0)
        CLR.W   -(SP)
        MOVE.W  #0x4A,-(SP)
        TRAP    #1
        LEA     12(SP),SP
CALL_MAIN:

/******* Execute main program *******************************************/

        JSR     _main

/******** exit ***********************************************************
*
* Terminate program
*
* Entry parameters:
*   <D0.W> = Termination status : Integer
* Return parameters:
*   Never returns
*/
exit:
        MOVE.W  D0,-(A7)
        MOVE.W  #76,-(A7)
        TRAP    #1

/*>>>>>>> Data segment <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/

        .data

/* Application flag */

_app:
        .DS.W   1

        .lcomm stack,STACK_SIZE

        .end
