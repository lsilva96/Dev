/*
 * xHarbour build 1.2.1 Intl. (SimpLex) (Rev. 9438)
 * Generated C source code from <pt1.prg>
 * Command: -opt1.c -m -n -p -q -gc0 -IC:\Omie\xHB\include -IC:\Omie\xHB\include\w32 pt1.prg 
 * Created: 2022.08.05 17:01:38 (XCC ISO C Compiler 2.70)
 */

#include "hbvmpub.h"
#include "hbinit.h"

#define __PRG_SOURCE__ "pt1.prg"

HB_FUNC( MAIN );
HB_FUNC( CODEBLOCK );
HB_FUNC( ARRAYS );
HB_FUNC( CACANOME );

HB_FUNC_EXTERN( QOUT );
HB_FUNC_EXTERN( __MVPUBLIC );
HB_FUNC_EXTERN( STR );
HB_FUNC_EXTERN( LEN );
HB_FUNC_EXTERN( ASCAN );

#undef HB_PRG_PCODE_VER
#define HB_PRG_PCODE_VER 10

#include "hbapi.h"

HB_INIT_SYMBOLS_BEGIN( hb_vm_SymbolInit_PT1 )
{ "MAIN", {HB_FS_PUBLIC | HB_FS_LOCAL | HB_FS_FIRST}, {HB_FUNCNAME( MAIN )}, &ModuleFakeDyn },
{ "CODEBLOCK", {HB_FS_PUBLIC | HB_FS_LOCAL}, {HB_FUNCNAME( CODEBLOCK )}, &ModuleFakeDyn },
{ "ARRAYS", {HB_FS_PUBLIC | HB_FS_LOCAL}, {HB_FUNCNAME( ARRAYS )}, &ModuleFakeDyn },
{ "QOUT", {HB_FS_PUBLIC}, {HB_FUNCNAME( QOUT )}, NULL },
{ "EVAL", {HB_FS_PUBLIC}, {NULL}, NULL },
{ "AUSERS", {HB_FS_PUBLIC}, {NULL}, NULL },
{ "__MVPUBLIC", {HB_FS_PUBLIC}, {HB_FUNCNAME( __MVPUBLIC )}, NULL },
{ "STR", {HB_FS_PUBLIC}, {HB_FUNCNAME( STR )}, NULL },
{ "LEN", {HB_FS_PUBLIC}, {HB_FUNCNAME( LEN )}, NULL },
{ "CACANOME", {HB_FS_PUBLIC | HB_FS_LOCAL}, {HB_FUNCNAME( CACANOME )}, &ModuleFakeDyn },
{ "ASCAN", {HB_FS_PUBLIC}, {HB_FUNCNAME( ASCAN )}, NULL }
HB_INIT_SYMBOLS_END( hb_vm_SymbolInit_PT1 )

#if defined( HB_PRAGMA_STARTUP )
   #pragma startup hb_vm_SymbolInit_PT1
#elif defined( HB_DATASEG_STARTUP )
   #define HB_DATASEG_BODY    HB_DATASEG_FUNC( hb_vm_SymbolInit_PT1 )
   #include "hbiniseg.h"
#endif

HB_FUNC( MAIN )
{
   static const BYTE pcode[] =
   {
	133,11,0,108,1,100,20,0,134,1,108,2,100,20,
	0,134,3,100,110,7
   };

   hb_vmExecute( pcode, symbols );
}

HB_FUNC( CODEBLOCK )
{
   static const BYTE pcode[] =
   {
	13,1,0,133,21,0,100,80,1,134,2,89,13,0,
	2,0,0,0,95,1,95,2,72,6,80,1,134,4,
	108,3,100,106,23,82,101,115,117,108,116,97,100,111,
	32,100,111,32,67,111,100,101,66,108,111,99,107,0,
	20,1,134,5,108,3,100,48,4,0,95,1,122,92,
	2,112,2,20,1,134,7,100,110,7
   };

   hb_vmExecute( pcode, symbols );
}

HB_FUNC( ARRAYS )
{
   static const BYTE pcode[] =
   {
	13,3,0,133,35,0,126,1,0,0,134,1,126,2,
	10,0,134,2,92,12,92,25,92,26,92,30,92,31,
	4,5,0,80,3,134,6,106,5,74,111,104,110,0,
	92,12,4,2,0,106,5,77,97,114,99,0,92,25,
	4,2,0,106,5,66,105,108,108,0,92,30,4,2,
	0,4,3,0,108,6,100,108,5,20,1,83,5,0,
	134,8,108,3,100,106,34,81,116,100,101,32,100,101,
	32,114,101,103,105,115,116,114,111,115,32,110,111,32,
	65,114,114,97,121,46,46,46,46,46,46,32,0,108,
	7,100,108,8,100,95,3,12,1,12,1,72,20,1,
	134,10,126,1,1,0,95,1,108,8,100,109,5,0,
	12,1,34,28,69,134,11,108,3,100,95,3,95,1,
	1,20,1,134,12,108,3,100,106,29,78,111,109,101,
	32,101,110,99,111,110,116,114,97,116,111,32,112,101,
	108,111,32,65,83,99,97,110,58,32,0,108,9,100,
	95,3,95,1,1,12,1,72,20,1,134,13,173,1,
	25,178,134,15,100,110,7
   };

   hb_vmExecute( pcode, symbols );
}

HB_FUNC( CACANOME )
{
   static const BYTE pcode[] =
   {
	13,2,1,133,57,0,127,2,1,0,0,134,1,126,
	3,0,0,134,3,108,10,100,109,5,0,89,18,0,
	1,0,1,0,1,0,95,1,92,2,1,95,255,8,
	6,12,2,80,3,134,5,95,3,121,15,28,14,134,
	6,98,5,0,95,3,1,122,1,80,2,134,9,95,
	2,110,7
   };

   hb_vmExecute( pcode, symbols );
}

