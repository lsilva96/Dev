/*
 * xHarbour build 1.2.1 Intl. (SimpLex) (Rev. 9438)
 * Generated C source code from <consultaMarca.prg>
 * Command: -oconsultaMarca.c -m -n -p -q -gc0 -IC:\Omie\xHB\include -IC:\Omie\xHB\include\w32 consultaMarca.prg 
 * Created: 2022.08.08 14:31:33 (XCC ISO C Compiler 2.70)
 */

#include "hbvmpub.h"
#include "hbinit.h"

#define __PRG_SOURCE__ "consultaMarca.prg"

HB_FUNC( MAIN );
HB_FUNC( MARCAS );
HB_FUNC( MODELOS );
HB_FUNC( ANOS );
HB_FUNC( VEICULOS );

HB_FUNC_EXTERN( __MVPUBLIC );
HB_FUNC_EXTERN( TIPCLIENTHTTP );
HB_FUNC_EXTERN( HB_JSONDECODE );
HB_FUNC_EXTERN( QOUT );
HB_FUNC_EXTERN( LEN );
HB_FUNC_EXTERN( __ACCEPT );
HB_FUNC_EXTERN( EMPTY );
HB_FUNC_EXTERN( STR );
HB_FUNC_EXTERN( ALLTRIM );

#undef HB_PRG_PCODE_VER
#define HB_PRG_PCODE_VER 10

#include "hbapi.h"

HB_INIT_SYMBOLS_BEGIN( hb_vm_SymbolInit_CONSULTAMARCA )
{ "MAIN", {HB_FS_PUBLIC | HB_FS_LOCAL | HB_FS_FIRST}, {HB_FUNCNAME( MAIN )}, &ModuleFakeDyn },
{ "CMARCA", {HB_FS_PUBLIC}, {NULL}, NULL },
{ "__MVPUBLIC", {HB_FS_PUBLIC}, {HB_FUNCNAME( __MVPUBLIC )}, NULL },
{ "CVEICULO", {HB_FS_PUBLIC}, {NULL}, NULL },
{ "CANO", {HB_FS_PUBLIC}, {NULL}, NULL },
{ "MARCAS", {HB_FS_PUBLIC | HB_FS_LOCAL}, {HB_FUNCNAME( MARCAS )}, &ModuleFakeDyn },
{ "MODELOS", {HB_FS_PUBLIC | HB_FS_LOCAL}, {HB_FUNCNAME( MODELOS )}, &ModuleFakeDyn },
{ "ANOS", {HB_FS_PUBLIC | HB_FS_LOCAL}, {HB_FUNCNAME( ANOS )}, &ModuleFakeDyn },
{ "VEICULOS", {HB_FS_PUBLIC | HB_FS_LOCAL}, {HB_FUNCNAME( VEICULOS )}, &ModuleFakeDyn },
{ "NEW", {HB_FS_PUBLIC}, {NULL}, NULL },
{ "TIPCLIENTHTTP", {HB_FS_PUBLIC}, {HB_FUNCNAME( TIPCLIENTHTTP )}, NULL },
{ "OPEN", {HB_FS_PUBLIC}, {NULL}, NULL },
{ "READALL", {HB_FS_PUBLIC}, {NULL}, NULL },
{ "HB_JSONDECODE", {HB_FS_PUBLIC}, {HB_FUNCNAME( HB_JSONDECODE )}, NULL },
{ "QOUT", {HB_FS_PUBLIC}, {HB_FUNCNAME( QOUT )}, NULL },
{ "N1", {HB_FS_PUBLIC}, {NULL}, NULL },
{ "LEN", {HB_FS_PUBLIC}, {HB_FUNCNAME( LEN )}, NULL },
{ "__ACCEPT", {HB_FS_PUBLIC}, {HB_FUNCNAME( __ACCEPT )}, NULL },
{ "CLOSE", {HB_FS_PUBLIC}, {NULL}, NULL },
{ "LASTERRORMESSAGE", {HB_FS_PUBLIC}, {NULL}, NULL },
{ "EMPTY", {HB_FS_PUBLIC}, {HB_FUNCNAME( EMPTY )}, NULL },
{ "STR", {HB_FS_PUBLIC}, {HB_FUNCNAME( STR )}, NULL },
{ "ALLTRIM", {HB_FS_PUBLIC}, {HB_FUNCNAME( ALLTRIM )}, NULL }
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
	133,9,0,108,2,100,108,1,20,1,134,1,108,2,
	100,108,3,20,1,134,2,108,2,100,108,4,20,1,
	134,5,108,5,100,20,0,134,6,108,6,100,20,0,
	134,7,108,7,100,20,0,134,8,108,8,100,20,0,
	134,10,7
   };

   hb_vmExecute( pcode, symbols );
}

