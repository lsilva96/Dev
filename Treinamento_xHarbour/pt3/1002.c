/*
 * xHarbour build 1.2.1 Intl. (SimpLex) (Rev. 9438)
 * Generated C source code from <1002.prg>
 * Command: -o1002.c -m -n -p -q -gc0 -IC:\Omie\xHB\include -IC:\Omie\xHB\include\w32 1002.prg 
 * Created: 2022.08.05 18:25:11 (XCC ISO C Compiler 2.70)
 */

#include "hbvmpub.h"
#include "hbinit.h"

#define __PRG_SOURCE__ "1002.prg"

HB_FUNC( MAIN );
HB_FUNC( AREADOCIRCULO );

HB_FUNC_EXTERN( __MVPUBLIC );
HB_FUNC_EXTERN( LEN );
HB_FUNC_EXTERN( QOUT );
HB_FUNC_EXTERN( STR );
HB_FUNC_EXTERN( ROUND );

#undef HB_PRG_PCODE_VER
#define HB_PRG_PCODE_VER 10

#include "hbapi.h"

HB_INIT_SYMBOLS_BEGIN( hb_vm_SymbolInit_1002 )
{ "MAIN", {HB_FS_PUBLIC | HB_FS_LOCAL | HB_FS_FIRST}, {HB_FUNCNAME( MAIN )}, &ModuleFakeDyn },
{ "AINPUTS", {HB_FS_PUBLIC}, {NULL}, NULL },
{ "__MVPUBLIC", {HB_FS_PUBLIC}, {HB_FUNCNAME( __MVPUBLIC )}, NULL },
{ "AREADOCIRCULO", {HB_FS_PUBLIC | HB_FS_LOCAL}, {HB_FUNCNAME( AREADOCIRCULO )}, &ModuleFakeDyn },
{ "LEN", {HB_FS_PUBLIC}, {HB_FUNCNAME( LEN )}, NULL },
{ "QOUT", {HB_FS_PUBLIC}, {HB_FUNCNAME( QOUT )}, NULL },
{ "STR", {HB_FS_PUBLIC}, {HB_FUNCNAME( STR )}, NULL },
{ "ROUND", {HB_FS_PUBLIC}, {HB_FUNCNAME( ROUND )}, NULL }
HB_INIT_SYMBOLS_END( hb_vm_SymbolInit_1002 )

#if defined( HB_PRAGMA_STARTUP )
   #pragma startup hb_vm_SymbolInit_1002
#elif defined( HB_DATASEG_STARTUP )
   #define HB_DATASEG_BODY    HB_DATASEG_FUNC( hb_vm_SymbolInit_1002 )
   #include "hbiniseg.h"
#endif

HB_FUNC( MAIN )
{
   static const BYTE pcode[] =
   {
	133,14,0,101,0,0,0,0,0,0,0,64,10,2,
	101,41,92,143,194,245,40,89,64,10,2,101,0,0,
	0,0,0,192,98,64,10,2,4,3,0,108,2,100,
	108,1,20,1,83,1,0,134,2,108,3,100,20,0,
	134,4,7
   };

   hb_vmExecute( pcode, symbols );
}

HB_FUNC( AREADOCIRCULO )
{
   static const BYTE pcode[] =
   {
	13,2,0,133,26,0,101,110,134,27,240,249,33,9,
	64,10,5,80,1,134,1,126,2,0,0,134,3,126,
	2,1,0,95,2,108,4,100,109,1,0,12,1,34,
	28,45,134,4,108,5,100,106,3,65,61,0,108,6,
	100,108,7,100,95,1,98,1,0,95,2,1,92,2,
	65,65,92,4,12,2,12,1,72,20,1,134,5,173,
	2,25,202,134,7,7
   };

   hb_vmExecute( pcode, symbols );
}

