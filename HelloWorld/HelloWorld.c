/*
 * xHarbour build 1.2.1 Intl. (SimpLex) (Rev. 9438)
 * Generated C source code from <HelloWorld.prg>
 * Command: -oHelloWorld.c -m -n -p -q -gc0 -IC:\Omie\xHB\include -IC:\Omie\xHB\include\w32 HelloWorld.prg 
 * Created: 2022.08.04 09:03:11 (XCC ISO C Compiler 2.70)
 */

#include "hbvmpub.h"
#include "hbinit.h"

#define __PRG_SOURCE__ "HelloWorld.prg"

HB_FUNC( MAIN );

HB_FUNC_EXTERN( QOUT );

#undef HB_PRG_PCODE_VER
#define HB_PRG_PCODE_VER 10

#include "hbapi.h"

HB_INIT_SYMBOLS_BEGIN( hb_vm_SymbolInit_HELLOWORLD )
{ "MAIN", {HB_FS_PUBLIC | HB_FS_LOCAL | HB_FS_FIRST}, {HB_FUNCNAME( MAIN )}, &ModuleFakeDyn },
{ "QOUT", {HB_FS_PUBLIC}, {HB_FUNCNAME( QOUT )}, NULL }
HB_INIT_SYMBOLS_END( hb_vm_SymbolInit_HELLOWORLD )

#if defined( HB_PRAGMA_STARTUP )
   #pragma startup hb_vm_SymbolInit_HELLOWORLD
#elif defined( HB_DATASEG_STARTUP )
   #define HB_DATASEG_BODY    HB_DATASEG_FUNC( hb_vm_SymbolInit_HELLOWORLD )
   #include "hbiniseg.h"
#endif

HB_FUNC( MAIN )
{
   static const BYTE pcode[] =
   {
	133,2,0,108,1,100,106,12,72,101,108,108,111,32,
	87,111,114,108,100,0,20,1,134,1,100,110,7
   };

   hb_vmExecute( pcode, symbols );
}