HB_FUNC( MARCAS )
{
   static const BYTE pcode[] =
   {
	13,3,0,133,23,0,172,0,0,80,3,134,2,48,
	9,0,108,10,100,12,0,106,51,104,116,116,112,58,
	47,47,112,97,114,97,108,108,101,108,117,109,46,99,
	111,109,46,98,114,47,102,105,112,101,47,97,112,105,
	47,118,49,47,99,97,114,114,111,115,47,109,97,114,
	99,97,115,0,112,1,80,1,134,4,48,11,0,95,
	1,112,0,29,236,0,134,5,48,12,0,95,1,112,
	0,80,2,134,7,108,13,100,95,2,96,3,0,20,
	2,134,9,108,14,100,106,2,32,0,20,1,134,10,
	108,14,100,106,29,45,45,45,45,124,67,79,68,73,
	71,79,124,45,45,45,45,45,124,78,79,77,69,124,
	45,45,45,45,45,0,20,1,134,11,108,14,100,106,
	2,32,0,20,1,134,12,122,83,15,0,109,15,0,
	108,16,100,95,3,12,1,34,28,58,134,13,108,14,
	100,95,3,109,15,0,1,106,7,99,111,100,105,103,
	111,0,1,106,4,32,45,32,0,72,95,3,109,15,
	0,1,106,5,110,111,109,101,0,1,72,20,1,134,
	14,109,15,0,23,83,15,0,25,189,134,16,108,17,
	100,106,51,32,73,110,102,111,114,109,101,32,111,32,
	67,111,100,105,103,111,32,100,97,32,77,97,114,99,
	97,32,113,117,101,32,100,101,115,101,106,97,32,99,
	111,110,115,117,108,116,97,114,32,58,32,0,12,1,
	83,1,0,134,18,48,18,0,95,1,112,0,73,25,
	35,134,20,108,14,100,106,17,101,114,114,111,32,100,
	101,32,99,111,110,101,120,97,111,58,0,48,19,0,
	95,1,112,0,20,2,134,23,7
   };

   hb_vmExecute( pcode, symbols );
}

