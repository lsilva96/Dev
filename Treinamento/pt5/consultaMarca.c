/*
 * xHarbour build 1.2.1 Intl. (SimpLex) (Rev. 9438)
 * Generated C source code from <consultaMarca.prg>
 * Command: -oconsultaMarca.c -m -n -p -q -gc0 -IC:\Omie\xHB\include -IC:\Omie\xHB\include\w32 consultaMarca.prg 
 * Created: 2022.08.07 15:52:26 (XCC ISO C Compiler 2.70)
 */

#include "hbvmpub.h"
#include "hbinit.h"

#define __PRG_SOURCE__ "consultaMarca.prg"

HB_FUNC( MAIN );

HB_FUNC_EXTERN( TIPCLIENTHTTP );
HB_FUNC_EXTERN( HB_JSONENCODE );
HB_FUNC_EXTERN( QOUT );

#undef HB_PRG_PCODE_VER
#define HB_PRG_PCODE_VER 10

#include "hbapi.h"

HB_INIT_SYMBOLS_BEGIN( hb_vm_SymbolInit_CONSULTAMARCA )
{ "MAIN", {HB_FS_PUBLIC | HB_FS_LOCAL | HB_FS_FIRST}, {HB_FUNCNAME( MAIN )}, &ModuleFakeDyn },
{ "NEW", {HB_FS_PUBLIC}, {NULL}, NULL },
{ "TIPCLIENTHTTP", {HB_FS_PUBLIC}, {HB_FUNCNAME( TIPCLIENTHTTP )}, NULL },
{ "OPEN", {HB_FS_PUBLIC}, {NULL}, NULL },
{ "READALL", {HB_FS_PUBLIC}, {NULL}, NULL },
{ "AMARCAS", {HB_FS_PUBLIC}, {NULL}, NULL },
{ "HMARCAS", {HB_FS_PUBLIC}, {NULL}, NULL },
{ "HB_JSONENCODE", {HB_FS_PUBLIC}, {HB_FUNCNAME( HB_JSONENCODE )}, NULL },
{ "QOUT", {HB_FS_PUBLIC}, {HB_FUNCNAME( QOUT )}, NULL },
{ "CLOSE", {HB_FS_PUBLIC}, {NULL}, NULL },
{ "LASTERRORMESSAGE", {HB_FS_PUBLIC}, {NULL}, NULL }
HB_INIT_SYMBOLS_END( hb_vm_SymbolInit_CONSULTAMARCA )

#if defined( HB_PRAGMA_STARTUP )
   #pragma startup hb_vm_SymbolInit_CONSULTAMARCA
#elif defined( HB_DATASEG_STARTUP )
   #define HB_DATASEG_BODY    HB_DATASEG_FUNC( hb_vm_SymbolInit_CONSULTAMARCA )
   #include "hbiniseg.h"
#endif

HB_FUNC( MAIN )
{
   static const BYTE pcode[] =
   {
	13,2,0,133,10,0,48,1,0,108,2,100,12,0,
	106,51,104,116,116,112,58,47,47,112,97,114,97,108,
	108,101,108,117,109,46,99,111,109,46,98,114,47,102,
	105,112,101,47,97,112,105,47,118,49,47,99,97,114,
	114,111,115,47,109,97,114,99,97,115,0,112,1,80,
	1,134,2,48,3,0,95,1,112,0,28,110,134,3,
	48,4,0,95,1,112,0,80,2,134,5,4,0,0,
	83,5,0,134,6,172,0,0,83,6,0,134,8,108,
	7,100,95,2,99,5,0,20,2,134,9,109,5,0,
	99,6,0,106,6,73,84,69,77,83,0,2,134,11,
	108,8,100,98,6,0,106,6,73,84,69,77,83,0,
	1,122,1,20,1,134,13,108,8,100,109,5,0,20,
	1,134,17,48,9,0,95,1,112,0,73,134,18,108,
	8,100,95,2,20,1,25,35,134,20,108,8,100,106,
	17,101,114,114,111,32,100,101,32,99,111,110,101,120,
	97,111,58,0,48,10,0,95,1,112,0,20,2,134,
	23,7
   };

   hb_vmExecute( pcode, symbols );
}

