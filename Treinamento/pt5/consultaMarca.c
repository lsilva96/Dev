/*
 * xHarbour build 1.2.1 Intl. (SimpLex) (Rev. 9438)
 * Generated C source code from <consultaMarca.prg>
 * Command: -oconsultaMarca.c -m -n -p -q -gc0 -IC:\Omie\xHB\include -IC:\Omie\xHB\include\w32 consultaMarca.prg 
 * Created: 2022.08.06 23:47:58 (XCC ISO C Compiler 2.70)
 */

#include "hbvmpub.h"
#include "hbinit.h"

#define __PRG_SOURCE__ "consultaMarca.prg"

HB_FUNC( MAIN );

HB_FUNC_EXTERN( TIPCLIENTHTTP );
HB_FUNC_EXTERN( HSETCASEMATCH );
HB_FUNC_EXTERN( QOUT );

#undef HB_PRG_PCODE_VER
#define HB_PRG_PCODE_VER 10

#include "hbapi.h"

HB_INIT_SYMBOLS_BEGIN( hb_vm_SymbolInit_CONSULTAMARCA )
{ "MAIN", {HB_FS_PUBLIC | HB_FS_LOCAL | HB_FS_FIRST}, {HB_FUNCNAME( MAIN )}, &ModuleFakeDyn },
{ "NEW", {HB_FS_PUBLIC}, {NULL}, NULL },
{ "TIPCLIENTHTTP", {HB_FS_PUBLIC}, {HB_FUNCNAME( TIPCLIENTHTTP )}, NULL },
{ "HSETCASEMATCH", {HB_FS_PUBLIC}, {HB_FUNCNAME( HSETCASEMATCH )}, NULL },
{ "OPEN", {HB_FS_PUBLIC}, {NULL}, NULL },
{ "READALL", {HB_FS_PUBLIC}, {NULL}, NULL },
{ "CLOSE", {HB_FS_PUBLIC}, {NULL}, NULL },
{ "QOUT", {HB_FS_PUBLIC}, {HB_FUNCNAME( QOUT )}, NULL },
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
	13,3,0,133,6,0,48,1,0,108,2,100,12,0,
	106,51,104,116,116,112,58,47,47,112,97,114,97,108,
	108,101,108,117,109,46,99,111,109,46,98,114,47,102,
	105,112,101,47,97,112,105,47,118,49,47,99,97,114,
	114,111,115,47,109,97,114,99,97,115,0,112,1,80,
	1,134,3,172,0,0,80,3,134,4,108,3,100,95,
	3,9,20,2,134,6,106,9,120,72,97,114,98,111,
	117,114,0,96,3,0,106,2,113,0,2,134,7,106,
	3,101,110,0,96,3,0,106,3,104,108,0,2,134,
	8,106,14,71,111,111,103,108,101,43,83,101,97,114,
	99,104,0,96,3,0,106,5,98,116,110,71,0,2,
	134,14,48,4,0,95,1,112,0,28,34,134,16,48,
	5,0,95,1,112,0,80,2,134,19,48,6,0,95,
	1,112,0,73,134,20,108,7,100,95,2,20,1,25,
	36,134,22,108,7,100,106,18,67,111,110,110,101,99,
	116,105,111,110,32,101,114,114,111,114,58,0,48,8,
	0,95,1,112,0,20,2,134,25,7
   };

   hb_vmExecute( pcode, symbols );
}