HB_FUNC( MODELOS )
{
   static const BYTE pcode[] =
   {
	13,4,0,133,50,0,172,0,0,80,3,134,1,126,
	4,0,0,134,3,48,9,0,108,10,100,12,0,106,
	52,104,116,116,112,58,47,47,112,97,114,97,108,108,
	101,108,117,109,46,99,111,109,46,98,114,47,102,105,
	112,101,47,97,112,105,47,118,49,47,99,97,114,114,
	111,115,47,109,97,114,99,97,115,47,0,109,1,0,
	72,106,9,47,109,111,100,101,108,111,115,0,72,112,
	1,80,1,134,5,48,11,0,95,1,112,0,29,57,
	1,134,6,48,12,0,95,1,112,0,80,2,134,8,
	108,20,100,95,2,12,1,32,246,0,134,10,108,13,
	100,95,2,96,3,0,20,2,134,12,108,14,100,106,
	2,32,0,20,1,134,13,108,14,100,106,29,45,45,
	45,45,124,67,79,68,73,71,79,124,45,45,45,45,
	45,124,78,79,77,69,124,45,45,45,45,45,0,20,
	1,134,14,108,14,100,106,2,32,0,20,1,134,15,
	126,4,1,0,95,4,108,16,100,95,3,12,1,34,
	28,78,134,16,108,14,100,108,21,100,95,3,106,8,
	109,111,100,101,108,111,115,0,1,95,4,1,106,7,
	99,111,100,105,103,111,0,1,12,1,106,4,32,45,
	32,0,72,95,3,106,8,109,111,100,101,108,111,115,
	0,1,95,4,1,106,5,110,111,109,101,0,1,72,
	20,1,134,17,173,4,25,170,134,19,108,17,100,106,
	53,32,73,110,102,111,114,109,101,32,111,32,67,111,
	100,105,103,111,32,100,111,32,86,101,105,99,117,108,
	111,32,113,117,101,32,100,101,115,101,106,97,32,99,
	111,110,115,117,108,116,97,114,32,58,32,0,12,1,
	83,3,0,134,21,48,18,0,95,1,112,0,73,25,
	79,134,23,108,14,100,106,33,32,80,97,114,97,109,
	101,116,114,111,115,32,101,110,118,105,97,100,111,115,
	32,105,110,99,111,114,114,101,116,111,115,32,0,20,
	1,25,35,134,26,108,14,100,106,17,101,114,114,111,
	32,100,101,32,99,111,110,101,120,97,111,58,0,48,
	19,0,95,1,112,0,20,2,134,29,7
   };

   hb_vmExecute( pcode, symbols );
}

HB_FUNC( ANOS )
{
   static const BYTE pcode[] =
   {
	13,4,0,133,84,0,172,0,0,80,3,134,1,126,
	4,0,0,134,3,48,9,0,108,10,100,12,0,106,
	52,104,116,116,112,58,47,47,112,97,114,97,108,108,
	101,108,117,109,46,99,111,109,46,98,114,47,102,105,
	112,101,47,97,112,105,47,118,49,47,99,97,114,114,
	111,115,47,109,97,114,99,97,115,47,0,109,1,0,
	72,106,10,47,109,111,100,101,108,111,115,47,0,72,
	109,3,0,72,106,6,47,97,110,111,115,0,72,112,
	1,80,1,134,5,48,11,0,95,1,112,0,29,47,
	1,134,6,48,12,0,95,1,112,0,80,2,134,8,
	108,20,100,95,2,12,1,32,236,0,134,9,108,13,
	100,95,2,96,3,0,20,2,134,11,108,14,100,106,
	2,32,0,20,1,134,12,108,14,100,106,29,45,45,
	45,45,124,67,79,68,73,71,79,124,45,45,45,45,
	45,124,78,79,77,69,124,45,45,45,45,45,0,20,
	1,134,13,108,14,100,106,2,32,0,20,1,134,14,
	126,4,1,0,95,4,108,16,100,95,3,12,1,34,
	28,61,134,15,108,14,100,108,22,100,95,3,95,4,
	1,106,7,99,111,100,105,103,111,0,1,12,1,106,
	4,32,45,32,0,72,108,22,100,95,3,95,4,1,
	106,5,110,111,109,101,0,1,12,1,72,20,1,134,
	16,173,4,25,187,134,18,108,17,100,106,60,32,73,
	110,102,111,114,109,101,32,111,32,67,111,100,105,103,
	111,32,100,111,32,65,110,111,32,100,111,32,86,101,
	105,99,117,108,111,32,113,117,101,32,100,101,115,101,
	106,97,32,99,111,110,115,117,108,116,97,114,32,58,
	32,0,12,1,83,4,0,134,20,48,18,0,95,1,
	112,0,73,25,79,134,23,108,14,100,106,33,32,80,
	97,114,97,109,101,116,114,111,115,32,101,110,118,105,
	97,100,111,115,32,105,110,99,111,114,114,101,116,111,
	115,32,0,20,1,25,35,134,26,108,14,100,106,17,
	101,114,114,111,32,100,101,32,99,111,110,101,120,97,
	111,58,0,48,19,0,95,1,112,0,20,2,134,29,
	7
   };

   hb_vmExecute( pcode, symbols );
}

HB_FUNC( VEICULOS )
{
   static const BYTE pcode[] =
   {
	13,3,0,133,117,0,172,0,0,80,3,134,2,48,
	9,0,108,10,100,12,0,106,52,104,116,116,112,58,
	47,47,112,97,114,97,108,108,101,108,117,109,46,99,
	111,109,46,98,114,47,102,105,112,101,47,97,112,105,
	47,118,49,47,99,97,114,114,111,115,47,109,97,114,
	99,97,115,47,0,109,1,0,72,106,10,47,109,111,
	100,101,108,111,115,47,0,72,109,3,0,72,106,7,
	47,97,110,111,115,47,0,72,109,4,0,72,106,1,
	0,72,112,1,80,1,134,4,48,11,0,95,1,112,
	0,29,6,2,134,5,48,12,0,95,1,112,0,80,
	2,134,7,108,14,100,95,2,20,1,134,9,108,20,
	100,95,2,12,1,32,186,1,134,11,108,13,100,95,
	2,96,3,0,20,2,134,13,108,14,100,106,2,32,
	0,20,1,134,14,108,14,100,106,26,45,45,45,45,
	68,65,68,79,83,32,68,79,32,86,69,73,67,85,
	76,79,45,45,45,45,45,0,20,1,134,15,108,14,
	100,106,2,32,0,20,1,134,16,108,14,100,106,8,
	86,97,108,111,114,58,32,0,95,3,106,6,86,97,
	108,111,114,0,1,72,20,1,134,17,108,14,100,106,
	8,77,97,114,99,97,58,32,0,95,3,106,6,77,
	97,114,99,97,0,1,72,20,1,134,18,108,14,100,
	106,9,77,111,100,101,108,111,58,32,0,95,3,106,
	7,77,111,100,101,108,111,0,1,72,20,1,134,19,
	108,14,100,106,12,65,110,111,77,111,100,101,108,111,
	58,32,0,108,22,100,108,21,100,95,3,106,10,65,
	110,111,77,111,100,101,108,111,0,1,12,1,12,1,
	72,20,1,134,20,108,14,100,106,14,67,111,109,98,
	117,115,116,105,118,101,108,58,32,0,95,3,106,12,
	67,111,109,98,117,115,116,105,118,101,108,0,1,72,
	20,1,134,21,108,14,100,106,11,67,111,100,32,70,
	105,112,101,58,32,0,95,3,106,11,67,111,100,105,
	103,111,70,105,112,101,0,1,72,20,1,134,22,108,
	14,100,106,11,77,101,115,32,82,101,102,46,58,32,
	0,95,3,106,14,77,101,115,82,101,102,101,114,101,
	110,99,105,97,0,1,72,20,1,134,23,108,14,100,
	106,15,84,105,112,111,32,86,101,105,99,117,108,111,
	58,32,0,108,22,100,108,21,100,95,3,106,12,84,
	105,112,111,86,101,105,99,117,108,111,0,1,12,1,
	12,1,72,20,1,134,24,108,14,100,106,20,83,105,
	103,108,97,32,67,111,109,98,117,115,116,105,118,101,
	108,58,32,0,95,3,106,17,83,105,103,108,97,67,
	111,109,98,117,115,116,105,118,101,108,0,1,72,20,
	1,134,26,48,18,0,95,1,112,0,73,25,79,134,
	28,108,14,100,106,33,32,80,97,114,97,109,101,116,
	114,111,115,32,101,110,118,105,97,100,111,115,32,105,
	110,99,111,114,114,101,116,111,115,32,0,20,1,25,
	35,134,31,108,14,100,106,17,101,114,114,111,32,100,
	101,32,99,111,110,101,120,97,111,58,0,48,19,0,
	95,1,112,0,20,2,134,34,7
   };

   hb_vmExecute( pcode, symbols );
}
