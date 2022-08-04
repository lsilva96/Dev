***************************************************************************************************************
**                                                                                                           **
**  Referencia    : OMIE.PRG                                                                                 **
**                                                                                                           **
**  Objeto        : omie                                                                                     **
**                                                                                                           **
**  Objetivo      : FunÁıes para controle do OmiePDV / IntegraÁao com Omie.                                  **
**                                                                                                           **
**  ObservaÁao    : Utiliza FiveWin / Consumo de APIs do Omie.                                               **
**                                                                                                           **
***************************************************************************************************************
**                                                                                                           **
**  CriaÁao       : 01/01/2014 - ALEXANDRE LEE                                                               **
**  AtualizaÁao   : 23/02/2015 - LUCIANO IURI PEREIRA                                                        **
**                                                                                                           **
***************************************************************************************************************
**
** OMIEPDV - V. 2.0 - Omiexperience                                                         15 de Mar de 2015 
** OMIEPDV - V. 2.1 - Omiexperience                                                         18 de Mai de 2015 
** OMIEPDV - V. 2.5 - Omiexperience                                                         10 de Ago de 2015 
** OBS: Manifestando Contra a corrupÁao do Governo Dilma.
**
** OMIEPDV - V. 3.1 - Omiexperience                                                         08 de Fev de 2016 
** OBS: Dilma ainda caiu! Governo em decadencia. 
***************************************************************************************************************

#include "FiveWin.ch"
#include "SysFar.ch"
#include "wininet.ch"
//#include "\xHB\Include\w32\wininet.ch"  // Sysfar

#DEFINE PDV_VERSION  "3.23"

STATIC ID       := ""
STATIC Key      := ""
STATIC Secret   := ""
STATIC Banco    := ""
STATIC Caixinha := ""
STATIC Erro     := .f.
STATIC nPagina
STATIC nTotpag
STATIC lErro 
STATIC lInicial
STATIC oXmlDoc
STATIC oXmlNode
STATIC oXmlIter
STATIC cObs
STATIC aVendedor := {}
STATIC cObsAV    := ""
STATIC cObsAV2   := ""

STATIC xPdv_logWS  := ""  
STATIC xPdv_logXML := "" 
STATIC xPdv_logCX  := ""
STATIC xPdv_Serial := ""
STATIC hOmieData   := {=>}

****************************************************************************************************************
function pu_GetVersion()
****************************************************************************************************************
return PDV_VERSION

// D· primeira vez que o OmiePDV È executado, faz a carga inicial dos dados.

****************************************************************************************************************
function CargaInicial( lInicial )
****************************************************************************************************************
local nRecno  := INDICE->(recno())
local cParam1 := ""

if !emuso("indice")
   USE INDICE NEW
endif

ID       := Alltrim(INDICE->OmieID)
Key      := Alltrim(INDICE->OmieKEY)
Secret   := Alltrim(INDICE->OmieSecret)
Banco    := Alltrim(INDICE->OmieBanco)
Caixinha := Alltrim(INDICE->OmieCx)

if lInicial

   cParam1 := pu_GetData( "IDMAQ", "NFCE" ) 
   
   if empty(cParam1) 
      pu_SetData( "IDMAQ", alltrim(str(nSerialHD())), "NFCE" )
   else
      if !(alltrim(str(nSerialHD())) $ cParam1)
         pu_SetData( "IDMAQ", alltrim(cParam1)+";"+alltrim(str(nSerialHD())), "NFCE" )
      endif
   endif

endif

///////////////////////////////////////////////////////////////////////////////////////////////////

// API de Produtos

pu_GetProdutos( lInicial, INDICE->COMUNICADO )

///////////////////////////////////////////////////////////////////////////////////////////////////

// API de Clientes

pu_GetClientes( lInicial, INDICE->COMUNICADO )

///////////////////////////////////////////////////////////////////////////////////////////////////
// Desmarca a sincronizaÁao o para obter todos os produtos e clientes novamente.

if pu_GetOmie( "SyncAll", "ADVANCED") == "true"
   pu_SetOmie( "SyncAll", "false", "ADVANCED")
endif

///////////////////////////////////////////////////////////////////////////////////////////////////

// API de Usu·rios

pu_GetUsuarios( lInicial )

///////////////////////////////////////////////////////////////////////////////////////////////////

// API de Conta Corrente (Cartoes de Credito)

pu_GetContas( lInicial )

///////////////////////////////////////////////////////////////////////////////////////////////////

// Ajuste no Suprimento.

pu_GetSuprimentos( lInicial )

///////////////////////////////////////////////////////////////////////////////////////////////////

if INDICE->(recno()) <> nRecno
   INDICE->(dbGoTo(nRecno))
endif

// Ajuste no Par‚metros do sistema.

INDICE->COMUNICADO := date()

INDICE->(dbcommit())
INDICE->(DbUnlock())

if !EmUso("cadastro")
   USE CADASTRO NEW
endif

return NIL

*****************************************************************************************
function pu_verifica_omie( cEmail, cSenha )
*****************************************************************************************
local aRet := {}
local nPos := 0

// API de Accounting

aRet := pu_GetServiceList( cEmail, cSenha )

if len(aRet)==0
   return .F.
endif

SysSeleciona( "Selecione seu aplicativo Omie", , , , , aRet )

setfilter( "AUXSEL", "flag" )

AUXSEL->(dbgotop())

if AUXSEL->(eof())
   return .F.
endif

nPos := ascan( aRet, { |x__| x__[1] $ AUXSEL->desc2 } )

if nPos = 0
   return .F.
endif

INDICE->OMIEID     := alltrim( aRet[nPos][1] )
INDICE->OMIEKEY    := alltrim( aRet[nPos][3] )
INDICE->OMIESECRET := alltrim( aRet[nPos][4] )
INDICE->ENDENTREGA := .F.  // Para nao imprimir EndereÁo de Entrega na NFCE.

//traz todos clientes e produtos primeira carga
INDICE->COMUNICADO := ctod("01/01/2001")

USE DADOS NEW

DADOS->EMAIL    := cEmail
DADOS->CNPJSOFT := "18511742000147"
DADOS->TOKEN    := "000001"

DADOS->(dbcommit())
DADOS->(DbUnlock())

////////////////////////////////////////////////////////////////////////////////////////////////

// API de Provisionamento 

if ! pu_StartSession( INDICE->OMIEKEY, INDICE->OMIESECRET, "PDV" )
   
   INDICE->OMIEID     := ""
   INDICE->OMIEKEY    := ""
   INDICE->OMIESECRET := ""
   
   FinalizaAplicacao() 

   __QUIT()
   
endif

pu_SetOmie( "ID_SERVICE", alltrim(INDICE->OMIEID), "CONFIG" )
pu_SetOmie( "APP_KEY"   , alltrim(INDICE->OMIEKEY), "CONFIG" )
pu_SetOmie( "APP_SECRET", alltrim(INDICE->OMIESECRET), "CONFIG" )

////////////////////////////////////////////////////////////////////////////////////////////////

pu_GetEmpresas( INDICE->omiekey, INDICE->omiesecret, .F. )

INDICE->(dbclosearea())

////////////////////////////////////////////////////////////////////////////////////////////////

MsgRun( "Sincronizando o OmiePDV com o seu aplicativo Omie ... ", ;
        "Por favor, aguarde ... ",     ;
         { || ( pu_EnviarCaixa( , .T., , ), sysdbcloseall(), ReiniciaSysfar() ) } )

return .t.

****************************************************************************************************
static function pu_EnviarCaixa( ECFNumSerie, lInicial, cPDV, cLote, lOpenIndice, lMsg )
****************************************************************************************************
local cData := ""
local nHandle := 0

DEFAULT lInicial    := .f.
DEFAULT ECFNumSerie := ""
DEFAULT cPdv        := ""
DEFAULT cLote       := ""
DEFAULT lOpenIndice := .T.
DEFAULT lMsg        := .T.

lMkDir(DIR_TEMP+"\Erro")

CurSorWait()

// Verifica se a internet est· disponÌvel.

if !SysVerifyActiveUrl("www.google.com")
   MsgStop("Sem acesso Internet, tente novamente ...",SYSTEM_NAME)
   return NIL
endif

// Verifica Pendencias de Cupons Desaparecidos.

pu_VerifyRec()

// Verifica se a base est· configurada para comunicaÁao.

if lOpenIndice

   USE INDICE NEW

   If INDICE->(FIELDPOS("OMIEID")) = 0
      MsgStop("Campos necess·rios IntegraÁao nao Encontrados, Organizar Arquivos SysFar...",SYSTEM_NAME)
      Close Indice
      Return NIL
   Endif

endif

ID       := alltrim(INDICE->OmieID)
Key      := alltrim(INDICE->OmieKEY)
Secret   := alltrim(INDICE->OmieSecret)
Banco    := alltrim(INDICE->OmieBanco)
Caixinha := alltrim(INDICE->OmieCx)

// Aciona a API de ECF para verificar se a mesma est· ativa.

if !lInicial
   if !pu_GetStatusECF( ECFNumSerie )
      return .F.
   endif
endif

// API NotaFiscalUtil->GetUrlLogo - Para obter o logo da empresa.

pu_GetLogoEmpresa( .T. )

// Envia para o Omie os clientes que foram incluÌdos modificados pelo OmiePDV.

pu_EnviarClientes( lInicial )
   
// Aciona as rotinas para dar a Carga Inicial no OmiePDV.

CargaInicial( lInicial )

////////////////////////////////////////////////////////////////////////////////////////////////

// API de envio do Cupom Fiscal.
if !lInicial
   pu_FecharCaixa( , , cPDV )
endif

////////////////////////////////////////////////////////////////////////////////////////////////
// Atualiza os dados da empresa, caso necess·rio.

if !lInicial
   pu_GetEmpresas( Key, Secret, .T. )
endif

////////////////////////////////////////////////////////////////////////////////////////////////

pu_SetOmie( "DTCORR", dtoc(date()), "CONFIG" )

////////////////////////////////////////////////////////////////////////////////////////////////
// Verifica se precisa gerar o arquivo TDM.

if !lInicial .and. !lMsg
   pu_GerarArqTDM()
endif

////////////////////////////////////////////////////////////////////////////////////////////////

if lMsg
   msginfo( "SincronizaÁ„o com o aplicativo Omie concluÌda!", SYSTEM_NAME )
endif

return .t.

****************************************************************************************************
function pu_TrocarUsuario( lSat, lNfce )
****************************************************************************************************
local xRet 

MsgRun( "Trocando usu·rio do OmiePDV...", ;
     "FaÁa um novo login... ",     ;
      { || (xRet := pu_login_omie( lSat, lNfce, .t. )) } )

return xRet

// return pu_login_omie( lSat, lNfce, .t. )

****************************************************************************************************
function pu_login_omie( lSat, lNfce, lOtherUser )
****************************************************************************************************
local oImgSplash, oDlg, oIcon, cEmail, _cEmail, cSenha, _cSenha, lOk := .f.
local oBtnOK, oImgOK, oImgnovo, oImgRecupera, oImgMenuFiscal, lInicial
local dDtCorr := date()
local lIndexar := .T.
local cParam1
local oImgLX
local oImgRZ

DEFAULT lSat  := .F. 
DEFAULT lNfce := .F.
DEFAULT lOtherUser := .F.

if !lOtherUser

   ///////////////////////////////////////////////////////////////
   
   cParam1 := "N"

   if !emuso("indice")
      USE "indice.dbf" NEW
      cParam1 := "S"
   endif

   if empty(INDICE->omieid) .or. empty(INDICE->omiekey) .or. empty(INDICE->omiesecret)
     pu_SetOmie( "LINKED", "no", "CONFIG" )
   endif

   if cParam1 == "S"
      INDICE->(dbCloseArea())
   endif

   ///////////////////////////////////////////////////////////////

   pu_SetOmie( "IsSAT" , if(lSat,"TRUE", "FALSE") )
   pu_SetOmie( "IsNFCE", if(lNfce,"TRUE", "FALSE") )
   pu_SetOmie( "IsECF" , if(!lSat .and. !lNfce,"TRUE", "FALSE") )

   ///////////////////////////////////////////////////////////////

   // Seta o Serial do HD para identificar a m·quina.

   pu_GetSerialNumber() 

   ///////////////////////////////////////////////////////////////

   // Reindexando automaticamente.

   cParam1 := pu_GetOmie( "LINKED", "CONFIG" )

   if cParam1 == 'yes'

      dDtCorr := pu_GetOmie("DTCORR","CONFIG")

      if empty(dDtCorr) 
         dDtCorr := date()-1
      else
         
         dDtCorr := ctod(dDtCorr)

         if dDtCorr == ctod('01/01/2015')
            lIndexar := .F.
         endif

         if empty(dDtCorr) 
            dDtCorr := date()-1
         endif

      endif
         
      if date() > dDtCorr 

         // Verifica se far· o backup do dia.

         cParam1 := pu_GetOmie("BackupOnLogin","ADVANCED")

         if empty(cParam1)
            cParam1 := "true"
            pu_SetOmie("BackupOnLogin", cParam1, "ADVANCED")
         endif

         if cParam1 == "true"

            MsgRun( "Realizando Backup dos dados do OmiePDV...", ;
                 "Por favor, aguarde ... ",     ;
                  { || ( pu_BackupPDV() ) } )
            
         endif

         // Verifica se Sincroniza o PDV no login.

         cParam1 := pu_GetOmie("SyncOnLogin","ADVANCED")

         if empty(cParam1)
            cParam1 := "true"
            pu_SetOmie("SyncOnLogin", cParam1, "ADVANCED")
         endif

         if cParam1 == "true"

            MsgRun( "Sincronizando com o seu aplicativo Omie no primeiro acesso ao OmiePDV...", ;
                 "Por favor, aguarde ... ",     ;
                  { || ( pu_EnviarCaixa( , .F., , , , .F. ), sysdbcloseall() ) } )

         else
            // Verifica se algum registro de NFC-e / SAT sem cupom foi gerado.
            pu_VerifyRec()
         endif

         pu_SetOmie( "HDSERIAL", pu_GetSerialNumber(), "CONFIG" )
         pu_SetOmie( "DTCORR", dtoc(date()), "CONFIG" )

         if lIndexar
            Bin2("indexar.bin",1,.f.,.f.,.t.,.f.)
         endif

      endif
   
   endif

   ///////////////////////////////////////////////////////////////

   // Ajusta a opÁao OcultaProd.

   cParam1 := pu_GetData( "STATUS", "OCULTAPROD" ) 

   if empty(cParam1) .or. alltrim(cParam1)="1"
      pu_SetData( "STATUS", "0", "OCULTAPROD" )
   endif

   // Ajusta a Vers o se necess>rio.

   cParam1 := pu_GetOmie( "VER", "CONFIG" )

   if empty(cParam1) .or. alltrim(cParam1)<>pu_GetVersion()
      pu_SetData( "VER" , pu_GetVersion() )
      pu_SetOmie( "VER", pu_GetVersion(), "CONFIG" )
   endif

   // Ajusta o Serial da NFC-e

   // [NFCE]
   // STATUS=1
   // IDMAQ=-1302045038;-757675144

   // SYSFAR.EXE HDVERIFICA 

   ///////////////////////////////////////////////////////////////

   cParam1 := pu_GetData( "IDMAQ", "NFCE" ) 

   if empty(cParam1) 
      pu_SetData( "IDMAQ", alltrim(str(nSerialHD())), "NFCE" )
   else
      if !(alltrim(str(nSerialHD())) $ cParam1)
         pu_SetData( "IDMAQ", alltrim(cParam1)+";"+alltrim(str(nSerialHD())), "NFCE" )
      endif
   endif

   ///////////////////////////////////////////////////////////////
   cParam1 := pu_GetData( "QRCODE", "NFCE" ) 

   if empty(cParam1) 
      pu_SetData( "QRCODE", 'S', "NFCE" )
   else
      if !(cParam1 $ "SN" )
         pu_SetData( "QRCODE", 'S', "NFCE" )
      endif
   endif

endif 

///////////////////////////////////////////////////////////////

if !emuso("indice")
   use "indice.dbf" new
endif

if empty(INDICE->omieid) .or. empty(INDICE->omiekey) .or. empty(INDICE->omiesecret)
   
   lInicial := .t.
   cEmail   := space(50)
   cSenha   := space(15)

   pu_SetOmie( "LOGWS" , "N", "CONFIG" )
   pu_SetOmie( "LOGXML", "N", "CONFIG" )
   pu_SetOmie( "LOGCX" , "S", "CONFIG" )

   aeval( directory(m->dirlocal+"\httpcln*.log"),   { |x| ferase(m->dirlocal+"\"+x[1]) } )
   aeval( directory(m->dirlocal+"\bin\omie_*.log"), { |x| ferase(m->dirlocal+"\bin\"+x[1]) } )
   aeval( directory(m->dirlocal+"\logs\*.log"),     { |x| ferase(m->dirlocal+"\logs\"+x[1]) } )

else

   ID       := alltrim(INDICE->omieid)
   Key      := alltrim(INDICE->omiekey)
   Secret   := alltrim(INDICE->omiesecret)

   pu_SetOmie( "ID_SERVICE", alltrim(INDICE->omieid), "CONFIG" )
   pu_SetOmie( "APP_KEY"   , alltrim(INDICE->omiekey), "CONFIG" )
   pu_SetOmie( "APP_SECRET", alltrim(INDICE->omiesecret), "CONFIG" )
   pu_SetOmie( "LINKED"    , "yes",  "CONFIG" )

   Use Cadastro New Alias snCadastro
   use acesso new
   
   snCadastro->(DbSetOrder(2))
   
   cEmail := pu_GetOmie( "EMAIL", "CONFIG" )

   if empty(cEmail)
      cEmail := space(50)
   else
      cEmail := padR(cEmail,50," ")
   endif

   cSenha := space( 15 )

   lInicial := .f.

endif

// pu_GetCupons()
// pu_GetStatusLote( 34423715431 )

///////////////////////////////////////////////////////////////////////////////////////////////////////

//DEFINE FONT oFont  NAME "VERDANA" SIZE 0,10

if lOtherUser
   DEFINE IMAGE oImgSplash FILE 'metro\00-otheruser.png'
else
   DEFINE IMAGE oImgSplash FILE 'metro\00-loginuser.png'
endif

//DEFINE IMAGE oImgSplash FILE 'metro\00-otheruser.png'

DEFINE ICON oIcon RESOURCE "OMIE32"

DEFINE DIALOG oDlg TITLE "Omie" STYLE nOr(WS_POPUP) FROM 0, 0 TO 495, 490 PIXEL ICON oIcon BRUSH TBrush():New("NULL")

//DEFINE FONT oFont  NAME "Courier New" SIZE 0,-12 BOLD
//DEFINE DIALOG oDlg FROM 0, 0 TO 11.2,28 TITLE "OMIExperience" FONT oFont COLOR CLR_BLACK,CLR_WHITE STYLE nOR(DS_MODALFRAME)

if !lOtherUser
   @ 0.50, 34.5 SAY "Rev " + pu_GetOmie( "VER", "CONFIG" ) OF oDlg COLOR CLR_WHITE,RGB(12,138,187) size 22,8 Font sysfont("VERDANA",10)
else
   @ 0.30, 34.5 SAY "Rev " + pu_GetOmie( "VER", "CONFIG" ) OF oDlg COLOR CLR_WHITE,RGB(12,138,187) size 22,8 Font sysfont("VERDANA",10)
endif

@   5.55, 30.0 SAY "Versao "+left(m->versao_exe,at("(",m->versao_exe)-2) OF oDlg COLOR CLR_WHITE,RGB(12,138,187)  size 46,8

@   9.44,  1.35 GET _cEmail VAR cEmail OF oDlg VALID !empty(cEmail) size 210,12
@  10.84,  1.35 GET _cSenha VAR cSenha OF oDlg VALID if(!empty(cSenha),(oBtnOK:click(),.t.) ,(_cEmail:setFocus(),.t.)) size 210,12 PASSWORD

if !lOtherUser

   @ 168.90, 63.8 IMAGE oImgok          FILENAME m->DirLocal+"\metro\login_bt_entrar.png"       OF oDlg PIXEL NOBORDER SIZE 167,17  // ADJUST

   @ 212.00, 6    IMAGE oImgnovo        FILENAME m->DirLocal+"\metro\login_bt_novocadastro.png" OF oDlg PIXEL NOBORDER SIZE 108,14  // ADJUST

   @ 188.4,107.6  IMAGE oImgRecupera    FILENAME m->DirLocal+"\metro\RecuperarSenha.png"        OF oDlg PIXEL NOBORDER  SIZE 55,10 // ADJUST

   if !lSat .and. !lNfce
      @ 213.00,160 IMAGE oImgMenuFiscal FILENAME m->DirLocal+"\metro\MenuFiscal.png"            OF oDlg PIXEL NOBORDER  SIZE 60,12  // ADJUST
   endif

   @ 229,  3  IMAGE oImgRZ              FILENAME m->DirLocal+"\metro\ReducaoZ.png"              OF oDlg PIXEL NOBORDER  SIZE 47,12.9 // ADJUST

   @ 229, 54  IMAGE oImgLX              FILENAME m->DirLocal+"\metro\LeituraX.png"              OF oDlg PIXEL NOBORDER  SIZE 40,12.9 // ADJUST

   oImgRecupera:bLClicked := { || ShellExecute( , "open", "http://app.omie.com.br/login/recover/", , , 1 ) }

   oImgnovo:bLClicked     := { || ShellExecute( , "open", "https://app.omie.com.br/register/", , , 1 ) }

   if !lSat .and. !lNfce
      oImgMenuFiscal:bLClicked := { || MenuFiscal() }
   endif

   oImgRZ:bLClicked := { || pu_ECFReport( "RZ", cEmail, cSenha ) }

   oImgLX:bLClicked := { || pu_ECFReport( "LX", cEmail, cSenha ) }

else

   @ 171.70, 63.8 IMAGE oImgok FILENAME m->DirLocal+"\metro\login_bt_entrar2.png" OF oDlg PIXEL NOBORDER SIZE 167,17  // ADJUST

endif

oImgok:bLClicked := { || msgrun("Verificando AutenticaÁ„o","Aguarde.",{||if(lInicial,;
                                                                           if(pu_verifica_omie(cEmail,cSenha),;
                                                                             (oDlg:end(),lOK:={.f.,"",""}),;
                                                                             .f.),;
                                                                           if(!empty(cSenha) .and. !empty(cEmail),;
                                                                             (lOK:=pu_Verifica_senha(cEmail,cSenha),;
                                                                             if(lOk[1],;
                                                                               (oDlg:end(),.t.),;
                                                                               (MsgInfo("Usu·rio ou Senha inv·lido.",SYSTEM_NAME),.f.))),;
                                                                             if(empty(cSenha),;
                                                                               (_cEmail:setFocus(),.t.),;
                                                                               (_cSenha:setFocus(),.f.)) ))})}


@ 500,500 BTNBMP oBtnOK OF oDlg ADJUST NOBORDER SIZE 43,15 ACTION msgrun("Verificando AutenticaÁ„o","Aguarde.",{||if(lInicial,;
                                                                           if(pu_verifica_omie(cEmail,cSenha),;
                                                                             (oDlg:end(),lOK:={.f.,"",""}),;
                                                                             .f.),;
                                                                           if(!empty(cSenha) .and. !empty(cEmail),;
                                                                             (lOK:=pu_Verifica_senha(cEmail,cSenha),;
                                                                             if(lOk[1],;
                                                                               (oDlg:end(),.t.),;
                                                                               (MsgInfo("Usu·rio ou Senha inv·lido.",SYSTEM_NAME),.f.))),;
                                                                             if(empty(cSenha),;
                                                                               (_cEmail:setFocus(),.t.),;
                                                                               (_cSenha:setFocus(),.f.))))})

//oBtnOK:hide()
//oBtnOK:lTransparent = .T.
//aadd(aBotoes,{@oBtnOK,"&Ok",{|| lRetorno := .t., oDlg:end() }})
//aadd(aBotoes,{@oBtnCancel,"&Cancela",{|| lRetorno := .f., oDlg:end() }})

ACTIVATE DIALOG oDlg CENTER ;
         ON PAINT (PALBMPDRAW(hDC, 0, 0, oImgSplash:hBitmap,0,0)) ;
         ON INIT(trazerparafrente("sysfar","Omie"),if(!empty(cEmail),_cSenha:setfocus(),_cEmail:setfocus()),oDlg:show() )

if getKeyState(27)
   lOK := {.f.,"",""}
endif

if !empty(cEmail)
   if alltrim(cEmail)<>pu_GetOmie( "EMAIL", "CONFIG" ) .or. empty(pu_GetOmie( "EMAIL", "CONFIG" ))
      pu_SetOmie( "EMAIL", alltrim(cEmail), "CONFIG" )
   endif
endif

return (lOk)

********************************************************************************
function pu_ECFReport( cAction, cEmail, cSenha )
********************************************************************************
DEFAULT cAction := ""
DEFAULT cEmail := ""
DEFAULT cSenha := ""

if empty(cAction)
   MsgInfo("AÁ„o n„o informada!")
   return .f.
endif

// if empty(cEmail) .or. empty(cSenha)
//    MsgInfo("E-Mail/Senha n„o informados!")
//    return .f.
// endif
// 
// if !pu_Verifica_senha(cEmail,cSenha)[1]
//    MsgInfo("E-Mail/Senha inv·lidos!")
//    return .f.
// endif

do case 
case cAction == "RZ"

   if MsgYesNo( "Confirma e emiss„o da ReduÁ„o Z ?")
      LeituraZ()
   endif

case cAction == "LX"

   if MsgYesNo( "Confirma a emiss„o da Leitura X ?")
      _LeituraX(1)
   endif

endcase

if select("snCadastro")=0
   Use Cadastro New Alias snCadastro
   snCadastro->(DbSetOrder(2))
endif

if select("acesso")=0
   use acesso new
endif

return .t.

// Verifica se o Cupom Fiscal nao foi gravado na tabela CUPOM.DBF, reconstroi o cupom fiscal a partir de ESTAT.DBF

********************************************************************************
function pu_CriaCupom( nCupom )
********************************************************************************

DEFAULT nCupom := 0

LogFile( "omie\consist.log", { date(), time(), "ERRO AO GRAVAR CUPOM", nCupom } )

if nCupom > 0
   pu_VerifyRec( "", nCupom )
endif

return NIL

********************************************************************************
static function pu_VerifyRec( cDir, nCupom )
********************************************************************************
local nCupNFCE := 0
local nCupSAT  := 0
local nNewNFCE := 0
local nNewSAT  := 0

DEFAULT cDir   := ""
DEFAULT nCupom := 0

USE (cDir+"CUPOM.DBF") ALIAS _CUPOM VIA "ADS" SHARED NEW
USE (cDir+"ESTAT.DBF") ALIAS _ESTAT VIA "ADS" SHARED NEW

DbUseArea( .T., "ADS", (cDir+"NFCCAB.DBF"), "_NFCCAB", .T. )

USE (cDir+"SATFISCAL.DBF") ALIAS _SATFISCAL VIA "ADS" SHARED NEW

_CUPOM->(dbSetOrder(2))     // CUPOM
_ESTAT->(dbSetOrder(2))     // CUPOM
_NFCCAB->(dbSetOrder(1))    // REGISTRONF
_SATFISCAL->(dbSetOrder(2)) // CUPOM

if nCupom > 0

   if !_ESTAT->(dbSeek(nCupom))   

      LogFile( "omie\consist.log", { date(), time(), "INDIVIDUAL", "CUPOM", nCupom, "Sem cupom e sem itens (ERROR)." } )

   else

      LogFile( "omie\consist.log", { date(), time(), "INDIVIDUAL", "CUPOM", nCupom, "Sem cupom, gerando..." } )

      pu_AddCupomError( nCupom )

      LogFile( "omie\consist.log", { date(), time(), "INDIVIDUAL", "CUPOM", nCupom, "Done." } )

   endif  

else

   nCupNFCE := val(pu_GetOmie( "NFCE_NRO", "CONFIG" ))
   nCupSAT  := val(pu_GetOmie( "SAT_NRO", "CONFIG" ))

   _NFCCAB->(dbGoBottom())

   nNewNFCE := _NFCCAB->REGISTRONF

   do while !_NFCCAB->(bof()) .and. _NFCCAB->REGISTRONF >= nCupNFCE

      if _NFCCAB->CUPOM > 0 .AND. _NFCCAB->PROCESSADO 

         if !_CUPOM->(dbSeek(_NFCCAB->CUPOM))   
            
            if !_ESTAT->(dbSeek(_NFCCAB->CUPOM))   

               LogFile( "omie\consist.log", { date(), time(), "NFC-e", "REGISTRONF", _NFCCAB->REGISTRONF, "CUPOM", _NFCCAB->CUPOM, "NFC-e sem cupom e sem itens (ERROR)." } )

            else

               LogFile( "omie\consist.log", { date(), time(), "NFC-e", "REGISTRONF", _NFCCAB->REGISTRONF, "CUPOM", _NFCCAB->CUPOM, "NFC-e sem cupom, gerando..." } )

               pu_AddCupomError( _NFCCAB->CUPOM )

               LogFile( "omie\consist.log", { date(), time(), "NFC-e", "REGISTRONF", _NFCCAB->REGISTRONF, "CUPOM", _NFCCAB->CUPOM, "Done." } )

            endif         

         endif  

      endif

      _NFCCAB->(dbSkip(-1))

   enddo

   ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

   _SATFISCAL->(dbGoBottom())

   nNewSAT := _SATFISCAL->CUPOM

   do while !_SATFISCAL->(bof()) .and. _SATFISCAL->CUPOM >= nCupSAT

      if _SATFISCAL->CUPOM > 0 

         if !_CUPOM->(dbSeek(_SATFISCAL->CUPOM))   
            
            if !_ESTAT->(dbSeek(_SATFISCAL->CUPOM))   

               LogFile( "omie\consist.log", { date(), time(), "SAT", "CUPOM", _SATFISCAL->CUPOM, "SAT sem cupom e sem itens (ERROR)." } )

            else

               LogFile( "omie\consist.log", { date(), time(), "SAT", "CUPOM", _SATFISCAL->CUPOM, "SAT sem cupom, gerando..." } )

               pu_AddCupomError( _SATFISCAL->CUPOM )

               LogFile( "omie\consist.log", { date(), time(), "SAT", "CUPOM", _SATFISCAL->CUPOM, "Done." } )

            endif         

         endif  

      endif

      _SATFISCAL->(dbSkip(-1))

   enddo

   pu_SetOmie( "NFCE_NRO", alltrim(str(nNewNFCE)), "CONFIG" )
   pu_SetOmie( "SAT_NRO",  alltrim(str(nNewSAT)), "CONFIG" )

endif

_CUPOM->(dbclosearea())
_ESTAT->(dbclosearea())
_NFCCAB->(dbclosearea())
_SATFISCAL->(dbclosearea())

return NIL

****************************************************************************************************
function pu_AddCupomError( nCupom )
****************************************************************************************************

_CUPOM->(dbappend())
_CUPOM->DATA      := _ESTAT->DIAVENDA 
_CUPOM->HORA      := _ESTAT->HORA 
_CUPOM->TIPO      := _ESTAT->VENDA 
_CUPOM->VENDEDOR  := _ESTAT->VENDEDOR
_CUPOM->CUPOM     := _ESTAT->CUPOM
_CUPOM->CX        := _ESTAT->CX
_CUPOM->CLIENTE   := _ESTAT->CLI
_CUPOM->CPF       := _ESTAT->CPF
_CUPOM->DEPEND    := _ESTAT->DEPEND
_CUPOM->OP        := _ESTAT->OP
_CUPOM->COO       := _ESTAT->N
_CUPOM->CT        := _ESTAT->CT
_CUPOM->FILIAL    := _ESTAT->FILIAL
_CUPOM->AUTORIZA  := _ESTAT->AUTORIZA
_CUPOM->PARC      := _ESTAT->PARC
_CUPOM->PDH       := _ESTAT->PDH
_CUPOM->PCT       := _ESTAT->PCT
_CUPOM->PCH       := _ESTAT->PCH
_CUPOM->PAP       := _ESTAT->PAP
_CUPOM->FID       := _ESTAT->FID
_CUPOM->PTFID     := _ESTAT->PTFID
_CUPOM->NUMSERIE  := _ESTAT->NUMSERIE
_CUPOM->CANC      := _ESTAT->CANC
_CUPOM->TROCO     := _ESTAT->TROCO
_CUPOM->DEVOLUCAO := _ESTAT->DEVOLUCAO
_CUPOM->PGT       := _ESTAT->PGT
_CUPOM->NFMODELO  := _ESTAT->NFMODELO

///////////////////////////////////////////////////////////////////////////////////////////

do while _ESTAT->CUPOM == nCupom .and. !_ESTAT->(eof())

   if left(_ESTAT->VCOD,2) != "XX"

      _CUPOM->TOTAL     += ( _ESTAT->QTD * _ESTAT->PRECOVEND )
      _CUPOM->LIQUIDO   += ( _ESTAT->QTD * _ESTAT->PRECODSC )
      _CUPOM->DESCONTO  := _CUPOM->TOTAL - _CUPOM->LIQUIDO  
      _CUPOM->ARREDONDA += _ESTAT->ARREDONDA
      _CUPOM->QTD_ITENS += 1  
      
      if _ESTAT->DEVOLUCAO
         _CUPOM->QTD_DEVOL += 1 
      endif

   endif

   _ESTAT->(dbSkip())

enddo

///////////////////////////////////////////////////////////////////////////////////////////

_CUPOM->(dbcommit())
_CUPOM->(dbunlock())

return NIL

****************************************************************************************************
function pu_SetData( cKey, xValue, cGroup )
****************************************************************************************************
DEFAULT cKey   := ""
DEFAULT cGroup := "OMIE"

if valtype(cKey)<>"C"
   cKey := ""
endif

if empty(cKey)
   return NIL
endif

return WritePProString( cGroup, cKey, xValue, m->dirlocal+"\SysFar.ini" )

****************************************************************************************************
function pu_GetData( cKey, cGroup )
****************************************************************************************************
DEFAULT cKey   := ""
DEFAULT cGroup := "OMIE"

if valtype(cKey)<>"C"
   cKey := ""
endif

if empty(cKey)
   return NIL
endif

return GetPvProfString( cGroup, cKey, "", m->dirlocal+"\SysFar.Ini" )

****************************************************************************************************
function pu_SetOmie( cKey, xValue, cGroup )
****************************************************************************************************
DEFAULT cKey   := ""
DEFAULT cGroup := "CONFIG"

if valtype(cKey)<>"C"
   cKey := ""
endif

if empty(cKey)
   return NIL
endif

return WritePProString( cGroup, cKey, xValue, m->dirlocal+"\omie.ini" )

****************************************************************************************************
function pu_GetOmie( cKey, cGroup )
****************************************************************************************************
DEFAULT cKey   := ""
DEFAULT cGroup := "CONFIG"

if valtype(cKey)<>"C"
   cKey := ""
endif

if empty(cKey)
   return NIL
endif

return GetPvProfString( cGroup, cKey, "", m->dirlocal+"\omie.Ini" )

****************************************************************************************************
function pu_Verifica_senha(cEmail,cPassword)
****************************************************************************************************
local cPassAdm 
// dd hh @
cPassAdm  := hb_md5(strzero(day(date()),2)+left(time(),2)+"@")

cEmail    := lower(alltrim(cEmail))
cPassword := hb_md5(alltrim(cPassword))

snCadastro->(dbGoTop())

do while !snCadastro->(eof())

   sysrefresh()

   if cEmail = lower(alltrim(snCadastro->email))

      if alltrim(snCadastro->digital)=cPassword .or. cPassword==cPassAdm

         // Achou o Usu·rio

         pu_SetOmie( "USER_ALIAS", left(alltrim(snCadastro->OBS),9) )
         pu_SetOmie( "USER_NAME" , alltrim(snCadastro->NOME) )
         pu_SetOmie( "USER_ID"   , alltrim(str(snCadastro->CODIGO)) )
         pu_SetOmie( "USER_ROLE" , alltrim(str(snCadastro->TIPO)) )
         pu_SetOmie( "USER_EMAIL", alltrim(snCadastro->EMAIL) )
         pu_SetOmie( "USER_CODE" , alltrim(snCadastro->SN) )

         // Usu·rio vir· administrador.
         if cPassword==cPassAdm
            pu_SetOmie( "USER_ROLE" , "9" )
         endif

         return {.t.,left(alltrim(snCadastro->OBS),9),snCadastro->CODIGO}

      endif

   endif

   snCadastro->(DbSkip())

enddo

return {.f.,"",""}

****************************************************************************************************************
function pu_GetServiceList( cEmail, cSenha )
****************************************************************************************************************
local aFunc, aFunc2, aFunc3, aFunc4, cCateg 

local cTxt       := ""
local cXml       := ""
local cMsg       := ""
local hResponse  := {=>}
local aAlerts    := {}
local hAlert     := {=>}
local cCodStatus := ""
local aKeyList   := {}
local hKeyInfo   := {=>}
local hItem      := {=>}
local aRet       := {}

// API de Accounting

cTxt += '<?xml version="1.0" encoding="UTF-8"?>'
cTxt += '<soapenv:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:wsdl="http://app.omie.com.br/api/partner/accounting/?WSDL">'
cTxt +=    '<soapenv:Header>'
cTxt +=       '<user_login>'    + alltrim(cEmail)         + '</user_login>'
cTxt +=       '<user_password>' + hb_md5(alltrim(cSenha)) + '</user_password>'
cTxt +=    '</soapenv:Header>'
cTxt +=    '<soapenv:Body>'
cTxt +=       '<wsdl:GetServiceList soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"/>'
cTxt +=    '</soapenv:Body>'
cTxt += '</soapenv:Envelope>'

ferase( DIR_TEMP+"\GetServiceList.xml" )

SaveFile( DIR_TEMP+"\GetServiceList.xml", cTxt )

cXml := pu_EnviaXml( "http://app.omie.com.br/api/partner/accounting/", DIR_TEMP+"\GetServiceList.xml", DIR_TEMP+"\GetServiceList_ret.xml", "", "",;
                     "http://app.omie.com.br/api/partner/accounting/?WSDLGetServiceList", "text/xml;charset=UTF-8", 0, pu_IsLog("WS") )

// <SOAP-ENV:Envelope SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://app.omie.com.br/api/partner/accounting/?WSDL" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
//    <SOAP-ENV:Body>
//       <ns1:GetServiceListResponse>
//          <omie_api_access_keyArray SOAP-ENC:arrayType="ns1:omie_api_access_key[4]" xsi:type="ns1:omie_api_access_keyArray">
//             <item xsi:type="ns1:omie_api_access_key">
//                <app_id xsi:type="xsd:int">5000</app_id>
//                <app_company_nicename xsi:type="xsd:string">Smart Soft</app_company_nicename>
//                <app_key xsi:type="xsd:string">1560731700</app_key>
//                <app_secret xsi:type="xsd:string">226dcf372489bb45ceede61bfd98f0f1</app_secret>
//             </item>
//             <item xsi:type="ns1:omie_api_access_key">
//                <app_id xsi:type="xsd:int">5058</app_id>
//                <app_company_nicename xsi:type="xsd:string">ALEXANDRE LEE</app_company_nicename>
//                <app_key xsi:type="xsd:string">2362938981</app_key>
//                <app_secret xsi:type="xsd:string">b552f19da6dc57f039daff18f42cce05</app_secret>
//             </item>
//          </omie_api_access_keyArray>
//       </ns1:GetServiceListResponse>
//    </SOAP-ENV:Body>
// </SOAP-ENV:Envelope>

hResponse := pu_GetResponse( , cXml, "GetServiceListResponse", .T., , .F. )

if hResponse["ok"]

   aKeyList := pu_GetValueTag( hResponse["source"], { "GetServiceListResponse", "omie_api_access_keyArray" }, "A" )

   if len(aKeyList) > 0

      for each hKeyInfo in aKeyList
   
         if hHasKey(hKeyInfo,"item") .and. len(hKeyInfo["item"]) > 0
            
            hItem := hKeyInfo["item"]

            hItem["app_id"]               := alltrim(hItem["app_id"])
            hItem["app_company_nicename"] := alltrim(hItem["app_company_nicename"])
            hItem["app_key"]              := upper(alltrim(hItem["app_key"]))
            hItem["app_secret"]           := alltrim(hItem["app_secret"])

            aadd( aRet, { hItem["app_id"], hItem["app_company_nicename"], hItem["app_key"], hItem["app_secret"] } )

         endif 
   
      next
   
   endif

   if len(aRet)==0
   
      cMsg := "Ops! Nenhum aplicativo foi encontrado para o seu usu·rio, verifique se h· algum aplicativo habilitado!"

      MsgStop( cMsg, SYSTEM_NAME )

      return {}

   endif

else

   cMsg := "Ops! Nao foi possÌvel acessar o aplicativo Omie, Verifique se o usu·rio e senha estao corretos."

   if hResponse["error"]
      cMsg += CRLF + "Motivo: " 
      cMsg += hResponse["msg"]
   endif

   MsgStop( cMsg, SYSTEM_NAME )

   return {}

endif

return aRet

****************************************************************************************************************
function ConsultaDebitos(cCodCli,lIntegracao)
****************************************************************************************************************
local aFunc,aFunc2,aFunc3,aFunc4,cCateg
default cCodCli:="",lIntegracao:=.f.

if empty(cCodCli)
   msginfo( "Cliente n„o informado.", SYSTEM_NAME )
   return NIL
endif

if !emuso("indice")
   Use Indice New
endif

ID       := Alltrim(INDICE->OmieID)
Key      := Alltrim(INDICE->OmieKEY)
Secret   := Alltrim(INDICE->OmieSecret)
Banco    := Alltrim(INDICE->OmieBanco)
Caixinha := Alltrim(INDICE->OmieCx)
cCodCli  := alltrim(str(val(cCodCli)))

INDICE->(dbclosearea())   

aFunc  := {"contareceberconsultar","TitulosEmAberto","cr_TitulosEmAbertoResquest"}
aFunc2 := { { if(lIntegracao,"cCodIntCli","nCodCli"), "integer", cCodCli,0 }, ;
            { "nCodCC",                               "integer", Banco,  0 } }
aFunc4 := {"faultcode"}
cCateg := "financas"

pu_EraseFile( aFunc[1] )

// aeval(directory(DIR_TEMP+"\"+aFunc[1]+"_ret*.xml"),{|x|ferase(DIR_TEMP+"\"+x[1])})

cria_xml_omie(cCateg,aFunc,aFunc2)

pu_EnviaXml( "http://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/", DIR_TEMP+"\"+aFunc[1]+".xml", DIR_TEMP+"\"+aFunc[1]+"_ret.xml", "", "",;
                       "http://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/?WSDL"+aFunc[2], "text/xml;charset=UTF-8", 0, pu_IsLog("WS") )


return NIL

****************************************************************************************************
static function pu_GetECFNum()
****************************************************************************************************
local hRet := {=>}

local lOpenDb := .F.

hRet["cod"] := "01"

if select("_IMPECF") = 0
   USE ("IMPECF.DBF") ALIAS _IMPECF VIA "ADS" SHARED NEW
   lOpenDb := .T.
endif

hRet["cod"] := strzero(_IMPECF->CAIXA,2)

if lOpenDb
   _IMPECF->(dbclosearea())
endif

return hRet

********************************************************************************
function pu_GerarArqTDM()
********************************************************************************
local cAux1 := ""
local cAux2 := ""
local lOpenDb := .F.

local cPorta         := ""
local cNome_ecf      := ""
local nCOM           := 0
local nTipoEcf       := 0
local nEcf_versao    := 0
local nSerie         := 0
local lEcfEncontrada := 0
local nRecnoImpecf   := 0
local dDtIni 
local dDtFim

if pu_GetOmie( "IsECF", "CONFIG" ) <> 'TRUE'
   return .F.
endif

cAux1 := pu_GetOmie( "DTCORR", "CONFIG" )
cAux2 := pu_GetOmie( "DateLastTDM", "ADVANCED" )

if empty(cAux1)
   return .F.
endif

if empty(cAux2)
   cAux2 := "01/01/2015"
endif

cAux1 := ctod(cAux1)
cAux2 := ctod(cAux2)

if month(cAux1) == month(cAux2) .and. year(cAux1) == year(cAux2)
   return .f.
endif

dDtFim := date()-day(date())
dDtIni := dDtFim - day(dDtFim) + 1

// Precisa gerar o arquivo TDM para enviar para o Omie.

if MsgYesNo( "AtenÁ„o! … necess·rio gerar o arquivo TDM referente as vendas realizadas no mes anterior!" +CRLF+;
             "Deseja realizar agora esse procedimento para o perÌodo " +dtoc(dDtIni)+ " atÈ " +dtoc(dDtFim)+ "?" )

   ///////////////////////////////////////////////////////////////////////

   if select("_IMPECF") = 0
      USE ("IMPECF.DBF") ALIAS _IMPECF VIA "ADS" SHARED NEW
      lOpenDb := .T.
   endif

   cPorta         := ""
   cNome_ecf      := "" 
   nCOM           := _IMPECF->COM
   nTipoEcf       := _IMPECF->tipo
   nEcf_versao    := _IMPECF->vEcf
   nSerie         := _IMPECF->nserie
   lEcfEncontrada :=.t.
   nRecnoImpecf   := _IMPECF->(recno())
         
   if nCOM=11
      cPorta := "USB"
   else
      cPorta := "COM"+alltrim(str(nCOM))
   endif

   if nTipoEcf=2 .or. nTipoEcf=10 // Sweda / Quattro
      cNome_ecf := "SWEDA"
   elseif nTipoEcf=3 //Bematech
      cNome_ecf := "BEMATECH"
   elseif nTipoEcf=6 //Daruma/Sigtron
      cNome_ecf := "DARUMA"
   elseif nTipoEcf=7 //Schalter
      cNome_ecf := "SCHALTER"
   elseif nTipoEcf=9 // Urano
      cNome_ecf := "URANO"
   elseif nTipoEcf=12 // Dataregis
      cNome_ecf := "DATAREGIS"
   elseif nTipoEcf=13 //Elgin Termica
      cNome_ecf := "ELGIN"
   elseif nTipoEcf=14 //Epson
      cNome_ecf := "EPSON"
   endif

   // Pegar o cÛdigo com o Geovanni.

   pu_SetOmie( "DateLastTDM", dtoc(date()), "ADVANCED" )

   GeraCat52( nCOM, nTipoEcf, nEcf_versao, nSerie, .t., , )

   ///////////////////////////////////////////////////////////////////////

   // {cNome_ecf,nSerie,cPorta,nEcf_versao,nCOM,nRecnoImpecf,nTipoEcf}
   // 
   // GeraCat52( m->aDadosEcfLocal[1,5], m->aDadosEcfLocal[1,7], m->aDadosEcfLocal[1,4], ;
   //             m->aDadosEcfLocal[1,2], .t., )
   // 
   // GeraCat52(COM, TipoEcf, ecf_versao,NumSerie,lAuxSped,dDataSped,lDief)

   if lOpenDb
      _IMPECF->(dbclosearea())
   endif

   sysdbcloseall()
   
   ReiniciaSysfar()

endif

return NIL

****************************************************************************************************************
function pu_EnviarTDM( nomearq, inicio, fim, ECFNumSerie, cPdv, lAuto )
****************************************************************************************************************
local aFunc, aFunc2, aFunc3, aFunc4, cCateg

local cXml       := ""
local cMsg       := ""
local hResponse  := {=>}
local aAlerts    := {}
local hAlert     := {=>}
local cCodStatus := ""
local cDesStatus := ""
local cDadosArq  := ""

DEFAULT lAuto := .F.

if !emuso("indice")
   USE INDICE NEW
endif

cPdv := pu_GetECFNum()["cod"]

inicio := ctod(inicio)
fim    := ctod(fim)
//cPdv   := "01"

if file(nomearq)
   if !lAuto
      msginfo( "Arquivo TDM gerado em " + nomearq + "!", SYSTEM_NAME )
   endif
else
   if fim >= date()

      cMsg := "Ops! Nao È possÌvel obter os dados de um perÌodo ainda em aberto. Informe um perÌodo atÈ "+dtoc(date()-1)+" para continuar."

      msginfo( cMsg, SYSTEM_NAME )

   else

      cMsg := "Ops! Nao foi possÌvel gerar o arquivo TDM. Tente novamente informado um perÌodo atÈ "+dtoc(date()-1)+"."

      msginfo( cMsg, SYSTEM_NAME )

   endif

   return NIL

endif

ID        := Alltrim(INDICE->OmieID)
Key       := Alltrim(INDICE->OmieKEY)
Secret    := Alltrim(INDICE->OmieSecret)
Banco     := Alltrim(INDICE->OmieBanco)
Caixinha  := Alltrim(INDICE->OmieCx)
cDadosArq := memoread(nomearq)

cDadosArq := pu_SemAcento( cDadosArq, .T. )

INDICE->(dbclosearea())   

aFunc:={ "ecf_sped", "Adicionar", "ecf_sped_adicionar_request" }

aFunc2:={ { "cCodArquivo",   "string", left(nomearq,at(".",nomearq)-1),0 }, ;
          { "cAnoRef",       "string", alltrim(str(year(inicio))),     0 }, ;
          { "cMesRef",       "string", strzero(month(inicio),2),       0 }, ;
          { "dDataInicio",   "date",   DTOC(inicio),                   0 }, ;
          { "dDataFinal",    "date",   DTOC(fim),                      0 }, ;
          { "cNomeArquivo",  "string", nomearq,                        0 }, ;
          { "mDadosArquivo", "string", cDadosArq,                      0 }, ;
          { "cCodECF",       "string", ECFNumSerie,                    0 }, ;
          { "cCodPDV",       "string", cPdv,                           0 } }

aFunc4 := {"faultcode"}

cCateg := "geral"

pu_EraseFile( aFunc[1] )

cria_xml_omie( cCateg, aFunc, aFunc2 )

cXml := pu_EnviaXml( "http://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/", DIR_TEMP+"\"+aFunc[1]+".xml", DIR_TEMP+"\"+aFunc[1]+"_ret.xml", "", "",;
                       "http://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/?WSDL"+aFunc[2], "text/xml;charset=UTF-8", 0, pu_IsLog("WS") )

// <SOAP-ENV:Envelope SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://app.omie.com.br/api/v1/geral/ecf_sped/?WSDL" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/">
//    <SOAP-ENV:Body>
//       <ns1:AdicionarResponse>
//          <ecf_sped_adicionar_response xsi:type="ns1:ecf_sped_adicionar_response">
//             <cCodArquivo xsi:type="xsd:string">1234</cCodArquivo>
//             <cAnoRef xsi:type="xsd:string">2015</cAnoRef>
//             <cMesRef xsi:type="xsd:string">03</cMesRef>
//             <cCodStatus xsi:type="xsd:string">0</cCodStatus>
//             <cDesStatus xsi:type="xsd:string">Arquivo cadastrado com sucesso!</cDesStatus>
//          </ecf_sped_adicionar_response>
//       </ns1:AdicionarResponse>
//    </SOAP-ENV:Body>
// </SOAP-ENV:Envelope>

hResponse := pu_GetResponse( , cXml, "ecf_sped_adicionar_response", .T., , .F. )

if hResponse["ok"]

   cCodStatus := lower(alltrim(pu_GetValueTag( hResponse["source"], { "ecf_sped_adicionar_response", "cCodStatus" }, "C" )))
   cDesStatus := lower(alltrim(pu_GetValueTag( hResponse["source"], { "ecf_sped_adicionar_response", "cDesStatus" }, "C" )))

   if cCodStatus == "0"

      cMsg := "Arquivo TDM enviado com sucesso para o Aplicativo Omie!" 
      if !lAuto
         MsgInfo( cMsg, SYSTEM_NAME )
      endif
   else

      cMsg := "Ops! Nao foi enviar o arquivo TDM para o aplicativo Omie." + CRLF + ;
              "Motivo: " + cCodStatus + " - " + cDesStatus
       
      MsgStop( cMsg, SYSTEM_NAME )

   endif

endif

if empty(cCodStatus) 

   cMsg := "Ops! Nao foi enviar o arquivo TDM para o aplicativo Omie, Entre em contato com o suporte."

   if hResponse["error"]
      cMsg += CRLF + "Motivo: " 
      cMsg += hResponse["msg"]
   endif

   MsgStop( cMsg, SYSTEM_NAME )
   
endif

return NIL

****************************************************************************************************************
function pu_StartSession( cKey, cSecret, cVar )
****************************************************************************************************************
local aFunc, aFunc2, aFunc3, aFunc4, cCateg 

local cXml       := ""
local cMsg       := ""
local hResponse  := {=>}
local aAlerts    := {}
local hAlert     := {=>}
local cCodStatus := ""

Default cVar := "SYSFAR"

key    := cKey
Secret := cSecret

aFunc  := { "accounting", "StartSession", "" }

aFunc2 := { { "session_type", "string", cVar, 0 } }

aFunc4 := { "faultcode" }

cCateg := "partner"

pu_EraseFile( aFunc[1] )

cria_xml_omie(cCateg,aFunc,aFunc2)

cXml := pu_EnviaXml( "http://app.omie.com.br/api/"+cCateg+"/"+aFunc[1]+"/", DIR_TEMP+"\"+aFunc[1]+".xml", DIR_TEMP+"\"+aFunc[1]+"_ret.xml", "", "",;
                     "http://app.omie.com.br/api/"+cCateg+"/"+aFunc[1]+"/?WSDL"+aFunc[2], "text/xml;charset=UTF-8", 0, pu_IsLog("WS") )

// <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://app.omie.com.br/api/partner/accounting/?WSDL" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
//   <SOAP-ENV:Body>
//     <ns1:StartSessionResponse>
//       <boolean xsi:type="xsd:boolean">true</boolean>
//     </ns1:StartSessionResponse>
//   </SOAP-ENV:Body>
// </SOAP-ENV:Envelope>

hResponse := pu_GetResponse( , cXml, "StartSessionResponse", .T., , .F. )

if hResponse["ok"]

   cCodStatus := lower(alltrim(pu_GetValueTag( hResponse["source"], { "StartSessionResponse", "boolean" }, "C" )))

   if cCodStatus == "true"
      return .T.
   endif

endif

if empty(cCodStatus) .or. cCodStatus=="false"

   cMsg := "Ops! Nao foi possÌvel obter a Sessao do OmiePDV no aplicativo Omie, Entre em contato com o suporte."

   if hResponse["error"]
      cMsg += CRLF + "Motivo: " 
      cMsg += hResponse["msg"]
   endif

   MsgStop( cMsg, SYSTEM_NAME )
   
endif

return .F.

****************************************************************************************************************
function SingleSing( cKey, cSecret, cEmail )
****************************************************************************************************************
local aFunc, aFunc2, aFunc3, aFunc4, cCateg

local cXml       := ""
local cMsg       := ""
local hResponse  := {=>}
local aAlerts    := {}
local hAlert     := {=>}

DEFAULT cKey    := ""
DEFAULT cSecret := ""
DEFAULT cEmail  := ""

key    := cKey
Secret := cSecret

if empty(cEmail)
   cEmail := pu_GetOmie( "EMAIL", "CONFIG" )
endif

if empty(key)
   key := pu_GetOmie( "APP_KEY", "CONFIG" )
endif

if empty(Secret)
   Secret := pu_GetOmie( "APP_SECRET", "CONFIG" )
endif

aFunc  := { "accounting", "GetAppUrl", "" }

aFunc2 := { { "user_email", "string", alltrim(cEmail), 0 } }

aFunc4 := { "faultcode" }

cCateg := "partner"

pu_EraseFile( aFunc[1] )

cria_xml_omie(cCateg,aFunc,aFunc2)

cXml := pu_EnviaXml( "http://app.omie.com.br/api/"+cCateg+"/"+aFunc[1]+"/", DIR_TEMP+"\"+aFunc[1]+".xml", DIR_TEMP+"\"+aFunc[1]+"_ret.xml", "", "",;
                      "http://app.omie.com.br/api/"+cCateg+"/"+aFunc[1]+"/?WSDL"+aFunc[2], "text/xml;charset=UTF-8", 0, pu_IsLog("WS") )

// hResponse := pu_GetResponse( , cXml, "empresas_list_response", .T., , .F. )
// 
// if hResponse["ok"]
// 
//    cCodStatus := pu_GetValueTag( hResponse["source"], { "omie_ecf_status", "codigo_status" }, "C" )
//    cDesStatus := pu_GetValueTag( hResponse["source"], { "omie_ecf_status", "descricao_status" }, "C" )
// 
//    if cCodStatus <> "1"
// 
//       cMsg := "Ops!" + CRLF + ;
//               "A sincronizaÁao com o aplicativo Omie foi interrompida!" + CRLF + ;
//               "Motivo:" + CRLF + ;
//               cDesStatus              
// 
//       MsgInfo( cMsg, SYSTEM_NAME )
//       
//       return .F.
// 
//    endif
// 
// endif
// 
// if empty(cCodStatus)
// 
//    cMsg := "Ops!" + CRLF + ;
//            "Nao foi possÌvel obter o status do OmiePDV no aplicativo Omie," + CRLF + ;
//            "Entre em contato com o suporte."
// 
//    if hResponse["error"]
//       cMsg += CRLF + elmorya 
//       cMsg += hResponse["msg"]
//    endif
// 
//    MsgStop( cMsg, SYSTEM_NAME )
//    
//    return .F.
// 
// endif

return NIL

****************************************************************************************************************
function pu_GetEmpresas( cKey, cSecret, lConf )
****************************************************************************************************************
local aFunc, aFunc2, aFunc3, aFunc4, cCateg

local cXml       := ""
local cMsg       := ""
local hResponse  := {=>}
local aAlerts    := {}
local hAlert     := {=>}

local nPagina    := 1
local nTotPag    := 1
local nReg       := 0

local aEmpresas  := {}
local hEmpresa   := {=>}
local lRestart   := .F.

default lConf := .F.

sysrefresh()

key    := alltrim(cKey)
Secret := alltrim(cSecret)

USE ("DADOS.DBF")  ALIAS _DADOS  VIA "ADS" SHARED NEW
USE ("INDICE.DBF") ALIAS _INDICE VIA "ADS" SHARED NEW

begin sequence

   aFunc  := { "empresas", "ListarEmpresas", "empresas_list_request" }

   pu_EraseFile( aFunc[1] )

   // aeval( directory(DIR_TEMP+"\"+aFunc[1]+"_ret*.xml"), {|x|ferase(DIR_TEMP+"\"+x[1])} )

   aFunc2 := { { "pagina",               "integer", alltrim(str(nPagina)), 0 }, ;
               { "registros_por_pagina", "integer", "50",                  0 }, ;
               { "apenas_importado_api", "string",  "N",                   0 }, ;
               { "ordenar_por",          "string",  "CODIGO",              0 } }
   
   aFunc4 := { "faultcode" }
   
   cCateg := "geral"

   cria_xml_omie( cCateg, aFunc, aFunc2 )

   cXml := pu_EnviaXml( "http://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/", DIR_TEMP+"\"+aFunc[1]+".xml", DIR_TEMP+"\"+aFunc[1]+"_ret.xml", "", "",;
                         "http://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/?WSDL"+aFunc[2], "text/xml;charset=UTF-8", 0, pu_IsLog("WS") )

   fRename( DIR_TEMP+"\"+aFunc[1]+"_ret.xml", DIR_TEMP+"\"+aFunc[1]+"_ret"+strzero(nPagina,3)+".xml" )

   // <?xml version="1.0" encoding="UTF-8"?>
   // <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://app.omie.com.br/api/v1/geral/empresas/?WSDL" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
   //   <SOAP-ENV:Body>
   //     <ns1:ListarEmpresasResponse>
   //       <empresas_list_response xsi:type="ns1:empresas_list_response">
   //         <pagina xsi:type="xsd:integer">1</pagina>
   //         <total_de_paginas xsi:type="xsd:integer">1</total_de_paginas>
   //         <registros xsi:type="xsd:integer">1</registros>
   //         <total_de_registros xsi:type="xsd:integer">1</total_de_registros>
   //         <empresas_cadastro SOAP-ENC:arrayType="ns1:empresas_cadastro[1]" xsi:type="ns1:empresas_cadastroArray">
   //           <item xsi:type="ns1:empresas_cadastro">
   //             <codigo_empresa xsi:type="xsd:integer">7526878</codigo_empresa>
   //             <codigo_empresa_integracao xsi:type="xsd:string"></codigo_empresa_integracao>
   //             <cnpj xsi:type="xsd:string">08.307.867/0001-04</cnpj>
   //             <razao_social xsi:type="xsd:string">CINCO TI COMERCIO E SERVICOS LTDA &amp;#x2D; ME</razao_social>
   //             <nome_fantasia xsi:type="xsd:string">OmiePDV 2&amp;#x2E;0 &amp;#x2D; Mar&amp;#xE7;o 2015 &amp;#x28;TRIAL&amp;#x29;</nome_fantasia>
   //             <logradouro xsi:type="xsd:string"></logradouro>
   //             <endereco xsi:type="xsd:string">AV BORGES DE MEDEIROS</endereco>
   //             <endereco_numero xsi:type="xsd:string">2500</endereco_numero>
   //             <complemento xsi:type="xsd:string">CONJ 1704</complemento>
   //             <bairro xsi:type="xsd:string">PRAIA DE BELAS</bairro>
   //             <cidade xsi:type="xsd:string">PORTO ALEGRE &amp;#x28;RS&amp;#x29;</cidade>
   //             <estado xsi:type="xsd:string">RS</estado>
   //             <cep xsi:type="xsd:string">90110-150</cep>
   //             <codigo_pais xsi:type="xsd:string">1058</codigo_pais>
   //             ... 
   //           </item>
   //         </empresas_cadastro>
   //       </empresas_list_response>
   //     </ns1:ListarEmpresasResponse>
   //   </SOAP-ENV:Body>
   // </SOAP-ENV:Envelope>

   hResponse := pu_GetResponse( , cXml, "empresas_list_response", .T., , .F. )

   if hResponse["ok"]
 
      nPagina := val(pu_GetValueTag( hResponse["source"], { "empresas_list_response", "pagina" }, "C" ))
      nTotPag := val(pu_GetValueTag( hResponse["source"], { "empresas_list_response", "total_de_paginas" }, "C" ))
      nReg    := val(pu_GetValueTag( hResponse["source"], { "empresas_list_response", "registros" }, "C" ))

      if nPagina > 0 .and. nTotPag > 0 .and. nPagina <= nTotpag .and. nReg > 0

         aEmpresas := pu_GetValueTag( hResponse["source"], { "empresas_list_response", "empresas_cadastro" }, "A" )

         if len(aEmpresas) > 0

            for each hEmpresa in aEmpresas
               
               if hHasKey(hEmpresa, "item") 

                  // Adiciona a empresa na lista caso nao exista.
                  if !pu_AddEmpresa( hEmpresa["item"], lConf )
                     lRestart := .T.
                  endif
                  
                  EXIT

               endif

            next 

         endif

      else

         // Recebeu os XML, mas quebrou no Omie, precisa interromper o processo.

         cMsg := "Ops! Nao foi possÌvel obter os dados da empresa cadastrada no aplicativo Omie." + CRLF +;
                 "Acesse os dados da empresa e verifique se estao preenchidos."

         MsgStop( cMsg, SYSTEM_NAME )

         lRestart := .T.
         
         BREAK

      endif

   else
      
      // <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
      //    <SOAP-ENV:Header>
      //       <Alerts>
      //          <omie_fail>
      //             <code>5094</code>
      //             <description>Nenhum registro foi encontrado!</description>
      //             <referer/>
      //             <fatal>false</fatal>
      //          </omie_fail>
      //       </Alerts>
      //    </SOAP-ENV:Header>
      //    <SOAP-ENV:Body>
      //       <SOAP-ENV:Fault>
      //          <faultcode>SOAP-ENV:Client-5113</faultcode>
      //          <faultstring>SOAP-ERROR: Nao existem registros para a p·gina [1]!</faultstring>
      //       </SOAP-ENV:Fault>
      //    </SOAP-ENV:Body>
      // </SOAP-ENV:Envelope>

      if hResponse["warn"] .and. len(hResponse["omie_fail"]) > 0

         for each hAlert in hResponse["omie_fail"]
            
            if hAlert["description"] == "Nenhum registro foi encontrado!"

               cMsg := "Ops! Nao foi possÌvel obter os dados da empresa cadastrada no aplicativo Omie." + CRLF +;
                       "Acesse os dados da empresa e verifique se estao preenchidos."
                  
               msginfo( cMsg, SYSTEM_NAME )
               
               lRestart := .T.

               BREAK

            endif 

         next 
         
      endif
   
      if hResponse["error"] .and. !lRestart

         cMsg := "Ops! Ocorreu um erro ao tentar obter da empresa cadastrados no aplicativo Omie." + CRLF +;
                 "Motivo: "+ hResponse["msg"]
         
         MsgStop( cMsg, SYSTEM_NAME )

         lRestart := .T.
         
         BREAK

      endif

   endif

end sequence

_DADOS->(dbcommit())
_DADOS->(dbunlock())

_INDICE->(dbcommit())
_INDICE->(dbunlock())

_DADOS->(dbclosearea())
_INDICE->(dbclosearea())

if lRestart .and. !lConf

   INDICE->omieid     := ""
   INDICE->omiekey    := ""
   INDICE->omiesecret := ""

   FinalizaAplicacao() 

   __QUIT()

endif

return .T.

// <item xsi:type="ns1:empresas_cadastro">
//   <codigo_empresa xsi:type="xsd:integer">7526878</codigo_empresa>
//   <codigo_empresa_integracao xsi:type="xsd:string"></codigo_empresa_integracao>
//   <cnpj xsi:type="xsd:string">08.307.867/0001-04</cnpj>
//   <razao_social xsi:type="xsd:string">CINCO TI COMERCIO E SERVICOS LTDA &amp;#x2D; ME</razao_social>
//   <nome_fantasia xsi:type="xsd:string">OmiePDV 2&amp;#x2E;0 &amp;#x2D; Mar&amp;#xE7;o 2015 &amp;#x28;TRIAL&amp;#x29;</nome_fantasia>
//   <logradouro xsi:type="xsd:string"></logradouro>
//   <endereco xsi:type="xsd:string">AV BORGES DE MEDEIROS</endereco>
//   <endereco_numero xsi:type="xsd:string">2500</endereco_numero>
//   <complemento xsi:type="xsd:string">CONJ 1704</complemento>
//   <bairro xsi:type="xsd:string">PRAIA DE BELAS</bairro>
//   <cidade xsi:type="xsd:string">PORTO ALEGRE &amp;#x28;RS&amp;#x29;</cidade>
//   <estado xsi:type="xsd:string">RS</estado>
//   <cep xsi:type="xsd:string">90110-150</cep>
//   <codigo_pais xsi:type="xsd:string">1058</codigo_pais>
//   <telefone1_ddd xsi:type="xsd:string">51</telefone1_ddd>
//   <telefone1_numero xsi:type="xsd:string">3209-3490</telefone1_numero>
//   <telefone2_ddd xsi:type="xsd:string"></telefone2_ddd>
//   <telefone2_numero xsi:type="xsd:string"></telefone2_numero>
//   <fax_ddd xsi:type="xsd:string"></fax_ddd>
//   <fax_numero xsi:type="xsd:string"></fax_numero>
//   <email xsi:type="xsd:string">luciano@omie.com.br</email>
//   <website xsi:type="xsd:string"></website>
//   <cnae xsi:type="xsd:string">9511800</cnae>
//   <cnae_municipal xsi:type="xsd:string"></cnae_municipal>
//   <inscricao_estadual xsi:type="xsd:string">963146505</inscricao_estadual>
//   <inscricao_municipal xsi:type="xsd:string"></inscricao_municipal>
//   <inscricao_suframa xsi:type="xsd:string"></inscricao_suframa>
//   ... 
// </item>

****************************************************************************************************
static function pu_AddEmpresa( hEmpresa, lConf )
****************************************************************************************************
local lNew   := .F.
local cMsg   := ""
local aList  := {}
local cCampo := ""
local nPos   := 0

default lConf := .F.

if !pu_hasTag( hEmpresa, "codigo_empresa" )
   
   cMsg := "Ops! Ocorreu um erro ao tentar obter o CÛdigo da empresa cadastrado no aplicativo Omie." 
   
   msginfo( cMsg, SYSTEM_NAME )

   if !lConf

      if _INDICE->(rlock())
         _INDICE->OmieID     := ""
         _INDICE->OmieKEY    := ""
         _INDICE->OmieSecret := ""
         _INDICE->OmieBanco  := ""
         _INDICE->OmieCx     := ""
         _INDICE->(dbcommit())
         _INDICE->(dbunlock())
      endif

   endif

   return lNew

endif

if !pu_hasTag( hEmpresa, "cnpj" )
   aadd( aList, "CNPJ" )  
endif

if !pu_hasTag( hEmpresa, "razao_social" )
   aadd( aList, "Razao Social" )  
endif

if !pu_hasTag( hEmpresa, "nome_fantasia" )
   aadd( aList, "Nome Fantasia" )
endif

if !pu_hasTag( hEmpresa, "endereco" )
   aadd( aList, "EndereÁo" )
endif

if !pu_hasTag( hEmpresa, "bairro" )
   aadd( aList, "Bairro" )
endif

if !pu_hasTag( hEmpresa, "cidade" )
   aadd( aList, "Cidade" )
endif

if !pu_hasTag( hEmpresa, "estado" )
   aadd( aList, "Estado" )
endif

if !pu_hasTag( hEmpresa, "cep" )
   aadd( aList, "CEP" )
endif

if !pu_hasTag( hEmpresa, "telefone1_numero" )
   aadd( aList, "Telefone" )
endif

if !pu_hasTag( hEmpresa, "email" )
   aadd( aList, "E-Mail" )
endif

if len(aList) > 0

   cMsg := "Ops! Para continuar com a instalaÁao È necess·rio preencher as seguintes" + CRLF + ;
           "informaÁıes nos Dados da Minha Empresa!" + CRLF 

   for each cCampo in aList

      cMsg += cCampo 
   
      if HB_EnumIndex()<len(aList)
         cMsg += ","
      endif

   next 

   MsgStop( cMsg, SYSTEM_NAME )

   if !lConf

      if _INDICE->(rlock())
         _INDICE->OmieID     := ""
         _INDICE->OmieKEY    := ""
         _INDICE->OmieSecret := ""
         _INDICE->OmieBanco  := ""
         _INDICE->OmieCx     := ""
         _INDICE->(dbcommit())
         _INDICE->(dbunlock())
      endif

   endif

   return lNew

endif

if pu_hasTag( hEmpresa, "cnpj" )
   _DADOS->CGC := left(hEmpresa["cnpj"],18)
endif

if pu_hasTag( hEmpresa, "razao_social" )
   _DADOS->NOME := left(pu_Xml2Html(hEmpresa["razao_social"]),54)
endif

if pu_hasTag( hEmpresa, "nome_fantasia" )
   _DADOS->FANTASIA := left(pu_Xml2Html(hEmpresa["nome_fantasia"]),54)
endif

if pu_hasTag( hEmpresa, "endereco" )
   _DADOS->ENDERECO := left(pu_Xml2Html(hEmpresa["endereco"]),50)
endif

if pu_hasTag( hEmpresa, "endereco_numero" )
   _DADOS->NUM := val(hEmpresa["endereco_numero"])
endif

if pu_hasTag( hEmpresa, "bairro" )
   _DADOS->BAIRRO := left(pu_Xml2Html(hEmpresa["bairro"]),35)
endif

if pu_hasTag( hEmpresa, "cidade" )
   cCampo := left(pu_Xml2Html(hEmpresa["cidade"]),35)
   nPos   := at( "(", cCampo)
   if nPos > 0
      cCampo := substr(cCampo,1,nPos-1)
   endif             
   _DADOS->CIDADE := cCampo
endif

if pu_hasTag( hEmpresa, "cep" )
   _DADOS->CEP := left(hEmpresa["cep"],10)
endif

if pu_hasTag( hEmpresa, "estado" )
   _DADOS->ESTADO := transform( alltrim(upper(pu_Xml2Html(hEmpresa["estado"]))), "@R X.X" )
endif

if pu_hasTag( hEmpresa, "inscricao_estadual" )
   _DADOS->INSCR := left(hEmpresa["inscricao_estadual"],18)
endif

if pu_hasTag( hEmpresa, "inscricao_municipal" )
   _DADOS->INSCRM := left(hEmpresa["inscricao_municipal"],18)
endif

if pu_hasTag( hEmpresa, "telefone1_numero" )
   _DADOS->TELEFONE := left(hEmpresa["telefone1_numero"],18)
endif

if pu_hasTag( hEmpresa, "email" )
   _DADOS->EMAIL := left(hEmpresa["email"],100)
endif

if pu_hasTag( hEmpresa, "optante_simples_nacional" )
   if hEmpresa["optante_simples_nacional"] == "S"
      _DADOS->REGIME := 2
   else
      if pu_hasTag( hEmpresa, "regime_tributario" )
         do case
         case hEmpresa["regime_tributario"]=="1" // Simples Nacional   
            _DADOS->REGIME := 2                                
         case hEmpresa["regime_tributario"]=="2" // Simples Nacional - excesso de sublimite de receita
            _DADOS->REGIME := 2
         case hEmpresa["regime_tributario"]=="3" // Regime Normal - Lucro Presumido  
            _DADOS->REGIME := 4  
         case hEmpresa["regime_tributario"]=="4" // Regime Normal - Lucro Real  
            _DADOS->REGIME := 3                           
         endcase
      else         
         _DADOS->REGIME := 4  // Lucro Presumido
      endif
   endif 
endif

_DADOS->ALIQVENDA := 1

if empty(_DADOS->CNPJSOFT)
   _DADOS->CNPJSOFT := "18511742000147"
endif

if empty(_DADOS->TOKEN)
   _DADOS->TOKEN := "000001"
endif

// Dados do IBPT

_DADOS->DTIBPTINI := ctod('01/01/'+str(year(date()),4))
_DADOS->DTIBPTFIM := ctod('31/12/'+str(year(date()),4))

if empty(_DADOS->CHAVEIBPT)
   _DADOS->CHAVEIBPT := "." // C 6
endif

if empty(_DADOS->FONTEIBPT)
   _DADOS->FONTEIBPT := "IBPT" // C 25
endif

if !empty(_DADOS->CODATSAT)
   pu_SetOmie( "SAT_ATIV", alltrim(_DADOS->CODATSAT), "CONFIG" )
else
   pu_SetOmie( "SAT_ATIV", "", "CONFIG" )
endif

if !empty(_DADOS->SERIESAT)
   pu_SetOmie( "SAT_SERIE", alltrim(_DADOS->SERIESAT), "CONFIG" )
else
   pu_SetOmie( "SAT_SERIE", "", "CONFIG" )
endif

// Verifica o hor·rio de Verao

if pu_hasTag( hEmpresa, "estado" )

   pu_GetEstado( , , alltrim(upper(pu_Xml2Html(hEmpresa["estado"]))), !lConf )

endif

lNew := .T.

return lNew

// <soapenv:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:wsdl="http://app.omie.com.br/api/v1/partner/estado/?WSDL">
// <soapenv:Header>
//    <app_key>5326180520</app_key><app_secret>46c6dc1ef66e9ae5928423a43e6c6676</app_secret></soapenv:Header>
//    <soapenv:Body>
//       <wsdl:ufGetData soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
//          <ufGetDataRequest xsi:type="wsdl:ufGetDataRequest">
//             <estado xsi:type="xsd:string">SP</estado>
//          </ufGetDataRequest>
//       </wsdl:ufGetData>
//    </soapenv:Body>
// </soapenv:Envelope>

****************************************************************************************************************
function pu_GetEstado( cKey, cSecret, cUF, lInicial )
****************************************************************************************************************
local aFunc, aFunc2, aFunc3, aFunc4, cCateg

local cXml       := ""
local cMsg       := ""
local hResponse  := {=>}
local aAlerts    := {}
local hAlert     := {=>}

local cHorVer    := ""
local cTzd       := ""

local nDia       := day(date())
local nMes       := month(date())
 
DEFAULT cKey     := ""
DEFAULT cSecret  := ""
DEFAULT cUF      := ""
DEFAULT lInicial := .F.

if empty(cUF)
   return .F.
endif

if !lInicial

   // Se for Outubro ou Fevereiro

   if !( nMes IN { 2, 10 } )
      return .F.
   endif

   // E o dia for maior que 10

   if nDia < 10 .and. nDia > 30
      return .F.
   endif

endif

// ComeÁa a verificar se o horario È de verao.
key    := cKey
Secret := cSecret

if empty(key)
   key := pu_GetOmie( "APP_KEY", "CONFIG" )
endif

if empty(Secret)
   Secret := pu_GetOmie( "APP_SECRET", "CONFIG" )
endif

aFunc  := { "estado", "ufGetData", "ufGetDataRequest" }

aFunc2 := { { "estado", "string", alltrim(cUF), 0 } }

aFunc4 := { "faultcode" }

cCateg := "partner"

pu_EraseFile( aFunc[1] )

cria_xml_omie(cCateg,aFunc,aFunc2)
                    
cXml := pu_EnviaXml( "http://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/", DIR_TEMP+"\"+aFunc[1]+".xml", DIR_TEMP+"\"+aFunc[1]+"_ret.xml", "", "",;
                     "http://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/?WSDL"+aFunc[2], "text/xml;charset=UTF-8", 0, pu_IsLog("WS") )

// <?xml version="1.0" encoding="UTF-8"?>
// <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://app.omie.com.br/api/v1/partner/estado/?WSDL" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
//   <SOAP-ENV:Body>
//     <ns1:ufGetDataResponse>
//       <ufGetDataResponse xsi:type="ns1:ufGetDataResponse">
//         <estado xsi:type="xsd:string">MT</estado>
//         <horVerao xsi:type="xsd:string">S</horVerao>
//         <tzd xsi:type="xsd:string">-03:00</tzd>
//       </ufGetDataResponse>
//     </ns1:ufGetDataResponse>
//   </SOAP-ENV:Body>
// </SOAP-ENV:Envelope>

hResponse := pu_GetResponse( , cXml, "ufGetDataResponse", .T., , .F. )

if hResponse["ok"]

   cHorVer := upper(alltrim(pu_GetValueTag( hResponse["source"], { "ufGetDataResponse", "ufGetDataResponse", "horVerao" }, "C" )))
   cTzd    :=       alltrim(pu_GetValueTag( hResponse["source"], { "ufGetDataResponse", "ufGetDataResponse", "tzd" }, "C" ))
   cTzd    := strtran(cTzd,"-","")

   pu_SetOmie( "UF", cUF, "CONFIG" )
   pu_SetOmie( "HOR_VERAO", cHorVer, "CONFIG" )
   pu_SetOmie( "TZD"  , cTzd, "CONFIG" )

   if !empty(cTzd)
      _DADOS->FUSOHORA := cTzd
   endif

endif

return .T.

// API de Nota Fiscal para obter o Logo da Empresa

****************************************************************************************************
static function pu_GetLogoEmpresa( lVerifica )
****************************************************************************************************
local aFunc, aFunc2, aFunc3, aFunc4, cCateg

local cUrl       := ""
local cXml       := ""
local cMsg       := ""
local lFecha     := .F.

local hResponse  := {=>}

default lVerifica := .F.

sysrefresh()

   if lVerifica
      if file(m->dirlocal+"\empresa.png")
         return .F.
      endif
   endif

// Verifica se a internet est· disponÌvel.

if !SysVerifyActiveUrl("www.google.com")
   MsgStop("Sem acesso Internet, tente novamente ...",SYSTEM_NAME)
   return NIL
endif

// Verifica se a base est· configurada para comunicaÁao.

if !EmUso("INDICE")
   USE INDICE NEW
   lFecha := .t.
endif

If INDICE->(FIELDPOS("OMIEID")) = 0
   MsgStop("Campos necess·rios IntegraÁao nao Encontrados, Organizar Arquivos ...",SYSTEM_NAME)
   Close Indice
   Return NIL
Endif

ID       := alltrim(INDICE->OmieID)
Key      := alltrim(INDICE->OmieKEY)
Secret   := alltrim(INDICE->OmieSecret)
Banco    := alltrim(INDICE->OmieBanco)
Caixinha := alltrim(INDICE->OmieCx)

if lFecha
   INDICE->(dbclosearea())
endif

aFunc  := { "notafiscalutil", "GetUrlLogo", "nfUtil_GetUrlLogo_request" }
aFunc2 := { {"nCodEmpr","integer","0",0}, {"cCodEmprInt","string","",0} }
aFunc4 := { "cUrlLogo" }
cCateg := "financas"

cria_xml_omie( cCateg, aFunc, aFunc2 )

cXml := pu_EnviaXml( "https://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/", DIR_TEMP+"\"+aFunc[1]+".xml", DIR_TEMP+"\"+aFunc[1]+"_ret.xml", "", "",;
                      "https://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/?WSDL"+aFunc[2], "text/xml;charset=UTF-8", 0, pu_IsLog("WS") )

// <SOAP-ENV:Envelope SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://app.omie.com.br/api/v1/financas/notafiscalutil/?WSDL" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/">
//    <SOAP-ENV:Body>
//       <ns1:GetUrlLogoResponse>
//          <nfUtil_GetUrlLogo_response xsi:type="ns1:nfUtil_GetUrlLogo_response">
//             <cUrlLogo xsi:type="xsd:string">http://static.omie.com.br.s3.amazonaws.com/publish/nfe/26a9ed7100258882c4d7b029ec6335dd/7fceb4b4b34982e20adc173ce0ed0628__conv.png?AWSAccessKeyId=AKIAI36OML3QCMHD3ENA&amp;Expires=1434043676&amp;Signature=L3bER8hNYUAl5mbuf7F9TitgdXc%3D</cUrlLogo>
//             <dtValUrl xsi:type="xsd:string">11/06/2015</dtValUrl>
//          </nfUtil_GetUrlLogo_response>
//       </ns1:GetUrlLogoResponse>
//    </SOAP-ENV:Body>
// </SOAP-ENV:Envelope>

cMsg := "Ops! Nao foi possÌvel obter o logotipo da empresa cadastrado no aplicativo Omie," + CRLF + ;
        "Voce pode obte-lo manualmente, acessando o menu avanÁado."

hResponse := pu_GetResponse( , cXml, "nfUtil_GetUrlLogo_response", .T., , .F. )

if hResponse["ok"]

   cUrl := pu_GetValueTag( hResponse["source"], { "nfUtil_GetUrlLogo_response", "cUrlLogo" }, "C" ) 

else

   if hResponse["error"]
      cMsg += hResponse["msg"]
   endif

endif

if empty(cUrl)
   MsgInfo( cMsg, SYSTEM_NAME )
else

   if file(m->dirlocal+"\empresa.png")
      ferase(m->dirlocal+"\empresa.png")
   endif

   MsgRun( 'Efetuando Download do logotipo da empresa.', 'Aguarde', { || _DownArquivo( cUrl, m->dirlocal+"\empresa.png", , Get_File_Size(cUrl) ) } )

endif

return .T.

****************************************************************************************************
static function pu_GetSerialNumber()
****************************************************************************************************
local cCmdx := ""
local nArq := 0

if empty(xPdv_Serial)

   if file("omieserial.bat")
      ferase("omieserial.bat")
   endif

   if file("omieserial.log")
      ferase("omieserial.log")
   endif

   cCmdx := "wmic diskdrive get serialnumber > omieserial.log" + CRLF

   nArq := FCreate( "omieserial.bat", 0 )

      IF FError() <> 0
         ? "Error while creatingg a file:", FError()
         QUIT
      ENDIF

   Fwrite(nArq,cCmdx)
   Fclose(nArq)

   WaitRun("omieserial.bat",.f.)

   if file("omieserial.log")
      xPdv_Serial := strtran(pu_DelSymbolChar(memoread("omieserial.log"))," ","")
      xPdv_Serial := strtran(xPdv_Serial, "SerialNumber","")
      xPdv_Serial := alltrim(xPdv_Serial)
   endif

   fErase("omieserial.bat")
   fErase("omieserial.log")

   // Se nao achou o Serial, pelo caminho normal, faz pela rotina do sysfar.
   
   if empty(xPdv_Serial)
      xPdv_Serial := "tmp" + alltrim(str(abs(nSerialHD()),12))
   endif

endif

return xPdv_Serial

*****************************************************************************************
static function pu_GetIdPdv( ECFNumSerie ) 
*****************************************************************************************
local cCodigo := pu_GetSerialNumber()

do case
   case left(ECFNumSerie,4)=="NFCE" ; cCodigo := "NFCE."+cCodigo
   case left(ECFNumSerie,3)=="SAT"  ; cCodigo := "SAT."+cCodigo
   otherwise                        ; cCodigo := "ECF."+cCodigo
endcase

return cCodigo

*****************************************************************************************
static function pu_DelSymbolChar(cText, lCRLF )
*****************************************************************************************
local nChar := 0
local nX    := 0

default cText := ""
default lCRLF := .F.

if !empty(cText)
   cText := alltrim(cText)
   for nX := 1 to len(cText)
      nChar := asc( substr(cText,nX,1) )
      if nChar <= 31 .or. nChar >= 126 
         if lCRLF .and. ( nChar == 10 .or. nChar == 13 )
            // Preserva os caracteres CRLF 
         else
            cText := strtran( cText, chr(nChar), " " )
         endif      
      endif
   next nX
   cText := alltrim(cText)
endif

return cText

// API de ECF

****************************************************************************************************
static function pu_GetStatusECF( ECFNumSerie )
****************************************************************************************************
local aFunc, aFunc2, aFunc3, aFunc4, cCateg

local cXml       := ""
local cMsg       := ""
local hResponse  := {=>}
local cCodStatus := ""
local cDesStatus := ""
local cCodigo    := ""

sysrefresh()

cCodigo := pu_GetSerialNumber()

if empty(cCodigo)
   return .F.
endif

ECFNumSerie := alltrim(strtran(ECFNumSerie,chr(0),""))

aFunc  := { "ecf", "StatusECF", "omie_ecf_cadastro_chave" }
aFunc2 := { { "codigo", "string", cCodigo, 0 } }
aFunc4 := {"codigo_status"}
cCateg := "geral"

pu_EraseFile( aFunc[1] )

cria_xml_omie( cCateg, aFunc, aFunc2 )
                      
cXml := pu_EnviaXml( "https://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/", DIR_TEMP+"\"+aFunc[1]+".xml", DIR_TEMP+"\"+aFunc[1]+"_ret.xml", "", "",;
                      "https://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/?WSDL"+aFunc[2], "text/xml;charset=UTF-8", 0, pu_IsLog("WS") )

// <SOAP-ENV:Envelope SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://app.omie.com.br/api/v1/geral/ecf/?WSDL" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/">
//    <SOAP-ENV:Body>
//       <ns1:StatusECFResponse>
//          <omie_ecf_status xsi:type="ns1:omie_ecf_status">
//             <codigo xsi:type="xsd:string">DR0914BR000000410123</codigo>
//             <codigo_status xsi:type="xsd:string">1</codigo_status>
//             <descricao_status xsi:type="xsd:string">Impressora ECF ativada!</descricao_status>
//          </omie_ecf_status>
//       </ns1:StatusECFResponse>
//    </SOAP-ENV:Body>
// </SOAP-ENV:Envelope>

hResponse := pu_GetResponse( , cXml, "omie_ecf_status", .T., , .F. )

SaveFile( DIR_TEMP+"\"+"ecfomie.log", cXml )
SaveFile( DIR_TEMP+"\"+"ecfomie.log", valtoprg(hResponse) )

if hResponse["ok"]

   cCodStatus := pu_GetValueTag( hResponse["source"], { "omie_ecf_status", "codigo_status" }, "C" )
   cDesStatus := pu_GetValueTag( hResponse["source"], { "omie_ecf_status", "descricao_status" }, "C" )

   if cCodStatus <> "1"

      cMsg := "Ops! A sincronizaÁ„o com o aplicativo Omie foi interrompida!" + CRLF + ;
              "Motivo: " + cDesStatus              

      MsgInfo( cMsg, SYSTEM_NAME )
      
      return .F.

   endif

endif

if empty(cCodStatus)

   cMsg := "Ops! Nao foi possÌvel obter o status do OmiePDV no aplicativo Omie, entre em contato com o suporte."

   if hResponse["error"]
      cMsg += CRLF + "Motivo: " 
      cMsg += hResponse["msg"]
   endif

   MsgStop( cMsg, SYSTEM_NAME )
   
   return .F.

endif

return .T.

****************************************************************************************************************
function pu_UpsertECF( ECFNumSerie, cMarca, cModelo, nSerialHD )
****************************************************************************************************************
local aFunc, aFunc2, aFunc3, aFunc4, cCateg

local cXml       := ""
local cMsg       := ""
local hResponse  := {=>}
local cCodStatus := ""
local cDesStatus := ""

local cCodigo := ""

if empty(ECFNumSerie)
   return .F.
endif

cCodigo := pu_GetSerialNumber()

if empty(cCodigo)
   return .F.
endif

sysrefresh()

///////////////////////////////////////////////////////////////////////////////////////////////////

USE ( "INDICE.DBF" ) ALIAS _INDICE VIA "ADS" SHARED NEW

Key    := Alltrim(_INDICE->OmieKEY)
Secret := Alltrim(_INDICE->OmieSecret)

_INDICE->(dbclosearea())

///////////////////////////////////////////////////////////////////////////////////////////////////

ECFNumSerie := alltrim(strtran(ECFNumSerie,chr(0),""))
nSerialHD   := alltrim(str(abs(nSerialHD())))
cCodigo     := pu_GetSerialNumber()

aFunc  := { "ecf", "UpsertECF", "omie_ecf_cadastro" }

aFunc2 := { { "codigo",         "string", cCodigo,     0 }, ; 
            { "marca",          "string", cMarca,      0 }, ;
            { "modelo",         "string", cModelo,     0 }, ;
            { "serie",          "string", ECFNumSerie, 0 }, ;
            { "numero_maquina", "string", nSerialHD,   0 } }

aFunc4 := { "faultcode" }

cCateg := "geral"

pu_EraseFile( aFunc[1] )

cria_xml_omie( cCateg, aFunc, aFunc2 )

cXml := pu_EnviaXml( "http://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/", DIR_TEMP+"\"+aFunc[1]+".xml", DIR_TEMP+"\"+aFunc[1]+"_ret.xml", "", "",;
                      "http://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/?WSDL"+aFunc[2], "text/xml;charset=UTF-8", 0, pu_IsLog("WS") )

// <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://app.omie.com.br/api/v1/geral/ecf/?WSDL" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
//   <SOAP-ENV:Body>
//     <ns1:UpsertECFResponse>
//       <omie_ecf_status xsi:type="ns1:omie_ecf_status">
//         <codigo xsi:type="xsd:string">DR0914BR000000410123</codigo>
//         <codigo_status xsi:type="xsd:string">0</codigo_status>
//         <descricao_status xsi:type="xsd:string">ECF cadastrado com sucesso!</descricao_status>
//       </omie_ecf_status>
//     </ns1:UpsertECFResponse>
//   </SOAP-ENV:Body>
// </SOAP-ENV:Envelope>

hResponse := pu_GetResponse( , cXml, "omie_ecf_status", .T., , .F. )

SaveFile( DIR_TEMP+"\"+"ecfomie.log", cXml )
SaveFile( DIR_TEMP+"\"+"ecfomie.log", valtoprg(hResponse) )

if hResponse["ok"]

   cCodStatus := pu_GetValueTag( hResponse["source"], { "omie_ecf_status", "codigo_status" }, "C" )
   cDesStatus := pu_GetValueTag( hResponse["source"], { "omie_ecf_status", "descricao_status" }, "C" )

   if cCodStatus <> "0"

      cMsg := "Ops! A sincronizaÁ„o com o aplicativo Omie foi interrompida!" + CRLF + ;
              "Motivo: " + cDesStatus              

      MsgInfo( cMsg, SYSTEM_NAME )
      
      return .F.

   endif

endif

if empty(cCodStatus)

   cMsg := "Ops! Nao foi possÌvel obter o status do OmiePDV no aplicativo Omie, entre em contato com o suporte."

   if hResponse["error"]
      cMsg += CRLF + "Motivo: " 
      cMsg += hResponse["msg"]
   endif

   MsgStop( cMsg, SYSTEM_NAME )
   
   return .F.

endif

return .T.

// API de Produtos

****************************************************************************************************
static function pu_GetProdutos( lInicial, dDtStart )
****************************************************************************************************
local aFunc, aFunc2, aFunc3, aFunc4, cCateg

local cXml       := ""
local cMsg       := ""
local hResponse  := {=>}
local aAlerts    := {}
local hAlert     := {=>}

local nPagina    := 1
local nTotPag    := 1
local nReg       := 0

local aProdutos  := {}
local hProduto   := {=>}
local lRestart   := .F.

local nCodigo    := 0

local aAddProd   := {}
local aDelProd   := {}
local nRecnoX    := 0

local lSyncAll   := .F.

lSyncAll := pu_GetOmie( "SyncAll", "ADVANCED" ) == "true"

sysrefresh()

USE ( "ESTOQUE.DBF" ) ALIAS _ESTOQUE VIA "ADS" SHARED NEW
USE ( "NBM.DBF" )     ALIAS _NBM     VIA "ADS" SHARED NEW

begin sequence

   ////////////////////////////////////////////////////////////////////////////////////////////////

   // Obtem o prÛximo cÛdigo disponÌvel.

   setfilter( "_ESTOQUE", "CODIGO<>'XX-'" )

   _ESTOQUE->(DbSetOrder(1)) // CODIGO
   _ESTOQUE->(dbgotop())
   _ESTOQUE->(dbgobottom())

   if _ESTOQUE->(RecCount()) = 0
      nCodigo := 1
   else
      nCodigo := val(_ESTOQUE->CODIGO)+1
   endif

   if nCodigo=0
      nCodigo := 1
   endif

   ////////////////////////////////////////////////////////////////////////////////////////////////

   _NBM->(dbsetorder(1)) // NBM

   _ESTOQUE->(DbSetOrder(22)) // CODOMIE
   _ESTOQUE->(dbgotop())

   aFunc  := { "produtos", "ListarProdutos", "produto_servico_list_request" }

   pu_EraseFile( aFunc[1] )

   do while .t.

      sysrefresh()

      aFunc2 := { { "pagina",               "integer", alltrim(str(nPagina)), 0 }, ;
                  { "registros_por_pagina", "integer", "50",                  0 }, ;
                  { "apenas_importado_api", "string",  "N",                   0 }, ;
                  { "ordenar_por",          "string",  "CODIGO_PRODUTO",      0 }, ;
                  { "ordem_decrescente",    "string",  "N",                   0 }, ;
                  { "filtrar_por_data_de",  "date",    dtoc(dDtStart),        0 } }

      aFunc4 := { "faultcode" }

      cCateg := "geral"

      cria_xml_omie( cCateg, aFunc, aFunc2 )

      cXml := pu_EnviaXml( "http://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/", DIR_TEMP+"\"+aFunc[1]+".xml", DIR_TEMP+"\"+aFunc[1]+"_ret.xml", "", "",;
                            "http://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/?WSDL"+aFunc[2], "text/xml;charset=UTF-8", 0, pu_IsLog("WS") )

      fRename( DIR_TEMP+"\"+aFunc[1]+"_ret.xml", DIR_TEMP+"\"+aFunc[1]+"_ret"+strzero(nPagina,3)+".xml" )

      // <SOAP-ENV:Envelope SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://app.omie.com.br/api/v1/geral/produtos/?WSDL" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/">
      //    <SOAP-ENV:Body>
      //       <ns1:ListarProdutosResponse>
      //          <produto_servico_listfull_response xsi:type="ns1:produto_servico_listfull_response">
      //             <pagina xsi:type="xsd:integer">1</pagina>
      //             <total_de_paginas xsi:type="xsd:integer">1</total_de_paginas>
      //             <registros xsi:type="xsd:integer">1</registros>
      //             <total_de_registros xsi:type="xsd:integer">1</total_de_registros>
      //             <produto_servico_cadastro SOAP-ENC:arrayType="ns1:produto_servico_cadastro[1]" xsi:type="ns1:produto_servico_cadastroArray">
      //                <item xsi:type="ns1:produto_servico_cadastro">
      //                   <codigo_produto xsi:type="xsd:integer">2037060</codigo_produto>
      //                   <codigo_produto_integracao xsi:type="xsd:string"/>
      //                   <codigo xsi:type="xsd:string">PRD00001</codigo>
      //                   <descricao xsi:type="xsd:string">CHOCOLATE PRESTIGIO</descricao>
      //                   <ean xsi:type="xsd:string">054321223457</ean>
      //                   <ncm xsi:type="xsd:string">1806.31.10</ncm>
      //                   <unidade xsi:type="xsd:string">UN</unidade>
      //                   <valor_unitario xsi:type="xsd:decimal">2.5</valor_unitario>
      //                   <quantidade_estoque xsi:type="xsd:decimal">10</quantidade_estoque>
      //                   <aliquota_icms xsi:type="xsd:decimal">18</aliquota_icms>
      //                   <aliquota_ibpt xsi:type="xsd:decimal">Object</aliquota_ibpt>
      //                   <bloqueado xsi:type="xsd:string">N</bloqueado>
      //                   <importado_api xsi:type="xsd:string"/>
      //                </item>
      //             </produto_servico_cadastro>
      //          </produto_servico_listfull_response>
      //       </ns1:ListarProdutosResponse>
      //    </SOAP-ENV:Body>
      // </SOAP-ENV:Envelope>

      hResponse := pu_GetResponse( , cXml, "produto_servico_listfull_response", .T., , .F. )

      if hResponse["ok"]
    
         nPagina := val(pu_GetValueTag( hResponse["source"], { "produto_servico_listfull_response", "pagina" }, "C" ))
         nTotPag := val(pu_GetValueTag( hResponse["source"], { "produto_servico_listfull_response", "total_de_paginas" }, "C" ))
         nReg    := val(pu_GetValueTag( hResponse["source"], { "produto_servico_listfull_response", "registros" }, "C" ))

         if nPagina > 0 .and. nTotPag > 0 .and. nPagina <= nTotpag .and. nReg > 0

            aProdutos := pu_GetValueTag( hResponse["source"], { "produto_servico_listfull_response", "produto_servico_cadastro" }, "A" )

            if len(aProdutos) > 0

               for each hProduto in aProdutos
                  
                  if hHasKey(hProduto, "item") 
                     // Adiciona o produto na lista caso nao exista.
                     if pu_AddProduto( nCodigo, hProduto["item"], lInicial )
                        aadd( aAddProd, _ESTOQUE->CODIGO )
                        nCodigo += 1
                     else
                        if val(_ESTOQUE->CODIGO) > 0 
                           if len(aAddProd)=0 .or. aAddProd[len(aAddProd)]<>_ESTOQUE->CODIGO
                              aadd( aAddProd, _ESTOQUE->CODIGO )
                           endif
                        endif                        
                     endif
                  endif

               next 

            endif

         else

            // Recebeu os XML, mas quebrou no Omie, precisa interromper o processo.

            if lInicial

               cMsg := "Ops! Nao foi possÌvel obter os produtos cadastrados no aplicativo Omie." + CRLF +;
                       "No cadastro de produtos verifique se os Impostos Aprendidos foram configurados (AlÌq. ICMS, Subst.Tribut.)."

               MsgStop( cMsg, SYSTEM_NAME )

               lRestart := .T.
               
               BREAK

            endif

         endif

      else
         
         // <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
         //    <SOAP-ENV:Header>
         //       <Alerts>
         //          <omie_fail>
         //             <code>5094</code>
         //             <description>Nenhum registro foi encontrado!</description>
         //             <referer/>
         //             <fatal>false</fatal>
         //          </omie_fail>
         //       </Alerts>
         //    </SOAP-ENV:Header>
         //    <SOAP-ENV:Body>
         //       <SOAP-ENV:Fault>
         //          <faultcode>SOAP-ENV:Client-5113</faultcode>
         //          <faultstring>SOAP-ERROR: Nao existem registros para a p·gina [1]!</faultstring>
         //       </SOAP-ENV:Fault>
         //    </SOAP-ENV:Body>
         // </SOAP-ENV:Envelope>

         if lInicial

            if hResponse["warn"] .and. len(hResponse["omie_fail"]) > 0

               for each hAlert in hResponse["omie_fail"]
                  
                  if hAlert["description"] == "Nenhum registro foi encontrado!"

                     cMsg := "Ops! Nao foi possÌvel obter os produtos cadastrados no aplicativo Omie." + CRLF +;
                             "No cadastro de produtos verifique se os Impostos Aprendidos foram configurados (AlÌq. ICMS, Subst.Tribut.)."
                        
                     msginfo( cMsg, SYSTEM_NAME )
                     
                     lRestart := .T.

                     BREAK

                  endif 

               next 
               
            endif
         
            if hResponse["error"] .and. !lRestart

               cMsg := "Ops! Ocorreu um erro ao tentar obter os produtos cadastrados no aplicativo Omie." + CRLF +;
                       "Motivo: "+ hResponse["msg"] + CRLF +;
                       "SoluÁao: No cadastro de produtos, verifique os Impostos Aprendidos (AlÌq.ICMS, Subst.Trib., CST PIS e COFINS)."
               MsgStop( cMsg, SYSTEM_NAME )

               lRestart := .T.
               
               BREAK

            endif

         endif

         EXIT

      endif

      if nPagina >= nTotPag
         exit
      endif

      nPagina += 1

   enddo

end sequence

_ESTOQUE->(dbcommit())
_ESTOQUE->(dbunlock())

_NBM->(dbcommit())
_NBM->(dbunlock())

/////////////////////////////////////////////////////////////////////////////////////////
// Rotina de exclus o de usu>rios antigos.

if len(aAddProd) > 0 .and. lSyncAll 
 
   aDelProd := {}

   _ESTOQUE->(dbGoTop())

   do while !_ESTOQUE->(eof())

      if left(_ESTOQUE->CODIGO,3)<>'XX-'

         if ascan( aAddProd, _ESTOQUE->CODIGO ) = 0
            LogFile( "omie\deleted.log", { "PRODUTO -->", _ESTOQUE->CODIGO, _ESTOQUE->CODOMIE, _ESTOQUE->BARRA2, _ESTOQUE->DESCRICAO } )
            aadd( aDelProd, _ESTOQUE->(RecNo()) )
         endif         

      endif

      _ESTOQUE->(dbSkip())
   
   enddo

   if len(aDelProd)>0

      for each nRecnoX in aDelProd
         _ESTOQUE->(dbGoTo(nRecnoX))
         _ESTOQUE->(dbDelete())
      next

   endif

endif

/////////////////////////////////////////////////////////////////////////////////////////

_ESTOQUE->(dbclosearea())
_NBM->(dbclosearea())

pu_Restart( lRestart )

return .T.

// <item xsi:type="ns1:produto_servico_cadastro">
//    <codigo_produto xsi:type="xsd:integer">7646512</codigo_produto>
//    <codigo_produto_integracao xsi:type="xsd:string"/>
//    <codigo xsi:type="xsd:string">1000</codigo>
//    <descricao xsi:type="xsd:string">Mouse sem fio Microsoft</descricao>
//    <ean xsi:type="xsd:string"/>
//    <ncm xsi:type="xsd:string">9504.10.99</ncm>
//    <unidade xsi:type="xsd:string">UN</unidade>
//    <valor_unitario xsi:type="xsd:decimal">150</valor_unitario>
//    <quantidade_estoque xsi:type="xsd:decimal">10</quantidade_estoque>
//    <aliquota_icms xsi:type="xsd:decimal">97</aliquota_icms>
//    <aliquota_ibpt xsi:type="xsd:decimal">Object</aliquota_ibpt>
//    <cst_pis xsi:type="xsd:string"></cst_pis>
//    <cst_cofins xsi:type="xsd:string"></cst_cofins>
//    <bloqueado xsi:type="xsd:string"/>
//    <importado_api xsi:type="xsd:string"/>
// </item>

****************************************************************************************************
static function pu_AddProduto( nCodigo, hProduto, lInicial )
****************************************************************************************************
local lNew := .F.
local hIbpt := {=>}
local cUnd  := ""

if !pu_hasTag( hProduto, "codigo_produto" )
   return lNew
endif

if !pu_hasTag( hProduto, "descricao" )
   return lNew
endif

hProduto["codigo_produto"] := strzero(val(hProduto["codigo_produto"]),20)

if lInicial
   lNew := .T.
else
   if !_ESTOQUE->( dbseek( hProduto["codigo_produto"] ) )
      lNew := .T.
   endif
endif

if lNew
   _ESTOQUE->(dbappend())
   _ESTOQUE->CODIGO  := strzero(nCodigo,7)
   _ESTOQUE->CODOMIE := hProduto["codigo_produto"]
endif

if pu_hasTag( hProduto, "codigo" )
   _ESTOQUE->BARRA2 := left(hProduto["codigo"],20)
endif

if pu_hasTag( hProduto, "descricao" )
   _ESTOQUE->DESCRICAO := upper(pu_SemAcento(left(pu_Xml2Html(hProduto["descricao"]),150)))
endif

if pu_hasTag( hProduto, "ean" )
   _ESTOQUE->BARRA := left(hProduto["ean"],20)
else
   if hHasKey(hProduto, "ean")
      _ESTOQUE->BARRA := ""
   endif
endif

if pu_hasTag( hProduto, "ncm" )
   _ESTOQUE->NBM := left(alltrim(strtran(hProduto["ncm"],".","")),8)
endif

if pu_hasTag( hProduto, "unidade" )
  
   cUnd := alltrim(left(upper(hProduto["unidade"]),10))

   if len(cUnd)=1
      do case
      case cUnd=="G" ; cUnd += "R"  // GR - Grama
      case cUnd=="L" ; cUnd += "T"  // LT - Litro
      case cUnd=="M" ; cUnd += "T"  // MT - Metro
      case cUnd=="T" ; cUnd += "N"  // TN - Tonelada
      otherwise      ; cUnd += "X"  // XX - Outros nao especificados no Omie atÈ 21/09/2015.
      endcase
   endif

   _ESTOQUE->UNIDADE := cUnd

endif

if pu_hasTag( hProduto, "valor_unitario" )
   _ESTOQUE->PRECO := val(hProduto["valor_unitario"])
endif

if pu_hasTag( hProduto, "quantidade_estoque" )
   _ESTOQUE->QUANTIDADE := val(hProduto["quantidade_estoque"])
endif

if pu_hasTag( hProduto, "cst_icms" )
   if hProduto["cst_icms"] == "20"
      if pu_hasTag( hProduto, "aliquota_icms" ) .and. pu_hasTag( hProduto, "red_base_icms" )
         _ESTOQUE->P_ALIQREDU := val(hProduto["aliquota_icms"]) * val(hProduto["red_base_icms"]) / 100
      endif
   endif  
endif

if pu_hasTag( hProduto, "aliquota_icms" )
   _ESTOQUE->ICM := val(hProduto["aliquota_icms"])
endif

if pu_hasTag( hProduto, "red_base_icms" )
   _ESTOQUE->P_REDUICMS := val(hProduto["red_base_icms"])
endif

//////////////////////////////////////////////////////////////////////////////////////////////

if hHasKey( hProduto, "dadosIbpt" )

   hIbpt := hProduto["dadosIbpt"]

   if valtype(hIbpt)="H" .and. len(hIbpt) > 0

      if !empty(_ESTOQUE->NBM)

         if pu_hasTag( hIbpt, "aliqFederal" )
            hIbpt["aliqFederal"] := val(hIbpt["aliqFederal"])
         else
            hIbpt["aliqFederal"] := 0
         endif

         if pu_hasTag( hIbpt, "aliqEstadual" )
            hIbpt["aliqEstadual"] := val(hIbpt["aliqEstadual"])
         else
            hIbpt["aliqEstadual"] := 0
         endif

         if pu_hasTag( hIbpt, "aliqMunicipal" )
            hIbpt["aliqMunicipal"] := val(hIbpt["aliqMunicipal"])
         else
            hIbpt["aliqMunicipal"] := 0
         endif

         if !_NBM->(dbseek(_ESTOQUE->NBM))
            _NBM->(dbappend())
            _NBM->NBM       := _ESTOQUE->NBM
            _NBM->ALIQNAC   := hIbpt["aliqFederal"]
            _NBM->ESTADUAL  := hIbpt["aliqEstadual"] 
            _NBM->MUNICIPAL := hIbpt["aliqMunicipal"]
         else
            if _NBM->ALIQNAC <> hIbpt["aliqFederal"]
               _NBM->ALIQNAC := hIbpt["aliqFederal"]    
            endif
            if _NBM->ESTADUAL <> hIbpt["aliqEstadual"] 
               _NBM->ESTADUAL := hIbpt["aliqEstadual"]
            endif
            if _NBM->MUNICIPAL <> hIbpt["aliqMunicipal"]
               _NBM->MUNICIPAL := hIbpt["aliqMunicipal"]
            endif
         endif

      endif

   endif

endif

//////////////////////////////////////////////////////////////////////////////////////////////

if pu_hasTag( hProduto, "cst_pis" )
   _ESTOQUE->CSTPISSAI := hProduto["cst_pis"]
endif

if pu_hasTag( hProduto, "aliquota_pis" )
   // _ESTOQUE-> := val(hProduto["aliquota_pis"])
endif

if pu_hasTag( hProduto, "cst_cofins" )
   _ESTOQUE->CSTCOFSAI := hProduto["cst_cofins"]
endif

if pu_hasTag( hProduto, "aliquota_cofins" )
   // _ESTOQUE-> := val(hProduto["aliquota_cofins"])
endif

if pu_hasTag( hProduto, "bloqueado" )
   _ESTOQUE->DESATIVADO := hProduto["bloqueado"]=="S"
endif

if pu_hasTag( hProduto, "cest" )
   _ESTOQUE->CEST := left(pu_OnlyNumber(hProduto["cest"]),9)
endif

_ESTOQUE->DTALTERA := date()

return lNew

// API de Clientes

****************************************************************************************************
static function pu_GetClientes( lInicial, dDtStart )
****************************************************************************************************
local aFunc, aFunc2, aFunc3, aFunc4, cCateg

local cXml       := ""
local cMsg       := ""
local hResponse  := {=>}
local aAlerts    := {}
local hAlert     := {=>}

local nPagina    := 1
local nTotPag    := 1
local nReg       := 0

local aClientes  := {}
local hCliente   := {=>}
local lRestart   := .F.

local nCodigo    := 0
local hItem      := {=>}

local aAddCliente := {}
local aDelCliente := {}
local nRecnoX     := 0

local lSyncAll   := .F.

sysrefresh()

lSyncAll := pu_GetOmie( "SyncAll", "ADVANCED" ) == "true"

if lInicial
   USE ( "CLIENTES.DBF" ) ALIAS _CLIENTES VIA "ADS" EXCLUSIVE NEW
else
   USE ( "CLIENTES.DBF" ) ALIAS _CLIENTES VIA "ADS" SHARED NEW
endif

USE ( "INDICE.DBF" )   ALIAS _INDICE   VIA "ADS" SHARED NEW

begin sequence

   if lInicial
      _CLIENTES->(dbzap())
      nCodigo := 1
   else
      nCodigo := _INDICE->ULTCLI + 1
   endif
   
   _CLIENTES->(DbSetOrder(22)) // CODOMIE

   aFunc := { "clientes", "ListarClientes", "clientes_list_request" }

   pu_EraseFile( aFunc[1] )

   do while .t.

      sysrefresh()

      aFunc2  := { {"pagina",               "integer", alltrim(str(nPagina)), 0 }, ;
                   {"registros_por_pagina", "integer", "50",                  0 }, ;
                   {"apenas_importado_api", "string",  "N",                   0 }, ;
                   {"ordenar_por",          "string",  "CODIGO_CLIENTE",      0 }, ;
                   {"ordem_decrescente",    "string",  "N",                   0 }, ;
                   {"filtrar_por_data_de",  "date",    dtoc(dDtStart),        0 } }

      aFunc4  := {"faultcode"}

      cCateg  := "geral"

      cria_xml_omie( cCateg, aFunc, aFunc2 )

      cXml := pu_EnviaXml( "http://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/", DIR_TEMP+"\"+aFunc[1]+".xml", DIR_TEMP+"\"+aFunc[1]+"_ret.xml", "", "",;
                            "http://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/?WSDL"+aFunc[2], "text/xml;charset=UTF-8", 0, pu_IsLog("WS") )

      fRename( DIR_TEMP+"\"+aFunc[1]+"_ret.xml", DIR_TEMP+"\"+aFunc[1]+"_ret"+strzero(nPagina,3)+".xml" )
      
      // <SOAP-ENV:Envelope SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://app.omie.com.br/api/v1/geral/clientes/?WSDL" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/">
      //    <SOAP-ENV:Body>
      //       <ns1:ListarClientesResponse>
      //          <clientes_listfull_response xsi:type="ns1:clientes_listfull_response">
      //             <pagina xsi:type="xsd:integer">1</pagina>
      //             <total_de_paginas xsi:type="xsd:integer">1</total_de_paginas>
      //             <registros xsi:type="xsd:integer">1</registros>
      //             <total_de_registros xsi:type="xsd:integer">1</total_de_registros>
      //             <clientes_cadastro SOAP-ENC:arrayType="ns1:clientes_cadastro[1]" xsi:type="ns1:clientes_cadastroArray">
      //                <item xsi:type="ns1:clientes_cadastro">
      //                   <codigo_cliente_omie xsi:type="xsd:integer">6706059</codigo_cliente_omie>
      //                   <codigo_cliente_integracao xsi:type="xsd:string"/>
      //                   <cnpj_cpf xsi:type="xsd:string">02.655.842/0002-98</cnpj_cpf>
      //                   <razao_social xsi:type="xsd:string">GABIVEL VEICULOS LTDA</razao_social>
      //                   <nome_fantasia xsi:type="xsd:string">GABIVEL VEICULOS LTDA</nome_fantasia>
      //                   <logradouro xsi:type="xsd:string"/>
      //                   <endereco xsi:type="xsd:string">AV PREFEITO WALDEMAR GRUBBA</endereco>
      //                   <endereco_numero xsi:type="xsd:string">2120</endereco_numero>
      //                   <complemento xsi:type="xsd:string">.</complemento>
      //                   <bairro xsi:type="xsd:string">VILA LALAU</bairro>
      //                   <cidade xsi:type="xsd:string">JARAGUA DO SUL &amp;#x28;SC&amp;#x29;</cidade>
      //                   <estado xsi:type="xsd:string">SC</estado>
      //                   <cep xsi:type="xsd:string">89256501</cep>
      //                   <codigo_pais xsi:type="xsd:string">1058</codigo_pais>
      //                   <contato xsi:type="xsd:string">.</contato>
      //                   <telefone1_ddd xsi:type="xsd:string">47</telefone1_ddd>
      //                   <telefone1_numero xsi:type="xsd:string">431-5700</telefone1_numero>
      //                   <telefone2_ddd xsi:type="xsd:string"/>
      //                   <telefone2_numero xsi:type="xsd:string"/>
      //                   <fax_ddd xsi:type="xsd:string"/>
      //                   <fax_numero xsi:type="xsd:string"/>
      //                   <email xsi:type="xsd:string">luciano@omie.com.br</email>
      //                   <homepage xsi:type="xsd:string"/>
      //                   <observacao xsi:type="xsd:string"/>
      //                   <inscricao_municipal xsi:type="xsd:string"/>
      //                   <inscricao_estadual xsi:type="xsd:string">isento</inscricao_estadual>
      //                   <inscricao_suframa xsi:type="xsd:string"/>
      //                   <pessoa_fisica xsi:type="xsd:string">N</pessoa_fisica>
      //                   <optante_simples_nacional xsi:type="xsd:string"/>
      //                   <bloqueado xsi:type="xsd:string">N</bloqueado>
      //                   <importado_api xsi:type="xsd:string"/>
      //                </item>
      //             </clientes_cadastro>
      //          </clientes_listfull_response>
      //       </ns1:ListarClientesResponse>
      //    </SOAP-ENV:Body>
      // </SOAP-ENV:Envelope>

      // pu_GetResponse( cFileXml, cXml, cTagName, lUtf8toLatin1, lLatin1toUtf8, lAttrib )

      hResponse := pu_GetResponse( , cXml, "clientes_listfull_response", .T., , .F. )

      if hResponse["ok"]
    
         nPagina := val(pu_GetValueTag( hResponse["source"], { "clientes_listfull_response", "pagina" }, "C" ))
         nTotPag := val(pu_GetValueTag( hResponse["source"], { "clientes_listfull_response", "total_de_paginas" }, "C" ))
         nReg    := val(pu_GetValueTag( hResponse["source"], { "clientes_listfull_response", "registros" }, "C" ))

         if nPagina > 0 .and. nTotPag > 0 .and. nPagina <= nTotpag .and. nReg > 0

            aClientes := pu_GetValueTag( hResponse["source"], { "clientes_listfull_response", "clientes_cadastro" }, "A" )

            if len(aClientes) > 0

               for each hCliente in aClientes
                  
                  if hHasKey(hCliente, "item") 
                     // Adiciona o produto na lista caso nao exista.
                     if pu_AddCliente( nCodigo, hCliente["item"], lInicial )
                        aadd( aAddCliente, _CLIENTES->CODIGO )
                        nCodigo += 1
                     else
                        if _CLIENTES->CODIGO > 0 
                           if len(aAddCliente)=0 .or. aAddCliente[len(aAddCliente)]<>_CLIENTES->CODIGO
                              aadd( aAddCliente, _CLIENTES->CODIGO )
                           endif
                        endif                       
                     endif
                  endif

               next 

            endif
 
         else

            // Recebeu os XML, mas quebrou no Omie, precisa interromper o processo. 
            // Se o provisionamento foi realizado, pelo menos o cliente consumidor existe.

            if lInicial

               cMsg := "Ops! Nao foi possÌvel obter os clientes cadastrados no aplicativo Omie." + CRLF +;
                       "Acesse o cadastro de clientes e verifique se algum cliente foi cadastrado!"

               MsgStop( cMsg, SYSTEM_NAME )

               lRestart := .T.
               
               BREAK

            endif

         endif

      else
         
         // <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
         //    <SOAP-ENV:Header>
         //       <Alerts>
         //          <omie_fail>
         //             <code>5094</code>
         //             <description>Nenhum registro foi encontrado!</description>
         //             <referer/>
         //             <fatal>false</fatal>
         //          </omie_fail>
         //       </Alerts>
         //    </SOAP-ENV:Header>
         //    <SOAP-ENV:Body>
         //       <SOAP-ENV:Fault>
         //          <faultcode>SOAP-ENV:Client-5113</faultcode>
         //          <faultstring>SOAP-ERROR: Nao existem registros para a p·gina [1]!</faultstring>
         //       </SOAP-ENV:Fault>
         //    </SOAP-ENV:Body>
         // </SOAP-ENV:Envelope>

         if lInicial

            if hResponse["warn"] .and. len(hResponse["omie_fail"]) > 0

               for each hAlert in hResponse["omie_fail"]
                  
                  if hAlert["description"] == "Nenhum registro foi encontrado!"

                     cMsg := "Ops! Nao foi possÌvel obter os clientes cadastrados no aplicativo Omie." + CRLF +;
                             "Acesse o cadastro de clientes e verifique se algum cliente foi cadastrado!"
                        
                     msginfo( cMsg, SYSTEM_NAME )
                     
                     lRestart := .T.

                     BREAK

                  endif 

               next 
               
            endif
         
            if hResponse["error"] .and. !lRestart

               cMsg := "Ops! Ocorreu um erro ao tentar obter os clientes cadastrados no aplicativo Omie." + CRLF +;
                       "Motivo: " + hResponse["msg"]
               
               MsgStop( cMsg, SYSTEM_NAME )

               lRestart := .T.
               
               BREAK

            endif

         endif

         EXIT

      endif

      if nPagina >= nTotPag
         exit
      endif

      nPagina += 1

   enddo

end sequence

INDICE->ULTCLI := nCodigo

_CLIENTES->(dbcommit())
_CLIENTES->(dbunlock())

/////////////////////////////////////////////////////////////////////////////////////////
// Rotina de exclus o de usu>rios antigos.

if len(aAddCliente) > 0 .and. lSyncAll
 
   aDelCliente := {}

   _CLIENTES->(dbGoTop())

   do while !_CLIENTES->(eof())

      if ascan( aAddCliente, _CLIENTES->CODIGO ) = 0
         LogFile( "omie\deleted.log", { "CLIENTE -->", _CLIENTES->CODIGO, _CLIENTES->CODOMIE, _CLIENTES->CIC, _CLIENTES->RAZAO } )
         aadd( aDelCliente, _CLIENTES->(RecNo()) )
      endif         

      _CLIENTES->(dbSkip())
   
   enddo

   if len(aDelCliente)>0

      for each nRecnoX in aDelCliente
         _CLIENTES->(dbGoTo(nRecnoX))
         _CLIENTES->(dbDelete())
      next

   endif

endif

/////////////////////////////////////////////////////////////////////////////////////////

_CLIENTES->(dbclosearea())
_INDICE->(dbclosearea())

pu_Restart( lRestart )

return .T.

// <item xsi:type="ns1:clientes_cadastro">
//    <codigo_cliente_omie xsi:type="xsd:integer">6706059</codigo_cliente_omie>
//    <codigo_cliente_integracao xsi:type="xsd:string"/>
//    <cnpj_cpf xsi:type="xsd:string">02.655.842/0002-98</cnpj_cpf>
//    <razao_social xsi:type="xsd:string">GABIVEL VEICULOS LTDA</razao_social>
//    <nome_fantasia xsi:type="xsd:string">GABIVEL VEICULOS LTDA</nome_fantasia>
//    <logradouro xsi:type="xsd:string"/>
//    <endereco xsi:type="xsd:string">AV PREFEITO WALDEMAR GRUBBA</endereco>
//    <endereco_numero xsi:type="xsd:string">2120</endereco_numero>
//    <complemento xsi:type="xsd:string">.</complemento>
//    <bairro xsi:type="xsd:string">VILA LALAU</bairro>
//    <cidade xsi:type="xsd:string">JARAGUA DO SUL &amp;#x28;SC&amp;#x29;</cidade>
//    <estado xsi:type="xsd:string">SC</estado>
//    <cep xsi:type="xsd:string">89256501</cep>
//    <codigo_pais xsi:type="xsd:string">1058</codigo_pais>
//    <contato xsi:type="xsd:string">.</contato>
//    <telefone1_ddd xsi:type="xsd:string">47</telefone1_ddd>
//    <telefone1_numero xsi:type="xsd:string">431-5700</telefone1_numero>
//    <telefone2_ddd xsi:type="xsd:string"/>
//    <telefone2_numero xsi:type="xsd:string"/>
//    <fax_ddd xsi:type="xsd:string"/>
//    <fax_numero xsi:type="xsd:string"/>
//    <email xsi:type="xsd:string">luciano@omie.com.br</email>
//    <homepage xsi:type="xsd:string"/>
//    <observacao xsi:type="xsd:string"/>
//    <inscricao_municipal xsi:type="xsd:string"/>
//    <inscricao_estadual xsi:type="xsd:string">isento</inscricao_estadual>
//    <inscricao_suframa xsi:type="xsd:string"/>
//    <pessoa_fisica xsi:type="xsd:string">N</pessoa_fisica>
//    <optante_simples_nacional xsi:type="xsd:string"/>
//    <bloqueado xsi:type="xsd:string">N</bloqueado>
//    <importado_api xsi:type="xsd:string"/>
// </item>

****************************************************************************************************
static function pu_AddCliente( nCodigo, hCliente, lInicial )
****************************************************************************************************
local lNew   := .F.
local nPos   := 0
local cCampo := ""
local lCnpj  := .F.

if !pu_hasTag( hCliente, "codigo_cliente_omie" )
   return lNew
endif

if !pu_hasTag( hCliente, "razao_social" )
   return lNew
endif

hCliente["codigo_cliente_omie"] := strzero(val(hCliente["codigo_cliente_omie"]),20)

if lInicial
   lNew := .T.
else
   
   if _CLIENTES->(IndexOrd()) <> 22 
      _CLIENTES->(dbsetorder(22)) // CODOMIE
   endif

   if !_CLIENTES->( dbseek( hCliente["codigo_cliente_omie"] ) )

      if pu_hasTag( hCliente, "cnpj_cpf" ) 

         _CLIENTES->(dbsetorder(8)) // CNPJ

         if !_CLIENTES->(dbseek( pu_OnlyNumber(hCliente["cnpj_cpf"]) ))
            lNew := .T.
         else
            lCnpj := .T.
         endif

         _CLIENTES->(dbsetorder(22)) // CODOMIE

      else
         lNew := .T.
      endif

   endif

endif

if lNew

   _CLIENTES->(dbappend())
   _CLIENTES->CODIGO  := nCodigo
   _CLIENTES->CODOMIE := hCliente["codigo_cliente_omie"]

else

   if lCnpj .and. empty(_CLIENTES->CODOMIE) .and. !empty(hCliente["codigo_cliente_omie"])
       _CLIENTES->CODOMIE := hCliente["codigo_cliente_omie"]
   endif

endif

if pu_hasTag( hCliente, "cnpj_cpf" )
   _CLIENTES->CIC := left(pu_OnlyNumber(hCliente["cnpj_cpf"]),18)
endif

if pu_hasTag( hCliente, "razao_social" )
   _CLIENTES->RAZAO := upper(left(pu_Xml2Html(hCliente["razao_social"]),70))
endif

if pu_hasTag( hCliente, "nome_fantasia" )
   _CLIENTES->NOME := upper(left(pu_Xml2Html(hCliente["nome_fantasia"]),54))
endif

if pu_hasTag( hCliente, "endereco" )
   _CLIENTES->ENDERECO := upper(left(pu_Xml2Html(hCliente["endereco"]),70))
endif

if pu_hasTag( hCliente, "endereco_numero" )
   _CLIENTES->NUMERO := val(left(alltrim(hCliente["endereco_numero"]),5))
endif

if pu_hasTag( hCliente, "complemento" )
   _CLIENTES->COMPLEMENT := upper(left(pu_Xml2Html(hCliente["complemento"]),40))
endif

if pu_hasTag( hCliente, "bairro" )
   _CLIENTES->BAIRRO := upper(left(pu_Xml2Html(hCliente["bairro"]),35))
endif

if pu_hasTag( hCliente, "cidade" )
   cCampo := upper(left(pu_Xml2Html(hCliente["cidade"]),35))
   nPos   := at( "(", cCampo)
   if nPos > 0
      cCampo := substr(cCampo,1,nPos-1)
   endif  
   _CLIENTES->CIDADE := cCampo
endif

if pu_hasTag( hCliente, "estado" )
   _CLIENTES->ESTADO := transform( alltrim(upper(pu_Xml2Html(hCliente["estado"]))), "@R X.X" )
endif

if pu_hasTag( hCliente, "cep" )
   _CLIENTES->CEP := left(hCliente["cep"],10)
endif

if pu_hasTag( hCliente, "telefone1_ddd" )
   _CLIENTES->DDD := left(hCliente["telefone1_ddd"],2)
endif

if pu_hasTag( hCliente, "telefone1_numero" )
   _CLIENTES->TELEFONE := left(hCliente["telefone1_numero"],18)
endif

if pu_hasTag( hCliente, "telefone2_numero" )
   _CLIENTES->TELEF2 := left(hCliente["telefone2_numero"],18)
endif

if pu_hasTag( hCliente, "email" )
   _CLIENTES->EMAIL := left(pu_Xml2Html(hCliente["email"]),100)
endif

if pu_hasTag( hCliente, "observacao" )
   _CLIENTES->OBS := left(pu_Xml2Html(hCliente["observacao"]),160)
endif

if pu_hasTag( hCliente, "inscricao_municipal" )
   _CLIENTES->INSCR_MUN := left(hCliente["inscricao_municipal"],10)
endif

if pu_hasTag( hCliente, "inscricao_estadual" )
   _CLIENTES->RG := left(hCliente["inscricao_estadual"],10)
else
   _CLIENTES->RG := "ISENTO" 
endif

_CLIENTES->DATA_ALT := date()
_CLIENTES->OMIE     := .F.

return lNew

// API de Usu·rios

****************************************************************************************************
static function pu_GetUsuarios( lInicial )
****************************************************************************************************
local aFunc, aFunc2, aFunc3, aFunc4, cCateg

local cXml       := ""
local cMsg       := ""
local hResponse  := {=>}

local aUsuarios  := {}
local hUsuario   := {=>}
local lRestart   := .F.

local nCodigo    := 0
local aAddUser   := {}
local aDelUser   := {}
local nRecnoX    := 0

sysrefresh()

if lInicial
   USE ( "CADASTRO.DBF" ) ALIAS _CADASTRO VIA "ADS" EXCLUSIVE NEW
else
   USE ( "CADASTRO.DBF" ) ALIAS _CADASTRO VIA "ADS" SHARED NEW
endif

begin sequence

   ////////////////////////////////////////////////////////////////////////////////////////////////

   if lInicial
      _CADASTRO->(dbzap())
      nCodigo := 1
   else
      _CADASTRO->(dbsetorder(2))  // CODIGO 
      _CADASTRO->(dbgobottom())
      nCodigo := _CADASTRO->CODIGO + 1
   endif
   
   _CADASTRO->(dbsetorder(4))  // SN 

   ////////////////////////////////////////////////////////////////////////////////////////////////

   aFunc  := { "users", "ListAll", "users_listall_request" }

   pu_EraseFile( aFunc[1] )

   sysrefresh()

   aFunc2 := { { "key", "string", "e67706937ce9213c876a7b503bbbaafe", 0 } }

   aFunc4 := {"faultcode"}

   cCateg := "partner"

   cria_xml_omie( cCateg, aFunc, aFunc2 )

   cXml := pu_EnviaXml( "http://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/", DIR_TEMP+"\"+aFunc[1]+".xml", DIR_TEMP+"\"+aFunc[1]+"_ret.xml", "", "",;
                         "http://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/?WSDL"+aFunc[2], "text/xml;charset=UTF-8", 0, pu_IsLog("WS") )

   // <SOAP-ENV:Envelope SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://app.omie.com.br/api/v1/partner/users/?WSDL" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
   //    <SOAP-ENV:Body>
   //       <ns1:ListAllResponse>
   //          <users_listall_response xsi:type="ns1:users_listall_response">
   //             <users_data SOAP-ENC:arrayType="ns1:users_data[8]" xsi:type="ns1:users_dataArray">
   //                <item xsi:type="ns1:users_data">
   //                   <UserId xsi:type="xsd:integer">4858</UserId>
   //                   <email xsi:type="xsd:string">luciano@omie.com.br</email>
   //                   <code xsi:type="xsd:string">P000004858</code>
   //                   <name xsi:type="xsd:string">LUCIANO PEREIRA</name>
   //                   <nickname xsi:type="xsd:string">Luciano</nickname>
   //                   <password xsi:type="xsd:string">052b5664650941fae16cbf55aa2be0a6</password>
   //                </item>
   //                <item xsi:type="ns1:users_data">
   //                   <UserId xsi:type="xsd:integer">792</UserId>
   //                   <email xsi:type="xsd:string">ajuda@omie.com.br</email>
   //                   <code xsi:type="xsd:string">P000000792</code>
   //                   <name xsi:type="xsd:string">AJUDA OMIE</name>
   //                   <nickname xsi:type="xsd:string">Ajuda</nickname>
   //                   <password xsi:type="xsd:string">cb9272ac9a226524690219784f87704c</password>
   //                </item>
   //             </users_data>
   //          </users_listall_response>
   //       </ns1:ListAllResponse>
   //    </SOAP-ENV:Body>
   // </SOAP-ENV:Envelope>

   hResponse := pu_GetResponse( , cXml, "users_listall_response", .T., , .F. )

   if hResponse["ok"]
 
      aUsuarios := pu_GetValueTag( hResponse["source"], { "users_listall_response", "users_data" }, "A" )

      if len(aUsuarios) > 0

         for each hUsuario in aUsuarios
            
            if hHasKey(hUsuario, "item") 
               // Adiciona o produto na lista caso nao exista.
               if pu_AddUsuario( nCodigo, hUsuario["item"], lInicial )
                  aadd( aAddUser, _CADASTRO->CODIGO )
                  nCodigo += 1
               else
                  if _CADASTRO->CODIGO > 0 
                     if len(aAddUser)=0 .or. aAddUser[len(aAddUser)]<>_CADASTRO->CODIGO
                        aadd( aAddUser, _CADASTRO->CODIGO )
                     endif
                  endif
               endif
            endif

         next 

      else

         if lInicial

            cMsg := "Ops! Ocorreu um erro ao tentar obter os usu·rios cadastrados no aplicativo Omie." + CRLF +;
                    "Motivo: "+ hResponse["msg"]
            
            msginfo( cMsg, SYSTEM_NAME )

            lRestart := .T.
            
            BREAK

         endif

      endif

   else
      
      // <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
      //    <SOAP-ENV:Body>
      //       <SOAP-ENV:Fault>
      //          <faultcode>SOAP-ENV:Client-4044</faultcode>
      //          <faultstring>SOAP-ERROR: [KEY] inv·lida!</faultstring>
      //       </SOAP-ENV:Fault>
      //    </SOAP-ENV:Body>
      // </SOAP-ENV:Envelope>

      if lInicial

         if hResponse["error"] 

            cMsg := "Ops! Ocorreu um erro ao tentar obter os usu·rios cadastrados no aplicativo Omie." + CRLF +;
                    "Motivo: " + hResponse["msg"]
            
            MsgStop( cMsg, SYSTEM_NAME )

            lRestart := .T.
            
            BREAK

         endif

      endif

   endif

end sequence

_CADASTRO->(dbcommit())
_CADASTRO->(dbunlock())

/////////////////////////////////////////////////////////////////////////////////////////
// Rotina de exclusao de usu·rios antigos.

if len(aAddUser) > 0
 
   aDelUser := {}

   _CADASTRO->(dbGoTop())

   do while !_CADASTRO->(eof())

      if ascan( aAddUser, _CADASTRO->CODIGO ) = 0
         LogFile( "omie\deleted.log", { "USUARIO -->", _CADASTRO->CODIGO, alltrim(_CADASTRO->EMAIL), alltrim(_CADASTRO->OBS), alltrim(_CADASTRO->NOME) } )
         aadd( aDelUser, _CADASTRO->(RecNo()) )
      endif         

      _CADASTRO->(dbSkip())
   
   enddo

   if len(aDelUser)>0

      for each nRecnoX in aDelUser
         _CADASTRO->(dbGoTo(nRecnoX))
         _CADASTRO->(dbDelete())
      next

   endif

endif

/////////////////////////////////////////////////////////////////////////////////////////

_CADASTRO->(dbclosearea())

pu_Restart( lRestart )

return .T.

// <item xsi:type="ns1:users_data">
//    <UserId xsi:type="xsd:integer">4858</UserId>
//    <email xsi:type="xsd:string">luciano@omie.com.br</email>
//    <code xsi:type="xsd:string">P000004858</code>
//    <name xsi:type="xsd:string">LUCIANO PEREIRA</name>
//    <nickname xsi:type="xsd:string">Luciano</nickname>
//    <password xsi:type="xsd:string">052b5664650941fae16cbf55aa2be0a6</password>
// </item>

// API de Usu·rios

****************************************************************************************************
static function pu_AddUsuario( nCodigo, hUsuario, lInicial )
****************************************************************************************************
local lNew := .F.

if !pu_hasTag( hUsuario, "code" )
   return lNew
endif

hUsuario["code"] := left(hUsuario["code"]+space(15),15)

if lInicial
   lNew := .T.
else
   if !_CADASTRO->( dbseek( hUsuario["code"] ) )
      lNew := .T.
   endif
endif

if lNew
   _CADASTRO->(dbappend())
   _CADASTRO->CODIGO := nCodigo
   _CADASTRO->SN     := left(hUsuario["code"],15)
endif

if pu_hasTag( hUsuario, "email" )
   _CADASTRO->EMAIL := left(hUsuario["email"],100)
endif

if pu_hasTag( hUsuario, "name" )
   _CADASTRO->NOME := left(hUsuario["name"],54)
endif

if pu_hasTag( hUsuario, "nickname" )
   _CADASTRO->OBS := left(hUsuario["nickname"],54)
endif

if pu_hasTag( hUsuario, "password" )
   _CADASTRO->DIGITAL := left(hUsuario["password"],500)
endif

if pu_hasTag( hUsuario, "role" )
   _CADASTRO->TIPO := val(hUsuario["role"])
endif

return lNew

// API de Contas Correntes (Cartoes de CrÈdito)

****************************************************************************************************
static function pu_GetContas( lInicial )
****************************************************************************************************
local aFunc, aFunc2, aFunc3, aFunc4, cCateg

local cXml       := ""
local cMsg       := ""
local hResponse  := {=>}
local aAlerts    := {}
local hAlert     := {=>}

local nPagina    := 1
local nTotPag    := 1
local nReg       := 0

local aContas    := {}
local hConta     := {=>}
local lRestart   := .F.

local nCodigo    := 0
local lFecha     := .F.

local aAddConta  := {}
local aDelConta  := {}
local nRecnoX    := 0
local aRet       := {}

sysrefresh()

if lInicial
   USE ( "CARTAO.DBF" ) ALIAS _CARTAO VIA "ADS" EXCLUSIVE NEW
else
   USE ( "CARTAO.DBF" ) ALIAS _CARTAO VIA "ADS" SHARED NEW
endif

if !EmUso("indice")
   USE INDICE NEW
   lFecha := .T.
endif

begin sequence

   _CARTAO->(DbSetOrder(1)) // CODIGO

   if lInicial
      _CARTAO->(dbzap())
      nCodigo := 1
   else
      _CARTAO->(dbGoTop())
      if _CARTAO->(eof())
         nCodigo := 1
      else
         _CARTAO->(dbgobottom())
         nCodigo := _CARTAO->CODIGO + 1
      endif
   endif

   aFunc := { "contacorrente", "PesquisarContaCorrente", "fin_conta_corrente_pesquisar" }
   
   pu_EraseFile( aFunc[1] )
   
   do while .t.

      sysrefresh()

      aFunc2 := { { "codigo",            "integer", "0", 0 }, ;
                  { "codigo_integracao", "string",  "0", 0 } }

      aFunc4 := { "faultcode"}

      cCateg := "geral"

      cria_xml_omie( cCateg, aFunc, aFunc2 )

      cXml := pu_EnviaXml( "http://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/", DIR_TEMP+"\"+aFunc[1]+".xml", DIR_TEMP+"\"+aFunc[1]+"_ret.xml", "", "",;
                            "http://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/?WSDL"+aFunc[2], "text/xml;charset=UTF-8", 0, pu_IsLog("WS") )

      fRename( DIR_TEMP+"\"+aFunc[1]+"_ret.xml", DIR_TEMP+"\"+aFunc[1]+"_ret"+strzero(nPagina,3)+".xml" )
      
      // <SOAP-ENV:Envelope SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://app.omie.com.br/api/v1/geral/contacorrente/?WSDL" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/">
      //    <SOAP-ENV:Body>
      //       <ns1:PesquisarContaCorrenteResponse>
      //          <fin_conta_corrente_pesquisar_resposta xsi:type="ns1:fin_conta_corrente_pesquisar_resposta">
      //             <pagina xsi:type="xsd:integer">0</pagina>
      //             <total_de_paginas xsi:type="xsd:integer">0</total_de_paginas>
      //             <registros xsi:type="xsd:integer">0</registros>
      //             <total_de_registros xsi:type="xsd:integer">0</total_de_registros>
      //             <conta_corrente_lista SOAP-ENC:arrayType="ns1:conta_corrente_lista[15]" xsi:type="ns1:conta_corrente_listaArray">
      //                <item xsi:type="ns1:conta_corrente_lista">
      //                   <nCodCC xsi:type="xsd:integer">1208238</nCodCC>
      //                   <cCodCCInt xsi:type="xsd:string"></cCodCCInt>
      //                   <descricao xsi:type="xsd:string">Caixinha</descricao>
      //                   <codigo_banco xsi:type="xsd:string">999</codigo_banco>
      //                   <codigo_agencia xsi:type="xsd:string"></codigo_agencia>
      //                   <conta_corrente xsi:type="xsd:string"></conta_corrente>
      //                   <nome_gerente xsi:type="xsd:string"></nome_gerente>
      //                   <tipo xsi:type="xsd:string">CX</tipo>
      //                   <tipo_comunicacao xsi:type="xsd:string"></tipo_comunicacao>
      //                   <cSincrAnalitica xsi:type="xsd:string"></cSincrAnalitica>
      //                   <nTpTef xsi:type="xsd:integer">0</nTpTef>
      //                   <nTaxaAdm xsi:type="xsd:decimal">0</nTaxaAdm>
      //                   <nDiasVenc xsi:type="xsd:integer">0</nDiasVenc>
      //                   <nNumParc xsi:type="xsd:integer">0</nNumParc>
      //                   <nCodAdm xsi:type="xsd:integer">0</nCodAdm>
      //                </0909item>
      //             </conta_corrente_lista>
      //          </fin_conta_corrente_pesquisar_resposta>
      //       </ns1:PesquisarContaCorrenteResponse>
      //    </SOAP-ENV:Body>
      // </SOAP-ENV:Envelope>      

      hResponse := pu_GetResponse( , cXml, "fin_conta_corrente_pesquisar_resposta", .T., , .F. )

      if hResponse["ok"]
    
         nPagina := val(pu_GetValueTag( hResponse["source"], { "fin_conta_corrente_pesquisar_resposta", "pagina" }, "C" ))
         nTotPag := val(pu_GetValueTag( hResponse["source"], { "fin_conta_corrente_pesquisar_resposta", "total_de_paginas" }, "C" ))
         nReg    := val(pu_GetValueTag( hResponse["source"], { "fin_conta_corrente_pesquisar_resposta", "registros" }, "C" ))

         if nPagina > 0 .and. nTotPag > 0 .and. nPagina <= nTotpag .and. nReg > 0

            aContas := pu_GetValueTag( hResponse["source"], { "fin_conta_corrente_pesquisar_resposta", "conta_corrente_lista" }, "A" )

            if len(aContas) > 0

               for each hConta in aContas

                  if hHasKey(hConta, "item") 
                     // Adiciona a Conta Corrente na lista caso nao exista.

                     aRet := pu_AddConta( nCodigo, hConta["item"], lInicial )

                     if aRet[1]
                        aadd( aAddConta, nCodigo )
                        nCodigo += 1
                     else
                        if aRet[2] > 0 
                           if len(aAddConta)=0 .or. aAddConta[len(aAddConta)]<>aRet[2]
                              aadd( aAddConta, aRet[2] )
                           endif
                        endif                        
                     endif
                  endif

               next 

            endif
 
         else

            // Recebeu os XML, mas quebrou no Omie, precisa interromper o processo. 
            // Se o provisionamento foi realizado, pelo a conta Caixinha deve existir.

            if lInicial

               cMsg := "Ops! Nao foi possÌvel obter as contas correntes cadastradas no aplicativo Omie." + CRLF +;
                       "Acesse o cadastro de contas correntes e verifique se foram cadastradas!"

               msginfo( cMsg, SYSTEM_NAME )

               lRestart := .T.
               
               BREAK

            endif

         endif

      else
         
         // <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
         //    <SOAP-ENV:Body>
         //       <SOAP-ENV:Fault>
         //          <faultcode>SOAP-ENV:Client-96</faultcode>
         //          <faultstring>SOAP-ERROR: AutenticaÁao negada! APP_KEY=1560731700 APP_SECRET=x226dcf372489bb45ceede61bfd98f0f1</faultstring>
         //       </SOAP-ENV:Fault>
         //    </SOAP-ENV:Body>
         // </SOAP-ENV:Envelope>

         if lInicial

            if hResponse["error"]

               cMsg := "Ops! Ocorreu um erro ao tentar obter as contas correntes cadastradas no aplicativo Omie." + CRLF +;
                       "Motivo: " + hResponse["msg"]
               
               MsgStop( cMsg, SYSTEM_NAME )

               lRestart := .T.
               
               BREAK

            endif

         endif

         EXIT

      endif

      if nPagina >= nTotPag
         exit
      endif

      nPagina += 1

   enddo

end sequence

_CARTAO->(dbcommit())
_CARTAO->(dbunlock())

/////////////////////////////////////////////////////////////////////////////////////////
// Rotina de exclusao de cartoes antigos.

if len(aAddConta) > 0
 
   aDelConta := {}

   _CARTAO->(dbGoTop())

   do while !_CARTAO->(eof())

      if ascan( aAddConta, _CARTAO->CODIGO ) = 0
         LogFile( "omie\deleted.log", { "CARTAO -->", _CARTAO->CODIGO, alltrim(_CARTAO->CODOMIE), alltrim(_CARTAO->DESCRICAO) } )
         aadd( aDelConta, _CARTAO->(RecNo()) )
      endif         

      _CARTAO->(dbSkip())
   
   enddo

   if len(aDelConta)>0

      for each nRecnoX in aDelConta
         _CARTAO->(dbGoTo(nRecnoX))
         _CARTAO->CODIGO := 999
         _CARTAO->(dbDelete())
      next

   endif

endif

/////////////////////////////////////////////////////////////////////////////////////////

_CARTAO->(dbclosearea())

if lFecha
   INDICE->(dbclosearea())
endif

pu_Restart( lRestart )

return .T.

// <item xsi:type="ns1:conta_corrente_lista">
//    <nCodCC xsi:type="xsd:integer">1208238</nCodCC>
//    <cCodCCInt xsi:type="xsd:string"></cCodCCInt>
//    <descricao xsi:type="xsd:string">Caixinha</descricao>
//    <codigo_banco xsi:type="xsd:string">999</codigo_banco>
//    <codigo_agencia xsi:type="xsd:string"></codigo_agencia>
//    <conta_corrente xsi:type="xsd:string"></conta_corrente>
//    <nome_gerente xsi:type="xsd:string"></nome_gerente>
//    <tipo xsi:type="xsd:string">CX</tipo>
//    <tipo_comunicacao xsi:type="xsd:string"></tipo_comunicacao>
//    <cSincrAnalitica xsi:type="xsd:string"></cSincrAnalitica>
//    <nTpTef xsi:type="xsd:integer">0</nTpTef>
//    <nTaxaAdm xsi:type="xsd:decimal">0</nTaxaAdm>
//    <nDiasVenc xsi:type="xsd:integer">0</nDiasVenc>
//    <nNumParc xsi:type="xsd:integer">0</nNumParc>
//    <nCodAdm xsi:type="xsd:integer">0</nCodAdm>
// </item>

****************************************************************************************************
static function pu_AddConta( nCodigo, hConta, lInicial )
****************************************************************************************************
local lNew := .F.
local xCodigo := 0

if !pu_hasTag( hConta, "nCodCC" )
   return { lNew, xCodigo }
endif

if !pu_hasTag( hConta, "tipo" )
   return { lNew, xCodigo }
else
   if !( hConta["tipo"] IN { "AC", "CN", "CX" } )
      return { lNew, xCodigo }
   endif
endif

do case
case hConta["tipo"] == "AC" // CARTAO

   hConta["nCodCC"] := strzero(val(hConta["nCodCC"]),20)

   if lInicial
      lNew := .T.
   else

      lNew := .T.
   
      _CARTAO->(dbgotop())

      do while !_CARTAO->(eof())

         if !empty(_CARTAO->CODOMIE)
            if alltrim(_CARTAO->CODOMIE) == hConta["nCodCC"]
               xCodigo := _CARTAO->CODIGO
               lNew := .F.
               EXIT
            endif
         endif
         _CARTAO->(DbSkip())
      enddo

   endif

   if lNew
      _CARTAO->(dbappend())
      _CARTAO->CODIGO  := nCodigo
      _CARTAO->CODOMIE := hConta["nCodCC"]
   endif

   if pu_hasTag( hConta, "descricao" )
      _CARTAO->DESCRICAO := left(hConta["descricao"],20)
   endif

   if pu_hasTag( hConta, "codigo_banco" )
      _CARTAO->BANCO := left(hConta["codigo_banco"],3)
   endif

   if pu_hasTag( hConta, "nTpTef" )
      _CARTAO->TRANS := val(hConta["nTpTef"])
   else
      _CARTAO->TRANS := 1
   endif

   if pu_hasTag( hConta, "nNumParc" )
      if val(hConta["nNumParc"]) >= 1 .and. val(hConta["nNumParc"]) <= 12
         _CARTAO->PARCELA := left(hConta["nNumParc"]+"x",3)         
      endif
   endif

   if pu_hasTag( hConta, "nDiasVenc" )
      _CARTAO->PRAZO := val(hConta["nDiasVenc"])
   endif

   _CARTAO->DESCONTO := .T.
   _CARTAO->PROMOCAO := .T.

case hConta["tipo"] == "CN" // A PRAZO

   INDICE->OMIEBANCO := hConta["nCodCC"]
   INDICE->(DbUnlock())

case hConta["tipo"] == "CX" // A VISTA

   INDICE->OMIECX := hConta["nCodCC"]
   INDICE->(DbUnlock())

endcase

return { lNew, xCodigo }

// Ajuste no Suprimento.

****************************************************************************************************
static function pu_GetSuprimentos( lInicial )
****************************************************************************************************

if !lInicial
   return .F.
endif

sysrefresh()

USE ( "MOTIVO.DBF" ) ALIAS _MOTIVO VIA "ADS" EXCLUSIVE NEW

_MOTIVO->(dbzap())

_MOTIVO->(DbAppend())
_MOTIVO->codigo := 1
_MOTIVO->motivo := "SANGRIA"
_MOTIVO->tipo   := "D"

_MOTIVO->(DbAppend())
_MOTIVO->codigo := 2
_MOTIVO->motivo := "SUPRIMENTO"
_MOTIVO->tipo   := "C"

_MOTIVO->(dbcommit())
_MOTIVO->(dbunlock())

_MOTIVO->(dbclosearea())

return .T.

****************************************************************************************************************
function pu_EnviarClientes( lInicial )
****************************************************************************************************************
local aFunc, aFunc2, aFunc3, aFunc4, cCateg, nCount

local hResponse  := {=>}
local cCodStatus := ""
local cDesStatus := ""
local nTimes     := 0

local cMsg       := ""
local cXml       := ""
local aRecnos    := {}
local nRecnoX    := 0

local hCliente   := {=>}
local aRecAlt    := {}

if lInicial
   return .F.
endif

sysrefresh()

USE ( "CLIENTES.DBF" ) ALIAS _CLIENTES VIA "ADS" SHARED NEW

do while .t.

   setfilter( "_CLIENTES", "omie" )

   _CLIENTES->(dbgotop())

   if _CLIENTES->(eof())
      
      exit
   
   else

      aFunc  := { "clientes", "UpsertClientesPorLote", "clientes_lote_request" }
     
      aFunc4 := { "codigo_status" }
     
      cCateg := "geral"
      
      nCount := 0
      
      aFunc3  := {}
      
      aRecnos := {}
      aRecAlt := {}

      do while !_CLIENTES->(eof())

         sysrefresh()

         if empty(_CLIENTES->CODOMIE)

            // Html2Xml

            hCliente := {=>}
            hCliente["ID_CLI"]     := if(!empty(_CLIENTES->CODOMIE),pu_TagValue(val(_CLIENTES->CODOMIE)),"")
            hCliente["CODINT"]     := if(empty(_CLIENTES->CODOMIE),pu_OnlyNumber(_CLIENTES->CIC),"") 
            hCliente["CIC"]        := pu_CNPJ(_CLIENTES->CIC)
            hCliente["RAZAO"]      := pu_TagValue(pu_SemAcento(_CLIENTES->RAZAO))
            hCliente["NOME"]       := pu_TagValue(pu_SemAcento(_CLIENTES->NOME))
            hCliente["ENDERECO"]   := pu_TagValue(pu_SemAcento(_CLIENTES->ENDERECO))
            hCliente["NUMERO"]     := pu_TagValue(_CLIENTES->NUMERO)
            hCliente["COMPLEMENT"] := pu_TagValue(pu_SemAcento(_CLIENTES->COMPLEMENT))
            hCliente["BAIRRO"]     := pu_TagValue(pu_SemAcento(_CLIENTES->BAIRRO))
            hCliente["CIDADE"]     := iif(!Empty(_CLIENTES->CIDADE),Upper(Alltrim(_CLIENTES->CIDADE))+" ("+alltrim(RemoveCaracter(_CLIENTES->ESTADO))+")","") 
            hCliente["ESTADO"]     := alltrim(RemoveCaracter(_CLIENTES->ESTADO))
            hCliente["CEP"]        := pu_TagValue(pu_OnlyNumber(_CLIENTES->CEP))
            hCliente["DDD"]        := pu_TagValue(pu_OnlyNumber(_CLIENTES->DDD))
            hCliente["TELEFONE"]   := left(pu_TagValue(pu_OnlyNumber(_CLIENTES->TELEFONE)),15)
            hCliente["EMAIL"]      := Html2Xml(_CLIENTES->EMAIL)
            hCliente["OBS"]        := pu_SemAcento("IncluÌdo/Alterado a partir da integraÁao com OmiePDV.")

            if empty(hCliente["RAZAO"]) .and. !empty(hCliente["NOME"])
               hCliente["RAZAO"] := hCliente["NOME"]
            endif

            AADD(aFunc3,{ { "codigo_cliente_omie",       "integer", hCliente["ID_CLI"]     },;
                          { "codigo_cliente_integracao", "string",  hCliente["CODINT"]     },;
                          { "cnpj_cpf",                  "string",  hCliente["CIC"]        },;
                          { "razao_social",              "string",  hCliente["RAZAO"]      },;
                          { "nome_fantasia",             "string",  hCliente["NOME"]       },;
                          { "endereco",                  "string",  hCliente["ENDERECO"]   },;
                          { "endereco_numero",           "string",  hCliente["NUMERO"]     },;
                          { "complemento",               "string",  hCliente["COMPLEMENT"] },;
                          { "bairro",                    "string",  hCliente["BAIRRO"]     },;
                          { "cidade",                    "string",  hCliente["CIDADE"]     },;
                          { "estado",                    "string",  hCliente["ESTADO"]     },;
                          { "cep",                       "string",  hCliente["CEP"]        },;
                          { "telefone1_ddd",             "string",  hCliente["DDD"]        },;
                          { "telefone1_numero",          "string",  hCliente["TELEFONE"]   },;
                          { "email",                     "string",  hCliente["EMAIL"]      },;
                          { "observacao",                "string",  hCliente["OBS"]        } } )

            nCount++

            aadd( aRecnos, _CLIENTES->(RecNo()) )

         else

            aadd( aRecAlt, _CLIENTES->(RecNo()) )

         endif

         if len(aRecnos) = 20
            exit
         endif

         _CLIENTES->(dbskip())

      enddo

      ////////////////////////////////////////////////////////////////////////////////////////
      
      // Ajusta os alterados.

      if len(aRecAlt) > 0

         for each nRecnoX in aRecAlt

            _CLIENTES->(dbgoto(nRecnoX))

            sysrefresh()

            _CLIENTES->OMIE := .F. 
       
         next

      endif

      ////////////////////////////////////////////////////////////////////////////////////////

      if len(aRecnos) = 0
         exit
      endif

      nTimes += 1

      if nTimes > 30
         exit
      endif

      aFunc2 := { { "lote",             "integer", alltrim(str(nCount)), 0 }, ;
                  {"clientes_cadastro", "Array",   alltrim(str(nCount)), 1 } }
      
      cria_xml_omie( cCateg, aFunc, aFunc2, aFunc3 )

      cXml := pu_EnviaXml( "https://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/", DIR_TEMP+"\"+aFunc[1]+".xml", DIR_TEMP+"\"+aFunc[1]+"_ret.xml", "", "",;
                            "https://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/?WSDL"+aFunc[2], "text/xml;charset=UTF-8", 0, pu_IsLog("WS") )

      // <SOAP-ENV:Envelope SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://app.omie.com.br/api/v1/geral/clientes/?WSDL" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/">
      //    <SOAP-ENV:Header>
      //       <Alerts>
      //          <omie_fail>
      //             <code>4075</code>
      //             <description>Cidade [S?O PAULO (SP)] nao cadastrada!</description>
      //             <referer>CLIENTESCADASTRO.UpsertClientesPorLote.clientes_cadastro.cidade</referer>
      //             <fatal>false</fatal>
      //          </omie_fail>
      //          <omie_fail>
      //             <code>7526689</code>
      //             <description>Cliente cadastrado com sucesso!</description>
      //             <referer>LUA125</referer>
      //             <fatal>false</fatal>
      //          </omie_fail>
      //       </Alerts>
      //    </SOAP-ENV:Header>
      //    <SOAP-ENV:Body>
      //       <ns1:UpsertClientesPorLoteResponse>
      //          <clientes_lote_response xsi:type="ns1:clientes_lote_response">
      //             <lote xsi:type="xsd:integer">100</lote>
      //             <codigo_status xsi:type="xsd:string">0</codigo_status>
      //             <descricao_status xsi:type="xsd:string">Ok!</descricao_status>
      //          </clientes_lote_response>
      //       </ns1:UpsertClientesPorLoteResponse>
      //    </SOAP-ENV:Body>
      // </SOAP-ENV:Envelope>

      hResponse := pu_GetResponse( , cXml, "clientes_lote_response", .T., , .F. )

      if hResponse["ok"]
    
         cCodStatus := pu_GetValueTag( hResponse["source"], { "clientes_lote_response", "codigo_status" }, "C" )
         cDesStatus := pu_GetValueTag( hResponse["source"], { "clientes_lote_response", "descricao_status" }, "C" )

         if cCodStatus == "0"

            for each nRecnoX in aRecnos

               _CLIENTES->(dbgoto(nRecnoX))

               sysrefresh()

               _CLIENTES->OMIE := .F. 
          
            next

         else

            cMsg := "Ops! Nao foi possÌvel enviar os clientes cadastrados no OmiePDV para o aplicativo Omie." + CRLF +;
                    "Motivo: " + cCodStatus + " - " + cDesStatus

            msginfo( cMsg, SYSTEM_NAME )

            exit

         endif

      else
         
         // <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
         //    <SOAP-ENV:Body>
         //       <SOAP-ENV:Fault>
         //          <faultcode>SOAP-ENV:Client-10</faultcode>
         //          <faultstring>SOAP-ERROR: Aplicativo desativado!</faultstring>
         //       </SOAP-ENV:Fault>
         //    </SOAP-ENV:Body>
         // </SOAP-ENV:Envelope>

         if hResponse["error"] 

            cMsg := "Ops! Ocorreu um erro ao tentar enviar os clientes cadastrados no OmiePDV para o aplicativo Omie." + CRLF +;
                    "Motivo: " + hResponse["msg"]
            
            MsgStop( cMsg, SYSTEM_NAME )

            exit

         endif

      endif

   endif

   setfilter( "_CLIENTES", "" )

   _CLIENTES->(dbcommit())
   _CLIENTES->(dbunlock())

enddo

_CLIENTES->(dbclosearea())

return .T.

****************************************************************************************************
static function pu_CNPJ( cDoc )
****************************************************************************************************

if !empty(cDoc)

   cDoc := pu_OnlyNumber(cDoc)

   if Len( cDoc ) >= 14
      cDoc := transform( substr( cDoc, 1, 14 ), "@R 99.999.999/9999-99" )
   else
      cDoc := transform( cDoc, "@R 999.999.999-99" )
   endif      

endif
   
return alltrim(cDoc)

****************************************************************************************************
**
** API de Fechamento de Caixa.
**
****************************************************************************************************

****************************************************************************************************
static function pu_CreateTables()
****************************************************************************************************

local aStruct := {}

local cTable := ""

local CUPOM
local COO
local ENVIADO
local MODELO
local LOTE

/////////////////////////////////////////////////////////////////////////////////////////////////////
cTable := "omie_pend"

if !file(cTable+".DBF")

   aStruct := { { "CAIXA"    , "N",  5, 0 }, ;
                { "MODELO"   , "C",  2, 0 }, ;
                { "CUPOM"    , "N",  5, 0 }, ; // _SATFISCAL->CUPOM                
                { "COO"      , "N",  6, 0 }, ; // _NFCCAB->NNF
                { "ENVIADO"  , "C",  1, 0 }, ;
                { "ACAO"     , "C",  3, 0 }, ;
                { "DTENV"    , "D",  8, 0 }, ;
                { "HRENV"    , "C",  8, 0 }, ;
                { "DTINC"    , "D",  8, 0 }, ;
                { "HRINC"    , "C",  8, 0 } }
   
   DbCreate( cTable, aStruct, "ADS" )

endif

if !file(cTable+".CDX")

   DbUseArea( .T., "ADS", "OMIE_PEND.DBF", "_OMIEPEND", .F. )

   INDEX ON CUPOM   TAG OMIEPEND1   

   INDEX ON COO     TAG OMIEPEND2     

   INDEX ON ENVIADO TAG OMIEPEND3

   INDEX ON ENVIADO+MODELO+str(CUPOM,5) TAG OMIEPEND4   

   _OMIEPEND->(dbclosearea())

endif

/////////////////////////////////////////////////////////////////////////////////////////////////////

cTable := "omie_lote"

if !file(cTable+".DBF")

   aStruct := { { "LOTE"     , "N", 15, 0 }, ;
                { "CAIXA"    , "N",  5, 0 }, ;
                { "ACAO"     , "C",  3, 0 }, ;
                { "FECHADO"  , "C",  1, 0 }, ;
                { "DTINC"    , "D",  8, 0 }, ;
                { "HRINC"    , "C",  8, 0 }, ;
                { "CUPONS"   , "N",  5, 0 }, ;
                { "VALOR"    , "N", 12, 2 }, ;
                { "ARQUIVO"  , "M", 10, 0 }, ;
                { "VERSAO"   , "C",  5, 0 }, ;
                { "CODSTAT"  , "C",  5, 0 }, ;
                { "HDSERIAL" , "C", 20, 0 }, ;
                { "DESSTAT"  , "C",300, 0 } }
   
   DbCreate( cTable, aStruct, "ADS" )

endif

if !file(cTable+".CDX")

   DbUseArea( .T., "ADS", "OMIE_LOTE.DBF", "_OMIELOTE", .F. )

   INDEX ON LOTE    TAG OMIELOTE1  

   _OMIELOTE->(dbclosearea())

endif

/////////////////////////////////////////////////////////////////////////////////////////////////////

cTable := "omie_cupom"

if !file(cTable+".DBF")

   aStruct := { { "LOTE"     , "N", 15, 0 }, ;
                { "MODELO"   , "C",  2, 0 }, ;
                { "CUPOM"    , "N",  5, 0 }, ; // _SATFISCAL->CUPOM                
                { "COO"      , "N",  6, 0 }, ; // _NFCCAB->NNF
                { "VALOR"    , "N", 12, 2 }, ;
                { "ACAO"     , "C",  3, 0 } }
   
   DbCreate( cTable, aStruct, "ADS" )

endif

if !file(cTable+".CDX")

   DbUseArea( .T., "ADS", "OMIE_CUPOM.DBF", "_OMIECUPOM", .F. )

   INDEX ON LOTE + CUPOM TAG OMIECUPOM1  

   INDEX ON CUPOM   TAG OMIECUPOM2 

   INDEX ON COO     TAG OMIECUPOM3     

   _OMIECUPOM->(dbclosearea())

endif

/////////////////////////////////////////////////////////////////////////////////////////////////////

return NIL

****************************************************************************************************
static function pu_AddLogLote( hLote, nCupons, nValor, cFile )
****************************************************************************************************

_OMIELOTE->(dbappend())
_OMIELOTE->LOTE     := hLote["LOTE"]
_OMIELOTE->CAIXA    := hLote["CAIXA"]
_OMIELOTE->ACAO     := hLote["ACAO"]
_OMIELOTE->FECHADO  := hLote["FECHADO"]
_OMIELOTE->VERSAO   := left(hLote["VERSAO"],5)
_OMIELOTE->HDSERIAL := left(hLote["HDSERIAL"],20)
_OMIELOTE->DTINC    := date()
_OMIELOTE->HRINC    := time()
_OMIELOTE->CUPONS   := nCupons
_OMIELOTE->VALOR    := nValor
_OMIELOTE->ARQUIVO  := cFile
_OMIELOTE->CODSTAT  := "999"
_OMIELOTE->DESSTAT  := "Lote nao enviado!"
_OMIELOTE->(dbUnLock())

return NIL

****************************************************************************************************
static function pu_UpdLogLote( hLote, cCod, cDes )
****************************************************************************************************

_OMIELOTE->(dbSetOrder(1)) // LOTE

if _OMIELOTE->(dbSeek( hLote["LOTE"] ))
   _OMIELOTE->CODSTAT  := left(cCod,5)
   _OMIELOTE->DESSTAT  := left(cDes,300)
   _OMIELOTE->(dbUnLock())
endif

return NIL

****************************************************************************************************
static function pu_AddLogCupom( hCupom )
****************************************************************************************************

_OMIECUPOM->(dbappend())
_OMIECUPOM->LOTE      := hCupom["LOTE"]
_OMIECUPOM->MODELO    := hCupom["MODELO"]
_OMIECUPOM->CUPOM     := hCupom["NUM_VENDA"]
_OMIECUPOM->COO       := hCupom["NUM_COO"]
_OMIECUPOM->VALOR     := hCupom["VALOR_TOT"]
_OMIECUPOM->ACAO      := hCupom["ACAO"]
_OMIECUPOM->(dbUnLock())

return NIL

****************************************************************************************************
static function pu_AddPendencia( nCaixa, cModelo, nCupom, nCOO, cAcao )
****************************************************************************************************

_OMIEPEND->(dbSetOrder(4)) // ENVIADO + MODELO + CUPOM

if !_OMIEPEND->(dbSeek( "N" + cModelo + str(nCupom,5) ))

   _OMIEPEND->(dbappend())
   _OMIEPEND->CAIXA    := nCaixa
   _OMIEPEND->MODELO   := cModelo
   _OMIEPEND->CUPOM    := nCupom
   _OMIEPEND->COO      := nCOO
   _OMIEPEND->ENVIADO  := "N"
   _OMIEPEND->ACAO     := cAcao
   _OMIEPEND->DTINC    := date()
   _OMIEPEND->HRINC    := time()
   // _OMIEPEND->DTENV := 
   // _OMIEPEND->HRENV := 
   _OMIEPEND->(dbUnLock())

endif

return NIL

****************************************************************************************************
static function pu_VerPendencias()
****************************************************************************************************

_CUPOM->(dbSetOrder(8))     // COO
setfilter( "_CUPOM", "" )

_NFCCAB->(dbSetOrder(3))    // NNF

///////////////////////////////////////////////////////////////////////

// NFC-e Cancelada

setfilter( "_NFCCAB", "CANCELADA AND !OMIE_CANC" )

_NFCCAB->(dbGoTop())

do while !_NFCCAB->(eof())
   if _CUPOM->(dbSeek( val(_NFCCAB->NNF) ))
      pu_AddPendencia( _CUPOM->CX, "65", _CUPOM->CUPOM, _CUPOM->COO, "CAN" )
   endif
   _NFCCAB->(dbSkip())
enddo

setfilter( "_NFCCAB", "" )

///////////////////////////////////////////////////////////////////////

// NFC-e Inutilizada

setfilter( "_NFCCAB", "INUTILIZA AND !OMIE_INUT" )

_NFCCAB->(dbGoTop())

do while !_NFCCAB->(eof())
   if _CUPOM->(dbSeek( val(_NFCCAB->NNF) ))
      pu_AddPendencia( _CUPOM->CX, "65", _CUPOM->CUPOM, _CUPOM->COO, "INU" )
   endif
   _NFCCAB->(dbSkip())
enddo

setfilter( "_NFCCAB", "" )

///////////////////////////////////////////////////////////////////////

// NFC-e emitida em contingencia e que foi enviada posteriormente

setfilter( "_NFCCAB", "!CONTINGENC AND OMIE_CONT" )

_NFCCAB->(dbGoTop())

do while !_NFCCAB->(eof())
   if _CUPOM->(dbSeek( val(_NFCCAB->NNF) ))
      pu_AddPendencia( _CUPOM->CX, "65", _CUPOM->CUPOM, _CUPOM->COO, "CTG" )
   endif
   _NFCCAB->(dbSkip())
enddo

setfilter( "_NFCCAB", "" )

///////////////////////////////////////////////////////////////////////

_CUPOM->(dbSetOrder(2))     // CUPOM
_SATFISCAL->(dbSetOrder(2)) // CUPOM

setfilter( "_SATFISCAL", "CANCELADA AND !OMIE_CANC" )

_SATFISCAL->(dbGoTop())

do while !_SATFISCAL->(eof())
   if _CUPOM->(dbSeek( _SATFISCAL->CUPOM ))
      pu_AddPendencia( _CUPOM->CX, "59", _CUPOM->CUPOM, _CUPOM->COO, "CAN" )
   endif
   _SATFISCAL->(dbSkip())
enddo

setfilter( "_SATFISCAL", "" )

///////////////////////////////////////////////////////////////////////

return NIL

****************************************************************************************************
static function pu_FecharCaixa( cPath, cPathNF, cPDV )
****************************************************************************************************
//local PU_PASSWORD := "_SysFarNew"

local aCupons := {}
local cReport := ""
local cRepAnt := ""
local nVezes  := 0
local nPos    := 0
local cAmb    := ""
local hLote   := {=>}

default cPath   := ""
default cPathNF := curdrive() + ":\" + CurDir() + "\" 
default cPDV    := ""

if val(cPDV) = 0
   cPDV := pu_GetECFNum()["cod"]
endif

sysrefresh()

SET DELETED OFF

pu_CreateTables()

//////////////////////////////////////////////////////////////////////////////
// Abre os arquivos.

USE ("CUPOM.DBF")     ALIAS _CUPOM     VIA "ADS" SHARED NEW
USE ("ESTAT.DBF")     ALIAS _ESTAT     VIA "ADS" SHARED NEW
USE ("CARTAO.DBF")    ALIAS _CARTAO    VIA "ADS" SHARED NEW
USE ("ESTOQUE.DBF")   ALIAS _ESTOQUE   VIA "ADS" SHARED NEW
USE ("CLIENTES.DBF")  ALIAS _CLIENTE   VIA "ADS" SHARED NEW
USE ("INDICE.DBF")    ALIAS _INDICE    VIA "ADS" SHARED NEW
USE ("DEBCART.DBF")   ALIAS _DEBCART   VIA "ADS" SHARED NEW
// USE ("NFCCAB.DBF")    ALIAS _NFCCAB    VIA "ADS" SHARED NEW
USE ("SATFISCAL.DBF") ALIAS _SATFISCAL VIA "ADS" SHARED NEW
USE ("SATITENS.DBF")  ALIAS _SATITENS  VIA "ADS" SHARED NEW
USE ("DADOS.DBF")     ALIAS _DADOS     VIA "ADS" SHARED NEW
USE ("CHEQUES.DBF")   ALIAS _CHEQUES   VIA "ADS" SHARED NEW
USE ("CAIXA.DBF")     ALIAS _CAIXA     VIA "ADS" SHARED NEW
USE ("CADASTRO.DBF")  ALIAS _CADASTRO  VIA "ADS" SHARED NEW
//USE ("OMIE_PEND.DBF") ALIAS _OMIEPEND  VIA "ADS" SHARED NEW

DbUseArea( .T., "ADS", "NFCCAB.DBF",     "_NFCCAB",    .T. )
DbUseArea( .T., "ADS", "OMIE_PEND.DBF",  "_OMIEPEND",  .T. )
DbUseArea( .T., "ADS", "OMIE_LOTE.DBF",  "_OMIELOTE",  .T. )
DbUseArea( .T., "ADS", "OMIE_CUPOM.DBF", "_OMIECUPOM", .T. )

if !IsDir(cPathNF+"omie")
   DirMake(cPathNF+"omie")
endif

BEGIN SEQUENCE

   cAmb := if(_DADOS->NFCEPROD, "P", "H" )

   //////////////////////////////////////////////////////////////////////////////////////////////
   // ADD
   //////////////////////////////////////////////////////////////////////////////////////////////

   // Processo normal de Fechamento de Caixa.

   do while .t.

      sysrefresh()

      // Gera o n˙mero do Lote. 
       
      hLote := {=>}
      hLote["LOTE"]     := pu_GetLote()
      hLote["CAIXA"]    := 0
      hLote["PDV"]      := cPDV
      hLote["ENVIADO"]  := .F. 
      hLote["NRECNO"]   := 0
      hLote["FECHADO"]  := "S"
      hLote["CX_DTINI"] := ctod("")
      hLote["CX_HRINI"] := ""
      hLote["CX_DTFIM"] := ctod("")
      hLote["CX_HRFIM"] := ""
      hLote["AMBIENTE"] := "P"
      hLote["AMB_ORIG"] := cAmb
      hLote["VERSAO"]   := pu_GetOmie( "VER", "CONFIG" )
      hLote["CX_VRINI"] := 0
      hLote["CX_VRFIM"] := 0
      hLote["ACAO"]     := "ADD"
      hLote["HDSERIAL"] := pu_GetSerialNumber()  
      hLote["ORIGEM"]   := "OmiePDV"
      hLote["BUILD"]    := left(alltrim(m->versao_exe),11)
      hLote["NUM_PESS"] := 0
      hLote["SINCRONO"] := "N"

      // Le as informaÁıes dos Cupons no OmiePDV.

      aCupons := pu_Pdv2Hash( cPathNF, hLote )

      // Se nao tem mais cupons para enviar, encerra o processamento.

      if len(aCupons) = 0 
         exit
      endif

      // Gera o arquivo CSV do OmiePDV para enviar para o Omie. 
   
      cReport := pu_Pdv2Txt( aCupons, hLote )

      if empty(cReport)
         exit
      endif

      // Se gerou exatamente o mesmo lote, tenta mandar por 3 vezes.

      if !empty(cRepAnt) .and. cRepAnt $ cReport 
         nVezes += 1
         if nVezes > 3
            exit
         endif
      else
         nVezes := 0
         // Guarda a versao anterior enviada.
         nPos := at( "\s\n", cReport )
         if nPos > 0
            cRepAnt := substr(cReport,nPos)
         endif         
      endif

      // Envia os Cupons.
       
      aCupons := pu_Pdv2Omie( cReport, aCupons, cPathNF, hLote )

      // Marca que os cupons foram gravados.
   
      if len(aCupons) > 0
         pu_PdvCheck( aCupons, hLote )
      endif

      if hLote["FECHADO"]!="S"
         exit
      endif

   enddo

   //////////////////////////////////////////////////////////////////////////////////////////////
   // UPDATE
   //////////////////////////////////////////////////////////////////////////////////////////////

   sysrefresh()

   // Verifica se alguma NFCe foi gerada em contingencia e envia para o OmiePDV.
  
   pu_VerPendencias()

   sysrefresh()

   // Gera o n˙mero do Lote. 
    
   hLote := {=>}
   hLote["LOTE"]     := pu_GetLote()
   hLote["CAIXA"]    := 0
   hLote["PDV"]      := cPDV
   hLote["ENVIADO"]  := .F. 
   hLote["NRECNO"]   := 0
   hLote["FECHADO"]  := "N" // Caixa ser· sempre "N" para Update
   hLote["CX_DTINI"] := ctod("")
   hLote["CX_HRINI"] := ""
   hLote["CX_DTFIM"] := ctod("")
   hLote["CX_HRFIM"] := ""
   hLote["AMBIENTE"] := "P"
   hLote["AMB_ORIG"] := cAmb
   hLote["VERSAO"]   := pu_GetOmie( "VER", "CONFIG" )
   hLote["CX_VRINI"] := 0
   hLote["CX_VRFIM"] := 0
   hLote["ACAO"]     := "UPD"
   hLote["HDSERIAL"] := pu_GetSerialNumber()  
   hLote["ORIGEM"]   := "OmiePDV"
   hLote["BUILD"]    := left(alltrim(m->versao_exe),11)
   hLote["NUM_PESS"] := 0
   hLote["SINCRONO"] := "N"

   // Le as informaÁıes dos Cupons no OmiePDV.

   aCupons := pu_Pdv2Hash( cPathNF, hLote )

   // Se nao tem mais cupons para enviar, encerra o processamento.

   if len(aCupons) = 0 
      break
   endif

   // Gera o arquivo CSV do OmiePDV para enviar para o Omie. 

   cReport := pu_Pdv2Txt( aCupons, hLote )

   if empty(cReport)
      break
   endif

   // Envia os Cupons.
    
   aCupons := pu_Pdv2Omie( cReport, aCupons, cPathNF, hLote )

   // Marca que os cupons foram gravados.

   if len(aCupons) > 0
      pu_PdvCheck( aCupons, hLote )
   endif

END SEQUENCE

_CUPOM->(dbclosearea())
_ESTAT->(dbclosearea())
_CARTAO->(dbclosearea())
_ESTOQUE->(dbclosearea())
_CLIENTE->(dbclosearea())
_INDICE->(dbclosearea())
_DEBCART->(dbclosearea())
_NFCCAB->(dbclosearea())
_SATFISCAL->(dbclosearea())
_SATITENS->(dbclosearea())
_DADOS->(dbclosearea())
_CHEQUES->(dbclosearea()) 
_CAIXA->(dbclosearea())
_CADASTRO->(dbclosearea())
_OMIEPEND->(dbclosearea())
_OMIELOTE->(dbclosearea())
_OMIECUPOM->(dbclosearea())

SET DELETED ON

return cReport

****************************************************************************************************
static function pu_ReenviarCupons()
****************************************************************************************************

USE ("CUPOM.DBF")     ALIAS _CUPOM     VIA "ADS" SHARED NEW

_CUPOM->(dbSetOrder(2))     // CUPOM

_CUPOM->(dbGoTop())

do while !_CUPOM->(eof())

   if _CUPOM->DATA >= ctod("01/03/2017") .and. _CUPOM->OMIE .and. !_CUPOM->CANC .and. !_CUPOM->CONTINGENC
      _CUPOM->OMIE := .F.
   endif
   
   _CUPOM->(dbSkip())

enddo

_CUPOM->(dbclosearea())

return NIL

// return ((((date()-ctod('01/01/2015'))*24)*60)*60)+round(seconds(),0)

****************************************************************************************************
static function pu_Pdv2Hash( cPathNF, hLote )
****************************************************************************************************

local aCaixas   := {}

local nCupons   := 0
local aCupons   := {}
local hCupom    := {=>}
local hitem     := {=>}
local hParcela  := {=>}
local hPagto    := {=>}
local hCheque   := {=>}
local lContinue := .T.

local nSeq    := 0
local cAux    := ""
local cAnoMes := ""
local cXmlNF  := ""
local nLastCx := 0
local nPos    := 0

local nValTot := 0
local nValDes := 0
local nCont   := 0

default cPathNF := curdrive() + ":\" + CurDir() + "\" 
default hLote   := {=>}

if empty(hLote)
   return aCupons
endif

_CUPOM->(dbSetOrder(2))     // CUPOM
_ESTAT->(dbSetOrder(2))     // CUPOM
_CARTAO->(dbSetOrder(1))    // CODIGO
_ESTOQUE->(dbSetOrder(1))   // CODIGO
_CLIENTE->(dbSetOrder(2))   // CODIGO
//_INDICE->(dbSetOrder(0))   
_DEBCART->(dbSetOrder(1))   // CUPOM
_NFCCAB->(dbSetOrder(3))    // NNF
_SATFISCAL->(dbSetOrder(2)) // CUPOM
_SATITENS->(dbSetOrder(1)) // REGSAT
//_DADOS->(dbSetOrder(0))   
_CHEQUES->(dbSetOrder(3))   // CUPOM
_CAIXA->(dbSetOrder(2))     // NUM
_CADASTRO->(dbSetOrder(2))  // CODIGO

//////////////////////////////////////////////////////////////////////////////

BEGIN SEQUENCE
   
   // Le apenas os caixas fechados e nao enviados.

   // setfilter( "_CAIXA", "FLAG <> 'X' AND DATA_FINAL <> '' ")

   if hLote["ACAO"] == "ADD"

      _CAIXA->(dbGoBottom())

      // Guarda o ˙ltimo caixa fechado.

      nLastCx := _CAIXA->NUM
 
      setfilter( "_CAIXA", "FLAG <> 'X' " )

      _CAIXA->(dbGoTop())

   endif

   // Percorre pelos caixas nao enviados ainda.

   //do while !_CAIXA->(eof())
   
   do while .t.

      if hLote["ACAO"] == "ADD"

         if _CAIXA->(eof())
            exit
         endif

         hLote["CAIXA"]    := _CAIXA->NUM
         hLote["NRECNO"]   := _CAIXA->(RecNo())
         hLote["FECHADO"]  := if(empty(_CAIXA->FINAL),"N","S")
         hLote["ENVIADO"]  := .F.
         hLote["CX_DTINI"] := _CAIXA->DATA
         hLote["CX_HRINI"] := _CAIXA->INICIAL
         hLote["CX_DTFIM"] := _CAIXA->DATA_FINAL
         hLote["CX_HRFIM"] := _CAIXA->FINAL
         hLote["CX_VRINI"] := _CAIXA->CX_INICIAL
         hLote["CX_VRFIM"] := _CAIXA->CX_FINAL

         setfilter("_CUPOM","!OMIE AND CX = "+ alltrim(str(_CAIXA->NUM)) )
      
         _CUPOM->(dbGoTop())         

      else  // UPD
         
         hLote["CAIXA"]    := 99999
         hLote["NRECNO"]   := 0
         hLote["FECHADO"]  := "N"
         hLote["ENVIADO"]  := .F.
         hLote["CX_DTINI"] := date()
         hLote["CX_HRINI"] := time()
         hLote["CX_DTFIM"] := date()
         hLote["CX_HRFIM"] := time()
         hLote["CX_VRINI"] := 0
         hLote["CX_VRFIM"] := 0

         setfilter("_CUPOM", "" )
      
         _CUPOM->(dbGoTop())

         setfilter( "_OMIEPEND", "ENVIADO = 'N' " )

         _OMIEPEND->(dbGoTop())

      endif

      // Definir critÈrio de filtro.

      // do while _CUPOM->CX == _CAIXA->NUM .AND. !_CUPOM->(eof()) 
      
      do while .t.

         //////////////////////////////////////////////////////////////////////////////////////////

         if hLote["ACAO"]=="ADD"

            if !( _CUPOM->CX == _CAIXA->NUM .AND. !_CUPOM->(eof()) )
               exit
            endif

         else

            if _OMIEPEND->(eof())
               exit
            endif

            _CUPOM->( dbSeek(_OMIEPEND->CUPOM) )

            do while _CUPOM->CUPOM = _OMIEPEND->CUPOM 
               if _CUPOM->COO <> _OMIEPEND->COO 
                  _CUPOM->(dbSkip())
               endif
               exit
            enddo

            // Se nao achou, vai para o prÛximo.

            if _CUPOM->CUPOM != _OMIEPEND->CUPOM
               _OMIEPEND->(dbSkip())
               loop 
            endif

         endif

         //////////////////////////////////////////////////////////////////////////////////////////

         // Totais por Cupom.

         nCupons += 1  

         hCupom := {=>}

         hCupom["ENVIADO"]        := .F.
         hCupom["NRECNO"]         := _CUPOM->(RecNo())
     
         hCupom["LOTE"]           := hLote["LOTE"]
         hCupom["COD_INT"]        := alltrim(str(_CUPOM->CUPOM))+"000"
         hCupom["COD_CLI"]        := 0
         hCupom["MODELO"]         := "00"
         hCupom["DTEMIS"]         := _CUPOM->DATA
         hCupom["HREMIS"]         := _CUPOM->HORA
         hCupom["NUM_CAIXA"]      := _CUPOM->CX
         hCupom["NUM_ECF"]        := _CUPOM->NUMSERIE
         hCupom["NUM_VENDA"]      := _CUPOM->CUPOM
         hCupom["NUM_CCF"]        := _CUPOM->CCF
         hCupom["NUM_COO"]        := _CUPOM->COO
         hCupom["QTDE"]           := _CUPOM->QTD_ITENS
         hCupom["VALOR_ACRE"]     := 0
         hCupom["VALOR_DESC"]     := _CUPOM->DESCONTO
         hCupom["VALOR_IBPT"]     := 0
         hCupom["VALOR_LIQ"]      := _CUPOM->LIQUIDO
         hCupom["VALOR_TOT"]      := _CUPOM->TOTAL
         hCupom["ARREDONDA"]      := _CUPOM->ARREDONDA
         hCupom["ACRESCIMO"]      := _CUPOM->ACRESCIMO

         hCupom["NUM_SAT"]        := ""
         hCupom["NUM_EXTRAT"]     := 0
         hCupom["VENDEDOR"]       := ""
         hCupom["NFCE_CHAVE"]     := ""
         hCupom["NFCE_NUM"]       := "" 
         hCupom["NFCE_SERIE"]     := ""
         hCupom["NFCE_PROTOCOLO"] := ""
         hCupom["NFCE_RECIBO"]    := ""
         hCupom["NFCE_XML"]       := ""
         hCupom["NFCE_LINK"]      := ""
         hCupom["NFCE_PROC"]      := "N"
         hCupom["NFCE_CONT"]      := "N"
         hCupom["NFCE_CANC"]      := "N"
         hCupom["NFCE_INUT"]      := "N"
         hCupom["NFCE_NRECNO"]    := 0

         hCupom["SAT_CHAVE"]      := ""
         hCupom["SAT_PROTOCOLO"]  := 0
         hCupom["SAT_QRCODE"]     := ""
         hCupom["SAT_SESSAO"]     := 0
         hCupom["SAT_XML"]        := ""
         hCupom["SAT_CANC"]       := "N"
         hCupom["SAT_CANCCHAVE"]  := ""
         hCupom["SAT_CANCDTHR"]   := ""
         hCupom["SAT_CANCPROT"]   := 0

         hCupom["SAT_NRECNO"]     := 0
         hCupom["CANCELADO"]      := if(_CUPOM->CANC,"S","N")
         hCupom["CXFECHADO"]      := hLote["FECHADO"]
         hCupom["MD5CUPOM"]       := _CUPOM->VALIDMD5

         // Auxiliares
         hCupom["ID_CONTA"]       := 0
         hCupom["DOC"]            := ""
         hCupom["AMBIENTE"]       := hLote["AMBIENTE"]
         hCupom["VERSAO"]         := hLote["VERSAO"] 
 
         hCupom["PEND_NRECNO"]    := 0 
         hCupom["ACAO"]           := hLote["ACAO"]

         if alltrim(_CUPOM->NFMODELO) == "59"
            hCupom["VALOR_DESC"] := 0
            hCupom["VALOR_LIQ"]  := hCupom["VALOR_TOT"]
         endif

         hCupom["itens"]          := {}
         hCupom["pagtos"]         := {}
         hCupom["parcelas"]       := {}
         hCupom["cheques"]        := {}

         if hLote["ACAO"]=="UPD"
            hCupom["PEND_NRECNO"] := _OMIEPEND->(RecNo())
            hCupom["ACAO"]        := _OMIEPEND->ACAO
         else
            if hLote["FECHADO"] == "N"
               hCupom["ACAO"] := "TMP"
            endif
         endif

         hCupom["SAT_CANXML"]  := ""
         hCupom["NFCE_CANXML"] := ""
         hCupom["NFCE_CHAVC"]  := ""
         hCupom["ARREDONDA"]   := 0
         hCupom["ACRESCIMO"]   := 0
         hCupom["ID_VEND"]     := 0
         hCupom["ID_PROJ"]     := 0
         hCupom["COD_PAG"]     := ""
         hCupom["NUM_MESA"]    := ""
         hCupom["NUM_PESS"]    := 0
         hCupom["VALOR_TAXA"]  := 0

         // Procura pelo Vendedor.

         if !empty(_CUPOM->VENDEDOR)
            if _CADASTRO->(dbSeek( val(_CUPOM->VENDEDOR) ))
               hCupom["VENDEDOR"] := _CADASTRO->SN
            endif
         endif   

         // Procura pelo Cliente.

         if _CUPOM->CLIENTE > 0
            hCupom["COD_CLI"] := _CUPOM->CLIENTE 
            if _CLIENTE->(dbSeek( _CUPOM->CLIENTE ))
               hCupom["COD_CLI"] := val(_CLIENTE->CODOMIE)
            endif
         endif

         // Verifica qual È o modelo de comunicaÁao.

         if !empty(hCupom["NUM_ECF"])
            hCupom["MODELO"] := "00"
         endif

         // Procura pelos dados do Cartao.

         do case
         case _CUPOM->TIPO = "AV"
            
            hCupom["DOC"]      := "10001"
            hCupom["ID_CONTA"] := val(_INDICE->OMIECX)

         case _CUPOM->TIPO = "CH"

            hCupom["DOC"]      := "10002"
            hCupom["ID_CONTA"] := val(_INDICE->OMIECX)

            if _CHEQUES->(dbSeek( _CUPOM->CUPOM ))

               hCheque := {=>}
               hCheque["ENVIADO"]    := .F.
               hCheque["NRECNO"]     := _CHEQUES->(RecNo())
               
               hCheque["ID"]         := _CHEQUES->ID
               hCheque["COD_INT"]    := alltrim(str(_CUPOM->CUPOM))+"501"
               hCheque["NUM_VENDA"]  := _CHEQUES->CUPOM

               hCheque["DATA"]       := _CHEQUES->DATA
               hCheque["BANCO"]      := _CHEQUES->BANCO
               hCheque["AGENCIA"]    := _CHEQUES->AGENCIA
               hCheque["N_CHEQUE"]   := _CHEQUES->N_CHEQUE
               hCheque["CONTA"]      := _CHEQUES->CONTA
               hCheque["SERIE"]      := _CHEQUES->SERIE
               hCheque["CPF"]        := _CHEQUES->CPF
               hCheque["CLIENTE"]    := _CHEQUES->CLIENTE
               hCheque["NOME"]       := _CHEQUES->NOME
               hCheque["ENDERECO"]   := _CHEQUES->ENDERECO
               hCheque["BAIRRO"]     := _CHEQUES->BAIRRO
               hCheque["CIDADE"]     := _CHEQUES->CIDADE
               hCheque["CEP"]        := _CHEQUES->CEP
               hCheque["ESTADO"]     := _CHEQUES->ESTADO
               hCheque["RG"]         := _CHEQUES->RG
               hCheque["TELEFONE"]   := _CHEQUES->TELEFONE
               hCheque["VENCIMENTO"] := _CHEQUES->VENCIMENTO
               hCheque["VALOR"]      := _CHEQUES->VALOR
               hCheque["TAXA"]       := _CHEQUES->TAXA
               hCheque["TNOME"]      := _CHEQUES->TNOME
               hCheque["TCPF"]       := _CHEQUES->TCPF
               hCheque["TTELEFONE"]  := _CHEQUES->TTELEFONE
               hCheque["TENDERECO"]  := _CHEQUES->TENDERECO
               hCheque["TCOMPL"]     := _CHEQUES->TCOMPL
               hCheque["TNUMERO"]    := _CHEQUES->TNUMERO
               hCheque["TCIDADE"]    := _CHEQUES->TCIDADE
               hCheque["TBAIRRO"]    := _CHEQUES->TBAIRRO
               hCheque["TCEP"]       := _CHEQUES->TCEP
               hCheque["TESTADO"]    := _CHEQUES->TESTADO
               hCheque["PARCELA"]    := _CHEQUES->PARCELA
               hCheque["EMITENTE"]   := _CHEQUES->EMITENTE
               hCheque["CODCLI"]     := _CHEQUES->CODCLI

               aadd( hCupom["cheques"], hCheque )

            endif

         case _CUPOM->TIPO = "AP"

            hCupom["DOC"]      := "10004"
            hCupom["ID_CONTA"] := val(_INDICE->OMIEBANCO)

         case _CUPOM->TIPO = "CT"

            hCupom["DOC"] := "10003"

            if _CUPOM->CT > 0
               if _CARTAO->(dbSeek( _CUPOM->CT ))
                  hCupom["ID_CONTA"] := val(_CARTAO->CODOMIE)
               endif
            endif
         
         endcase

         /////////////////////////////////////////////////////////////////////////

         // Formas de Pagamento

         if _CUPOM->PDH > 0 // A Vista
            hPagto := {=>}
            hPagto["TIPO"]       := "AV"
            hPagto["COD_INT"]    := alltrim(str(_CUPOM->CUPOM))+"402"
            hPagto["VALOR"]      := _CUPOM->PDH  
            hPagto["ID_CONTA"]   := val(_INDICE->OMIECX)
            hPagto["PRINCIPAL"]  := "N"
            hPagto["DOC"]        := "10001"
            hPagto["AL_TAXA"]    := 0
            hPagto["VALOR_TAXA"] := 0
            aadd( hCupom["pagtos"], hPagto )    
         endif

         if _CUPOM->PCT > 0 // Cartao
            hPagto := {=>}
            hPagto["TIPO"]       := "CT"
            hPagto["COD_INT"]    := alltrim(str(_CUPOM->CUPOM))+"403"
            hPagto["VALOR"]      := _CUPOM->PCT  
            hPagto["ID_CONTA"]   := hCupom["ID_CONTA"]
            hPagto["PRINCIPAL"]  := "N"
            hPagto["DOC"]        := "10003"
            hPagto["AL_TAXA"]    := 0
            hPagto["VALOR_TAXA"] := 0
            aadd( hCupom["pagtos"], hPagto )                 
         endif

         if _CUPOM->PCH > 0 // Cheque
            hPagto := {=>}
            hPagto["TIPO"]       := "CH"
            hPagto["COD_INT"]    := alltrim(str(_CUPOM->CUPOM))+"404"
            hPagto["VALOR"]      := _CUPOM->PCH  
            hPagto["ID_CONTA"]   := val(_INDICE->OMIEBANCO)
            hPagto["PRINCIPAL"]  := "N"
            hPagto["DOC"]        := "10002"
            hPagto["AL_TAXA"]    := 0
            hPagto["VALOR_TAXA"] := 0
            aadd( hCupom["pagtos"], hPagto )                 
         endif

         if _CUPOM->PAP > 0 // A Prazo
            hPagto := {=>}
            hPagto["TIPO"]       := "AP"
            hPagto["COD_INT"]    := alltrim(str(_CUPOM->CUPOM))+"405"
            hPagto["VALOR"]      := _CUPOM->PAP  
            hPagto["ID_CONTA"]   := val(_INDICE->OMIEBANCO)
            hPagto["PRINCIPAL"]  := "N"
            hPagto["DOC"]        := "10004"
            hPagto["AL_TAXA"]    := 0
            hPagto["VALOR_TAXA"] := 0
            aadd( hCupom["pagtos"], hPagto )                 
         endif

         // Pagamento principal.
         hPagto := {=>}
         hPagto["TIPO"]       := _CUPOM->TIPO
         hPagto["COD_INT"]    := alltrim(str(_CUPOM->CUPOM))+"401"
         hPagto["VALOR"]      := _CUPOM->LIQUIDO - _CUPOM->PDH - _CUPOM->PCT - _CUPOM->PCH - _CUPOM->PAP  
         hPagto["ID_CONTA"]   := hCupom["ID_CONTA"]
         hPagto["PRINCIPAL"]  := "S"
         hPagto["DOC"]        := hCupom["DOC"]
         hPagto["AL_TAXA"]    := 0
         hPagto["VALOR_TAXA"] := 0
         aadd( hCupom["pagtos"], hPagto ) 

         /////////////////////////////////////////////////////////////////////////

         // Itens do Cupom.

         if _ESTAT->(dbSeek( hCupom["NUM_VENDA"] ))

            do while _ESTAT->CUPOM = hCupom["NUM_VENDA"] .and. !_ESTAT->(eof())

               if left(_ESTAT->VCOD,2)<>"XX" .and. _CUPOM->DATA = _ESTAT->DIAVENDA           
                  
                  hitem := {=>}
                  hitem["ID_PROD"]    := 0
                  hitem["COD_INT"]    := alltrim(str(_CUPOM->CUPOM))+strzero(200+_ESTAT->SEQ,3)

                  hitem["ENVIADO"]    := .F.
                  hitem["NRECNO"]     := _ESTAT->(RecNo())

                  hitem["SEQ"]        := _ESTAT->SEQ

                  nValTot := round( _ESTAT->QTD * _ESTAT->PRECOVEND, 2) + _ESTAT->ACRESCIMO
                  nValDes := round( _ESTAT->QTD * _ESTAT->PRECODSC, 2)

                  hitem["QTDE"]        := _ESTAT->QTD
                  hitem["VALOR_UNI"]   := _ESTAT->PRECOVEND
                  //hitem["VALOR_DESC"] := ( (_ESTAT->PRECOVEND * _ESTAT->QTD) * _ESTAT->DSC ) / 100
                  // hitem["VALOR_TOT"] := _ESTAT->PRECOVEND * _ESTAT->QTD
                  hitem["VALOR_DESC"]  := nValTot-nValDes
                  hitem["VALOR_TOT"]   := nValTot
                  hitem["ARREDONDA"]   := _ESTAT->ARREDONDA
                  hitem["ACRESCIMO"]   := _ESTAT->ACRESCIMO
                  hitem["VALOR_OUTRO"] := 0

                  hitem["VCOD"]       := alltrim(_ESTAT->VCOD)
                  hitem["CFOP"]       := _ESTAT->CFOP
                  hitem["CST_ICMS"]   := alltrim(_ESTAT->CSTICMSAI)
                  hitem["CST_PIS"]    := alltrim(_ESTAT->CSTPISSAI)
                  hitem["CST_COFINS"] := alltrim(_ESTAT->CSTCOFSAI)
                  hitem["NCM"]        := alltrim(_ESTAT->NCM)
                  hitem["CSOSN"]      := alltrim(_ESTAT->CSOSN)

                  if _ESTOQUE->(dbSeek( _ESTAT->VCOD ))
                     hitem["ID_PROD"] := val(_ESTOQUE->CODOMIE)
                  endif
      
                  // aadd( hCupom["itens"], hitem )

                  if !empty(_ESTAT->SAT) .and. (empty(hCupom["NFCE_CHAVE"]) .or. empty(hCupom["SAT_CHAVE"]))

                     // Cfe35150205761098000113599000003830000261927970

                     if upper(left(_ESTAT->SAT,3))=="CFE"   
                        cAux := substr(_ESTAT->SAT,4)
                     else
                        cAux := _ESTAT->SAT
                     endif
                     
                     cAux := alltrim(cAux)

                     // 51150202220825000147650010000000081000000086

                     do case
                     case substr(cAux,21,2) == "65" // NFCE
         
                        if hLote["AMBIENTE"]<>hLote["AMB_ORIG"]
                           hLote["AMBIENTE"] := hLote["AMB_ORIG"]
                        endif

                        hCupom["MODELO"]     := "65"
                        hCupom["NFCE_CHAVE"] := cAux
                        hCupom["AMBIENTE"]   := hLote["AMB_ORIG"]

                        if _NFCCAB->(dbSeek( alltrim(str(_CUPOM->COO)) ))

                           hCupom["NUM_CCF"]        := val(_NFCCAB->NNF)
                           hCupom["NFCE_NUM"]       := _NFCCAB->CNF
                           hCupom["NFCE_SERIE"]     := _NFCCAB->SERIE
                           hCupom["NFCE_PROTOCOLO"] := _NFCCAB->PROTOCOLO
                           hCupom["NFCE_RECIBO"]    := _NFCCAB->RECIBO
                           hCupom["NFCE_XML"]       := ""
                           hCupom["NFCE_LINK"]      := alltrim(_NFCCAB->QRCODE) + alltrim(_NFCCAB->QRCODE1) // 022015
                           hCupom["NFCE_PROC"]      := if(_NFCCAB->PROCESSADO, "S", "N" )
                           hCupom["NFCE_CONT"]      := if(_NFCCAB->CONTINGENC, "S", "N" )
                           hCupom["NFCE_CANC"]      := if(_NFCCAB->CANCELADA, "S", "N" )
                           hCupom["NFCE_INUT"]      := if(_NFCCAB->INUTILIZA, "S", "N" )
                           hCupom["NFCE_NRECNO"]    := _NFCCAB->(RecNo())

                           cAnoMes := strzero(month(_CUPOM->DATA),2)+strzero(year(_CUPOM->DATA),4)

                           // C:\omiepdv\nfce_assinado\022015\ProtNFCE51150202220825000147650010000000081000000086.XML

                           cXmlNF := cPathNF + "nfce_assinado" + "\" + cAnoMes + "\" + "ProtNFCE" + hCupom["NFCE_CHAVE"] + ".XML" 

                           if file(cXmlNF)
                              hCupom["NFCE_XML"]  := memoread(cXmlNF)
                              //hCupom["NFCE_CONT"] := "N"
                           else

                              // C:\omiepdv\nfce_Contingencia\NFE51150202126021000183650010000000011000000017.XML
                              
                              cXmlNF := cPathNF + "nfce_Contingencia" + "\" + "NFE" + hCupom["NFCE_CHAVE"] + ".XML" 
                              
                              if file(cXmlNF)
                                 hCupom["NFCE_XML"]  := memoread(cXmlNF)
                                 //hCupom["NFCE_CONT"] := "S"
                              endif

                           endif

                           if !empty(hCupom["NFCE_XML"])
                              hCupom["NFCE_XML"] := pu_ChangeChar( hCupom["NFCE_XML"] )  
                           endif 

                           //////////////////////////////////////////////////////////////////////////////
                           
                           // XML de Cancelamento

                           hCupom["NFCE_CHAVC"]  := ""
                           hCupom["NFCE_CANXML"] := ""                           
                           
                           // CancNFCE-33160108942090000141650010000060181000060183

                           cXmlNF := cPathNF + "nfce_assinado" + "\" + cAnoMes + "\" + "CancNFCE-" + hCupom["NFCE_CHAVE"] + ".XML" 

                           if file(cXmlNF)
                              hCupom["NFCE_CANXML"] := memoread(cXmlNF)
                              hCupom["NFCE_CHAVC"]  := hCupom["NFCE_CHAVE"]
                           else

                              cXmlNF := cPathNF + "nfce_assinado" + "\" + cAnoMes + "\" + "InutilizaNFCE-" + hCupom["NFCE_CHAVE"] + ".XML" 

                              if file(cXmlNF)
                                 hCupom["NFCE_CANXML"] := memoread(cXmlNF)
                                 hCupom["NFCE_CHAVC"]  := hCupom["NFCE_CHAVE"]
                              endif
                           
                           endif

                           if !empty(hCupom["NFCE_CANXML"])
                              hCupom["NFCE_CANXML"] := pu_ChangeChar( hCupom["NFCE_CANXML"] )  
                           endif 

                           //////////////////////////////////////////////////////////////////////////////

                        endif

                        ///////////////////////////////////////////////////////////////////////////

                        // Se o lote for de atualizaÁao UDP, verifica se È contingencia e a NFC-e j· foi enviada.

                        if hLote["ACAO"]=="UPD"

                           // Se a aÁao È enviar NFCE em Contingencia 

                           if hCupom["ACAO"]=="CTG" .AND. hCupom["NFCE_CONT"]=="S"
                              hCupom := {=>}
                              _OMIEPEND->(dbSkip())
                              exit
                           endif

                        endif

                        ///////////////////////////////////////////////////////////////////////////

                     // CFe35150361099008000141599000008510002659351
                     // 35150361099008000141599000008510002659351
                     
                     case substr(cAux,21,2) == "59" // SAT
                        
                        hCupom["MODELO"]     := "59"
                        hCupom["SAT_CHAVE"]  := cAux
                        hCupom["NUM_SAT"]    := _DADOS->SERIESAT
                        hCupom["NUM_EXTRAT"] := val(substr(cAux,32,6)) 

                        if _SATFISCAL->(dbSeek( _CUPOM->CUPOM ))

                           cXmlNF := alltrim(_SATFISCAL->QRCODE)
                           if !empty(cXmlNF) 
                              nPos := rat("|",cXmlNF)
                              if nPos > 0 
                                 cXmlNF := substr(cXmlNF,nPos+1)
                              endif
                           endif
                           hCupom["SAT_QRCODE"] := cXmlNF
                           //hCupom["SAT_QRCODE"] := _SATFISCAL->QRCODE

                           hCupom["SAT_PROTOCOLO"] := _SATFISCAL->PROTOCOLO
                           hCupom["SAT_SESSAO"]    := _SATFISCAL->SESSAO
                           hCupom["SAT_CANC"]      := if(_SATFISCAL->CANCELADA, "S", "N" )
                           hCupom["SAT_CANCCHAVE"] := _SATFISCAL->CHAVECANCE
                           hCupom["SAT_CANCDTHR"]  := _SATFISCAL->DATAHORACA
                           hCupom["SAT_CANCPROT"]  := _SATFISCAL->PROTCANCE                           
                           hCupom["SAT_NRECNO"]    := _SATFISCAL->(RecNo())

                           // C:\omiepdv\sat\Cfe35150205761098000113599000003830000261927970.xml
                           
                           cAnoMes := strzero(month(_CUPOM->DATA),2)+strzero(year(_CUPOM->DATA),4)

                           cXmlNF  := cPathNF + "sat_assinado" + "\" + cAnoMes + "\" + "Cfe" + hCupom["SAT_CHAVE"] + ".xml" 

                           if file(cXmlNF)
                              hCupom["SAT_XML"]  := memoread(cXmlNF)
                           else
                              cXmlNF  := cPathNF + "sat" + "\" + "Cfe" + hCupom["SAT_CHAVE"] + ".xml" 
                              if file(cXmlNF)
                                 hCupom["SAT_XML"]  := memoread(cXmlNF)
                              endif
                           endif

                           if !empty(hCupom["SAT_XML"])
                              hCupom["SAT_XML"] := pu_ChangeChar( hCupom["SAT_XML"] )  
                           endif 

                           if _SATITENS->(dbSeek( _SATFISCAL->SESSAO ))

                              nCont := 0

                              do while _SATITENS->REGSAT == _SATFISCAL->SESSAO
                                 nCont += 1
                                 if alltrim(_SATITENS->CPROD) == alltrim(_ESTAT->VCOD) .and. hitem["SEQ"] == nCont
                                    hitem["VALOR_DESC"]  := _SATITENS->VDESC
                                    hitem["VALOR_OUTRO"] := _SATITENS->VOUTRO
                                    hCupom["VALOR_DESC"] += _SATITENS->VDESC
                                    hCupom["VALOR_LIQ"]  -= _SATITENS->VDESC
                                    hCupom["VALOR_LIQ"]  += _SATITENS->VOUTRO
                                    EXIT
                                 endif
                                 _SATITENS->(dbSkip())
                              enddo
                           
                           endif

                           //////////////////////////////////////////////////////////////////////////////
                           // XML de Cancelamento

                           hCupom["SAT_CANXML"]  := ""

                           cXmlNF  := cPathNF + "sat_assinado" + "\" + cAnoMes + "\" + "canc-" + hCupom["SAT_CANCCHAVE"] + ".xml" 

                           if file(cXmlNF)
                              hCupom["SAT_CANXML"]  := memoread(cXmlNF)
                           endif

                           if !empty(hCupom["SAT_CANXML"])
                              hCupom["SAT_CANXML"] := pu_ChangeChar( hCupom["SAT_CANXML"] )  
                           endif 
                           
                           //////////////////////////////////////////////////////////////////////////////

                        endif

                     endcase
                  
                  endif

                  aadd( hCupom["itens"], hitem )
               
               endif

               _ESTAT->(dbSkip())

            enddo

            if hLote["ACAO"]=="UPD"
               if empty(hCupom)
                  loop
               endif
            endif

         endif

         /////////////////////////////////////////////////////////////////////////

         // Para pagamento no cartao, le as informaÁıes do pagamento.

         if _DEBCART->(dbSeek( hCupom["NUM_VENDA"] ))

            nSeq := 300

            do while _DEBCART->CUPOM = hCupom["NUM_VENDA"] .and. !_DEBCART->(eof())

               if _CUPOM->DATA = _DEBCART->DATA  

                  nSeq += 1
                  hParcela := {=>}
                  hParcela["COD_INT"]    := alltrim(str(_CUPOM->CUPOM))+strzero(nSeq,3)
                  hParcela["ID"]         := _DEBCART->ID
                  hParcela["PARCELA"]    := _DEBCART->PARCELA
                  hParcela["VENCIMENTO"] := _DEBCART->VENCIMENTO
                  hParcela["VALOR"]      := _DEBCART->VALOR
                  hParcela["DATA"]       := _DEBCART->DATA
                  hParcela["TEF_NSU"]    := _DEBCART->TEFNSU
                  hParcela["TEF_AUT"]    := _DEBCART->TEFAUT
                  hParcela["TEF_PARC"]   := _DEBCART->TEFPARC
                  hParcela["TEF_VALOR"]  := _DEBCART->TEFVALOR
                  hParcela["TEF_CREDEB"] := _DEBCART->TEFCD
                  hParcela["TEF_TIPO"]   := _DEBCART->TEFTIPO
                  hParcela["TEF_REDE"]   := _DEBCART->REDETEF

                  aadd( hCupom["parcelas"], hParcela )
               
               endif

               _DEBCART->(dbSkip())

            enddo

         endif
         
         hCupom["num_parc"] := len(hCupom["parcelas"])

         /////////////////////////////////////////////////////////////////////////

         if hLote["ACAO"] == "ADD" 

            if hCupom["QTDE"] > 0 .and. hCupom["VALOR_LIQ"] > 0
               aadd( aCupons, hCupom )
            endif

         else
   
            aadd( aCupons, hCupom )

         endif

         /////////////////////////////////////////////////////////////////////////
         
         // aadd( aCupons, hCupom )

         if hLote["ACAO"] == "ADD"
            _CUPOM->(dbSkip())
         else
            _OMIEPEND->(dbSkip())
         endif

      enddo

      // Caso nao haja cupons no CAIXA fechado.

      if hLote["ACAO"] == "ADD"

         if len(aCupons) == 0 
            if _CAIXA->NUM = nLastCx .and. empty(_CAIXA->DATA_FINAL)
               // Neste caso nao marca que o caixa foi fechado, para que possa ser enviado novamente. 
            else
               _CAIXA->FLAG := "X" // Neste ponto, pode ter ocorrido problemas no fechamento do caixa, entao marca que foi encerrado para continuar o processo de envio.
            endif
         endif
   
         _CAIXA->(dbSkip())
 
         // ForÁa a saÌda para enviar um caixa de cada vez.
         
         if len(aCupons) > 0
            exit 
         endif

      else // Para UPD forÁa o EXIT

         EXIT 

      endif

   enddo

END SEQUENCE

setfilter("_CAIXA","")
setfilter("_CUPOM","")

return aCupons

****************************************************************************************************
function pu_Pdv2Txt( aCupons, hLote )
****************************************************************************************************

local cReport   := ""

local hCupom    := {=>}

local aItens    := {}
local hitem     := {=>}

local aParcelas := {}
local hParcela  := {=>}

local aPagtos   := {} 
local hPagto    := {=>}

local aCheques  := {}
local hCheque   := {=>}

local cSepCol   := "|"
local cSepLine  := "\s\n"
local nLines    := 0
local nValTot   := 0

//cSepLine := CRLF

BEGIN SEQUENCE

   // Gera o RelatÛrio do arquivo TDM.

   if len(aCupons) > 0 

      // ComeÁo de arquivo.
      cReport += "0" + cSepCol                              //  1
      cReport += alltrim(str(hLote["LOTE"]))      + cSepCol //  2  
      cReport += alltrim(str(len(aCupons)))       + cSepCol //  3
      cReport += strzero(val(hLote["PDV"]),2)     + cSepCol //  4
      cReport += alltrim(str(hLote["CAIXA"]))     + cSepCol //  5
      cReport += alltrim(hLote["FECHADO"])        + cSepCol //  6
      cReport += alltrim(dtos(hLote["CX_DTINI"])) + cSepCol //  7 
      cReport += alltrim(hLote["CX_HRINI"])       + cSepCol //  8
      cReport += alltrim(dtos(hLote["CX_DTFIM"])) + cSepCol //  9
      cReport += alltrim(hLote["CX_HRFIM"])       + cSepCol // 10
      cReport += alltrim(hLote["AMBIENTE"])       + cSepCol // 11
      cReport += alltrim(hLote["VERSAO"])         + cSepCol // 12
      cReport += alltrim(str(hLote["CX_VRINI"]))  + cSepCol // 13
      cReport += alltrim(str(hLote["CX_VRFIM"]))  + cSepCol // 14
      cReport += alltrim(hLote["ACAO"])           + cSepCol // 15
      cReport += alltrim(hLote["HDSERIAL"])       + cSepCol // 16
      cReport += alltrim(hLote["ORIGEM"])         + cSepCol // 17
      cReport += alltrim(hLote["BUILD"])          + cSepCol // 18
      cReport += alltrim(str(hLote["NUM_PESS"]))  + cSepCol // 19
      cReport += alltrim(hLote["SINCRONO"])       + cSepCol // 20
      cReport += cSepLine

      for each hCupom in aCupons
         
         // Cupom Fiscal

         nLines  += 1
         cReport += "1"                                   + cSepCol //  1
         cReport += hCupom["COD_INT"]                     + cSepCol //  2   
         cReport += alltrim(str(hCupom["COD_CLI"]))       + cSepCol //  3   
         cReport += alltrim(hCupom["MODELO"])             + cSepCol //  4    
         cReport += dtos(hCupom["DTEMIS"])                + cSepCol //  5    
         cReport += hCupom["HREMIS"]                      + cSepCol //  6    
         cReport += alltrim(str(hCupom["NUM_CAIXA"]))     + cSepCol //  7 
         cReport += alltrim(hCupom["NUM_ECF"])            + cSepCol //  8   
         cReport += alltrim(str(hCupom["NUM_VENDA"]))     + cSepCol //  9 
         cReport += alltrim(str(hCupom["NUM_CCF"]))       + cSepCol // 10   
         cReport += alltrim(str(hCupom["NUM_COO"]))       + cSepCol // 11   
         cReport += alltrim(str(hCupom["QTDE"]))          + cSepCol // 12      
         cReport += alltrim(str(hCupom["VALOR_ACRE"]))    + cSepCol // 13 
         cReport += alltrim(str(hCupom["VALOR_DESC"]))    + cSepCol // 14
         cReport += alltrim(str(hCupom["VALOR_IBPT"]))    + cSepCol // 15
         cReport += alltrim(str(hCupom["VALOR_LIQ"]))     + cSepCol // 16 
         cReport += alltrim(str(hCupom["VALOR_TOT"]))     + cSepCol // 17 
         cReport += alltrim(hCupom["NFCE_CHAVE"])         + cSepCol // 18 
         cReport += alltrim(hCupom["NUM_SAT"])            + cSepCol // 19   
         cReport += alltrim(str(hCupom["NUM_EXTRAT"]))    + cSepCol // 20
         cReport += alltrim(hCupom["VENDEDOR"])           + cSepCol // 21  
         cReport += alltrim(hCupom["NFCE_NUM"])           + cSepCol // 22 
         cReport += alltrim(hCupom["NFCE_SERIE"])         + cSepCol // 23
         cReport += alltrim(hCupom["NFCE_PROTOCOLO"])     + cSepCol // 24
         cReport += alltrim(hCupom["NFCE_RECIBO"])        + cSepCol // 25
         cReport += alltrim(hCupom["NFCE_XML"])           + cSepCol // 26
         cReport += alltrim(hCupom["SAT_CHAVE"])          + cSepCol // 27 
         cReport += alltrim(str(hCupom["SAT_PROTOCOLO"])) + cSepCol // 28
         cReport += alltrim(hCupom["NFCE_LINK"])          + cSepCol // 29    
         cReport += alltrim(hCupom["SAT_QRCODE"])         + cSepCol // 30    
         cReport += alltrim(str(hCupom["SAT_SESSAO"]))    + cSepCol // 31
         cReport += alltrim(hCupom["NFCE_CONT"])          + cSepCol // 32
         cReport += alltrim(hCupom["SAT_XML"])            + cSepCol // 33
         cReport += alltrim(hCupom["CANCELADO"])          + cSepCol // 34
         cReport += alltrim(hCupom["CXFECHADO"])          + cSepCol // 35
         cReport += alltrim(hCupom["MD5CUPOM"])           + cSepCol // 36
         cReport += alltrim(hCupom["AMBIENTE"])           + cSepCol // 37
         cReport += alltrim(hCupom["VERSAO"])             + cSepCol // 38
         cReport += alltrim(hCupom["NFCE_PROC"])          + cSepCol // 39
         cReport += alltrim(hCupom["NFCE_CONT"])          + cSepCol // 40
         cReport += alltrim(hCupom["NFCE_CANC"])          + cSepCol // 41
         cReport += alltrim(hCupom["NFCE_INUT"])          + cSepCol // 42
         cReport += alltrim(hCupom["SAT_CANC"])           + cSepCol // 43
         cReport += alltrim(hCupom["SAT_CANCCHAVE"])      + cSepCol // 44
         cReport += alltrim(hCupom["SAT_CANCDTHR"])       + cSepCol // 45
         cReport += alltrim(str(hCupom["SAT_CANCPROT"]))  + cSepCol // 46
         cReport += alltrim(hCupom["ACAO"])               + cSepCol // 47
         cReport += alltrim(hCupom["NFCE_CANXML"])        + cSepCol // 48
         cReport += alltrim(hCupom["SAT_CANXML"])         + cSepCol // 49
         cReport += alltrim(hCupom["NFCE_CHAVC"])         + cSepCol // 50
         cReport += alltrim(str(hCupom["ARREDONDA"]))     + cSepCol // 51
         cReport += alltrim(str(hCupom["ACRESCIMO"]))     + cSepCol // 52
         cReport += alltrim(str(hCupom["ID_VEND"]))       + cSepCol // 53
         cReport += alltrim(str(hCupom["ID_PROJ"]))       + cSepCol // 54
         cReport += alltrim(hCupom["COD_PAG"])            + cSepCol // 55
         cReport += alltrim(hCupom["NUM_MESA"])           + cSepCol // 56
         cReport += alltrim(str(hCupom["NUM_PESS"]))      + cSepCol // 57
         cReport += alltrim(str(hCupom["VALOR_TAXA"]))    + cSepCol // 58
         cReport += cSepLine
 
         if hCupom["CANCELADO"]<>"S"
            nValTot += hCupom["VALOR_LIQ"]
         endif
         
         // Le os itens 

         aItens := aclone(hCupom["itens"])

         for each hitem in aItens

            nLines  += 1
            cReport += "2"                                         + cSepCol //  1
            cReport += hitem["COD_INT"]                            + cSepCol //  2
            cReport += alltrim(str(hitem["SEQ"]))                  + cSepCol //  3
            cReport += alltrim(str(hCupom["NUM_VENDA"]))           + cSepCol //  4
            cReport += alltrim(str(hitem["ID_PROD"]))              + cSepCol //  5
            cReport += alltrim(str(hitem["QTDE"]))                 + cSepCol //  6
            cReport += alltrim(str(hitem["VALOR_UNI"]))            + cSepCol //  7
            cReport += alltrim(str(hitem["VALOR_DESC"]))           + cSepCol //  8
            cReport += alltrim(str(round(hitem["VALOR_TOT"],2)))   + cSepCol //  9
            cReport += alltrim(str(round(hitem["ARREDONDA"],2)))   + cSepCol // 10
            cReport += alltrim(str(round(hitem["VALOR_OUTRO"],2))) + cSepCol // 11
            cReport += alltrim(str(round(hitem["ACRESCIMO"],2)))   + cSepCol // 12
            cReport += alltrim(hitem["VCOD"])                      + cSepCol // 13
            cReport += alltrim(str(hitem["CFOP"]))                 + cSepCol // 14
            cReport += alltrim(hitem["CST_ICMS"])                  + cSepCol // 15
            cReport += alltrim(hitem["CST_PIS"])                   + cSepCol // 16
            cReport += alltrim(hitem["CST_COFINS"])                + cSepCol // 17
            cReport += alltrim(hitem["NCM"])                       + cSepCol // 18
            cReport += alltrim(hitem["CSOSN"])                     + cSepCol // 19
            cReport += cSepLine

         next

         // Le as parcelas

         aParcelas := aclone(hCupom["parcelas"])

         for each hParcela in aParcelas

            nLines  += 1
            cReport += "3"                                 + cSepCol // 1
            cReport += hParcela["COD_INT"]                 + cSepCol // 2
            cReport += alltrim(str(hParcela["ID"]))        + cSepCol // 3
            cReport += alltrim(str(hCupom["NUM_VENDA"]))   + cSepCol // 4
            cReport += alltrim(hParcela["PARCELA"])        + cSepCol // 5
            cReport += dtos(hParcela["VENCIMENTO"])        + cSepCol // 6
            cReport += alltrim(str(hParcela["VALOR"]))     + cSepCol // 7
            cReport += dtos(hParcela["DATA"])              + cSepCol // 8       
            cReport += alltrim(hParcela["TEF_NSU"])        + cSepCol // 9    
            cReport += alltrim(hParcela["TEF_AUT"])        + cSepCol // 10   
            cReport += alltrim(str(hParcela["TEF_PARC"]))  + cSepCol // 11  
            cReport += alltrim(str(hParcela["TEF_VALOR"])) + cSepCol // 12 
            cReport += alltrim(hParcela["TEF_CREDEB"])     + cSepCol // 13
            cReport += alltrim(hParcela["TEF_TIPO"])       + cSepCol // 14  
            cReport += alltrim(hParcela["TEF_REDE"])       + cSepCol // 15  
            cReport += cSepLine

         next

         // Le os pagamentos

         aPagtos := aclone(hCupom["pagtos"])

         for each hPagto in aPagtos

            nLines  += 1
            cReport += "4"                                + cSepCol //  1
            cReport += hPagto["COD_INT"]                  + cSepCol //  2
            cReport += alltrim(hPagto["TIPO"])            + cSepCol //  3
            cReport += alltrim(str(hCupom["NUM_VENDA"]))  + cSepCol //  4
            cReport += alltrim(str(hPagto["ID_CONTA"]))   + cSepCol //  5
            cReport += alltrim(str(hPagto["VALOR"]))      + cSepCol //  6
            cReport += alltrim(hPagto["PRINCIPAL"])       + cSepCol //  7
            cReport += alltrim(hPagto["DOC"])             + cSepCol //  8
            cReport += alltrim(str(hPagto["AL_TAXA"]))    + cSepCol //  9
            cReport += alltrim(str(hPagto["VALOR_TAXA"])) + cSepCol // 10
            cReport += cSepLine

         next

         // Le os cheques

         aCheques := aclone(hCupom["cheques"])

         for each hCheque in aCheques

            nLines  += 1
            cReport += "5"                                + cSepCol // 01
            cReport += hCheque["COD_INT"]                 + cSepCol // 02
            cReport += alltrim(str(hCheque["ID"]))        + cSepCol // 03
            cReport += dtos(hCheque["DATA"])              + cSepCol // 04
            cReport += alltrim(hCheque["BANCO"])          + cSepCol // 05
            cReport += alltrim(hCheque["AGENCIA"])        + cSepCol // 06
            cReport += alltrim(hCheque["CONTA"])          + cSepCol // 07
            cReport += alltrim(hCheque["N_CHEQUE"])       + cSepCol // 08
            cReport += alltrim(hCheque["SERIE"])          + cSepCol // 09
            cReport += dtos(hCheque["VENCIMENTO"])        + cSepCol // 10
            cReport += alltrim(str(hCheque["VALOR"]))     + cSepCol // 11
            cReport += alltrim(str(hCheque["TAXA"]))      + cSepCol // 12
            cReport += alltrim(hCheque["PARCELA"])        + cSepCol // 13
            cReport += alltrim(str(hCheque["EMITENTE"]))  + cSepCol // 14
            cReport += alltrim(str(hCheque["CODCLI"]))    + cSepCol // 15
            cReport += alltrim(hCheque["CPF"])            + cSepCol // 16
            cReport += alltrim(hCheque["RG"])             + cSepCol // 17
            cReport += alltrim(hCheque["CLIENTE"])        + cSepCol // 18
            cReport += alltrim(hCheque["NOME"])           + cSepCol // 19
            cReport += alltrim(hCheque["ENDERECO"])       + cSepCol // 20
            cReport += alltrim(hCheque["TCOMPL"])         + cSepCol // 21
            cReport += alltrim(hCheque["BAIRRO"])         + cSepCol // 22
            cReport += alltrim(hCheque["CIDADE"])         + cSepCol // 23
            cReport += alltrim(hCheque["ESTADO"])         + cSepCol // 24
            cReport += alltrim(hCheque["CEP"])            + cSepCol // 25
            cReport += alltrim(hCheque["TELEFONE"])       + cSepCol // 26
            cReport += alltrim(hCheque["TCPF"])           + cSepCol // 27
            cReport += alltrim(hCheque["TNOME"])          + cSepCol // 28
            cReport += alltrim(hCheque["TENDERECO"])      + cSepCol // 29
            cReport += alltrim(str(hCheque["TNUMERO"]))   + cSepCol // 30
            cReport += alltrim(hCheque["TCOMPL"])         + cSepCol // 31
            cReport += alltrim(hCheque["TBAIRRO"])        + cSepCol // 32
            cReport += alltrim(hCheque["TCIDADE"])        + cSepCol // 33
            cReport += alltrim(hCheque["TESTADO"])        + cSepCol // 34
            cReport += alltrim(hCheque["TCEP"])           + cSepCol // 35
            cReport += alltrim(hCheque["TTELEFONE"])      + cSepCol // 36
            cReport += alltrim(str(hCheque["NUM_VENDA"])) + cSepCol // 37
            cReport += cSepLine

         next

         pu_AddLogCupom( hCupom )

      next 

      // Fim de Arquivo.
      cReport += "9" + cSepCol 
      cReport += alltrim(str(hLote["LOTE"])) + cSepCol 
      cReport += alltrim(str(nLines)) + cSepCol
      cReport += alltrim(str(nValTot)) + cSepCol
      cReport += cSepLine

   endif

   // Registra que o lote foi enviado.
   pu_AddLogLote( hLote, len(aCupons), nValTot, cReport )

END SEQUENCE

return cReport

****************************************************************************************************
static function pu_Pdv2Omie( cReport, aCupons, cPathNF, hLote )
****************************************************************************************************

local hCupom := {=>}
local cMsg := ""
local aFunc
local aFunc2
local aFunc4
local cCateg
local cMd5 := ""
local cFile := strzero(hLote["LOTE"],15)
local hResponse
local cCodStatus := ""
local cDesStatus := ""
local cXml := ""

if pu_IsLog("CX") == "S"
   
   cPathNF += "omie\cupomfiscalcsv\"
   
   if !IsDir(cPathNF)
      DirMake(cPathNF)
   endif
   
   // Grava uma cÛpia do arquivo enviado.

   SaveFile( cPathNF+cFile+"_source"+".txt", cReport )

endif

// Salva o arquivo.

cReport := pu_ZipData( hLote["LOTE"], cReport )

cMd5    := hb_md5(cReport)

// Faz o Consumo.

aFunc  := { "cupomfiscalcsv", "Enviar", "CsvEnviarRequest" }

aFunc2 := { {"nLote", "integer", alltrim(str(hLote["LOTE"])),0}, ;
            {"cFile", "string",  cReport,0}, ;
            {"cMd5",  "string",  cMd5,0} }

aFunc4 := { "CsvEnviarResponse" }

cCateg := "produtos"

// <wsdl:Enviar soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
//    <CsvEnviarRequest xsi:type="wsdl:CsvEnviarRequest">
//       <nLote xsi:type="xsd:integer">4292373</nLote>
//       <cFile xsi:type="xsd:string">file</cFile>
//       <cMd5 xsi:type="xsd:string">377b305d099736bfdcf3c500201d108f</cMd5>
//    </CsvEnviarRequest>
// </wsdl:Enviar>

pu_EraseFile( aFunc[1] )

cria_xml_omie( cCateg, aFunc, aFunc2 )

cXml := pu_EnviaXml( "https://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/", DIR_TEMP+"\"+aFunc[1]+".xml", DIR_TEMP+"\"+aFunc[1]+"_ret.xml", "", "",;
                      "https://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/?WSDL"+aFunc[2], "text/xml;charset=UTF-8", 0, pu_IsLog("WS") )

// Grava o arquivo no backup.

if pu_IsLog("XML") == "S"

   copyfile( DIR_TEMP+"\"+aFunc[1]+".xml"    , cPathNF+cFile+"_"+aFunc[1]+".xml")
   copyfile( DIR_TEMP+"\"+aFunc[1]+"_ret.xml", cPathNF+cFile+"_"+aFunc[1]+"_ret.xml")

endif

// <ns1:EnviarResponse>
//   <CsvEnviarResponse xsi:type="ns1:CsvEnviarResponse">
//     <nLote xsi:type="xsd:integer">4798088</nLote>
//     <cCodStatus xsi:type="xsd:string">0</cCodStatus>
//     <cDescStatus xsi:type="xsd:string">Lote importado com sucesso!</cDescStatus>
//   </CsvEnviarResponse>
// </ns1:EnviarResponse>

hResponse := pu_GetResponse( , cXml, "EnviarResponse", .T., , .F. )

if hResponse["ok"]

   cCodStatus := pu_GetValueTag( hResponse["source"], { "EnviarResponse", "CsvEnviarResponse", "cCodStatus" }, "C" ) 
   cDesStatus := pu_GetValueTag( hResponse["source"], { "EnviarResponse", "CsvEnviarResponse", "cDescStatus" }, "C" ) 

   pu_UpdLogLote( hLote, cCodStatus, cDesStatus )

   // if pu_IsLog() == "S"
   //    if cCodStatus == "0"
   //       MsgInfo( "Lote ["+alltrim(str(hLote["LOTE"]))+"] importado com sucesso! " + CRLF + CRLF + cDesStatus )
   //    else
   //       if cCodStatus > "0"
   //          MsgInfo( "Ops! Falha ao importar o lote ["+alltrim(str(hLote["LOTE"]))+"]! " + CRLF + CRLF + cCodStatus + " - " + cDesStatus )
   //       endif
   //    endif   
   // endif

   if cCodStatus <> "0"

      cMsg := "Ops! Nao foi possÌvel enviar os lanÁamentos do caixa para o aplicativo Omie. Tente enviar novamente mais tarde." + CRLF + ;
              cDesStatus

      MsgInfo( cMsg, SYSTEM_NAME )

   endif

endif

if empty(cCodStatus)

   cMsg := "Ops! Nao foi possÌvel enviar os lanÁamentos para o aplicativo Omie." + CRLF

   if hResponse["error"]
      cMsg += hResponse["msg"] 
   endif

   pu_UpdLogLote( hLote, "777", strtran( cMsg, CRLF, "" ) )

   MsgInfo( cMsg, SYSTEM_NAME )

else  

   // Marcar que os cupons foram enviados.
   
   if cCodStatus == "0"
   
      // Marca que enviou o lote com sucesso, apenas se o caixa j· estiver fechado.
      // O caixa aberto È enviado apenas para efeito de visualizaÁao na tela.
   
      if hLote["FECHADO"]=="S" .or. hLote["ACAO"] == "UPD"
      
         hLote["ENVIADO"] := .T.
      
         for each hCupom in aCupons
            hCupom["ENVIADO"] := .T.
         next
      
      endif
   
   endif   

endif

return aCupons

****************************************************************************************************
static function pu_ZipData( nLote, cReport )
****************************************************************************************************
local oZip 
local cFile := DIR_TEMP+"\"+"cf"+strzero(nLote,15)

if file(cFile+".txt")
   ferase(cFile+".txt")
endif

if file(cFile+".zip")
   ferase(cFile+".zip")
endif

if file(cFile+".enc")
   ferase(cFile+".enc")
endif

SaveFile( cFile+".txt", cReport )

// Gera o ZIP do arquivo a ser enviado.

oZip := TZip():New(cFile+".zip", 1 )

oZip:AddFiles( { cFile+".txt" } )

oZip:end()

HB_Base64EncodeFile( cFile+".zip", cFile+".enc" )

cReport := memoread(cFile+".enc")

if file(cFile+".txt")
   ferase(cFile+".txt")
endif

if file(cFile+".zip")
   ferase(cFile+".zip")
endif

if file(cFile+".enc")
   ferase(cFile+".enc")
endif

return cReport

****************************************************************************************************
static function pu_PdvCheck( aCupons, hLote )
****************************************************************************************************

local hCupom := {=>}
local aItens := {}
local hitem  := {=>}

if hLote["ENVIADO"] 

   if hLote["ACAO"] == "ADD" 

      _CAIXA->(dbGoTo(hLote["NRECNO"]))

      _CAIXA->FLAG := "X"

      for each hCupom in aCupons
         
         if hCupom["ENVIADO"]
      
            _CUPOM->(dbGoTo(hCupom["NRECNO"]))
      
            _CUPOM->OMIE := .T.

            // Marca os itens os itens 

            if _ESTAT->(dbSeek( hCupom["NUM_VENDA"] ))

               do while _ESTAT->CUPOM = hCupom["NUM_VENDA"] .and. !_ESTAT->(eof())

                  _ESTAT->OMIE := .T.
                  _ESTAT->(dbSkip())

               enddo

            endif

            if _CUPOM->TIPO=="CH"
               if _CHEQUES->(dbSeek( hCupom["NUM_VENDA"] ))
                  _CHEQUES->OMIE := .T.
               endif
            endif

            // Indica que a NFCE / SAT foram enviados para o Omie.

            do case 
            case hCupom["MODELO"] == "65" .AND. hCupom["NFCE_NRECNO"] > 0 // NFCE

               _NFCCAB->(dbGoTo(hCupom["NFCE_NRECNO"]))

               _NFCCAB->OMIE := .T.

               if hCupom["NFCE_CANC"]=="S"
                  _NFCCAB->OMIE_CANC := .T.
               else
                  _NFCCAB->OMIE_CANC := .F.
               endif

               if hCupom["NFCE_INUT"]=="S"
                  _NFCCAB->OMIE_INUT := .T.
               else
                  _NFCCAB->OMIE_INUT := .F.
               endif

               if hCupom["NFCE_CONT"]=="S"
                  _NFCCAB->OMIE_CONT := .T.
               else
                  _NFCCAB->OMIE_CONT := .F.
               endif

               // Se a NFCe foi enviada em contigencia, ela precisar· ser enviada novamente, assim que a nota for processada. 
               
               // if _NFCCAB->CONTINGENC
               //    pu_AddPendencia( _CUPOM->CX, hCupom["MODELO"], _CUPOM->CUPOM, _CUPOM->COO, "CTG" )
               // endif

            case hCupom["MODELO"] == "59" .AND. hCupom["SAT_NRECNO"] > 0 // SAT
            
               _SATFISCAL->(dbGoTo(hCupom["SAT_NRECNO"]))

               _SATFISCAL->OMIE := .T.

               if hCupom["SAT_CANC"]=="S"
                  _SATFISCAL->OMIE_CANC := .T.
               else
                  _SATFISCAL->OMIE_CANC := .F.
               endif

            endcase

         endif 
      
      next
   
   else

      for each hCupom in aCupons

         if hCupom["PEND_NRECNO"] > 0
      
            _OMIEPEND->(dbGoTo(hCupom["PEND_NRECNO"]))
      
            _OMIEPEND->ENVIADO := "S"
            _OMIEPEND->DTENV   := date()
            _OMIEPEND->HRENV   := time()

            // Indica que a NFCE / SAT foram enviados para o Omie.

            do case 
            case hCupom["MODELO"] == "65" .AND. hCupom["NFCE_NRECNO"] > 0 // NFCE

               _NFCCAB->(dbGoTo(hCupom["NFCE_NRECNO"]))

               if hCupom["NFCE_CANC"]=="S" .and. hCupom["ACAO"]=="CAN" .and. !_NFCCAB->OMIE_CANC
                  _NFCCAB->OMIE_CANC := .T.
               endif

               if hCupom["NFCE_INUT"]=="S" .and. hCupom["ACAO"]=="INU" .and. !_NFCCAB->OMIE_INUT
                  _NFCCAB->OMIE_INUT := .T.
               endif

               if hCupom["NFCE_CONT"]=="N" .and. hCupom["ACAO"]=="CTG" .and. _NFCCAB->OMIE_CONT
                  _NFCCAB->OMIE_CONT := .F.
               endif

            case hCupom["MODELO"] == "59" .AND. hCupom["SAT_NRECNO"] > 0 // SAT
            
               _SATFISCAL->(dbGoTo(hCupom["SAT_NRECNO"]))

               if hCupom["SAT_CANC"]=="S" .and. hCupom["ACAO"]=="CAN" .and. !_SATFISCAL->OMIE_CANC
                  _SATFISCAL->OMIE_CANC := .T.
               endif

            endcase

         endif 
      
      next

   endif

endif

return .t.

****************************************************************************************************
**
** UTILITIES
**
****************************************************************************************************

****************************************************************************************************
function cria_xml_omie( cCateg, aFunc, aFunc2, aFunc3 )
****************************************************************************************************
local x, y, z

local cPath := ""
local cTxt  := ""

cTxt += '<?xml version="1.0" encoding="UTF-8"?>'  // ISO-8859-1
cTxt += '<soapenv:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:wsdl="http://app.omie.com.br/api/v1/'+cCateg+'/'+aFunc[1]+'/?WSDL">'
cTxt +=    '<soapenv:Header>'
cTxt +=       '<app_key>'    + Key    + '</app_key>'
cTxt +=       '<app_secret>' + Secret + '</app_secret>'
cTxt +=    '</soapenv:Header>'
cTxt +=    '<soapenv:Body>'
cTxt +=       '<wsdl:'+aFunc[2]+' soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'

if !empty(aFunc[3])
   cTxt += '<'+aFunc[3]+'>'
endif

for x=1 to len(aFunc2)
   if aFunc2[x][4]=1 .and. !empty(aFunc3)
      cTxt += '<'+aFunc2[x][1]+' xsi:type="wsdl:'+aFunc2[x][1]+aFunc2[x][2]+'" soapenc:arrayType="wsdl:'+aFunc2[x][1]+'['+aFunc2[x][3]+']">'
      for y := 1 to len(aFunc3)
         cTxt += '<item xsi:type="wsdl:'+aFunc2[x][1]+'">'
         for z=1 to len(aFunc3[1])
            cTxt += '<'+aFunc3[y][z][1]+'>'+aFunc3[y][z][3]+'</'+aFunc3[y][z][1]+'>'
         next
         cTxt += '</item>'
      next
      cTxt += '</'+aFunc2[x][1]+'>'
   else
      cTxt += iif(empty(aFunc[3]),"","")+'<'+aFunc2[x][1]+'>'+aFunc2[x][3]+'</'+aFunc2[x][1]+'>'
   endif
next

if !empty(aFunc[3])
   cTxt += '</' + aFunc[3] + '>'
endif

cTxt +=       '</wsdl:'+aFunc[2]+'>'
cTxt +=    '</soapenv:Body>'
cTxt += '</soapenv:Envelope>'

SaveFile( DIR_TEMP+"\"+aFunc[1]+".xml", cTxt )

///////////////////////////////////////////////////////////////////////////////////////////////////

// Guarda uma cÛpia dos XMLs gerados.

if pu_IsLog( "XML" ) == "S"

   cPath := CurDrive() + ":\" + CurDir() + "\" + "omie" + "\" + alltrim(cCateg) + "\"
   
   if !IsDir(cPath)
      DirMake(cPath)
   endif
   
   cPath += aFunc[1]+"\"
   
   if !IsDir(cPath)
      DirMake(cPath)
   endif
   
   SaveFile( cPath+aFunc[2]+"_"+strzero(pu_GetLote(),12)+".xml", cTxt )

endif

///////////////////////////////////////////////////////////////////////////////////////////////////

return cTxt

****************************************************************************************************
function pu_EnviaXml( cURL, cXml, rXml, cCert, cSenha, cSoapAction, cContentType, nTimeOut, cExibeLog, cKey )
****************************************************************************************************
LOCAL cRet := ""
local oUrl
local oWebService
local cPath := ""
local cFile  := ""
local cFile2 := "wssend.log"
local aDir_ := {}
local cString := ""
Local oTempo:=0 ,wTime,xTempo

default cSoapAction  := ""
default cContentType := ""
default nTimeOut     := 0
default cExibeLog    := "N"

IF GetStatus("ATIVALOGWS")
   cExibeLog := "S"
Endif

if file(cXml)
   cXml := memoread(cXml)
endif

IF !SysVerifyActiveUrl()
   MsgStop("Erro ao conectar na internet, por favor verifique o acesso a internet.", SYSTEM_NAME)
   cRet:="erro"
   Return cRet
Endif

Try
   oUrl := tURLSSL():New( cUrl )
Catch
   Try
      oUrl := tURLSSL():New( cUrl )
   Catch
      MsgStop("Erro ao Acessar o Webservice: "+CRLF+cURL+CRLF+"Verifique a conexao da internet ou se o EndereÁo Webservice est· correto.",SYSTEM_NAME)
      cRet:="erro"
      Return cRet
   end
end

Try
   oWebService := tIPCntSSLHTTP():New( oUrl,cExibeLog="S",,,,cCert,,cSenha)
Catch
   Try
      oWebService := tIPCntSSLHTTP():New( oUrl,cExibeLog="S",,,,cCert,,cSenha)
   Catch
      MsgStop("Erro ao Acessar o Webservice: "+CRLF+cURL+CRLF+"Verifique a conexao da internet ou se o EndereÁo Webservice est· correto.",SYSTEM_NAME)
      cRet:="erro"
      Return cRet
   end
end

if nTimeOut=0
   oWebService:nConnTimeout := 90000
else
   oWebService:nConnTimeout := nTimeOut
endif

if !empty(cContentType)
   oWebService:hFields['Content-Type'] := cContentType
else
   oWebService:hFields['Content-Type'] := 'application/soap+xml;charset=utf-8'
endif

if !empty(cSoapAction)
   oWebService:hFields['SOAPAction'] := cSoapAction
endif

oWebService:cConnetion:= 'Keep-Alive'

oWebService:cUserAgent := 'XHB-SOAP/1.2.1'

Ferase(rXml)

xtempo := 2
oTempo := GetPvProfint("TENTATIVASWS","QTD","",m->dirlocal+"\SysFar.Ini") 

if oTempo=0
   oTempo:=2
Endif

Do While .T.
   
   sysrefresh()
   
   IF oWebService:Open()
      
      IF oWebService:Post(cXml)
         cRet := oWebService:ReadAll()
      ENDIF
   
      if Empty(cRet) // Se Nao houve retorno ainda... tenta novamente
         xtempo++ 
         if oTempo>xtempo 
            MsgInfo('Tempo limite de espera atingido, para aumentar o tempo limite pressione F11-> 5 Config ->Tempo limite espera do retorno WebService []',SYSTEM_NAME)
            Exit    // Se For maior que o tempo de espera forÁa saida
         ENDIF
         SysWait(1)
         oWebService:close()
      Else
         Exit      // Se houve retorno encerra While
      ENDIF
   Else
      xtempo++ 
      if oTempo>xtempo
         MsgInfo('Tempo limite de espera atingido, para aumentar o tempo limite pressione F11-> 5 Config ->Tempo limite espera do retorno WebService []',SYSTEM_NAME)
         Exit     // Se For maior que o tempo de espera forÁa saida
      Endif
      SysWait(1)
   ENDIF

Enddo  

if oWebService:ltrace .and. oWebService:nhandle > -1
   fClose( oWebService:nHandle )
   oWebService:nhandle := -1
endif

oWebService:close()  

if !SaveFile( rXml, cRet)
   MsgStop("Erro Retorno:" +rXml)
endif

return cRet

****************************************************************************************************
static function pu_GetResponse( cFileXml, cXml, cTagName, lUtf8toLatin1, lLatin1toUtf8, lAttrib )
****************************************************************************************************
local aRet            := {}
local hResponse       := {=>}
local cXmlAux         := ""

default cFileXml      := ""
default cXml          := ""
default cTagName      := ""
default lUtf8toLatin1 := .F. 
default lLatin1toUtf8 := .F.
default lAttrib       := .T.

hResponse["ok"]          := .F.
hResponse["error"]       := .F.
hResponse["warn"]        := .F.

hResponse["msg"]         := ""
hResponse["source"]      := {=>}
hResponse["xml"]         := ""
hResponse["fault"]       := {=>}
hResponse["faultcode"]   := ""
hResponse["faultstring"] := ""
hResponse["detail"]      := ""

hResponse["source"]      := {=>}

hResponse["Alerts"]      := {=>}
hResponse["omie_fail"]   := {}

if empty(cXml) .and. empty(cFileXml)
   return hResponse
endif

if empty(cXml) 

   if !file(cFileXml)
      return hResponse
   endif

   cXml := memoread(cFileXml)   

   if empty(cXml) 
      return hResponse
   endif

endif

hResponse["xml"] := cXml

// pu_RemEnvSoap( cSoapMessage, cTagName, lToString, lClearXml, cHeadXml, lConvertXML )

aRet := pu_RemEnvSoap( hResponse["xml"], cTagName, .T., .F., "", .F. )

if !aRet[1]
   
   hResponse["xml"] := aRet[3]

   if lUtf8toLatin1
      hResponse["xml"] := utf8tolatin1(hResponse["xml"])
   endif

   if lLatin1toUtf8
      hResponse["xml"] := latin1toutf8(hResponse["xml"])
   endif

   hResponse["source"] := pu_XMLtoHash( hResponse["xml"], lAttrib )

   if !empty(hResponse["source"])
      hResponse["ok"] := .T.
   endif

else
   hResponse["msg"] := "Ocorreu o seguinte erro na comunicaÁao como o aplicativo Omie:" + CRLF + aRet[2]
endif

// Se nao conseguiu ler o XML 

if ! hResponse["ok"] 

   // <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
   //    <SOAP-ENV:Header>
   //       <Alerts>
   //          <omie_fail>
   //             <code>5094</code>
   //             <description>Nenhum registro foi encontrado!</description>
   //             <referer/>
   //             <fatal>false</fatal>
   //          </omie_fail>
   //       </Alerts>
   //    </SOAP-ENV:Header>
   //    <SOAP-ENV:Body>
   //       <SOAP-ENV:Fault>
   //          <faultcode>SOAP-ENV:Client-5113</faultcode>
   //          <faultstring>SOAP-ERROR: Nao existem registros para a p·gina [1]!</faultstring>
   //       </SOAP-ENV:Fault>
   //    </SOAP-ENV:Body>
   // </SOAP-ENV:Envelope>

   aRet := pu_RemEnvSoap( cXml, "Fault", .T., .F., "", .F. )
   
   if !aRet[1]
      
      cXml := aRet[3]
   
      if lUtf8toLatin1
         cXml := utf8tolatin1(cXml)
      endif
   
      if lLatin1toUtf8
         cXml := latin1toutf8(cXml)
      endif
   
      hResponse["fault"] := pu_XMLtoHash( cXml, lAttrib )
   
      if !empty(hResponse["fault"])
         hResponse["error"]       := .T.
         hResponse["faultcode"]   := strtran(pu_GetValueTag( hResponse["fault"], { "Fault", "faultcode" }, "C" ),"SOAP-ENV:") 
         hResponse["faultstring"] := strtran(pu_GetValueTag( hResponse["fault"], { "Fault", "faultstring" }, "C" ),"SOAP-ERROR:") 
         hResponse["detail"]      := alltrim(pu_GetValueTag( hResponse["fault"], { "Fault", "detail" }, "C" ))

         if !empty(hResponse["faultcode"])
            hResponse["msg"] := hResponse["faultcode"] + " " + hResponse["faultstring"] + " " + hResponse["detail"] 
         endif

      endif
   
   endif

   aRet := pu_RemEnvSoap( hResponse["xml"], "Alerts", .T., .F., "", .F. )
   
   if !aRet[1]
      
      cXml := aRet[3]
   
      if lUtf8toLatin1
         cXml := utf8tolatin1(cXml)
      endif
   
      if lLatin1toUtf8
         cXml := latin1toutf8(cXml)
      endif
   
      hResponse["Alerts"] := pu_XMLtoHash( cXml, lAttrib )

      if !empty(hResponse["Alerts"])
         hResponse["warn"] := .T.
         hResponse["omie_fail"] := pu_GetValueTag( hResponse["Alerts"], { "Alerts", "omie_fail" }, "A" ) 
      endif
   
   endif

endif

return hResponse

****************************************************************************************************
static function pu_RemEnvSoap( cSoapMessage, cTagName, lToString, lClearXml, cHeadXml, lConvertXML )
****************************************************************************************************
local oXmlDoc, oXmlNode

local cXml   := ""
local hRet   := {=>} 

default cSoapMessage := ""
default cTagName     := ""
default lToString    := .F.
default lClearXml    := .F.
default cHeadXml     := ""
default lConvertXML  := .T.

// Testa se recebeu os par‚metros corretamente

if empty(cSoapMessage)
   return { .T., "pu_RemEnvSoap - Envelope SOAP nao foi informado!", cXml }
else
   cXml := cSoapMessage
endif

if empty(cTagName)
   return { .T., "pu_RemEnvSoap - Tag a ser extraÌda do Envelope SOAP nao foi informada!", cXml }
endif

* Elimina do XML os namespaces ( NS1: / xsd: / ca: )

cXml := cSoapMessage

cSoapMessage := pu_FindXmlNs(cSoapMessage)

if empty(cSoapMessage)
   return { .T., "pu_RemEnvSoap - Falha ao remover namespaces do Envelope SOAP! (Ns)", cXml }
endif

* Elimina do XML prefixos de nomes de tags com ".".
* Traduz <ws_nfe.PROCESSARPSResponse xmlns="NFe"> para <PROCESSARPSResponse xmlns="NFe">
* para que seja possÌvel ler com o tXmlDocument.

cXml := cSoapMessage
                  
cSoapMessage := pu_FindXmlNsDot(cSoapMessage)

if empty(cSoapMessage)
   return { .T., "pu_RemEnvSoap - Falha ao remover namespaces do Envelope SOAP! (NsDot)", cXml }
endif

// Tira as referencias de cabeÁalho.

if lClearXml
   cSoapMessage := strtran( cSoapMessage, cHeadXml, "" )
   cSoapMessage := strtran( cSoapMessage, "&", "" )
endif

// Verifica se a estrutura do XML do Envelope SOAP È v·lido.

cXml := cSoapMessage

hRet := pu_CheckXml( cSoapMessage )

if hRet["StatusCode"]<>"OK" .or. hRet["ErrorCode"] <> "NONE"
   return { .T., "pu_RemEnvSoap - " + hRet["ErrorCode"] + " - " + hRet["ErrorDesc"], cXml }
endif

* Remove a mensagem XML do Envelope SOAP.

*   cSoapMessage:
*
*   <?xml version="1.0" encoding="utf-8"?>
*   <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
*      <soap:Body>
*         <CancelarNfseResponse xmlns="http://www.abrasf.org.br/nfse.xsd">
*            <CancelarNfseResult>&lt;?xml version="1.0" encoding="utf-8"?&gt;&lt;CancelarNfseResposta xmlns:xs="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.abrasf.org.br/nfse.xsd"&gt; &lt;ListaMensagemRetorno&gt; &lt;MensagemRetorno&gt; &lt;Codigo&gt;E78&lt;/Codigo&gt; &lt;Mensagem&gt;N˙mero da NFS-e inexistente na base de dados para o prestador do serviÁo pesquisado.&lt;/Mensagem&gt; &lt;Correcao&gt;Informe corretamente o n˙mero da NFS-e.&lt;/Correcao&gt; &lt;/MensagemRetorno&gt; &lt;/ListaMensagemRetorno&gt;&lt;/CancelarNfseResposta&gt;</CancelarNfseResult>
*         </CancelarNfseResponse>
*      </soap:Body>
*   </soap:Envelope>
*
*  cTagName: CancelarNfseResult

oXmlDoc := TXmlDocument():new( cSoapMessage )

// Ocorreu erro ao ler o XML.

oXmlNode := oXmlDoc:findFirst( cTagName )

if valtype(oXmlNode)="O"
   if lToString
      cXml := oXmlNode:toString()
      cXml := strtran( cXml, [<?xml version='1.0' encoding='utf-8'?>] )
      cXml := strtran( cXml, [<?xml version='1.0' encoding='UTF-8'?>] )      
   else
      cXml := oXmlNode:cData
      if cXml=NIL
         cXml := ""
      else   
         cXml := strtran( cXml, "<![CDATA[" )
         cXml := strtran( cXml, "]]>" )
         cXml := strtran( cXml, "&#xD;" )
         cXml := strtran( cXml, "&#xA;" )
         cXml := strtran( cXml, [<xml version="1.0" encoding="utf-8">] )
         cXml := strtran( cXml, [<xml version="1.0" encoding="UTF-8">] )
         cXml := strtran( cXml, [<xml version='1.0' encoding='utf-8'>] )
         cXml := strtran( cXml, [<xml version='1.0' encoding='UTF-8'>] )
      endif
   endif
else
   oXmlDoc  := NIL
   oXmlNode := NIL
   hb_gcall(.t.)
   return { .T., "pu_RemEnvSoap - tag [" + cTagName + "] nao foi encontrada no XML!", cXml }
endif

oXmlDoc  := NIL
oXmlNode := NIL
hb_gcall(.t.)

if empty(cXml)
   return { .T., "pu_RemEnvSoap - Nao foi possÌvel ler a mensagem XML de resposta!", cSoapMessage }
else

   // Faz o tratamento dos caracteres especiais do arquivo.

   if lConvertXML   
   
      cSoapMessage := cXml
   
      cXml := pu_Xml2Html(cXml)
   
      if empty(cXml)
         return { .T., "pu_RemEnvSoap - Falha ao tratar caracteres especiais da mensagem XML! (XtoH)", cSoapMessage }
      endif
   
   endif

   // Elimina do XML os namespaces ( NS1: / xsd: / ca: )

   cSoapMessage := cXml

   cXml := pu_FindXmlNs(cXml)

   if empty(cXml)
      return { .T., "pu_RemEnvSoap - Falha ao remover namespaces da mensagem XML! (Ns)", cSoapMessage }
   endif

   // Elimina do XML prefixos de nomes de tags com ".".
   // Traduz <ws_nfe.PROCESSARPSResponse xmlns="NFe"> para <PROCESSARPSResponse xmlns="NFe">
   // para que seja possÌvel ler com o tXmlDocument.
        
   cSoapMessage := cXml

   cXml := pu_FindXmlNsDot(cXml)

   if empty(cXml)
      return { .T., "pu_RemEnvSoap - Falha ao remover namespaces da mensagem XML! (NsDot)", cSoapMessage }
   endif

endif

return { .F., "", cXml }

****************************************************************************************************
static function pu_FindXmlNs( cText )
****************************************************************************************************
LOCAL cRegEx := "<[A-Za-z0-9._%-]+:"
LOCAL cInfo, nStart, nLen

if empty(cText)
   return cText
endif

do while .t.

   nStart := NIL
   nLen   := NIL

   cInfo := HB_AtX( cRegEx, cText, .F., @nStart, @nLen )

   if empty(cInfo)
      exit
   endif

   if left(cInfo,1)="<"
      cInfo := substr(cInfo,2)
   endif

   cText := strtran(cText,cInfo)

enddo

return cText

****************************************************************************************************
static function pu_FindXmlNsDot( cText )
****************************************************************************************************
LOCAL cRegEx := "<[A-Za-z0-9._%-]+[.]"
LOCAL cInfo, nStart, nLen

if empty(cText)
   return cText
endif

do while .t.

   nStart := NIL
   nLen   := NIL

   cInfo := HB_AtX( cRegEx, cText, .F., @nStart, @nLen )

   if empty(cInfo)
      exit
   endif

   if left(cInfo,1)="<"
      cInfo := substr(cInfo,2)
   endif

   cText := strtran(cText,cInfo)

enddo

return cText

****************************************************************************************************
static function pu_CheckXml( cXml, cTag )
****************************************************************************************************
local hRet := {=>}
local oXmlDoc 
local oXmlNode

hRet["StatusCode"] := ""
hRet["ErrorCode"]  := ""
hRet["ErrorDesc"]  := ""
hRet["TagName"]    := ""
hRet["TagFound"]   := ""

if valtype(cXml)<>"C"
   cXml := ""
endif

if valtype(cTag)<>"C"
   cTag := ""
endif

if empty(cXml)
   hRet["StatusCode"] := "ERROR"
   hRet["ErrorCode"]  := "EMPTY"
   hRet["ErrorDesc"]  := "Arquivo XML nao informado"
   return hRet
endif

if !empty(cTag)
   hRet["TagName"] := cTag
endif

oXmlDoc := TXmlDocument():new( cXml )

do case
case oXmlDoc:nStatus == 0 ; hRet["StatusCode"] := "ERROR"     // STATUS_ERROR    
case oXmlDoc:nStatus == 1 ; hRet["StatusCode"] := "OK"        // STATUS_OK       
case oXmlDoc:nStatus == 2 ; hRet["StatusCode"] := "MORE"      // STATUS_MORE     
case oXmlDoc:nStatus == 3 ; hRet["StatusCode"] := "DONE"      // STATUS_DONE     
case oXmlDoc:nStatus == 4 ; hRet["StatusCode"] := "UNDEFINED" // STATUS_UNDEFINED
case oXmlDoc:nStatus == 5 ; hRet["StatusCode"] := "MALFORMED" // STATUS_MALFORMED
endcase

do case 
case oXmlDoc:nError ==  0 ; hRet["ErrorCode"] := "NONE"                 
case oXmlDoc:nError ==  1 ; hRet["ErrorCode"] := "IO"                   
case oXmlDoc:nError ==  2 ; hRet["ErrorCode"] := "NOMEM"                
case oXmlDoc:nError ==  3 ; hRet["ErrorCode"] := "OUTCHAR"              
case oXmlDoc:nError ==  4 ; hRet["ErrorCode"] := "INVNODE"              
case oXmlDoc:nError ==  5 ; hRet["ErrorCode"] := "INVATT"               
case oXmlDoc:nError ==  6 ; hRet["ErrorCode"] := "MALFATT"              
case oXmlDoc:nError ==  7 ; hRet["ErrorCode"] := "INVCHAR"              
case oXmlDoc:nError ==  8 ; hRet["ErrorCode"] := "NAMETOOLONG"          
case oXmlDoc:nError ==  9 ; hRet["ErrorCode"] := "ATTRIBTOOLONG"        
case oXmlDoc:nError == 10 ; hRet["ErrorCode"] := "VALATTOOLONG"        
case oXmlDoc:nError == 11 ; hRet["ErrorCode"] := "UNCLOSED"            
case oXmlDoc:nError == 12 ; hRet["ErrorCode"] := "UNCLOSEDENTITY"   
case oXmlDoc:nError == 13 ; hRet["ErrorCode"] := "WRONGENTITY"      
endcase

hRet["ErrorDesc"] := HB_XmlErrorDesc( oXmlDoc:nError )

if !empty(hRet["TagName"])

   oXmlNode := oXmlDoc:findfirst( hRet["TagName"] )

   if oXmlNode == NIL
      hRet["TagFound"] := "false"
   else
      hRet["TagFound"] := "true"
   endif

endif

oXmlDoc := NIL

hb_gcall(.t.)

return hRet

****************************************************************************************************
static function pu_XMLtoHash( cXml, lAttrib )
****************************************************************************************************
local hHash := {=>}
local oXmlDoc 

if empty(cXml)
   return hHash
endif

if at( "<?xml", cXml ) = 0
   cXml := [<?xml version='1.0' encoding='utf-8'?>] + cXml
endif

oXmlDoc := TXmlDocument():new( cXml )

hHash   := pu_NodeToHash( oXmlDoc:oRoot:oChild, lAttrib ) 

oXmlDoc := NIL

hb_gcall(.t.)

return hHash

****************************************************************************************************
static function pu_NodeToHash( oXmlNode, lAttrib )
****************************************************************************************************
local hHash := {=>}
local hComp := {=>}
local aTags := {}
local cName := ""
local cData := ""
local cTag  := ""
local hAux
local nAux
local hAttrib := {=>}
local nPos  := 0

local oXmlNode2

default lAttrib := .T.

if oXmlNode <> NIL

   while oXmlNode <> NIL

      hHash     := {=>}
      oXmlNode2 := oXmlNode:oChild

      cName     := oXmlNode:cName
      cData     := oXmlNode:cData

      if lAttrib
         hAttrib := oXmlNode:aAttributes
      else
         hAttrib := {}
      endif

      if cName=NIL
         cName := "Root"
      endif

      if cData=NIL
         cData := ""
      endif

      if oXmlNode2 = NIL 
         hHash[cName] := cData
      else
         hHash[cName] := pu_NodeToHash( oXmlNode2, lAttrib )  
      endif

      do case
      case valtype(hHash[cName]) = "H"

         if len(hAttrib)>0
            hHash[cName]["attributes"] := hAttrib
         endif

      case valtype(hHash[cName]) = "A"

         if len(hAttrib)>0

            nPos := AScan( hHash[cName], {|hItemX| hHasKey( hItemX, "attributes") } )

            if nPos = 0
               aadd( hHash[cName], { "attributes" => hAttrib } )
            else
               hHash[cName][nPos]["attributes"] := hAttrib
            endif

         endif

      case valtype(hHash[cName]) = "C"

         if len(hAttrib)>0
            hHash[cName] := { cName => hHash[cName], "attributes" => hAttrib }
         endif

      endcase

      aadd( aTags, hHash )          

      oXmlNode := oXmlNode:oNext

   enddo

   do case
   case len(aTags) = 1 ; hHash := aTags[1]
   case len(aTags) > 1 ; hHash := aclone(aTags)
   endcase

   if valtype(hHash)="A"
      
      hComp := {=>}
      
      for nAux := 1 to len(hHash)

         hAux := hHash[nAux]

         if valtype(hAux)="H"

            cTag := HGetKeyAt( hAux, 1 )

            if len(hComp)>0 .and. hHasKey( hComp, cTag ) 
               hComp := {=>}
               exit
            else
               hComp[cTag] := hAux[cTag]
            endif

         endif
      next
      
      if len(hComp)>0
         hHash := hComp
      endif

   endif

endif

oXmlNode2 := NIL

return hHash

****************************************************************************************************
static function pu_GetValueTag( hHash, aTags, cType )
****************************************************************************************************
local cTag   := ""
local cValue := ""
local aAux   := ""
local hAux   := {=>}
local hItem  := {=>}

default hHash := {=>}
default aTags := {}
default cType := "H"

if valtype(aTags)="C"
   if empty(aTags)
      return cValue
   else
      aTags := { aTags }
   endif
endif

if len(hHash)=0 .or. len(aTags)=0
   return cValue
endif

hAux := hHash

for each cTag in aTags
   
   do case
   case valtype(hAux)="H"

      if hHasKey( hAux, cTag )
         hAux := hAux[cTag]
      else
         exit
      endif   

   case valtype(hAux)="A"
   
      for each hItem in hAux
         
         do case
         case valtype(hItem)="H"
      
            if hHasKey( hItem, cTag )
               hAux := hItem[cTag]
               exit
            endif   
         
         case valtype(hItem)="A"
            
            hAux := hItem
            exit

         endcase   

      next 

   endcase

   if HB_EnumIndex() = len(aTags) 
      cValue := hAux
   endif

next 

if cType="A" .and. valtype(cValue)="H" 
   cValue := {cValue}
endif

if cType="C" .and. valtype(cValue)="U" 
   cValue := ""
endif

if valtype(cValue)="H" 

   cTag := aTags[len(aTags)]
   
   if len(cValue)==2 .and. hHasKey(cValue,"attributes") .and. hHasKey( cValue, cTag ) .and. valtype(cValue[cTag])=="C"
      cValue := cValue[cTag]
   endif

endif

return cValue

****************************************************************************************************
static function pu_Xml2Html( cTexto )
****************************************************************************************************
local i, char_

if "&" $ cTexto

   char_ := {}
         
   AAdd( char_, { "&#34;" , chr(34) } ) //(aspas duplas)
   AAdd( char_, { "&#38;" , "&" } )
   AAdd( char_, { "&#39;"  , "'" } )
   AAdd( char_, { "&#60;"  , "<" } )
   AAdd( char_, { "&#62;"  , ">" } )
   AAdd( char_, { "&#161;" , "?" } )
   AAdd( char_, { "&#162;" , "c" } )
   AAdd( char_, { "&#163;" , "?" } )
   AAdd( char_, { "&#164;" , "§" } )
   AAdd( char_, { "&#165;" , "û" } )
   AAdd( char_, { "&#166;" , "?" } )
   AAdd( char_, { "&#167;" , "ß" } )
   AAdd( char_, { "&#168;" , "®" } )
   AAdd( char_, { "&#169;" , "?" } )
   AAdd( char_, { "&#170;" , "a" } )
   AAdd( char_, { "&#171;" , "ç" } )
   AAdd( char_, { "&#172;" , "?" } )
   AAdd( char_, { "&#173;" , "≠" } )
   AAdd( char_, { "&#45;"  , "-" } )
   AAdd( char_, { "&#174;" , "é" } )
   AAdd( char_, { "&#175;" , "?" } )
   AAdd( char_, { "&#176;" , "∞" } )
   AAdd( char_, { "&#177;" , "?" } )
   AAdd( char_, { "&#178;" , "2" } )
   AAdd( char_, { "&#179;" , "3" } )
   AAdd( char_, { "&#180;" , "¥" } )
   AAdd( char_, { "&#181;" , "?" } )
   AAdd( char_, { "&#182;" , "ü" } )
   AAdd( char_, { "&#183;" , "?" } )
   AAdd( char_, { "&#184;" , "∏" } )
   AAdd( char_, { "&#185;" , "ë" } )
   AAdd( char_, { "&#186;" , "o" } )
   AAdd( char_, { "&#187;" , "?" } )
   AAdd( char_, { "&#188;" , "." } )
   AAdd( char_, { "&#189;" , "?" } )
   AAdd( char_, { "&#190;" , "?" } )
   AAdd( char_, { "&#191;" , "?" } )
   AAdd( char_, { "&#192;" , "A" } )
   AAdd( char_, { "&#193;" , "¡" } )
   AAdd( char_, { "&#194;" , "¬" } )
   AAdd( char_, { "&#195;" , "A" } )
   AAdd( char_, { "&#196;" , "ƒ" } )
   AAdd( char_, { "&#197;" , "A" } )
   AAdd( char_, { "&#198;" , "A" } )
   AAdd( char_, { "&#199;" , "«" } )
   AAdd( char_, { "&#200;" , "E" } )
   AAdd( char_, { "&#201;" , "…" } )
   AAdd( char_, { "&#202;" , "E" } )
   AAdd( char_, { "&#203;" , "À" } )
   AAdd( char_, { "&#204;" , "I" } )
   AAdd( char_, { "&#205;" , "Õ" } )
   AAdd( char_, { "&#206;" , "Œ" } )
   AAdd( char_, { "&#207;" , "I" } )
   AAdd( char_, { "&#208;" , "D" } )
   AAdd( char_, { "&#209;" , "N" } )
   AAdd( char_, { "&#210;" , "O" } )
   AAdd( char_, { "&#211;" , "”" } )
   AAdd( char_, { "&#212;" , "‘" } )
   AAdd( char_, { "&#213;" , "O" } )
   AAdd( char_, { "&#214;" , "÷" } )
   AAdd( char_, { "&#215;" , "◊" } )
   AAdd( char_, { "&#216;" , "O" } )
   AAdd( char_, { "&#217;" , "U" } )
   AAdd( char_, { "&#218;" , "⁄" } )
   AAdd( char_, { "&#219;" , "U" } )
   AAdd( char_, { "&#220;" , "‹" } )
   AAdd( char_, { "&#221;" , "›" } )
   AAdd( char_, { "&#222;" , "?" } )
   AAdd( char_, { "&#223;" , "ﬂ" } )
   AAdd( char_, { "&#224;" , "a" } )
   AAdd( char_, { "&#225;" , "·" } )
   AAdd( char_, { "&#226;" , "‚" } )
   AAdd( char_, { "&#227;" , "a" } )
   AAdd( char_, { "&#228;" , "‰" } )
   AAdd( char_, { "&#229;" , "a" } )
   AAdd( char_, { "&#230;" , "a" } )
   AAdd( char_, { "&#231;" , "Á" } )
   AAdd( char_, { "&#232;" , "e" } )
   AAdd( char_, { "&#233;" , "È" } )
   AAdd( char_, { "&#234;" , "e" } )
   AAdd( char_, { "&#235;" , "Î" } )
   AAdd( char_, { "&#236;" , "i" } )
   AAdd( char_, { "&#237;" , "Ì" } )
   AAdd( char_, { "&#238;" , "Ó" } )
   AAdd( char_, { "&#239;" , "i" } )
   AAdd( char_, { "&#240;" , "?" } )
   AAdd( char_, { "&#241;" , "n" } )
   AAdd( char_, { "&#242;" , "o" } )
   AAdd( char_, { "&#243;" , "Û" } )
   AAdd( char_, { "&#244;" , "Ù" } )
   AAdd( char_, { "&#245;" , "o" } )
   AAdd( char_, { "&#246;" , "ˆ" } )
   AAdd( char_, { "&#247;" , Chr(247) } ) //(simbolo de divisao)
   AAdd( char_, { "&#248;" , "o" } )
   AAdd( char_, { "&#249;" , "u" } )
   AAdd( char_, { "&#250;" , "˙" } )
   AAdd( char_, { "&#251;" , "u" } )
   AAdd( char_, { "&#252;" , "¸" } )
   AAdd( char_, { "&#253;" , "˝" } )
   AAdd( char_, { "&#254;" , "?" } )
   AAdd( char_, { "&#255;" , "y" } )

   AAdd( char_, { "&#x20;", " " } )
   AAdd( char_, { "&#x21;", "!" } )
   AAdd( char_, { "&#x22;", ["] } )
   AAdd( char_, { "&quot;", ["] } )
   AAdd( char_, { "&#x23;", "#" } )
   AAdd( char_, { "&#x24;", "$" } )
   AAdd( char_, { "&#x25;", "%" } )
   AAdd( char_, { "&#x26;", "&" } )
   AAdd( char_, { "&amp;" , "&" } )
   AAdd( char_, { "&#x27;", "'" } )
   AAdd( char_, { "&#x28;", "(" } )
   AAdd( char_, { "&#x29;", ")" } )
   AAdd( char_, { "&#x2A;", "*" } )
   AAdd( char_, { "&#x2B;", "+" } )
   AAdd( char_, { "&#x2C;", "," } )
   AAdd( char_, { "&#x2D;", "-" } )
   AAdd( char_, { "&#x2E;", "." } )
   AAdd( char_, { "&#x2F;", "/" } )
   AAdd( char_, { "&#x30;", "0" } )
   AAdd( char_, { "&#x31;", "1" } )
   AAdd( char_, { "&#x32;", "2" } )
   AAdd( char_, { "&#x33;", "3" } )
   AAdd( char_, { "&#x34;", "4" } )
   AAdd( char_, { "&#x35;", "5" } )
   AAdd( char_, { "&#x36;", "6" } )
   AAdd( char_, { "&#x37;", "7" } )
   AAdd( char_, { "&#x38;", "8" } )
   AAdd( char_, { "&#x39;", "9" } )
   AAdd( char_, { "&#x3A;", ":" } )
   AAdd( char_, { "&#x3B;", ";" } )
   AAdd( char_, { "&#x3C;", "<" } )
   AAdd( char_, { "&lt;"  , "<" } )
   AAdd( char_, { "&#x3D;", "=" } )
   AAdd( char_, { "&#x3E;", ">" } )
   AAdd( char_, { "&gt;"  , ">" } )
   AAdd( char_, { "&#x3F;", "?" } )
   AAdd( char_, { "&#x40;", "@" } )
   AAdd( char_, { "&#x41;", "A" } )
   AAdd( char_, { "&#x42;", "B" } )
   AAdd( char_, { "&#x43;", "C" } )
   AAdd( char_, { "&#x44;", "D" } )
   AAdd( char_, { "&#x45;", "E" } )
   AAdd( char_, { "&#x46;", "F" } )
   AAdd( char_, { "&#x47;", "G" } )
   AAdd( char_, { "&#x48;", "H" } )
   AAdd( char_, { "&#x49;", "I" } )
   AAdd( char_, { "&#x4A;", "J" } )
   AAdd( char_, { "&#x4B;", "K" } )
   AAdd( char_, { "&#x4C;", "L" } )
   AAdd( char_, { "&#x4D;", "M" } )
   AAdd( char_, { "&#x4E;", "N" } )
   AAdd( char_, { "&#x4F;", "O" } )
   AAdd( char_, { "&#x50;", "P" } )
   AAdd( char_, { "&#x51;", "Q" } )
   AAdd( char_, { "&#x52;", "R" } )
   AAdd( char_, { "&#x53;", "S" } )
   AAdd( char_, { "&#x54;", "T" } )
   AAdd( char_, { "&#x55;", "U" } )
   AAdd( char_, { "&#x56;", "V" } )
   AAdd( char_, { "&#x57;", "W" } )
   AAdd( char_, { "&#x58;", "X" } )
   AAdd( char_, { "&#x59;", "Y" } )
   AAdd( char_, { "&#x5A;", "Z" } )
   AAdd( char_, { "&#x5B;", "[" } )
   AAdd( char_, { "&#x5C;", "\" } )
   AAdd( char_, { "&#x5D;", "]" } )
   AAdd( char_, { "&#x5F;", "_" } )
   AAdd( char_, { "&#x61;", "a" } )
   AAdd( char_, { "&#x62;", "b" } )
   AAdd( char_, { "&#x63;", "c" } )
   AAdd( char_, { "&#x64;", "d" } )
   AAdd( char_, { "&#x65;", "e" } )
   AAdd( char_, { "&#x66;", "f" } )
   AAdd( char_, { "&#x67;", "g" } )
   AAdd( char_, { "&#x68;", "h" } )
   AAdd( char_, { "&#x69;", "i" } )
   AAdd( char_, { "&#x6A;", "j" } )
   AAdd( char_, { "&#x6B;", "k" } )
   AAdd( char_, { "&#x6C;", "l" } )
   AAdd( char_, { "&#x6D;", "m" } )
   AAdd( char_, { "&#x6E;", "n" } )
   AAdd( char_, { "&#x6F;", "o" } )
   AAdd( char_, { "&#x70;", "p" } )
   AAdd( char_, { "&#x71;", "q" } )
   AAdd( char_, { "&#x72;", "r" } )
   AAdd( char_, { "&#x73;", "s" } )
   AAdd( char_, { "&#x74;", "t" } )
   AAdd( char_, { "&#x75;", "u" } )
   AAdd( char_, { "&#x76;", "v" } )
   AAdd( char_, { "&#x77;", "w" } )
   AAdd( char_, { "&#x78;", "x" } )
   AAdd( char_, { "&#x79;", "y" } )
   AAdd( char_, { "&#x7A;", "z" } )
   AAdd( char_, { "&#x7B;", "{" } )
   AAdd( char_, { "&#x7C;", "|" } )
   AAdd( char_, { "&#x7D;", "}" } )
   AAdd( char_, { "&#x7E;", "~" } )
   AAdd( char_, { "&#xA1;", "?" } )
   AAdd( char_, { "&iexcl;","?" } )
   AAdd( char_, { "&#xA2;", "c" } )
   AAdd( char_, { "&cent;", "c" } )
   AAdd( char_, { "&#xA3;", "?" } )
   AAdd( char_, { "&pound;","?" } )
   AAdd( char_, { "&#xA6;"  , "?" } )
   AAdd( char_, { "&brvbar;", "?" } )
   AAdd( char_, { "&sect;"  , "ß" } )
   AAdd( char_, { "&sect;"  , "ß" } )
   AAdd( char_, { "&#xAA;"  , "a" } )
   AAdd( char_, { "&ordf;"  , "a" } )
   AAdd( char_, { "&#xAE;"  , "r" } )
   AAdd( char_, { "&reg;"   , "r" } )
   AAdd( char_, { "&#xB2;"  , "2" } )
   AAdd( char_, { "&sup2;"  , "2" } )
   AAdd( char_, { "&#xB3;"  , "3" } )
   AAdd( char_, { "&sup3;"  , "3" } )
   AAdd( char_, { "&#xB4;"  , "'" } )
   AAdd( char_, { "&acute;" , "'" } )
   AAdd( char_, { "&#xB7;"  , "?" } )
   AAdd( char_, { "&middot;", "?" } )
   AAdd( char_, { "&#xB8;"  , "," } )
   AAdd( char_, { "&cedil;" , "," } )
   AAdd( char_, { "&#xB9;"  , "1" } )
   AAdd( char_, { "&sup1;"  , "1" } )
   AAdd( char_, { "&#xBA;"  , "o" } )
   AAdd( char_, { "&ordm;"  , "o" } )
   AAdd( char_, { "&#xBC;"  , "." } )
   AAdd( char_, { "&frac14;", "." } )
   AAdd( char_, { "&#xBD;"  , "?" } )
   AAdd( char_, { "&frac12;", "?" } )
   AAdd( char_, { "&#xBE;"  , "_" } )
   AAdd( char_, { "&frac34;", "_" } )
   AAdd( char_, { "&#xC0;"  , "A" } )
   AAdd( char_, { "&Agrave;", "A" } )
   AAdd( char_, { "&#xC1;"  , "A" } )
   AAdd( char_, { "&Aacute;", "A" } )
   AAdd( char_, { "&#xC2;"  , "A" } )
   AAdd( char_, { "&Acirc;" , "A" } )
   AAdd( char_, { "&#xC3;"  , "A" } )
   AAdd( char_, { "&Atilde;", "A" } )
   AAdd( char_, { "&#xC4;"  , "ƒ" } )
   AAdd( char_, { "&Auml;"  , "ƒ" } )
   AAdd( char_, { "&#xC5;"  , "A" } )
   AAdd( char_, { "&Aring;" , "A" } )
   AAdd( char_, { "&#xC7;"  , "«" } )
   AAdd( char_, { "&Ccedil;", "«" } )
   AAdd( char_, { "&#xC8;"  , "E" } )
   AAdd( char_, { "&Egrave;", "E" } )
   AAdd( char_, { "&#xC9;"  , "…" } )
   AAdd( char_, { "&Eacute;", "…" } )
   AAdd( char_, { "&#xCA;"  , "E" } )
   AAdd( char_, { "&Ecirc;" , "E" } )
   AAdd( char_, { "&#xCB;"  , "E" } )
   AAdd( char_, { "&Euml;"  , "E" } )
   AAdd( char_, { "&#xCD;"  , "I" } )
   AAdd( char_, { "&Iacute;", "I" } )
   AAdd( char_, { "&#xCE;"  , "I" } )
   AAdd( char_, { "&Icirc;" , "I" } )
   AAdd( char_, { "&#xCF;"  , "I" } )
   AAdd( char_, { "&Iuml;"  , "I" } )
   AAdd( char_, { "&#xD1;"  , "N" } )
   AAdd( char_, { "&Ntilde;", "N" } )
   AAdd( char_, { "&#xD2;"  , "O" } )
   AAdd( char_, { "&Ograve;", "O" } )
   AAdd( char_, { "&#xD3;"  , "O" } )
   AAdd( char_, { "&Ocirc;" , "O" } )
   AAdd( char_, { "&#xD5;"  , "O" } )
   AAdd( char_, { "&Otilde;", "O" } )
   AAdd( char_, { "&#xD6;"  , "÷" } )
   AAdd( char_, { "&Ouml;"  , "÷" } )
   AAdd( char_, { "&#xD7;"  , "x" } )
   AAdd( char_, { "&times;" , "x" } )
   AAdd( char_, { "&#xD8;"  , "O" } )
   AAdd( char_, { "&Oslash;", "O" } )
   AAdd( char_, { "&#xD9;"  , "U" } )
   AAdd( char_, { "&Ugrave;", "U" } )
   AAdd( char_, { "&#xDA;"  , "U" } )
   AAdd( char_, { "&Uacute;", "U" } )
   AAdd( char_, { "&#xDB;"  , "U" } )
   AAdd( char_, { "&Ucirc;" , "U" } )
   AAdd( char_, { "&#xDC;"  , "‹" } )
   AAdd( char_, { "&Uuml;"  , "‹" } )
   AAdd( char_, { "&#xDD;"  , "Y" } )
   AAdd( char_, { "&Yacute;", "Y" } )
   AAdd( char_, { "&#xDE;"  , "_" } )
   AAdd( char_, { "&THORN;" , "_" } )
   AAdd( char_, { "&#xDF;"  , "ﬂ" } )
   AAdd( char_, { "&szlig;" , "ﬂ" } )
   AAdd( char_, { "&#xE0;"  , "a" } )
   AAdd( char_, { "&agrave;", "a" } )
   AAdd( char_, { "&#xE1;"  , "·" } )
   AAdd( char_, { "&aacute;", "·" } )
   AAdd( char_, { "&#xE2;"  , "‚" } )
   AAdd( char_, { "&acirc;" , "‚" } )
   AAdd( char_, { "&#xE3;"  , "a" } )
   AAdd( char_, { "&atilde;", "a" } )
   AAdd( char_, { "&#xE4;"  , "‰" } )
   AAdd( char_, { "&auml;"  , "‰" } )
   AAdd( char_, { "&#xE5;"  , "a" } )
   AAdd( char_, { "&aring;" , "a" } )
   AAdd( char_, { "&#xE6;"  , "a" } )
   AAdd( char_, { "&aelig;" , "a" } )
   AAdd( char_, { "&#xE7;"  , "Á" } )
   AAdd( char_, { "&ccedil;", "Á" } )
   AAdd( char_, { "&#xE8;"  , "e" } )
   AAdd( char_, { "&egrave;", "e" } )
   AAdd( char_, { "&#xEA;"  , "e" } )
   AAdd( char_, { "&ecirc;" , "e" } )
   AAdd( char_, { "&#xEB;"  , "Î" } )
   AAdd( char_, { "&euml;"  , "Î" } )
   AAdd( char_, { "&#xE9;"  , "È" } )
   AAdd( char_, { "&#xEC;"  , "i" } )
   AAdd( char_, { "&igrave;", "i" } )
   AAdd( char_, { "&#xED;"  , "Ì" } )
   AAdd( char_, { "&iacute;", "Ì" } )
   AAdd( char_, { "&#xEE;"  , "Ó" } )
   AAdd( char_, { "&icirc;" , "Ó" } )
   AAdd( char_, { "&#xEF;"  , "i" } )
   AAdd( char_, { "&iuml;"  , "i" } )
   AAdd( char_, { "&#xF0;"  , "d" } )
   AAdd( char_, { "&eth;"   , "d" } )
   AAdd( char_, { "&#xF1;"  , "n" } )
   AAdd( char_, { "&ntilde;", "n" } )
   AAdd( char_, { "&#xF2;"  , "o" } )
   AAdd( char_, { "&ograve;", "o" } )
   AAdd( char_, { "&#xF3;"  , "Û" } )
   AAdd( char_, { "&oacute;", "Û" } )
   AAdd( char_, { "&#xF4;"  , "Ù" } )
   AAdd( char_, { "&ocirc;" , "Ù" } )
   AAdd( char_, { "&#xF5;"  , "o" } )
   AAdd( char_, { "&otilde;", "o" } )
   AAdd( char_, { "&#xF6;"  , "ˆ" } )
   AAdd( char_, { "&ouml;"  , "ˆ" } )
   AAdd( char_, { "&#xF9;"  , "u" } )
   AAdd( char_, { "&ugrave;", "u" } )
   AAdd( char_, { "&#xFA;"  , "˙" } )
   AAdd( char_, { "&uacute;", "˙" } )
   AAdd( char_, { "&ucirc;" , "u" } )
   AAdd( char_, { "&ucirc;" , "u" } )
   AAdd( char_, { "&uuml;"  , "¸" } )
   AAdd( char_, { "&#xFC;"  , "¸" } )
   AAdd( char_, { "&uuml;"  , "¸" } )
   AAdd( char_, { "&#xFD;"  , "y" } )
   AAdd( char_, { "&yacute;", "y" } )
   AAdd( char_, { "&#xFE;"  , "_" } )
   AAdd( char_, { "&thorn;" , "_" } )
   AAdd( char_, { "&#xFF;"  , "y" } )
   AAdd( char_, { "&yuml;"  , "y" } )

   for i := 1 to Len( char_ )
     cTexto := StrTran( cTexto , char_[i,1] , char_[i,2] )
   next i

endif

return cTexto

****************************************************************************************************
static function pu_Html2Xml( cTexto )
****************************************************************************************************
local i, char_

if "&" $ cTexto

   char_ := {}
         
   AAdd( char_, { "&#34;"  , chr(34) } ) //(aspas duplas)
   AAdd( char_, { "&#38;"  , "&" } )
   AAdd( char_, { "&#39;"  , "'" } )
   AAdd( char_, { "&#60;"  , "<" } )
   AAdd( char_, { "&#62;"  , ">" } )
   AAdd( char_, { "&#161;" , "?" } )
   AAdd( char_, { "&#162;" , "c" } )
   AAdd( char_, { "&#163;" , "?" } )
   AAdd( char_, { "&#164;" , "§" } )
   AAdd( char_, { "&#165;" , "û" } )
   AAdd( char_, { "&#166;" , "?" } )
   AAdd( char_, { "&#167;" , "ß" } )
   AAdd( char_, { "&#168;" , "®" } )
   AAdd( char_, { "&#169;" , "?" } )
   AAdd( char_, { "&#170;" , "a" } )
   AAdd( char_, { "&#171;" , "ç" } )
   AAdd( char_, { "&#172;" , "?" } )
   AAdd( char_, { "&#173;" , "≠" } )
   AAdd( char_, { "&#45;"  , "-" } )
   AAdd( char_, { "&#174;" , "é" } )
   AAdd( char_, { "&#175;" , "?" } )
   AAdd( char_, { "&#176;" , "∞" } )
   AAdd( char_, { "&#177;" , "?" } )
   AAdd( char_, { "&#178;" , "2" } )
   AAdd( char_, { "&#179;" , "3" } )
   AAdd( char_, { "&#180;" , "¥" } )
   AAdd( char_, { "&#181;" , "?" } )
   AAdd( char_, { "&#182;" , "ü" } )
   AAdd( char_, { "&#183;" , "?" } )
   AAdd( char_, { "&#184;" , "∏" } )
   AAdd( char_, { "&#185;" , "ë" } )
   AAdd( char_, { "&#186;" , "o" } )
   AAdd( char_, { "&#187;" , "?" } )
   AAdd( char_, { "&#188;" , "." } )
   AAdd( char_, { "&#189;" , "?" } )
   AAdd( char_, { "&#190;" , "?" } )
   AAdd( char_, { "&#191;" , "?" } )
   AAdd( char_, { "&#192;" , "A" } )
   AAdd( char_, { "&#193;" , "¡" } )
   AAdd( char_, { "&#194;" , "¬" } )
   AAdd( char_, { "&#195;" , "A" } )
   AAdd( char_, { "&#196;" , "ƒ" } )
   AAdd( char_, { "&#197;" , "A" } )
   AAdd( char_, { "&#198;" , "A" } )
   AAdd( char_, { "&#199;" , "«" } )
   AAdd( char_, { "&#200;" , "E" } )
   AAdd( char_, { "&#201;" , "…" } )
   AAdd( char_, { "&#202;" , "E" } )
   AAdd( char_, { "&#203;" , "À" } )
   AAdd( char_, { "&#204;" , "I" } )
   AAdd( char_, { "&#205;" , "Õ" } )
   AAdd( char_, { "&#206;" , "Œ" } )
   AAdd( char_, { "&#207;" , "I" } )
   AAdd( char_, { "&#208;" , "D" } )
   AAdd( char_, { "&#209;" , "N" } )
   AAdd( char_, { "&#210;" , "O" } )
   AAdd( char_, { "&#211;" , "”" } )
   AAdd( char_, { "&#212;" , "‘" } )
   AAdd( char_, { "&#213;" , "O" } )
   AAdd( char_, { "&#214;" , "÷" } )
   AAdd( char_, { "&#215;" , "◊" } )
   AAdd( char_, { "&#216;" , "O" } )
   AAdd( char_, { "&#217;" , "U" } )
   AAdd( char_, { "&#218;" , "⁄" } )
   AAdd( char_, { "&#219;" , "U" } )
   AAdd( char_, { "&#220;" , "‹" } )
   AAdd( char_, { "&#221;" , "›" } )
   AAdd( char_, { "&#222;" , "?" } )
   AAdd( char_, { "&#223;" , "ﬂ" } )
   AAdd( char_, { "&#224;" , "a" } )
   AAdd( char_, { "&#225;" , "·" } )
   AAdd( char_, { "&#226;" , "‚" } )
   AAdd( char_, { "&#227;" , "a" } )
   AAdd( char_, { "&#228;" , "‰" } )
   AAdd( char_, { "&#229;" , "a" } )
   AAdd( char_, { "&#230;" , "a" } )
   AAdd( char_, { "&#231;" , "Á" } )
   AAdd( char_, { "&#232;" , "e" } )
   AAdd( char_, { "&#233;" , "È" } )
   AAdd( char_, { "&#234;" , "e" } )
   AAdd( char_, { "&#235;" , "Î" } )
   AAdd( char_, { "&#236;" , "i" } )
   AAdd( char_, { "&#237;" , "Ì" } )
   AAdd( char_, { "&#238;" , "Ó" } )
   AAdd( char_, { "&#239;" , "i" } )
   AAdd( char_, { "&#240;" , "?" } )
   AAdd( char_, { "&#241;" , "n" } )
   AAdd( char_, { "&#242;" , "o" } )
   AAdd( char_, { "&#243;" , "Û" } )
   AAdd( char_, { "&#244;" , "Ù" } )
   AAdd( char_, { "&#245;" , "o" } )
   AAdd( char_, { "&#246;" , "ˆ" } )
   AAdd( char_, { "&#247;" , Chr(247) } ) //(simbolo de divisao)
   AAdd( char_, { "&#248;" , "o" } )
   AAdd( char_, { "&#249;" , "u" } )
   AAdd( char_, { "&#250;" , "˙" } )
   AAdd( char_, { "&#251;" , "u" } )
   AAdd( char_, { "&#252;" , "¸" } )
   AAdd( char_, { "&#253;" , "˝" } )
   AAdd( char_, { "&#254;" , "?" } )
   AAdd( char_, { "&#255;" , "y" } )

   AAdd( char_, { "&#x20;", " " } )
   AAdd( char_, { "&#x21;", "!" } )
   AAdd( char_, { "&#x22;", ["] } )
   AAdd( char_, { "&quot;", ["] } )
   AAdd( char_, { "&#x23;", "#" } )
   AAdd( char_, { "&#x24;", "$" } )
   AAdd( char_, { "&#x25;", "%" } )
   AAdd( char_, { "&#x26;", "&" } )
   AAdd( char_, { "&amp;" , "&" } )
   AAdd( char_, { "&#x27;", "'" } )
   AAdd( char_, { "&#x28;", "(" } )
   AAdd( char_, { "&#x29;", ")" } )
   AAdd( char_, { "&#x2A;", "*" } )
   AAdd( char_, { "&#x2B;", "+" } )
   AAdd( char_, { "&#x2C;", "," } )
   AAdd( char_, { "&#x2D;", "-" } )
   AAdd( char_, { "&#x2E;", "." } )
   AAdd( char_, { "&#x2F;", "/" } )
   AAdd( char_, { "&#x30;", "0" } )
   AAdd( char_, { "&#x31;", "1" } )
   AAdd( char_, { "&#x32;", "2" } )
   AAdd( char_, { "&#x33;", "3" } )
   AAdd( char_, { "&#x34;", "4" } )
   AAdd( char_, { "&#x35;", "5" } )
   AAdd( char_, { "&#x36;", "6" } )
   AAdd( char_, { "&#x37;", "7" } )
   AAdd( char_, { "&#x38;", "8" } )
   AAdd( char_, { "&#x39;", "9" } )
   AAdd( char_, { "&#x3A;", ":" } )
   AAdd( char_, { "&#x3B;", ";" } )
   AAdd( char_, { "&#x3C;", "<" } )
   AAdd( char_, { "&lt;"  , "<" } )
   AAdd( char_, { "&#x3D;", "=" } )
   AAdd( char_, { "&#x3E;", ">" } )
   AAdd( char_, { "&gt;"  , ">" } )
   AAdd( char_, { "&#x3F;", "?" } )
   AAdd( char_, { "&#x40;", "@" } )
   AAdd( char_, { "&#x41;", "A" } )
   AAdd( char_, { "&#x42;", "B" } )
   AAdd( char_, { "&#x43;", "C" } )
   AAdd( char_, { "&#x44;", "D" } )
   AAdd( char_, { "&#x45;", "E" } )
   AAdd( char_, { "&#x46;", "F" } )
   AAdd( char_, { "&#x47;", "G" } )
   AAdd( char_, { "&#x48;", "H" } )
   AAdd( char_, { "&#x49;", "I" } )
   AAdd( char_, { "&#x4A;", "J" } )
   AAdd( char_, { "&#x4B;", "K" } )
   AAdd( char_, { "&#x4C;", "L" } )
   AAdd( char_, { "&#x4D;", "M" } )
   AAdd( char_, { "&#x4E;", "N" } )
   AAdd( char_, { "&#x4F;", "O" } )
   AAdd( char_, { "&#x50;", "P" } )
   AAdd( char_, { "&#x51;", "Q" } )
   AAdd( char_, { "&#x52;", "R" } )
   AAdd( char_, { "&#x53;", "S" } )
   AAdd( char_, { "&#x54;", "T" } )
   AAdd( char_, { "&#x55;", "U" } )
   AAdd( char_, { "&#x56;", "V" } )
   AAdd( char_, { "&#x57;", "W" } )
   AAdd( char_, { "&#x58;", "X" } )
   AAdd( char_, { "&#x59;", "Y" } )
   AAdd( char_, { "&#x5A;", "Z" } )
   AAdd( char_, { "&#x5B;", "[" } )
   AAdd( char_, { "&#x5C;", "\" } )
   AAdd( char_, { "&#x5D;", "]" } )
   AAdd( char_, { "&#x5F;", "_" } )
   AAdd( char_, { "&#x61;", "a" } )
   AAdd( char_, { "&#x62;", "b" } )
   AAdd( char_, { "&#x63;", "c" } )
   AAdd( char_, { "&#x64;", "d" } )
   AAdd( char_, { "&#x65;", "e" } )
   AAdd( char_, { "&#x66;", "f" } )
   AAdd( char_, { "&#x67;", "g" } )
   AAdd( char_, { "&#x68;", "h" } )
   AAdd( char_, { "&#x69;", "i" } )
   AAdd( char_, { "&#x6A;", "j" } )
   AAdd( char_, { "&#x6B;", "k" } )
   AAdd( char_, { "&#x6C;", "l" } )
   AAdd( char_, { "&#x6D;", "m" } )
   AAdd( char_, { "&#x6E;", "n" } )
   AAdd( char_, { "&#x6F;", "o" } )
   AAdd( char_, { "&#x70;", "p" } )
   AAdd( char_, { "&#x71;", "q" } )
   AAdd( char_, { "&#x72;", "r" } )
   AAdd( char_, { "&#x73;", "s" } )
   AAdd( char_, { "&#x74;", "t" } )
   AAdd( char_, { "&#x75;", "u" } )
   AAdd( char_, { "&#x76;", "v" } )
   AAdd( char_, { "&#x77;", "w" } )
   AAdd( char_, { "&#x78;", "x" } )
   AAdd( char_, { "&#x79;", "y" } )
   AAdd( char_, { "&#x7A;", "z" } )
   AAdd( char_, { "&#x7B;", "{" } )
   AAdd( char_, { "&#x7C;", "|" } )
   AAdd( char_, { "&#x7D;", "}" } )
   AAdd( char_, { "&#x7E;", "~" } )
   AAdd( char_, { "&#xA1;", "?" } )
   AAdd( char_, { "&iexcl;","?" } )
   AAdd( char_, { "&#xA2;", "c" } )
   AAdd( char_, { "&cent;", "c" } )
   AAdd( char_, { "&#xA3;", "?" } )
   AAdd( char_, { "&pound;","?" } )
   AAdd( char_, { "&#xA6;"  , "?" } )
   AAdd( char_, { "&brvbar;", "?" } )
   AAdd( char_, { "&sect;"  , "ß" } )
   AAdd( char_, { "&sect;"  , "ß" } )
   AAdd( char_, { "&#xAA;"  , "a" } )
   AAdd( char_, { "&ordf;"  , "a" } )
   AAdd( char_, { "&#xAE;"  , "r" } )
   AAdd( char_, { "&reg;"   , "r" } )
   AAdd( char_, { "&#xB2;"  , "2" } )
   AAdd( char_, { "&sup2;"  , "2" } )
   AAdd( char_, { "&#xB3;"  , "3" } )
   AAdd( char_, { "&sup3;"  , "3" } )
   AAdd( char_, { "&#xB4;"  , "'" } )
   AAdd( char_, { "&acute;" , "'" } )
   AAdd( char_, { "&#xB7;"  , "?" } )
   AAdd( char_, { "&middot;", "?" } )
   AAdd( char_, { "&#xB8;"  , "," } )
   AAdd( char_, { "&cedil;" , "," } )
   AAdd( char_, { "&#xB9;"  , "1" } )
   AAdd( char_, { "&sup1;"  , "1" } )
   AAdd( char_, { "&#xBA;"  , "o" } )
   AAdd( char_, { "&ordm;"  , "o" } )
   AAdd( char_, { "&#xBC;"  , "." } )
   AAdd( char_, { "&frac14;", "." } )
   AAdd( char_, { "&#xBD;"  , "?" } )
   AAdd( char_, { "&frac12;", "?" } )
   AAdd( char_, { "&#xBE;"  , "_" } )
   AAdd( char_, { "&frac34;", "_" } )
   AAdd( char_, { "&#xC0;"  , "A" } )
   AAdd( char_, { "&Agrave;", "A" } )
   AAdd( char_, { "&#xC1;"  , "A" } )
   AAdd( char_, { "&Aacute;", "A" } )
   AAdd( char_, { "&#xC2;"  , "A" } )
   AAdd( char_, { "&Acirc;" , "A" } )
   AAdd( char_, { "&#xC3;"  , "A" } )
   AAdd( char_, { "&Atilde;", "A" } )
   AAdd( char_, { "&#xC4;"  , "ƒ" } )
   AAdd( char_, { "&Auml;"  , "ƒ" } )
   AAdd( char_, { "&#xC5;"  , "A" } )
   AAdd( char_, { "&Aring;" , "A" } )
   AAdd( char_, { "&#xC7;"  , "«" } )
   AAdd( char_, { "&Ccedil;", "«" } )
   AAdd( char_, { "&#xC8;"  , "E" } )
   AAdd( char_, { "&Egrave;", "E" } )
   AAdd( char_, { "&#xC9;"  , "…" } )
   AAdd( char_, { "&Eacute;", "…" } )
   AAdd( char_, { "&#xCA;"  , "E" } )
   AAdd( char_, { "&Ecirc;" , "E" } )
   AAdd( char_, { "&#xCB;"  , "E" } )
   AAdd( char_, { "&Euml;"  , "E" } )
   AAdd( char_, { "&#xCD;"  , "I" } )
   AAdd( char_, { "&Iacute;", "I" } )
   AAdd( char_, { "&#xCE;"  , "I" } )
   AAdd( char_, { "&Icirc;" , "I" } )
   AAdd( char_, { "&#xCF;"  , "I" } )
   AAdd( char_, { "&Iuml;"  , "I" } )
   AAdd( char_, { "&#xD1;"  , "N" } )
   AAdd( char_, { "&Ntilde;", "N" } )
   AAdd( char_, { "&#xD2;"  , "O" } )
   AAdd( char_, { "&Ograve;", "O" } )
   AAdd( char_, { "&#xD3;"  , "O" } )
   AAdd( char_, { "&Ocirc;" , "O" } )
   AAdd( char_, { "&#xD5;"  , "O" } )
   AAdd( char_, { "&Otilde;", "O" } )
   AAdd( char_, { "&#xD6;"  , "÷" } )
   AAdd( char_, { "&Ouml;"  , "÷" } )
   AAdd( char_, { "&#xD7;"  , "x" } )
   AAdd( char_, { "&times;" , "x" } )
   AAdd( char_, { "&#xD8;"  , "O" } )
   AAdd( char_, { "&Oslash;", "O" } )
   AAdd( char_, { "&#xD9;"  , "U" } )
   AAdd( char_, { "&Ugrave;", "U" } )
   AAdd( char_, { "&#xDA;"  , "U" } )
   AAdd( char_, { "&Uacute;", "U" } )
   AAdd( char_, { "&#xDB;"  , "U" } )
   AAdd( char_, { "&Ucirc;" , "U" } )
   AAdd( char_, { "&#xDC;"  , "‹" } )
   AAdd( char_, { "&Uuml;"  , "‹" } )
   AAdd( char_, { "&#xDD;"  , "Y" } )
   AAdd( char_, { "&Yacute;", "Y" } )
   AAdd( char_, { "&#xDE;"  , "_" } )
   AAdd( char_, { "&THORN;" , "_" } )
   AAdd( char_, { "&#xDF;"  , "ﬂ" } )
   AAdd( char_, { "&szlig;" , "ﬂ" } )
   AAdd( char_, { "&#xE0;"  , "a" } )
   AAdd( char_, { "&agrave;", "a" } )
   AAdd( char_, { "&#xE1;"  , "·" } )
   AAdd( char_, { "&aacute;", "·" } )
   AAdd( char_, { "&#xE2;"  , "‚" } )
   AAdd( char_, { "&acirc;" , "‚" } )
   AAdd( char_, { "&#xE3;"  , "a" } )
   AAdd( char_, { "&atilde;", "a" } )
   AAdd( char_, { "&#xE4;"  , "‰" } )
   AAdd( char_, { "&auml;"  , "‰" } )
   AAdd( char_, { "&#xE5;"  , "a" } )
   AAdd( char_, { "&aring;" , "a" } )
   AAdd( char_, { "&#xE6;"  , "a" } )
   AAdd( char_, { "&aelig;" , "a" } )
   AAdd( char_, { "&#xE7;"  , "Á" } )
   AAdd( char_, { "&ccedil;", "Á" } )
   AAdd( char_, { "&#xE8;"  , "e" } )
   AAdd( char_, { "&egrave;", "e" } )
   AAdd( char_, { "&#xEA;"  , "e" } )
   AAdd( char_, { "&ecirc;" , "e" } )
   AAdd( char_, { "&#xEB;"  , "Î" } )
   AAdd( char_, { "&euml;"  , "Î" } )
   AAdd( char_, { "&#xE9;"  , "È" } )
   AAdd( char_, { "&#xEC;"  , "i" } )
   AAdd( char_, { "&igrave;", "i" } )
   AAdd( char_, { "&#xED;"  , "Ì" } )
   AAdd( char_, { "&iacute;", "Ì" } )
   AAdd( char_, { "&#xEE;"  , "Ó" } )
   AAdd( char_, { "&icirc;" , "Ó" } )
   AAdd( char_, { "&#xEF;"  , "i" } )
   AAdd( char_, { "&iuml;"  , "i" } )
   AAdd( char_, { "&#xF0;"  , "d" } )
   AAdd( char_, { "&eth;"   , "d" } )
   AAdd( char_, { "&#xF1;"  , "n" } )
   AAdd( char_, { "&ntilde;", "n" } )
   AAdd( char_, { "&#xF2;"  , "o" } )
   AAdd( char_, { "&ograve;", "o" } )
   AAdd( char_, { "&#xF3;"  , "Û" } )
   AAdd( char_, { "&oacute;", "Û" } )
   AAdd( char_, { "&#xF4;"  , "Ù" } )
   AAdd( char_, { "&ocirc;" , "Ù" } )
   AAdd( char_, { "&#xF5;"  , "o" } )
   AAdd( char_, { "&otilde;", "o" } )
   AAdd( char_, { "&#xF6;"  , "ˆ" } )
   AAdd( char_, { "&ouml;"  , "ˆ" } )
   AAdd( char_, { "&#xF9;"  , "u" } )
   AAdd( char_, { "&ugrave;", "u" } )
   AAdd( char_, { "&#xFA;"  , "˙" } )
   AAdd( char_, { "&uacute;", "˙" } )
   AAdd( char_, { "&ucirc;" , "u" } )
   AAdd( char_, { "&ucirc;" , "u" } )
   AAdd( char_, { "&uuml;"  , "¸" } )
   AAdd( char_, { "&#xFC;"  , "¸" } )
   AAdd( char_, { "&uuml;"  , "¸" } )
   AAdd( char_, { "&#xFD;"  , "y" } )
   AAdd( char_, { "&yacute;", "y" } )
   AAdd( char_, { "&#xFE;"  , "_" } )
   AAdd( char_, { "&thorn;" , "_" } )
   AAdd( char_, { "&#xFF;"  , "y" } )
   AAdd( char_, { "&yuml;"  , "y" } )

   for i := 1 to Len( char_ )
      cTexto := StrTran( cTexto , char_[i,2] , char_[i,1] )
   next i

endif

return cTexto

*****************************************************************************************
function pu_TagValue
*****************************************************************************************
param cText, nLen, nDec

local aChars := {}
local aItem  := {}

cText := pu_TagConvert( cText, nLen, nDec )

cText := pu_DelSymbolChar( cText )

if !empty(cText) 

   aadd( aChars, { "&" , "&amp;"  } )
   aadd( aChars, { "<" , "&lt;"   } )
   aadd( aChars, { ">" , "&gt;"   } )
   aadd( aChars, { "'" , "&apos;" } )
   aadd( aChars, { '"' , "&quot;" } )

   for each aItem in aChars
      cText := StrTran( cText, aItem[1], aItem[2] )
   next 

endif

return cText

*****************************************************************************************
function pu_TagConvert
*****************************************************************************************
param cText, nLen, nDec

default cText := ""
default nLen  := 0 
default nDec  := 0

if valtype(cText)<>"C" 

   do case
   case valtype(cText)="M" 
   case valtype(cText)="N" 
      
      if nLen > 0
         cText := str(cText, nLen, nDec)
      else
         cText := str(cText)
      endif

   case valtype(cText)="D" ; cText := dtoc(cText)
   case valtype(cText)="L" ; cText := if(cText,'true','false')
   case valtype(cText)="A" ; cText := "array"
   case valtype(cText)="H" ; cText := "hash"
   case valtype(cText)="O" ; cText := "object"
   case valtype(cText)="B" ; cText := "codeblock"
   case valtype(cText)="P" ; cText := "pointer"
   case valtype(cText)="U" ; cText := ""
   otherwise               ; cText := "unknown"
   endcase

endif

return alltrim(cText)

*****************************************************************************************
function pu_SemAcento( cText, lCRLF )
*****************************************************************************************
local aChars := {}
local aItem  := {}

default cText := ""

if !empty(cText) 

   // Troca os caracteres de acentuaÁao - Complemento - Regra de NegÛcio.
   
   aChars := pu_GetCharList()
   
   for each aItem in aChars
      cText := StrTran( cText, aItem[1], aItem[2] )
   next 
   
   // Elimina os caracteres especiais que nao traduÁao e sao rejeitados no XML.
   
   cText := pu_DelSymbolChar( cText, lCRLF )

endif

return cText

*****************************************************************************************
function pu_GetCharList()
*****************************************************************************************
local aChars := {}

// AADD( aChars, { "&" , "E" } )
// AADD( aChars, { "*" , "x" } )

AADD( aChars, { "o" , "o" } )
AADD( aChars, { "a" , "a" } )
AADD( aChars, { "∞" , "o" } )

AADD( aChars, { "·" , "a" } )
AADD( aChars, { "‚" , "a" } )
AADD( aChars, { "a" , "a" } )
AADD( aChars, { "‰" , "a" } )
AADD( aChars, { "a" , "a" } )

AADD( aChars, { "¡" , "A" } )
AADD( aChars, { "¬" , "A" } )
AADD( aChars, { "A" , "A" } )
AADD( aChars, { "ƒ" , "A" } )
AADD( aChars, { "A" , "A" } )

AADD( aChars, { "È" , "e" } )
AADD( aChars, { "e" , "e" } )
AADD( aChars, { "e" , "e" } )
AADD( aChars, { "Î" , "e" } )

AADD( aChars, { "…" , "E" } )
AADD( aChars, { "E" , "E" } )
AADD( aChars, { "E" , "E" } )
AADD( aChars, { "À" , "E" } )

AADD( aChars, { "Ì" , "i" } )
AADD( aChars, { "Ó" , "i" } )
AADD( aChars, { "i" , "i" } )
AADD( aChars, { "i" , "i" } )

AADD( aChars, { "Õ" , "I" } )
AADD( aChars, { "Œ" , "I" } )
AADD( aChars, { "I" , "I" } )
AADD( aChars, { "I" , "I" } )

AADD( aChars, { "Û" , "o" } )
AADD( aChars, { "Ù" , "o" } )
AADD( aChars, { "o" , "o" } )
AADD( aChars, { "o" , "o" } )
AADD( aChars, { "ˆ" , "o" } )

AADD( aChars, { "”" , "O" } )
AADD( aChars, { "‘" , "O" } )
AADD( aChars, { "O" , "O" } )
AADD( aChars, { "O" , "O" } )
AADD( aChars, { "÷" , "O" } )

AADD( aChars, { "˙" , "u" } )
AADD( aChars, { "u" , "u" } )
AADD( aChars, { "u" , "u" } )
AADD( aChars, { "¸" , "u" } )

AADD( aChars, { "⁄" , "U" } )
AADD( aChars, { "U" , "U" } )
AADD( aChars, { "U" , "U" } )
AADD( aChars, { "‹" , "U" } )

AADD( aChars, { "«" , "C" } )
AADD( aChars, { "Á" , "c" } )

aadd( aChars, { chr(94) , " "  } ) // `
aadd( aChars, { chr(96) , "'"  } ) // `
aadd( aChars, { chr(130), ","  } ) // Virgula
aadd( aChars, { chr(132), '"'  } ) // "
aadd( aChars, { chr(145), "'"  } ) // '
aadd( aChars, { chr(146), "'"  } ) // '
aadd( aChars, { chr(147), '"'  } ) // "
aadd( aChars, { chr(148), '"'  } ) // "
aadd( aChars, { chr(150), "-"  } ) // -
aadd( aChars, { chr(151), "_"  } ) // _
aadd( aChars, { chr(153), "TM" } ) // TM
aadd( aChars, { chr(168), '"'  } ) // "
aadd( aChars, { chr(170), "a"  } ) // a
aadd( aChars, { chr(176), "o"  } ) // o
aadd( aChars, { chr(178), "2"  } ) // 2
aadd( aChars, { chr(179), "3"  } ) // 3
aadd( aChars, { chr(180), "'"  } ) // '
aadd( aChars, { chr(185), "1"  } ) // o
aadd( aChars, { chr(186), "o"  } ) // o

return aChars

****************************************************************************************************
static function pu_ChangeChar( cXml )
****************************************************************************************************

cXml := strtran( cXml, chr(13), []  )
cXml := strtran( cXml, chr(10), []  )
cXml := strtran( cXml, [|],     []  )

cXml := strtran( cXml, [&], [&amp;]  )
cXml := strtran( cXml, [<], [&lt;]   )
cXml := strtran( cXml, [>], [&gt;]   )
cXml := strtran( cXml, ['], [&apos;] )
cXml := strtran( cXml, ["], [&quot;] )

return cXml 

****************************************************************************************************
static function pu_IsLog( cType )
****************************************************************************************************
local cRet := "N"

DEFAULT cType := "WS"

if empty(xPdv_logWS)
   xPdv_logWS  := GetPvProfString( "OMIE", "LOGWS",  "", m->dirlocal+"\SysFar.Ini" )
endif

if empty(xPdv_logXML)
   xPdv_logXML := GetPvProfString( "OMIE", "LOGXML",  "", m->dirlocal+"\SysFar.Ini" )
endif

if empty(xPdv_logCX)
   xPdv_logCX  := GetPvProfString( "OMIE", "LOGCX",  "", m->dirlocal+"\SysFar.Ini" )
endif

do case
case cType = "WS"  ; cRet := xPdv_logWS  
case cType = "XML" ; cRet := xPdv_logXML 
case cType = "CX"  ; cRet := xPdv_logCX  
endcase

return cRet

****************************************************************************************************
function pu_GetLote()
****************************************************************************************************
return (date()-ctod('01/01/2015'))*(24*60*60*1000)+int(seconds()*1000)

****************************************************************************************************
function pu_hasTag( hHash, cTag )
****************************************************************************************************
return hHasKey( hHash, cTag ) .and. !empty(hHash[cTag])

****************************************************************************************************
function pu_Restart( lRestart )
****************************************************************************************************

if lRestart

   trocar_empresa_omie()
   
   logfile( "update.sys", {"ok"} )
   
   FinalizaAplicacao()
   
   __QUIT()

endif

return NIL

*****************************************************************************************
function pu_OnlyNumber(cTag)
*****************************************************************************************

Local cRet, i

If ValType( cTag ) <> "C" .or. Empty( cTag )
   Return ""
EndIf

cRet := ""

For i := 1 to Len( cTag )

    If cTag[i] $ "1234567890"
       cRet += cTag[i]
    EndIf

Next i

return cRet

*****************************************************************************************
function pu_EraseFile(cName)
*****************************************************************************************

aeval( directory( DIR_TEMP+"\"+cName+"_ret*.xml" ), { |x| ferase( DIR_TEMP+"\"+x[1] ) } ) 

return NIL

****************************************************************************************************
function pu_suporte()
****************************************************************************************************

MsgInfo("pu_suporte() !")

return NIL

****************************************************************************************************
function pu_consistir()
****************************************************************************************************

MsgInfo("pu_consistir() !")

return NIL

// Toda vez que cancelar um SAT ou NFC-e, alimentar as tabela CUPOM.DBF e ESTAT.DBF.
****************************************************************************************************
function pu_CancCfe( nCupom )
****************************************************************************************************
local aDel_  := {}
local nRecno := 0

DEFAULT nCupom := 0

if nCupom = 0
   return .F.
endif

LogFile( "omie\canceled.log", { "CUPOM -->", nCupom } )

USE ("CUPOM.DBF") ALIAS _CUPOM VIA "ADS" SHARED NEW
USE ("ESTAT.DBF") ALIAS _ESTAT VIA "ADS" SHARED NEW

_CUPOM->(dbSetOrder(2))  // CUPOM
_ESTAT->(dbSetOrder(2))  // CUPOM

if _CUPOM->(dbSeek(nCupom))   
   
   _CUPOM->CANC       := .T. 
   _CUPOM->DIACANCEL  := date() 
   _CUPOM->HORACANCEL := time()
   _CUPOM->CANCECF    := .T.
   
   _CUPOM->(dbDelete())

endif         

if _ESTAT->(dbSeek(nCupom))
   
   do while _ESTAT->CUPOM == nCupom .and. !_ESTAT->(eof())  

      _ESTAT->CANC       := .T. 
      _ESTAT->DIACANCEL  := date() 
      _ESTAT->HORACANCEL := time()
      _ESTAT->CANCECF    := .T.

      aadd( aDel_, _ESTAT->(RecNo()) )
     
      _ESTAT->(dbSkip())
   
   enddo

   if len(aDel_) > 0

      for each nRecno in aDel_
         _ESTAT->(dbGoTo(nRecno))
         _ESTAT->(dbDelete())
      next

   endif

endif

_CUPOM->(dbclosearea())
_ESTAT->(dbclosearea())

return NIL

// Verifica se usu·rio È administrador para bloquear menu avanÁado.
****************************************************************************************************
function pu_IsAdmin( nUser )
****************************************************************************************************
local lAdmin := .F.

local cRole := ""

cRole := pu_GetOmie( "USER_ROLE" )

if cRole in { "1", "9"}
   lAdmin := .T.
else
   MsgInfo("O seu usu·rio nao tem permiss„o para acessar esse menu." + CRLF + ;
           "Apenas usu·rios administradores podem acessar as configuraÁıes!")
endif

return lAdmin

****************************************************************************************************
function pu_IsUserAdmin()
****************************************************************************************************
return pu_GetOmie( "USER_ROLE" ) == "1"

****************************************************************************************************
function pu_IsUserSupport()
****************************************************************************************************
return pu_GetOmie( "USER_ROLE" ) == "9"

// Ajuda do PDV.
****************************************************************************************************
function pu_Ajuda( lNfce, lSat )
****************************************************************************************************
local lAdmin := .T.

DEFAULT lSat  := .F.
DEFAULT lNfce := .F.

if lSat
   ShellExecute( 0, "Open", "http://docs.omie.com.br/m/PDV/c/157870", 0 )
else
   if lNfce
      ShellExecute( 0, "Open", "http://docs.omie.com.br/m/PDV/c/157871", 0 )
   else
      ShellExecute( 0, "Open", "http://docs.omie.com.br/m/PDV/c/77076", 0 )
   endif
endif

return NIL

// OpÁıes AvanÁadas de ConfiguraÁao.
****************************************************************************************************
function pu_Opcoes( lSat, lNfce )
****************************************************************************************************
local oFont
local oDlg
local aBotoes := {}
local oBtnSalvar
local oBtnCancelar
local hAdvanced := {=>}
local lOk := .F.
local oBtn1
local oBtn2
local cUserRole := ""
local lIsSAT := .F.

hAdvanced["SyncOnLogin"]   := .T.
hAdvanced["BackupOnLogin"] := .T.
hAdvanced["DebugMode"]     := .F.
hAdvanced["CardOnScreen"]  := .F.
hAdvanced["SAT_ON"]        := pu_GetOmie("IsSAT","CONFIG") == "TRUE"
hAdvanced["SAT_Assin"]     := left(pu_GetData("ASSVINC","dllsat")+space(500),500)
hAdvanced["SAT_Versao"]    := left(pu_GetData("VERSAO" ,"dllsat")+space(10) , 10)
hAdvanced["SAT_DLL"]       := left(pu_GetData("DLL"    ,"dllsat")+space(100),100)

if pu_GetOmie("SyncOnLogin","ADVANCED") = "false"
   hAdvanced["SyncOnLogin"] := .F.
endif

if pu_GetOmie("BackupOnLogin","ADVANCED") = "false"
   hAdvanced["BackupOnLogin"] := .F.
endif

if pu_GetOmie("DebugMode","ADVANCED") = "true"
   hAdvanced["DebugMode"] := .T.
endif

if pu_GetOmie("CardOnScreen","ADVANCED") = "true"
   hAdvanced["CardOnScreen"] := .T.
endif

cUserRole := pu_GetOmie("USER_ROLE","CONFIG") 

///////////////////////////////////////////////////////////////////////////////

lOk := .F.

DEFINE FONT oFont  NAME "Arial" SIZE 06,16

DEFINE DIALOG oDlg FROM 0, 0 TO 28, 63 TITLE "ConfiguraÁıes AvanÁadas" FONT oFont

@ 1,   1 BTNBMP oBtn1 FILENAME "metro\80-ObterLogo.bmp"   PROMPT "Obter Logo"  SIZE 40, 30 OF oDlg NOBORDER ACTION pu_OpcoesLogo() // NOBORDER
@ 1,  41 BTNBMP oBtn2 FILENAME "metro\81-Organizar.bmp"   PROMPT "Organizar"   SIZE 40, 30 OF oDlg NOBORDER ACTION pu_OpcoesInd() // NOBORDER
@ 1,  82 BTNBMP oBtn2 FILENAME "metro\82-Sincronizar.bmp" PROMPT "Sincronizar" SIZE 40, 30 OF oDlg NOBORDER ACTION pu_OpcoesSin() // NOBORDER

if cUserRole == "9"
   @ 1, 123 BTNBMP oBtn2 FILENAME "metro\83-sysfar.bmp"   PROMPT "sysfar.ini"  SIZE 40, 30 OF oDlg NOBORDER ACTION WinExec("notepad.exe sysfar.ini") // NOBORDER
   @ 1, 164 BTNBMP oBtn2 FILENAME "metro\84-omie.bmp"     PROMPT "omie.ini"    SIZE 40, 30 OF oDlg NOBORDER ACTION WinExec("notepad.exe omie.ini") // NOBORDER
   @ 1, 205 BTNBMP oBtn2 FILENAME "metro\85-backup.bmp"   PROMPT "Backup"      SIZE 40, 30 OF oDlg NOBORDER ACTION pu_RunBackup() // NOBORDER

   @ 1, 246 BTNBMP oBtn2 FILENAME "metro\85-backup.bmp"   PROMPT "Reenviar"    SIZE 40, 30 OF oDlg NOBORDER ACTION pu_ReenviarCupons() // NOBORDER

endif

@ 3,  1 CHECKBOX hAdvanced["SyncOnLogin"]     PROMPT "Sincronizar com o Omie no primeiro acesso do dia"     SIZE 200,12 OF oDlg

@ 4,  1 CHECKBOX hAdvanced["BackupOnLogin"]   PROMPT "Efetuar CÛpia de SeguranÁa no primeiro acesso do dia" SIZE 200,12 OF oDlg

@ 5,  1 CHECKBOX hAdvanced["CardOnScreen"]    PROMPT "Exibir cupons na tela (Nao serao impressos)."         SIZE 200,12 OF oDlg

if cUserRole == "9"

   @ 6.0, 1.0 CHECKBOX hAdvanced["DebugMode"] PROMPT "Ativar DEBUG (apenas suporte)"                        SIZE 200,12 OF oDlg
   
   if hAdvanced["SAT_ON"]
   
      @ 6.3, 1.5 SAY "Assinatura da Software House" OF oDlg
      @ 8.0, 1.0 GET hAdvanced["SAT_Assin"] OF oDlg SIZE 200,12

      @  8.0, 1.5 SAY "Versao" OF oDlg
      @ 10.0, 1.0 GET hAdvanced["SAT_Versao"] OF oDlg SIZE 95,12

      @  8.0, 19.3 SAY "DLL" OF oDlg
      @ 10.0, 14.3 GET hAdvanced["SAT_DLL"] OF oDlg SIZE 95,12
   
   endif

endif

aadd( aBotoes, { @oBtnSalvar  , "&Salvar", { || lOk := .T., oDlg:End() } } )

aadd( aBotoes, { @oBtnCancelar, "&Voltar", { || lOk := .F., oDlg:End() } } )

ACTIVATE DIALOG oDlg CENTERED ON INIT (EstiloTela(oDlg,aBotoes),oDlg:show(),setfocus(oDlg))

if lOk

   pu_SetOmie( "SyncOnLogin",   if(hAdvanced["SyncOnLogin"]   ,"true","false"), "ADVANCED" ) 
   pu_SetOmie( "BackupOnLogin", if(hAdvanced["BackupOnLogin"] ,"true","false"), "ADVANCED" ) 
   pu_SetOmie( "DebugMode",     if(hAdvanced["DebugMode"]     ,"true","false"), "ADVANCED" ) 
   pu_SetOmie( "CardOnScreen",  if(hAdvanced["CardOnScreen"]  ,"true","false"), "ADVANCED" ) 

   if hAdvanced["CardOnScreen"]
      if !file("c:\temp\imagenfce.sys")
         __run("dir *.txt > c:\temp\imagenfce.sys")
         MsgInfo("Todos os cupons serao exibidos apenas na tela!")
      endif
   else
      if file("c:\temp\imagenfce.sys")
         ferase("c:\temp\imagenfce.sys")
         MsgInfo("Todos os cupons serao direcionados para a impressora padr„o do Windows!")
      endif
   endif

   if hAdvanced["DebugMode"]
      if !file("c:\temp\debug.txt")
         __run("dir *.txt > c:\temp\debug.txt")
         MsgInfo("Modo Debug ativado!")
      endif
   else
      if file("c:\temp\debug.txt")
         ferase("c:\temp\debug.txt")
         MsgInfo("Modo Debug desativado!")
      endif
   endif

   // Grava a assinatura do SAT.
   if hAdvanced["SAT_ON"]

      pu_SetData("ASSVINC", alltrim(hAdvanced["SAT_Assin"]) , "dllsat" )
      pu_SetData("VERSAO" , alltrim(hAdvanced["SAT_Versao"]), "dllsat" )
      pu_SetData("DLL"    , alltrim(hAdvanced["SAT_DLL"])   , "dllsat" )
   
   endif

endif

// oBtn1:lTransparent = .T.   
// @ 1.00,  2   SAY "De"  OF oDlg
// @ 1.00, 13.5 SAY "AtÈ" OF oDlg
// @ 1.25,  3 GET _dDtIni VAR dDtIni OF oDlg VALID !empty(dDtIni) SIZE 50,12
// @ 1.25, 12 GET _dDtFim VAR dDtFim OF oDlg VALID !empty(dDtFim) SIZE 50,12 
// @ 00.50,01.00 SAY "Desconto m>ximo permitido %" OF oDlg

return NIL

****************************************************************************************************
function pu_OpcoesLogo()
****************************************************************************************************

if MsgYesNo("Confirma o download do logotipo da empresa?"+ CRLF + ;
            "AVISO: O aplicativo ser· fechado apÛs a conclusao desse processo!")
   
   sysexecfuncaoBin("pu_GetLogoEmpresa","omie.bin",.f.)

   sysdbcloseall()
   
   ReiniciaSysfar()

endif

return .t.

****************************************************************************************************
function pu_OpcoesInd()
****************************************************************************************************

if MsgYesNo("Confirma a verificaÁao dos arquivos do aplicativo?"+ CRLF + ;
            "AVISO: O aplicativo ser· fechado apÛs a conclusao desse processo!")

   sysdbcloseall()

   Bin2("indexar.bin",1,.f.,.f.,.t.,.f.)

   sysdbcloseall()

   pu_VerifyRec()
   
   ReiniciaSysfar()

endif

return .t.

****************************************************************************************************
function pu_OpcoesSin()
****************************************************************************************************

local lAbriu := .F.

if MsgYesNo("Esta opÁao ir· sincronizar com o aplicativo Omie obtendo TODOS os clientes e produtos cadastrados, confirma?")
   
   pu_setOmie( "SyncAll", "true", "ADVANCED")

   if Select("INDICE") = 0
      USE "Indice.dbf" new alias INDICE
      lAbriu := .T.
   endif

   INDICE->COMUNICADO := ctod("01/01/2001")

   if lAbriu
      INDICE->(dbCloseArea())
   endif

   if MsgYesNo("Deseja sincronizar com o aplicativo Omie agora?" + CRLF + ;
               "AVISO: O aplicativo ser· fechado apÛs a conclusao desse processo!" )

      MsgRun( "Sincronizando com o seu aplicativo Omie ...", ;
              "Por favor, aguarde ... ",     ;
               { || pu_EnviarCaixa( , .F., , ) } )
   
      sysdbcloseall()

      ReiniciaSysfar()

   endif

endif

return .t.

****************************************************************************************************
function pu_RunBackup()
****************************************************************************************************

if MsgYesNo("Confirma a CÛpia de seguranÁa dos dados b·sicos do aplicativo?"+ CRLF + ;
            "AVISO: O aplicativo ser· fechado apÛs a conclusao desse processo!")
   
   sysdbcloseall()

   pu_BackupPDV()
      
   ReiniciaSysfar()

endif

return .t.

****************************************************************************************************
function pu_ConfGeral(xVar,comando,lVendas)
****************************************************************************************************

local oFont
local oDlg
local aBotoes := {}
local oBtnSalvar
local oBtnCancelar

local lOk         := .F.
local _DescMaximo := 0.00
local _Arredonda  := 0.00
local _CopiaMov   := 0

local _Mensagem1  := ""
local _Mensagem2  := ""

DEFAULT xVar    :=  3
DEFAULT comando := .f. 
DEFAULT lVendas := .f. 

if comando

   USE "Indice.dbf" new alias indice

else
   
   if !VerificaNewFieldTable("INDICE","PMCTOPRECO","_INDICE")
      return sysdbcloseall()
   endif
   
   if !VerificaNewFieldTable("INDICE","HORADTSUP","_INDICE")
      return sysdbcloseall()
   endif
   
   if !emuso("online")
      USE online new
   endif

   USE "Indice.dbf" NEW ALIAS indice

endif

_DescMaximo := INDICE->DESCMAXIMO
_Arredonda  := INDICE->ARREDONDA
_CopiaMov   := INDICE->COPIAMOV
_Mensagem1  := INDICE->MEMSAGEM1
_Mensagem2  := INDICE->MEMSAGEM2

lOk := .F.

DEFINE FONT oFont  NAME "Arial" SIZE 06,16

DEFINE DIALOG oDlg FROM 0, 0 TO 22, 46 TITLE "ConfiguraÁıes Gerais" FONT oFont

@ 00.50,01.00 SAY "Desconto m·ximo permitido %" OF oDlg
@ 01.40,00.70 GET _DescMaximo OF oDlg SIZE 170,12 RIGHT PICTURE "@E 99.99"
@ 02.10,01.00 SAY "Valor m·ximo de arredondamento " OF oDlg
@ 03.30,00.70 GET _Arredonda  OF oDlg SIZE 170,12 RIGHT PICTURE "@E 999.99"
@ 03.70,01.00 SAY "Quantidade de cupom para movimentaÁao de caixa" OF oDlg
@ 05.20,00.70 GET  _CopiaMov  OF oDlg SIZE 170,12 RIGHT PICTURE "9"

@ 05.30,01.00 SAY "Linha 1 da mensagem do cupom " OF oDlg
@ 07.10,00.70 GET _Mensagem1 OF oDlg SIZE 170,12 

@ 06.90,01.00 SAY "Linha 2 da mensagem do cupom" OF oDlg
@ 09.00,00.70 GET _Mensagem2  OF oDlg SIZE 170,12 

aadd( aBotoes, { @oBtnSalvar  , "&Salvar", { || lOk := .T., oDlg:End() } } )

aadd( aBotoes, { @oBtnCancelar, "&Voltar", { || lOk := .F., oDlg:End() } } )

ACTIVATE DIALOG oDlg CENTERED ON INIT (EstiloTela(oDlg,aBotoes),oDlg:show(),setfocus(oDlg))

if lOk
   INDICE->DESCMAXIMO := _DescMaximo 
   INDICE->ARREDONDA  := _Arredonda  
   INDICE->COPIAMOV   := _CopiaMov   
   INDICE->MEMSAGEM1  := _Mensagem1  
   INDICE->MEMSAGEM2  := _Mensagem2  
   INDICE->(dbcommit())
   INDICE->(dbUnLock())
endif

return NIL

//aadd(aBotoes,{@oBtnSalvar,"&Salvar",{||If(SalvaConf(xVar,comando,),if(MsgYesNo("Para que as alterao es realizadas tenham efeito, o OmiePDV precisa ser reiniciado." +;
//                                     CRLF + "Deseja reiniciar agora?", SYSTEM_VERSION), ReiniciaSysfar(), oDlg:End()),.f.)}})

// Preciso implementar isso.

****************************************************************************************************
function cadastra_ecf_omie(cNserie,cMarca,cModelo,nSerialHD)
****************************************************************************************************

pu_UpsertECF( cNserie, cMarca, cModelo, nSerialHD )

return NIL

****************************************************************************************************
function pu_LogFile( cFileName, aInfo, lLogTS )
****************************************************************************************************

local hFile, cLine := DToC( Date() ) + " " + Time() + " : ", n

default lLogTS := .T.

if !lLogTS
   cLine := ""
endif

for n = 1 to Len( aInfo )
   cLine += cValToChar( aInfo[ n ] ) + Chr( 9 )
next

cLine += CRLF

if ! File( cFileName )
   FClose( FCreate( cFileName ) )
endif

hFile := FOpen( cFileName, 1 )

if( ( hFile ) != -1 )
   FSeek( hFile, 0, 2 )
   FWrite( hFile, alltrim( cLine ), Len( alltrim( cLine ) ) )
   FClose( hFile )
endif

return NIL

// RelatÛrios - Resumo de Vendas.

****************************************************************************************************
function pu_Resumo()
****************************************************************************************************
local aTdmFile := {}
local hTdmFile := {=>}

local aOmiePdv := {}
local hOmiePdv := {=>}

local aReport  := {}
local cReport  := ""

local aRepPdv  := {}
local cData    := ""
local cFile    := ""

hTdmFile := {=>}
hTdmFile["confirm"]    := .f.
hTdmFile["dtDe"]       := date()-(day(date())-1)
hTdmFile["dtAte"]      := date()
hTdmFile["ShowDetail"] := .F.

hTdmFile["PASTA_OMIEPDV"] := ""
hTdmFile["tipoCF"]        := ""
hTdmFile["DEBUG"]         := "false"
hTdmFile["DETALHADO"]     := "true"
hTdmFile["PASTA_DESTINO"] := "c:\temp\"

if pu_GetOmie("IsSAT")=="TRUE"
   hTdmFile["tipoCF"] := "SAT"
endif

if pu_GetOmie("IsNFCE")=="TRUE"
   hTdmFile["tipoCF"] := "NFCE"
endif

if pu_GetOmie("IsECF")=="TRUE"
   hTdmFile["tipoCF"] := "ECF"
endif

hTdmFile := pu_AskWhen( hTdmFile )

if !hTdmFile["confirm"]
   return .F.
endif

hTdmFile["hEcf"] := {=>}
hTdmFile["hEcf"]["dtIni"] := dtos(hTdmFile["dtDe"])
hTdmFile["hEcf"]["dtFim"] := dtos(hTdmFile["dtAte"])

BEGIN SEQUENCE

//   // Lo o arquivo TDM.
//
//   if !empty(cData)
//
//      aTdmFile := pu_Tdm2Hash( cData )
//
//      if !aTdmFile[1]
//         BREAK
//      endif
//      
//      hTdmFile := aTdmFile[2] 
//
//   endif
      
   // Lo as informao es do Omie.
      
   aOmiePdv := pu_Omie2Hash( hTdmFile )

   if !aOmiePdv[1]
      BREAK
   endif

   hOmiePdv := aOmiePdv[2]

   // Gera o Relat rio do arquivo TDM.

//   aReport := { .f., "" }
//
//   if !empty(cData)
//
//      aReport := pu_Hash2Txt( hTdmFile, hTdmFile["DETALHADO"]=="true", "TXT" )
//
//      if !aReport[1]
//       BREAK
//      endif
//
//      cReport := aReport[2]
//   
//   endif

   // Gera o relat rio do OmiePDV. 

   aRepPdv := pu_Omie2Txt( hOmiePdv, hTdmFile["DETALHADO"]=="true", "TXT" )

   if !aRepPdv[1]
      BREAK
   endif

   cReport += aRepPdv[2]
   
   cFile  := "OmiePDV_"+transform(dtos(date()),"@R 9999-99-99")+"_"+strtran(time(),":","")+".txt"
 
   pu_LogFile( hTdmFile["PASTA_DESTINO"]+cFile, { cReport }, .f. )

   if file(hTdmFile["PASTA_DESTINO"]+cFile)
      winexec( "notepad.exe " + hTdmFile["PASTA_DESTINO"]+cFile )
   endif

END SEQUENCE

return .T.

// OpÁıes AvanÁadas de ConfiguraÁao.
****************************************************************************************************
function pu_AskWhen( hTdmFile )
****************************************************************************************************
local oFont
local oDlg
local aBotoes := {}
local oBtnConfirmar
local oBtnCancelar

local lOk := .F.

local _dDtIni 
local _dDtFim 
local dDtIni := ctod("") 
local dDtFim := ctod("")

dDtIni := hTdmFile["dtDe"]    
dDtFim := hTdmFile["dtAte"]   

if pu_GetOmie("ShowDetail","REPORT") == "true"
   hTdmFile["ShowDetail"] := .T.
endif

lOk := .F.

DEFINE FONT oFont  NAME "Arial" SIZE 06,16

DEFINE DIALOG oDlg FROM 0, 0 TO 10, 40 TITLE "Resumo de Vendas" FONT oFont

@ 1.00,  2   SAY "De"  OF oDlg

@ 1.00, 13.5 SAY "AtÈ" OF oDlg

@ 1.25,  3 GET _dDtIni VAR dDtIni OF oDlg VALID !empty(dDtIni) SIZE 50,12
@ 1.25, 12 GET _dDtFim VAR dDtFim OF oDlg VALID !empty(dDtFim) SIZE 50,12 

@ 2.5 ,1.9 CHECKBOX hTdmFile["ShowDetail"] PROMPT "Exibir detalhes por dia" SIZE 100,12 OF oDlg

aadd( aBotoes, { @oBtnConfirmar, "&Confirmar", { || lOk := .T., oDlg:End() } } )
aadd( aBotoes, { @oBtnCancelar , "&Voltar",    { || lOk := .F., oDlg:End() } } )

ACTIVATE DIALOG oDlg CENTERED ON INIT (EstiloTela(oDlg,aBotoes),oDlg:show(),setfocus(oDlg))

if lOk

   hTdmFile["dtDe"]    := dDtIni    
   hTdmFile["dtAte"]   := dDtFim   
   hTdmFile["confirm"] := .T. 

   pu_SetOmie( "ShowDetail", if(hTdmFile["ShowDetail"],"true", "false"), "REPORT" )

endif

return hTdmFile

********************************************************************************
static function pu_Omie2Hash( hTdmFile )
********************************************************************************

local lRet      := .F.
local hOmiePdv  := {=>}

local nPos      := 0

local aCupons   := {}
local hCupom    := {=>}

local aDias     := {}
local hDia      := {=>}

local aMeios    := {}
local hMeio     := {=>}

local aMeioDias := {}
local hMeioDia  := {=>}

local aProdDias := {}
local hProdDia  := {=>}

local aProdutos := {}
local hProduto  := {=>}

local aCaixas   := {}
local hCaixa    := {=>}

local aCaiDias  := {}
local hCaiDia   := {=>}

local cTexto := ""

SET DELETED OFF

USE ( hTdmFile["PASTA_OMIEPDV"]+"CUPOM.DBF" )    ALIAS xCUPOM     VIA "ADS" SHARED NEW

USE ( hTdmFile["PASTA_OMIEPDV"]+"ESTAT.DBF" )    ALIAS xESTAT     VIA "ADS" SHARED NEW

USE ( hTdmFile["PASTA_OMIEPDV"]+"CARTAO.DBF" )   ALIAS xCARTAO    VIA "ADS" SHARED NEW

USE ( hTdmFile["PASTA_OMIEPDV"]+"ESTOQUE.DBF" )  ALIAS xESTOQUE   VIA "ADS" SHARED NEW

USE ( hTdmFile["PASTA_OMIEPDV"]+"CAIXA.DBF" )    ALIAS xCAIXA     VIA "ADS" SHARED NEW

USE ( hTdmFile["PASTA_OMIEPDV"]+"MOVCAIXA.DBF" ) ALIAS xMOVCAIXA  VIA "ADS" SHARED NEW

USE (hTdmFile["PASTA_OMIEPDV"]+"SATFISCAL.DBF")  ALIAS xSATFISCAL VIA "ADS" SHARED NEW

USE (hTdmFile["PASTA_OMIEPDV"]+"SATITENS.DBF")   ALIAS xSATITENS  VIA "ADS" SHARED NEW

DbUseArea( .T., "ADS", (hTdmFile["PASTA_OMIEPDV"]+"NFCCAB.DBF"), "xNFCCAB", .T. )

DbUseArea( .T., "ADS", (hTdmFile["PASTA_OMIEPDV"]+"NFCITENS.DBF"), "xNFCITENS", .T. )

xCUPOM->(dbSetOrder(4))     // DATA
xESTAT->(dbSetOrder(2))     // CUPOM
xCARTAO->(dbSetOrder(1))    // CODIGO
xESTOQUE->(dbSetOrder(1))   // CODIGO
xCAIXA->(dbSetOrder(1))     // DATA
xMOVCAIXA->(dbSetOrder(1))  // DATA

xSATFISCAL->(dbSetOrder(2)) // CUPOM
xSATITENS->(dbSetOrder(1))  // REGSAT

xNFCCAB->(dbSetOrder(3))    // NNF
xNFCITENS->(dbSetOrder(1))  // REGISTRONF

BEGIN SEQUENCE

   ////////////////////////////////////////////
   /*
   cTexto := ""
   
   // USE ( "omieest.DBF" )  ALIAS vbESTOQUE   VIA "ADS" SHARED NEW
   
   // vbESTOQUE->(dbSetOrder(1))   // CODIGO

   xESTOQUE->(dbGoTop())

   do while !xESTOQUE->(eof())
      if val(xESTOQUE->BARRA) = 0
         cTexto += xESTOQUE->CODOMIE + "|" + xESTOQUE->CODIGO + "|" + xESTOQUE->DESCRICAO + "|" + xESTOQUE->BARRA + "|" + xESTOQUE->BARRA2 + "|" + xESTOQUE->UNIDADE + "|" + CRLF
      endif
      xESTOQUE->(dbSkip())
   enddo
   
   // vbESTOQUE->(dbCloseArea())

   if !empty(cTexto)
      if file('G:\temp\sos\omienull.log')
         ferase('G:\temp\sos\omienull.log')
      endif
      pu_LogFile( 'G:\temp\sos\omienull.log', { cTexto }, .f. )
   endif
   */
   ////////////////////////////////////////////

   hOmiePdv["dtIni"]      := stod(hTdmFile["hEcf"]["dtIni"])
   hOmiePdv["dtFim"]      := stod(hTdmFile["hEcf"]["dtFim"])
   hOmiePdv["tipoCF"]     := hTdmFile["tipoCF"]
   hOmiePdv["DEBUG"]      := hTdmFile["DEBUG"]
   hOmiePdv["ShowDetail"] := hTdmFile["ShowDetail"]

   xCUPOM->(dbGoTop())

   xCUPOM->(dbSeek( dtos(hOmiePdv["dtIni"]), .t. ))

   if xCUPOM->DATA > hOmiePdv["dtFim"] .or. xCUPOM->(eof())
      BREAK
   endif

   do while xCUPOM->DATA <= hOmiePdv["dtFim"] .and. !xCUPOM->(eof())

      // Totais por Cupom.

      hCupom  := {=>}
      hCupom["dtEmi"]   := xCUPOM->DATA
      hCupom["hrEmi"]   := xCUPOM->HORA
      hCupom["MeioPag"] := xCUPOM->TIPO
      hCupom["Cupom"]   := xCUPOM->CUPOM
      hCupom["CCF"]     := xCUPOM->CCF
      hCupom["COO"]     := xCUPOM->COO
      hCupom["vTot"]    := xCUPOM->TOTAL
      hCupom["vLiq"]    := xCUPOM->LIQUIDO
      hCupom["caixa"]   := xCUPOM->CX
      hCupom["itens"]   := xCUPOM->QTD_ITENS
      hCupom["cartao"]  := xCUPOM->CT
      hCupom["nSerie"]  := xCUPOM->NUMSERIE
      hCupom["canc"]    := xCUPOM->CANC
      hCupom["descr"]   := hCupom["MeioPag"]
      hCupom["IsSAT"]   := .F.
      hCupom["IsNFCE"]  := .F.

      hCupom["NFCE_CHAVE"]     := ""
      hCupom["NFCE_NUM"]       := ""
      hCupom["NFCE_SERIE"]     := ""
      hCupom["NFCE_PROTOCOLO"] := ""
      hCupom["NFCE_DHEMI"]     := ""
      hCupom["NFCE_DATA"]      := ""
      hCupom["NFCE_HORA"]      := ""
      hCupom["NFCE_XJUST"]     := ""

      hCupom["NFCE_CVPROD"]    := 0
      hCupom["NFCE_CVDESC"]    := 0
      hCupom["NFCE_CVOUTRO"]   := 0
      hCupom["NFCE_CVNF"]      := 0
      hCupom["NFCE_CVBC"]      := 0

      hCupom["NFCE_VPROD"]     := 0
      hCupom["NFCE_VDESC"]     := 0
      hCupom["NFCE_VOUTRO"]    := 0
      hCupom["NFCE_VNF"]       := 0
      hCupom["NFCE_VBC"]       := 0

      hCupom["NFCE_RECIBO"]    := ""
      hCupom["NFCE_PROC"]      := ""
      hCupom["NFCE_CONT"]      := ""
      hCupom["NFCE_CANC"]      := ""
      hCupom["NFCE_INUT"]      := ""
      hCupom["NFCE_NRECNO"]    := 0

      hCupom["SAT_EXTRATO"]    := ""
      hCupom["SAT_CHAVE"]      := ""
      hCupom["SAT_PROTOCOLO"]  := 0
      hCupom["SAT_SESSAO"]     := ""
      hCupom["SAT_CANC"]       := ""
      hCupom["SAT_CANCCHAVE"]  := ""
      hCupom["SAT_CANCDTHR"]   := ""
      hCupom["SAT_CANCPROT"]   := ""
      hCupom["SAT_NRECNO"]     := 0

      do case
      case hCupom["MeioPag"] = "CH" ; hCupom["descr"] := "Cheque"
      case hCupom["MeioPag"] = "AV" ; hCupom["descr"] := "Dinheiro"
      case hCupom["MeioPag"] = "AP" ; hCupom["descr"] := "A prazo"
      case hCupom["MeioPag"] = "CT" 
         
         hCupom["descr"] := "Cartao"

         if xCARTAO->(dbSeek( hCupom["cartao"] ))
            hCupom["descr"] := pu_SemAcento(xCARTAO->DESCRICAO)
         endif

      endcase

      ///////////////////////////////////////////////////////////////////////

      do case
      case hTdmFile["tipoCF"] == "NFCE"

         if xNFCCAB->(dbSeek( alltrim(str(xCUPOM->COO)) ))

            hCupom["CCF"]            := val(xNFCCAB->NNF)
            hCupom["NFCE_CHAVE"]     := xNFCCAB->CHAVENFCE
            hCupom["NFCE_NUM"]       := xNFCCAB->CNF
            hCupom["NFCE_SERIE"]     := xNFCCAB->SERIE
            hCupom["NFCE_PROTOCOLO"] := xNFCCAB->PROTOCOLO
            hCupom["NFCE_DHEMI"]     := xNFCCAB->DHEMI
            hCupom["NFCE_DATA"]      := substr(xNFCCAB->DHEMI,1,10)
            hCupom["NFCE_HORA"]      := substr(xNFCCAB->DHEMI,12,8)
            hCupom["NFCE_XJUST"]     := xNFCCAB->XJUST

            hCupom["NFCE_CVPROD"]    := 0
            hCupom["NFCE_CVDESC"]    := 0
            hCupom["NFCE_CVOUTRO"]   := 0
            hCupom["NFCE_CVNF"]      := 0
            hCupom["NFCE_CVBC"]      := 0

            hCupom["NFCE_VPROD"]     := 0
            hCupom["NFCE_VDESC"]     := 0
            hCupom["NFCE_VOUTRO"]    := 0
            hCupom["NFCE_VNF"]       := 0
            hCupom["NFCE_VBC"]       := 0

            if xNFCCAB->CANCELADA
               hCupom["NFCE_CVPROD"]    := xNFCCAB->VPROD
               hCupom["NFCE_CVDESC"]    := xNFCCAB->VDESC
               hCupom["NFCE_CVOUTRO"]   := xNFCCAB->VOUTRO
               hCupom["NFCE_CVNF"]      := xNFCCAB->VNF
               hCupom["NFCE_CVBC"]      := xNFCCAB->VBC
            else
               hCupom["NFCE_VPROD"]     := xNFCCAB->VPROD
               hCupom["NFCE_VDESC"]     := xNFCCAB->VDESC
               hCupom["NFCE_VOUTRO"]    := xNFCCAB->VOUTRO
               hCupom["NFCE_VNF"]       := xNFCCAB->VNF
               hCupom["NFCE_VBC"]       := xNFCCAB->VBC
            endif

            hCupom["NFCE_RECIBO"]    := xNFCCAB->RECIBO
            hCupom["NFCE_PROC"]      := if(xNFCCAB->PROCESSADO, "S", "N" )
            hCupom["NFCE_CONT"]      := if(xNFCCAB->CONTINGENC, "S", "N" )
            hCupom["NFCE_CANC"]      := if(xNFCCAB->CANCELADA, "S", "N" )
            hCupom["NFCE_INUT"]      := if(xNFCCAB->INUTILIZA, "S", "N" )
            hCupom["NFCE_NRECNO"]    := xNFCCAB->(RecNo())
            hCupom["IsNFCE"]         := .T.
            hCupom["canc"]           := xNFCCAB->CANCELADA
         endif

      case hTdmFile["tipoCF"] == "SAT"

         if xSATFISCAL->(dbSeek( xCUPOM->CUPOM ))

            hCupom["SAT_EXTRATO"]   := substr(xSATFISCAL->CHAVESAT,32,6)
            hCupom["SAT_CHAVE"]     := xSATFISCAL->CHAVESAT
            hCupom["SAT_PROTOCOLO"] := xSATFISCAL->PROTOCOLO
            hCupom["SAT_SESSAO"]    := xSATFISCAL->SESSAO
            hCupom["SAT_CANC"]      := if(xSATFISCAL->CANCELADA, "S", "N" )
            hCupom["SAT_CANCCHAVE"] := xSATFISCAL->CHAVECANCE
            hCupom["SAT_CANCDTHR"]  := xSATFISCAL->DATAHORACA
            hCupom["SAT_CANCPROT"]  := xSATFISCAL->PROTCANCE                           
            hCupom["SAT_NRECNO"]    := xSATFISCAL->(RecNo())
            hCupom["IsSAT"]         := .T.
            hCupom["canc"]          := xSATFISCAL->CANCELADA
         
         endif

      endcase

      ///////////////////////////////////////////////////////////////////////

      aadd( aCupons, hCupom )

      // Totais por Meio de Pagamento.

      if len(aMeios) = 0
         nPos := 0
      else
         nPos := ascan( aMeios, {|hItMeio| alltrim(hItMeio["MeioPag"]) == alltrim(hCupom["MeioPag"]) .and. hItMeio["cartao"] == hCupom["cartao"] } )
      endif

      if nPos = 0
         hMeio := {=>}
         hMeio["MeioPag"] := hCupom["MeioPag"]
         hMeio["cartao"]  := hCupom["cartao"]
         hMeio["COO"]     := 1            
         hMeio["vTot"]    := 0
         hMeio["vLiq"]    := 0
         hMeio["vTotC"]   := 0
         hMeio["vLiqC"]   := 0

         hMeio["descr"]   := ""

         do case
         case hTdmFile["tipoCF"] == "NFCE"
            hMeio["vTot"]    := hCupom["NFCE_VPROD"]
            hMeio["vLiq"]    := hCupom["NFCE_VNF"]
            hMeio["vTotC"]   := hCupom["NFCE_CVPROD"]
            hMeio["vLiqC"]   := hCupom["NFCE_CVNF"]

         case hTdmFile["tipoCF"] == "SAT"
            hMeio["vTot"]    := hCupom["vTot"]
            hMeio["vLiq"]    := hCupom["vLiq"]

         case hTdmFile["tipoCF"] == "ECF"
            hMeio["vTot"]    := hCupom["vTot"]
            hMeio["vLiq"]    := hCupom["vLiq"]

         endcase

         do case
         case hCupom["MeioPag"] = "CH" ; hMeio["descr"] := "Cheque"
         case hCupom["MeioPag"] = "AV" ; hMeio["descr"] := "Dinheiro"
         case hCupom["MeioPag"] = "AP" ; hMeio["descr"] := "A prazo"
         case hCupom["MeioPag"] = "CT" 
            
            hMeio["descr"] := "Cartao"

            if xCARTAO->(dbSeek( hCupom["cartao"] ))
               hMeio["descr"] := pu_SemAcento(xCARTAO->DESCRICAO)
            endif

         endcase

         aadd( aMeios, hMeio )
      else
         aMeios[nPos]["COO"]  += 1  

         do case
         case hTdmFile["tipoCF"] == "NFCE"
            aMeios[nPos]["vTot"]  += hCupom["NFCE_VPROD"]
            aMeios[nPos]["vLiq"]  += hCupom["NFCE_VNF"]
            aMeios[nPos]["vTotC"] += hCupom["NFCE_CVPROD"]
            aMeios[nPos]["vLiqC"] += hCupom["NFCE_CVNF"]

         case hTdmFile["tipoCF"] == "SAT"
            aMeios[nPos]["vTot"] += hCupom["vTot"]
            aMeios[nPos]["vLiq"] += hCupom["vLiq"]

         case hTdmFile["tipoCF"] == "ECF"
            aMeios[nPos]["vTot"] += hCupom["vTot"]
            aMeios[nPos]["vLiq"] += hCupom["vLiq"]

         endcase

      endif

      // Totais por Meio de Pagamento / Dia .

      if len(aMeioDias) = 0
         nPos := 0
      else
         nPos := ascan( aMeioDias, {|hItMeio| alltrim(hItMeio["MeioPag"]) == alltrim(hCupom["MeioPag"]) .and. hItMeio["cartao"] == hCupom["cartao"] .and. hItMeio["dtEmi"] == hCupom["dtEmi"]  } )
      endif

      if nPos = 0
         hMeioDia := {=>}
         hMeioDia["MeioPag"] := hCupom["MeioPag"]
         hMeioDia["cartao"]  := hCupom["cartao"]
         hMeioDia["dtEmi"]   := hCupom["dtEmi"]
         hMeioDia["COO"]     := 1            
         hMeioDia["vTot"]    := 0
         hMeioDia["vLiq"]    := 0
         hMeioDia["vTotC"]   := 0
         hMeioDia["vLiqC"]   := 0
         hMeioDia["descr"]   := ""

         do case
         case hTdmFile["tipoCF"] == "NFCE"
            hMeioDia["vTot"]  := hCupom["NFCE_VPROD"]
            hMeioDia["vLiq"]  := hCupom["NFCE_VNF"]
            hMeioDia["vTotC"] := hCupom["NFCE_CVPROD"]
            hMeioDia["vLiqC"] := hCupom["NFCE_CVNF"]

         case hTdmFile["tipoCF"] == "SAT"
            hMeioDia["vTot"] := hCupom["vTot"]
            hMeioDia["vLiq"] := hCupom["vLiq"]

         case hTdmFile["tipoCF"] == "ECF"
            hMeioDia["vTot"] := hCupom["vTot"]
            hMeioDia["vLiq"] := hCupom["vLiq"]

         endcase

         do case
         case hCupom["MeioPag"] = "CH" ; hMeioDia["descr"] := "Cheque"
         case hCupom["MeioPag"] = "AV" ; hMeioDia["descr"] := "Dinheiro"
         case hCupom["MeioPag"] = "AP" ; hMeioDia["descr"] := "A prazo"
         case hCupom["MeioPag"] = "CT" 
            
            hMeioDia["descr"] := "Cartao"

            if xCARTAO->(dbSeek( hCupom["cartao"] ))
               hMeioDia["descr"] := pu_SemAcento(xCARTAO->DESCRICAO)
            endif

         endcase

         aadd( aMeioDias, hMeioDia )
      else
         aMeioDias[nPos]["COO"]  += 1  

         do case
         case hTdmFile["tipoCF"] == "NFCE"
            aMeioDias[nPos]["vTot"]  += hCupom["NFCE_VPROD"]
            aMeioDias[nPos]["vLiq"]  += hCupom["NFCE_VNF"]
            aMeioDias[nPos]["vTotC"] += hCupom["NFCE_CVPROD"]
            aMeioDias[nPos]["vLiqC"] += hCupom["NFCE_CVNF"]

         case hTdmFile["tipoCF"] == "SAT"
            aMeioDias[nPos]["vTot"] += hCupom["vTot"]
            aMeioDias[nPos]["vLiq"] += hCupom["vLiq"]

         case hTdmFile["tipoCF"] == "ECF"
            aMeioDias[nPos]["vTot"] += hCupom["vTot"]
            aMeioDias[nPos]["vLiq"] += hCupom["vLiq"]

         endcase

      endif

      // Totais por dia.

      if len(aDias) = 0
         nPos := 0
      else
         nPos := ascan( aDias, {|hItDia| hItDia["dtEmi"] == hCupom["dtEmi"] } )
      endif

      if nPos = 0
         hDia := {=>}
         hDia["dtEmi"] := hCupom["dtEmi"]
         hDia["COO"]   := 1            
         hDia["vTot"]  := 0
         hDia["vDes"]  := 0
         hDia["vOut"]  := 0
         hDia["vLiq"]  := 0
         hDia["vTotC"] := 0
         hDia["vDesC"] := 0
         hDia["vOutC"] := 0
         hDia["vLiqC"] := 0

         do case
         case hTdmFile["tipoCF"] == "NFCE"
            hDia["vTot"]  := hCupom["NFCE_VPROD"]
            hDia["vDes"]  := hCupom["NFCE_VDESC"]
            hDia["vOut"]  := hCupom["NFCE_VOUTRO"]
            hDia["vLiq"]  := hCupom["NFCE_VNF"]
            hDia["vTotC"] := hCupom["NFCE_CVPROD"]
            hDia["vDesC"] := hCupom["NFCE_CVDESC"]
            hDia["vOutC"] := hCupom["NFCE_CVOUTRO"]
            hDia["vLiqC"] := hCupom["NFCE_CVNF"]

         case hTdmFile["tipoCF"] == "SAT"
            hDia["vTot"] := hCupom["vTot"]
            hDia["vLiq"] := hCupom["vLiq"]

         case hTdmFile["tipoCF"] == "ECF"
            hDia["vTot"] := hCupom["vTot"]
            hDia["vLiq"] := hCupom["vLiq"]

         endcase

         aadd( aDias, hDia )
      else
         aDias[nPos]["COO"]  += 1

         do case
         case hTdmFile["tipoCF"] == "NFCE"
            aDias[nPos]["vTot"]  += hCupom["NFCE_VPROD"]
            aDias[nPos]["vDes"]  += hCupom["NFCE_VDESC"]
            aDias[nPos]["vOut"]  += hCupom["NFCE_VOUTRO"]
            aDias[nPos]["vLiq"]  += hCupom["NFCE_VNF"]
            aDias[nPos]["vTotC"] += hCupom["NFCE_CVPROD"]
            aDias[nPos]["vDesC"] += hCupom["NFCE_CVDESC"]
            aDias[nPos]["vOutC"] += hCupom["NFCE_CVOUTRO"]
            aDias[nPos]["vLiqC"] += hCupom["NFCE_CVNF"]

         case hTdmFile["tipoCF"] == "SAT"
            aDias[nPos]["vTot"] += hCupom["vTot"]
            aDias[nPos]["vLiq"] += hCupom["vLiq"]

         case hTdmFile["tipoCF"] == "ECF"
            aDias[nPos]["vTot"] += hCupom["vTot"]
            aDias[nPos]["vLiq"] += hCupom["vLiq"]

         endcase

      endif

      //////////////////////////////////////////////////////

      // Totais por Produto

      do case
      case hTdmFile["tipoCF"] == "NFCE"

         if xNFCITENS->(dbSeek( hCupom["COO"] ))

            do while xNFCITENS->REGISTRONF = hCupom["COO"] .and. !xNFCITENS->(eof())
               
               hProduto := {=>}
               hProduto["codigo"] := left(xNFCITENS->CPROD,7)
               hProduto["descr"]  := left(pu_SemAcento(xNFCITENS->XPROD),50)

               hProduto["qtdeC"]  := 0
               hProduto["vTotC"]  := 0 
               hProduto["vDesC"]  := 0
               hProduto["vOutC"]  := 0
               hProduto["vLiqC"]  := 0

               hProduto["qtde"]   := 0
               hProduto["vTot"]   := 0 
               hProduto["vDes"]   := 0
               hProduto["vOut"]   := 0
               hProduto["vLiq"]   := 0

               if hCupom["canc"]
                  hProduto["qtdeC"]  := xNFCITENS->QCOM
                  hProduto["vTotC"]  := xNFCITENS->VPROD 
                  hProduto["vDesC"]  := xNFCITENS->VDESC
                  hProduto["vOutC"]  := xNFCITENS->VOUTRO
                  hProduto["vLiqC"]  := xNFCITENS->VBC
               else
                  hProduto["qtde"]   := xNFCITENS->QCOM
                  hProduto["vTot"]   := xNFCITENS->VPROD 
                  hProduto["vDes"]   := xNFCITENS->VDESC
                  hProduto["vOut"]   := xNFCITENS->VOUTRO
                  hProduto["vLiq"]   := xNFCITENS->VBC
               endif

               if len(aProdutos) = 0
                  nPos := 0
               else
                  nPos := ascan( aProdutos, {|hItPrd| hItPrd["codigo"] == hProduto["codigo"] } )
               endif

               if nPos = 0
                  aadd( aProdutos, hProduto )
               else
                  if hCupom["canc"]
                     aProdutos[nPos]["qtdeC"] += hProduto["qtde"]
                     aProdutos[nPos]["vTotC"] += hProduto["vTot"]
                     aProdutos[nPos]["vDesC"] += hProduto["vDes"]
                     aProdutos[nPos]["vOutC"] += hProduto["vOut"]
                     aProdutos[nPos]["vLiqC"] += hProduto["vLiq"]
                  else
                     aProdutos[nPos]["qtde"] += hProduto["qtde"]
                     aProdutos[nPos]["vTot"] += hProduto["vTot"]
                     aProdutos[nPos]["vDes"] += hProduto["vDes"]
                     aProdutos[nPos]["vOut"] += hProduto["vOut"]
                     aProdutos[nPos]["vLiq"] += hProduto["vLiq"]
                  endif
               endif

               // Totais por Produto / Dia

               if len(aProdDias) = 0
                  nPos := 0
               else
                  nPos := ascan( aProdDias, {|hItPrd| hItPrd["codigo"] == hProduto["codigo"] .and. hItPrd["dtEmi"] == hCupom["dtEmi"] } )
               endif

               if nPos = 0
                  hProdDia := {=>}
                  hProdDia["codigo"] := hProduto["codigo"]
                  hProdDia["dtEmi"]  := hCupom["dtEmi"]
                  hProdDia["descr"]  := hProduto["descr"]

                  hProdDia["qtdeC"]  := 0
                  hProdDia["vTotC"]  := 0
                  hProdDia["vDesC"]  := 0
                  hProdDia["vOutC"]  := 0
                  hProdDia["vLiqC"]  := 0
                  hProdDia["qtde"]   := 0
                  hProdDia["vTot"]   := 0
                  hProdDia["vDes"]   := 0
                  hProdDia["vOut"]   := 0
                  hProdDia["vLiq"]   := 0

                  if hCupom["canc"]
                     hProdDia["qtdeC"]  := hProduto["qtdeC"]
                     hProdDia["vTotC"]  := hProduto["vTotC"]
                     hProdDia["vDesC"]  := hProduto["vDesC"]
                     hProdDia["vOutC"]  := hProduto["vOutC"]
                     hProdDia["vLiqC"]  := hProduto["vLiqC"]
                  else
                     hProdDia["qtde"]   := hProduto["qtde"]
                     hProdDia["vTot"]   := hProduto["vTot"]
                     hProdDia["vDes"]   := hProduto["vDes"]
                     hProdDia["vOut"]   := hProduto["vOut"]
                     hProdDia["vLiq"]   := hProduto["vLiq"]
                  endif

                  aadd( aProdDias, hProdDia )
               else

                  if hCupom["canc"]
                     aProdDias[nPos]["qtdeC"] += hProduto["qtdeC"]
                     aProdDias[nPos]["vTotC"] += hProduto["vTotC"]
                     aProdDias[nPos]["vDesC"] += hProduto["vDesC"]
                     aProdDias[nPos]["vOutC"] += hProduto["vOutC"]
                     aProdDias[nPos]["vLiqC"] += hProduto["vLiqC"]
                  else
                     aProdDias[nPos]["qtde"]  += hProduto["qtde"]
                     aProdDias[nPos]["vTot"]  += hProduto["vTot"]
                     aProdDias[nPos]["vDes"]  += hProduto["vDes"]
                     aProdDias[nPos]["vOut"]  += hProduto["vOut"]
                     aProdDias[nPos]["vLiq"]  += hProduto["vLiq"]
                  endif

               endif

               xNFCITENS->(dbSkip())

            enddo

         endif

      case hTdmFile["tipoCF"] == "SAT"

      case hTdmFile["tipoCF"] == "ECF"

         if xESTAT->(dbSeek( hCupom["Cupom"] ))

            do while xESTAT->CUPOM = hCupom["Cupom"] .and. !xESTAT->(eof())
               
               hProduto := {=>}
               hProduto["codigo"] := xESTAT->VCOD
               hProduto["descr"]  := ""
               hProduto["qtdeC"]  := 0
               hProduto["vTotC"]  := 0 
               hProduto["vDesC"]  := 0
               hProduto["vOutC"]  := 0
               hProduto["vLiqC"]  := 0
               hProduto["qtde"]   := 0
               hProduto["vTot"]   := 0
               hProduto["vDes"]   := 0
               hProduto["vOut"]   := 0
               hProduto["vLiq"]   := 0

               if hCupom["canc"]
                  hProduto["qtdeC"]  := xESTAT->QTD
                  hProduto["vTotC"]  := xESTAT->PRECOVEND * xESTAT->QTD
                  hProduto["vLiqC"]  := xESTAT->PRECODSC * xESTAT->QTD
               else
                  hProduto["qtde"]   := xESTAT->QTD
                  hProduto["vTot"]   := xESTAT->PRECOVEND * xESTAT->QTD
                  hProduto["vLiq"]   := xESTAT->PRECODSC * xESTAT->QTD
               endif

               if len(aProdutos) = 0
                  nPos := 0
               else
                  nPos := ascan( aProdutos, {|hItPrd| hItPrd["codigo"] == hProduto["codigo"] } )
               endif

               if nPos = 0

                  if xESTOQUE->(dbSeek( hProduto["codigo"] ))
                     hProduto["descr"] := pu_SemAcento(xESTOQUE->DESCRICAO)
                  endif

                  aadd( aProdutos, hProduto )
               else
                  aProdutos[nPos]["qtde"] += hProduto["qtde"]
                  aProdutos[nPos]["vTot"] += hProduto["vTot"]
                  aProdutos[nPos]["vLiq"] += hProduto["vLiq"]
               endif

               // Totais por Produto / Dia

               if len(aProdDias) = 0
                  nPos := 0
               else
                  nPos := ascan( aProdDias, {|hItPrd| hItPrd["codigo"] == hProduto["codigo"] .and. hItPrd["dtEmi"] == hCupom["dtEmi"] } )
               endif

               if nPos = 0

                  hProdDia := {=>}
                  hProdDia["codigo"] := hProduto["codigo"]
                  hProdDia["dtEmi"]  := hCupom["dtEmi"]
                  hProdDia["descr"]  := ""
                  hProdDia["qtdeC"]  := 0
                  hProdDia["vTotC"]  := 0
                  hProdDia["vDesC"]  := 0
                  hProdDia["vOutC"]  := 0
                  hProdDia["vLiqC"]  := 0
                  hProdDia["qtde"]   := 0
                  hProdDia["vTot"]   := 0
                  hProdDia["vDes"]   := 0
                  hProdDia["vOut"]   := 0
                  hProdDia["vLiq"]   := 0

                  if xESTOQUE->(dbSeek( hProdDia["codigo"] ))
                     hProdDia["descr"] := pu_SemAcento(xESTOQUE->DESCRICAO)
                  endif

                  if hCupom["canc"]
                     hProdDia["qtdeC"]  := hProduto["qtdeC"]
                     hProdDia["vTotC"]  := hProduto["vTotC"]
                     hProdDia["vDesC"]  := hProduto["vDesC"]
                     hProdDia["vOutC"]  := hProduto["vOutC"]
                     hProdDia["vLiqC"]  := hProduto["vLiqC"]                  
                  else
                     hProdDia["qtde"]   := hProduto["qtde"]
                     hProdDia["vTot"]   := hProduto["vTot"]
                     hProdDia["vDes"]   := hProduto["vDes"]
                     hProdDia["vOut"]   := hProduto["vOut"]                  
                     hProdDia["vLiq"]   := hProduto["vLiq"]
                  endif

                  aadd( aProdDias, hProdDia )
               
               else

                  if hCupom["canc"]
                     aProdDias[nPos]["qtdeC"] += hProduto["qtdeC"]
                     aProdDias[nPos]["vTotC"] += hProduto["vTotC"]
                     aProdDias[nPos]["vDesC"] += hProduto["vDesC"]
                     aProdDias[nPos]["vOutC"] += hProduto["vOutC"]
                     aProdDias[nPos]["vLiqC"] += hProduto["vLiqC"]
                  else
                     aProdDias[nPos]["qtde"]  += hProduto["qtde"]
                     aProdDias[nPos]["vTot"]  += hProduto["vTot"]
                     aProdDias[nPos]["vDes"]  += hProduto["vDes"]
                     aProdDias[nPos]["vOut"]  += hProduto["vOut"]
                     aProdDias[nPos]["vLiq"]  += hProduto["vLiq"]
                  endif

               endif

               xESTAT->(dbSkip())

            enddo

         endif
         
      endcase

      //////////////////////////////////////////////////////

      xCUPOM->(dbSkip())

   enddo

   ///////////////////////////////////////////////////

   // Caixa.

   xCAIXA->(dbGoTop())

   xCAIXA->(dbSeek( dtos(hOmiePdv["dtIni"]), .t. ))

   if xCAIXA->DATA > hOmiePdv["dtFim"] .or. xCAIXA->(eof())

      // Sem Caixa
   
   else

      do while xCAIXA->DATA <= hOmiePdv["dtFim"] .and. !xCAIXA->(eof())

         hCaixa := {=>}
         hCaixa["dtEmi"]  := xCAIXA->DATA 
         hCaixa["hrEmi"]  := left(xCAIXA->INICIAL,5)
         hCaixa["numero"] := xCAIXA->NUM
         hCaixa["codigo"] := 0 
         hCaixa["valor"]  := xCAIXA->CX_INICIAL
         hCaixa["obs"]    := "Abertura"
         hCaixa["order"]  := "10"
         aadd( aCaixas, hCaixa )

         // Se houve venda em dinheiro, Adiciona ao fechamento do Caixa.

         nPos := ascan( aMeioDias, {|hItMeio| alltrim(hItMeio["MeioPag"]) == "AV" .and. hItMeio["dtEmi"] == xCAIXA->DATA } )

         if nPos > 0
            hCaixa := {=>}
            hCaixa["dtEmi"]  := xCAIXA->DATA 
            hCaixa["hrEmi"]  := left(xCAIXA->INICIAL,5)
            hCaixa["numero"] := xCAIXA->NUM
            hCaixa["codigo"] := 0 
            hCaixa["valor"]  := aMeioDias[nPos]["vLiq"]
            hCaixa["obs"]    := "Dinheiro"
            hCaixa["order"]  := "70"
            aadd( aCaixas, hCaixa )
         endif

         if !empty(xCAIXA->DATA_FINAL)
            hCaixa := {=>}
            hCaixa["dtEmi"]  := xCAIXA->DATA_FINAL 
            hCaixa["hrEmi"]  := left(xCAIXA->FINAL,5)
            hCaixa["numero"] := xCAIXA->NUM
            hCaixa["codigo"] := 0 
            hCaixa["valor"]  := xCAIXA->CX_FINAL
            hCaixa["obs"]    := "Fechamento"
            hCaixa["order"]  := "90"
            aadd( aCaixas, hCaixa )
         endif

         xCAIXA->(dbSkip())

      enddo

   endif

   // Movimento do caixa.

   xMOVCAIXA->(dbGoTop())

   xMOVCAIXA->(dbSeek( dtos(hOmiePdv["dtIni"]), .t. ))

   if xMOVCAIXA->DATA > hOmiePdv["dtFim"] .or. xMOVCAIXA->(eof())

      // Sem Movimento de Caixa
   
   else

      do while xMOVCAIXA->DATA <= hOmiePdv["dtFim"] .and. !xMOVCAIXA->(eof())

         hCaixa := {=>}
         hCaixa["dtEmi"]  := xMOVCAIXA->DATA 
         hCaixa["hrEmi"]  := left(xMOVCAIXA->HORA,5)
         hCaixa["numero"] := xMOVCAIXA->CX 
         hCaixa["codigo"] := xMOVCAIXA->CODIGO 
         if hCaixa["codigo"] = 1
            hCaixa["valor"] := xMOVCAIXA->VALOR * (-1)
         else
            hCaixa["valor"] := xMOVCAIXA->VALOR
         endif
         hCaixa["obs"]    := xMOVCAIXA->OBS
         hCaixa["order"]  := "50"

         aadd( aCaixas, hCaixa )

         xMOVCAIXA->(dbSkip())

      enddo

   endif

   if len(aCaixas) > 0
      aCaixas := ASort( aCaixas,,, {|x,y| dtos(x["dtEmi"])+x["order"]+x["hrEmi"] < dtos(y["dtEmi"])+y["order"]+y["hrEmi"] } )
   endif

   ///////////////////////////////////////////////////

   hOmiePdv["aCupons"]   := aclone(aCupons)
   hOmiePdv["aDias"]     := aclone(aDias)
   hOmiePdv["aMeios"]    := aclone(aMeios)
   hOmiePdv["aMeioDias"] := aclone(aMeioDias)
   hOmiePdv["aProdutos"] := aclone(aProdutos)
   hOmiePdv["aProdDias"] := aclone(aProdDias)
   hOmiePdv["aCaixas"]   := aclone(aCaixas)
   hOmiePdv["hCaiDia"]   := aclone(hCaiDia)

   lRet := .T.

END SEQUENCE

xCUPOM->(dbclosearea())
xESTAT->(dbclosearea())
xCARTAO->(dbclosearea())
xESTOQUE->(dbclosearea())
xCAIXA->(dbclosearea())
xMOVCAIXA->(dbclosearea())
xSATFISCAL->(dbclosearea())
xSATITENS->(dbclosearea())
xNFCCAB->(dbclosearea())
xNFCITENS->(dbclosearea())

SET DELETED ON

return { lRet, hOmiePdv }

********************************************************************************
static function pu_Omie2Txt( hOmiePdv, lDetalhado, cTpFile )
********************************************************************************

local lRet      := .F.
local cReport   := ""
local cSep      := ""

local nTotLiq   := 0 
local nTotProd  := 0
local nTotDesc  := 0
local nTotOut   := 0
local nTotCF    := 0
local nTotCanc  := 0
local nTotQtde  := 0

local nTotLiqDia  := 0
local nTotProdDia := 0
local nTotDescDia := 0
local nTotOutDia  := 0
local nTotCFDia   := 0
local nTotCancDia := 0
local nTotQtdDia  := 0

local dDtAnt    := ctod("")
local cCOO      := ""

local aCupons   := {}
local hCupom    := {=>}
local aDias     := {}
local hDia      := {=>}
local aMeios    := {}
local hMeio     := {=>}
local aMeioDias := {}
local hMeioDia  := {=>}
local aProdutos := {}
local hProduto  := {=>}
local aProdDias := {}
local hProdDia  := {=>}
local aCaixas   := {}
local hCaixa    := {=>}
local aCaiDias  := {}
local hCaiDia   := {=>}

local nSaldo     := 0

default lDetalhado := .T.
default cTpFile    := "TXT"

BEGIN SEQUENCE

   if len(hOmiePdv) = 0
      BREAK
   endif

   // Separador de campos.

   //cSep := ";"

   if cTpFile == "TXT"
      cSep := "  "
   else
      cSep := ";"
   endif

   aCupons   := aclone(hOmiePdv["aCupons"])
   aDias     := aclone(hOmiePdv["aDias"])
   aMeios    := aclone(hOmiePdv["aMeios"])
   aMeioDias := aclone(hOmiePdv["aMeioDias"])
   aProdutos := aclone(hOmiePdv["aProdutos"])
   aProdDias := aclone(hOmiePdv["aProdDias"])
   aCaixas   := aclone(hOmiePdv["aCaixas"])
   hCaiDia   := aclone(hOmiePdv["hCaiDia"])

   // Gera o Relat rio do arquivo TDM.

   if len(aCupons) > 0 
      
      cReport += CRLF
      cReport += CRLF
      cReport += "OmiePDV - Resumo de Vendas - " + dtoc(date()) + " - " + time() + CRLF
      cReport += "Periodo: de " + dtoc(hOmiePdv["dtIni"]) + " a " + dtoc(hOmiePdv["dtFim"]) + CRLF

      do case
      case hOmiePdv["tipoCF"]=="NFCE" ; cReport += "NFC-e" + CRLF
      case hOmiePdv["tipoCF"]=="SAT"  ; cReport += "CF-e-SAT" + CRLF
      case hOmiePdv["tipoCF"]=="ECF"  ; cReport += "PAF-ECF" + CRLF
      endcase

   endif

   //////////////////////////////////////////////////////////////////////////////////////////////////////////
   // Imprime os cupons.
   //////////////////////////////////////////////////////////////////////////////////////////////////////////

   if len(aCupons) > 0 .and. hOmiePdv["ShowDetail"]

      nTotLiq  := 0
      nTotProd := 0
      nTotDesc := 0
      nTotOut  := 0
      nTotCF   := 0
      nTotCanc := 0

      dDtAnt   := ctod("")
      
      do case
      ///////////////////////////////////////////////////////////////////////////////////////////////////////   
      case hOmiePdv["tipoCF"]=="NFCE"

         cReport += replicate("=",220) + CRLF
         cReport += "NFC-e - Cupons Fiscais" + CRLF
         cReport += replicate("=",220) + CRLF
         cReport += "Data        Hora      Numero  Serie    Valor Prod.     Valor Desc.    Valor Outros     Valor Canc.        Valor NF  Chave                                         Protocolo           Proc Cont Canc Inut  Meio Pagto" + CRLF
         cReport += replicate("-",220) + CRLF

         for each hCupom in aCupons

            if hCupom["dtEmi"] <> dDtAnt 

               if !empty(dDtAnt) .and. cTpFile == "TXT"
                  cReport += pu_TotDia( dDtAnt, aDias, cSep )
               endif

               dDtAnt := hCupom["dtEmi"] 

            endif

            // Data de emiss o
            cReport += dtoc(hCupom["dtEmi"]) + cSep

            //// Data
            //cReport += hCupom["NFCE_DATA"] + cSep

            // Hora
            cReport += hCupom["NFCE_HORA"] + cSep

            // CCF 
            cReport += str(hCupom["CCF"],6) + cSep

            // // N mero 
            // cReport += hCupom["NFCE_NUM"] + cSep

            // S+rie
            cReport += hCupom["NFCE_SERIE"] + cSep

            // Valor de Produtos
            cReport += transform( hCupom["NFCE_VPROD"], "@RE 999,999,999.99" ) + cSep

            // Valor de Descontos
            cReport += transform( hCupom["NFCE_VDESC"], "@RE 999,999,999.99" ) + cSep

            // Valor de Outros
            cReport += transform( hCupom["NFCE_VOUTRO"], "@RE 999,999,999.99" ) + cSep

            // Valor de Cancelados
            cReport += transform( hCupom["NFCE_CVNF"], "@RE 999,999,999.99" ) + cSep

            // Valor da NF
            cReport += transform( hCupom["NFCE_VNF"], "@RE 999,999,999.99" ) + cSep

            // Chave da NFC-e
            cReport += hCupom["NFCE_CHAVE"] + cSep

            // Protocolo
            cReport += left(hCupom["NFCE_PROTOCOLO"],18) + cSep

            // Processada
            cReport += hCupom["NFCE_PROC"] + "  " + cSep

            // Contingoncia
            cReport += hCupom["NFCE_CONT"] + "  " + cSep

            // Cancelada
            cReport += hCupom["NFCE_CANC"] + "  " + cSep

            // Inutilizada
            cReport += hCupom["NFCE_INUT"] + "   " + cSep

            // Meio de Pagamento
            cReport += hCupom["MeioPag"] + cSep

            if hOmiePdv["DEBUG"] == 'true'

               // Valor da Base de Calculo
               cReport += transform( hCupom["NFCE_VBC"], "@RE 999,999,999.99" ) + cSep

               // Valor Cupom Fiscal
               cReport += transform( hCupom["vLiq"], "@RE 999,999,999.99" ) + cSep

               // Diferenoa
               cReport += transform( hCupom["vLiq"] - hCupom["NFCE_VNF"], "@RE 999,999,999.99" ) + cSep
            
            endif

            cReport += CRLF

            nTotProd += hCupom["NFCE_VPROD"]
            nTotDesc += hCupom["NFCE_VDESC"]
            nTotOut  += hCupom["NFCE_VOUTRO"]
            nTotCanc += hCupom["NFCE_CVNF"]
            nTotLiq  += hCupom["NFCE_VNF"]

            nTotCF += 1

         next 

         cReport += pu_TotDia( dDtAnt, aDias, cSep )
         cReport += "TOTAL                   "+str(nTotCF,4)+"        " + transform( nTotProd, "@RE 999,999,999.99" ) + "  " + transform( nTotDesc, "@RE 999,999,999.99" ) + "  " + transform( nTotOut, "@RE 999,999,999.99" ) + "  " +  transform( nTotCanc, "@RE 999,999,999.99" ) + "  " + transform( nTotLiq, "@RE 999,999,999.99" ) + cSep
         cReport += CRLF

      ///////////////////////////////////////////////////////////////////////////////////////////////////////
      case hOmiePdv["tipoCF"]=="SAT"

         cReport += replicate("=",220) + CRLF
         cReport += "SAT - Cupons Fiscais" + CRLF
         cReport += replicate("=",220) + CRLF
         cReport += "Data        Hora       Cupom  Extrato        Valor Total       Valor Liquido  Canc. Chave                                         Protocolo           " + CRLF
         cReport += replicate("-",220) + CRLF

         for each hCupom in aCupons

            if hCupom["dtEmi"] <> dDtAnt 

               if !empty(dDtAnt) .and. cTpFile == "TXT"
                  cReport += replicate("-",220) + CRLF
               endif

               dDtAnt := hCupom["dtEmi"] 

            endif

            // Data de emissao
            cReport += dtoc(hCupom["dtEmi"]) + cSep

            // Hora de emissao
            cReport += hCupom["hrEmi"] + cSep
                   
            // COO 
            cReport += str(hCupom["COO"],6) + cSep

            // Extrato
            cReport += hCupom["SAT_EXTRATO"] + cSep

            // Valor total
            cReport += transform( hCupom["vTot"], "@RE 999,999,999,999.99" ) + cSep
         
            // Valor loquido
            cReport += transform( hCupom["vLiq"], "@RE 999,999,999,999.99" ) + cSep

            // Cancelado S/N
            cReport += if(hCupom["canc"],"S   ","N   ") + cSep

            // Chave da NFC-e
            cReport += hCupom["SAT_CHAVE"] + cSep

            // Protocolo
            cReport += left(alltrim(str(hCupom["SAT_PROTOCOLO"]))+space(18),18) + cSep

            cReport += CRLF

            nTotLiq += hCupom["vLiq"]

            nTotCF += 1

         next 

         cReport += replicate("-",220) + CRLF
         cReport += "TOTAL                                                     " + transform( nTotLiq, "@RE 999,999,999,999.99" ) + cSep
         cReport += CRLF

      ///////////////////////////////////////////////////////////////////////////////////////////////////////
      case hOmiePdv["tipoCF"]=="ECF"

         cReport += replicate("=",85) + CRLF
         cReport += "ECF - Cupons Fiscais" + CRLF
         cReport += replicate("=",85) + CRLF
         cReport += "Data           CCF     COO         Valor Total       Valor Liquido  Canc  Meio Pagto" + CRLF
         cReport += replicate("-",85) + CRLF

         for each hCupom in aCupons

            if hCupom["dtEmi"] <> dDtAnt 
               if !empty(dDtAnt) .and. cTpFile == "TXT" 
                  cReport += replicate("-",85) + CRLF
               endif
               dDtAnt := hCupom["dtEmi"] 
            endif

            // Data de emiss o
            cReport += dtoc(hCupom["dtEmi"]) + cSep
                        
            // CCF 
            cReport += str(hCupom["CCF"],6) + cSep

            // COO
            cReport += str(hCupom["COO"],6) + cSep

            // Valor total
            cReport += transform( hCupom["vTot"], "@RE 999,999,999,999.99" ) + cSep
         
            // Valor loquido
            cReport += transform( hCupom["vLiq"], "@RE 999,999,999,999.99" ) + cSep

            // Cancelado S/N
            cReport += if(hCupom["canc"],"S   ","N   ") + cSep

            // Meio de Pagamento
            cReport += hCupom["MeioPag"] + cSep

            cReport += CRLF

            nTotLiq += hCupom["vLiq"]

         next 
         
         cReport += replicate("-",85) + CRLF
         cReport += "TOTAL                                           " + transform( nTotLiq, "@RE 999,999,999,999.99" ) + cSep
         cReport += CRLF
      
      endcase

   endif

   //////////////////////////////////////////////////////////////////////////////////////////////////////////
   // Imprime os totais por Dia.
   //////////////////////////////////////////////////////////////////////////////////////////////////////////

   if len(aDias) > 0 .and. hOmiePdv["ShowDetail"]

      nTotLiq  := 0
      nTotProd := 0
      nTotDesc := 0
      nTotOut  := 0
      nTotCF   := 0
      nTotCanc := 0

      do case
      ///////////////////////////////////////////////////////////////////////////////////////////////////////
      case hOmiePdv["tipoCF"]=="NFCE"

         cReport += CRLF 
         cReport += replicate("=",220) + CRLF
         cReport += "NFC-e - Vendas por dia" + CRLF
         cReport += replicate("=",220) + CRLF
         cReport += "Data              Qtde Cupom           Valor Prod.     Valor Desc.    Valor Outros     Valor Canc.        Valor NF      NF + Canc." + CRLF
         cReport += replicate("-",220) + CRLF

         for each hDia in aDias

            // Data
            cReport += left(dtoc(hDia["dtEmi"])+space(20),20) + cSep

            // COO
            cReport += str(hDia["COO"],6) + space(6) + cSep

            // Valor Produtos
            cReport += transform( hDia["vTot"], "@RE 999,999,999.99" ) + cSep

            // Valor Descontos
            cReport += transform( hDia["vDes"], "@RE 999,999,999.99" ) + cSep

            // Valor Outros
            cReport += transform( hDia["vOut"], "@RE 999,999,999.99" ) + cSep

            // Valor Cancelado
            cReport += transform( hDia["vLiqC"], "@RE 999,999,999.99" ) + cSep

            // Valor Liquido
            cReport += transform( hDia["vLiq"], "@RE 999,999,999.99" ) + cSep

            // Valor Liquido + Valor Cancelado
            cReport += transform( hDia["vLiq"] + hDia["vLiqC"], "@RE 999,999,999.99" ) + cSep

            cReport += CRLF

            nTotProd += hDia["vTot"]
            nTotDesc += hDia["vDes"]
            nTotOut  += hDia["vOut"]
            nTotCanc += hDia["vLiqC"]
            nTotLiq  += hDia["vLiq"]

            nTotCF   += hDia["COO"]

         next 

         cReport += replicate("-",220) + CRLF
         cReport += "TOTAL                 "+ str(nTotCF,6)+ "        "  +transform( nTotProd, "@RE 999,999,999.99" ) + "  " + transform( nTotDesc, "@RE 999,999,999.99" ) + "  " + transform( nTotOut, "@RE 999,999,999.99" ) + "  " + transform( nTotCanc, "@RE 999,999,999.99" ) + "  " + transform( nTotLiq, "@RE 999,999,999.99" ) + "  " + transform( nTotLiq+nTotCanc, "@RE 999,999,999.99" ) + cSep

         cReport += CRLF

      ///////////////////////////////////////////////////////////////////////////////////////////////////////
      case hOmiePdv["tipoCF"]=="SAT"

         cReport += CRLF 
         cReport += replicate("=",220) + CRLF
         cReport += "SAT - Vendas por dia" + CRLF
         cReport += replicate("=",220) + CRLF
         cReport += "Data              Qtde Cupom           Valor Prod.     Valor Desc.    Valor Outros     Valor Canc.        Valor NF      NF + Canc." + CRLF
         cReport += replicate("-",220) + CRLF

         for each hDia in aDias

            // Data
            cReport += left(dtoc(hDia["dtEmi"])+space(20),20) + cSep

            // COO
            cReport += str(hDia["COO"],6) + space(6) + cSep

            // Valor Produtos
            cReport += transform( hDia["vTot"], "@RE 999,999,999.99" ) + cSep

            // Valor Descontos
            cReport += transform( hDia["vDes"], "@RE 999,999,999.99" ) + cSep

            // Valor Outros
            cReport += transform( hDia["vOut"], "@RE 999,999,999.99" ) + cSep

            // Valor Cancelado
            cReport += transform( hDia["vLiqC"], "@RE 999,999,999.99" ) + cSep

            // Valor Liquido
            cReport += transform( hDia["vLiq"], "@RE 999,999,999.99" ) + cSep

            // Valor Liquido + Valor Cancelado
            cReport += transform( hDia["vLiq"] + hDia["vLiqC"], "@RE 999,999,999.99" ) + cSep

            cReport += CRLF

            nTotProd += hDia["vTot"]
            nTotDesc += hDia["vDes"]
            nTotOut  += hDia["vOut"]
            nTotCanc += hDia["vLiqC"]
            nTotLiq  += hDia["vLiq"]

            nTotCF   += hDia["COO"]

         next 

         cReport += replicate("-",220) + CRLF
         cReport += "TOTAL                 "+ str(nTotCF,6)+ "        "  +transform( nTotProd, "@RE 999,999,999.99" ) + "  " + transform( nTotDesc, "@RE 999,999,999.99" ) + "  " + transform( nTotOut, "@RE 999,999,999.99" ) + "  " + transform( nTotCanc, "@RE 999,999,999.99" ) + "  " + transform( nTotLiq, "@RE 999,999,999.99" ) + "  " + transform( nTotLiq+nTotCanc, "@RE 999,999,999.99" ) + cSep

         cReport += CRLF

      ///////////////////////////////////////////////////////////////////////////////////////////////////////
      case hOmiePdv["tipoCF"]=="ECF"

         cReport += CRLF 
         cReport += replicate("=",77) + CRLF
         cReport += "ECF - Vendas por dia" + CRLF
         cReport += replicate("=",77) + CRLF
         cReport += "Data                   Qtde Cupom         Valor Total       Valor Liquido" + CRLF
         cReport += replicate("-",77) + CRLF

         for each hDia in aDias

            // Data
            cReport += left(dtoc(hDia["dtEmi"])+space(25),25) + cSep

            // COO
            cReport += str(hDia["COO"],6) + cSep

            // Valor pago
            cReport += transform( hDia["vTot"], "@RE 999,999,999,999.99" ) + cSep

            // Valor liquido
            cReport += transform( hDia["vLiq"], "@RE 999,999,999,999.99" ) + cSep

            // estorno
            //cReport += hDia["estorno"] + cSep

            cReport += CRLF

            nTotLiq += hDia["vLiq"]

         next 

         cReport += replicate("-",77) + CRLF
         cReport += "TOTAL                                                  " + transform( nTotLiq, "@RE 999,999,999,999.99" ) + cSep
         cReport += CRLF

      endcase

   endif

   //////////////////////////////////////////////////////////////////////////////////////////////////////////
   // Imprime os totais por Dia / Produto.
   //////////////////////////////////////////////////////////////////////////////////////////////////////////

   if len(aProdDias) > 0 .and. hOmiePdv["ShowDetail"]

      aProdDias := ASort( aProdDias,,, {|x,y| dtos(x["dtEmi"])+x["descr"] < dtos(y["dtEmi"])+y["descr"] } )

      dDtAnt  := ctod("")

      nTotProd := 0
      nTotDesc := 0
      nTotOut  := 0
      nTotCanc := 0
      nTotLiq  := 0
      nTotCF   := 0
      nTotQtde := 0

      nTotProdDia := 0
      nTotDescDia := 0
      nTotOutDia  := 0
      nTotCancDia := 0               
      nTotLiqDia  := 0
      nTotCFDia   := 0
      nTotQtdDia  := 0

      do case
      ///////////////////////////////////////////////////////////////////////////////////////////////////////
      case hOmiePdv["tipoCF"]=="NFCE"

         cReport += CRLF 
         cReport += replicate("=",220) + CRLF
         cReport += "NFC-e - Produtos por dia" + CRLF
         cReport += replicate("=",220) + CRLF
         cReport += "Data         Codigo  Descricao                                                  Qtde     Valor Unit.     Valor Prod.     Valor Desc.    Valor Outros     Valor Canc.        Valor NF      NF + Canc." + CRLF
         cReport += replicate("-",220) + CRLF

         for each hProdDia in aProdDias

            if hProdDia["dtEmi"] <> dDtAnt 
               if !empty(dDtAnt) .and. cTpFile == "TXT" 
                  cReport += "Total Dia      "+str(nTotCFDia,4)+"                                                  " + transform( nTotQtdDia, "@RE 999,999,999.999" ) + "                  " + transform( nTotProdDia, "@RE 999,999,999.99" ) + "  " + transform( nTotDescDia, "@RE 999,999,999.99" ) + "  " + transform( nTotOutDia, "@RE 999,999,999.99" ) + "  " +  transform( nTotCancDia, "@RE 999,999,999.99" ) + "  " + transform( nTotLiqDia, "@RE 999,999,999.99" ) + "  " + transform( nTotLiqDia+nTotCancDia, "@RE 999,999,999.99" ) + cSep + CRLF
                  //cReport += CRLF
                  //cReport += "Data         Codigo  Descricao                                                  Qtde     Valor Unit.     Valor Prod.     Valor Desc.    Valor Outros     Valor Canc.        Valor NF      NF + Canc." + CRLF
                  cReport += replicate("-",220) + CRLF
               endif
               dDtAnt      := hProdDia["dtEmi"] 
               nTotProdDia := 0
               nTotDescDia := 0
               nTotOutDia  := 0
               nTotCancDia := 0               
               nTotLiqDia  := 0
               nTotCFDia   := 0
               nTotQtdDia  := 0
            endif

            // Data
            cReport += dtoc(hProdDia["dtEmi"]) + cSep

            // C digo
            cReport += hProdDia["codigo"] + cSep

            // Descrio o
            cReport += left(hProdDia["descr"]+space(50),50) + cSep

            // Qtde
            cReport += transform( hProdDia["qtde"], "@RE 999,999.999" ) + cSep

            // Valor Unit>rio
            cReport += transform( hProdDia["vTot"]/hProdDia["qtde"], "@RE 999,999,999.99" ) + cSep

            // Valor de Produtos
            cReport += transform( hProdDia["vTot"], "@RE 999,999,999.99" ) + cSep

            // Valor Desconto
            cReport += transform( hProdDia["vDes"], "@RE 999,999,999.99" ) + cSep

            // Valor Outros
            cReport += transform( hProdDia["vOut"], "@RE 999,999,999.99" ) + cSep

            // Valor Cancelados
            cReport += transform( hProdDia["vLiqC"], "@RE 999,999,999.99" ) + cSep

            // Valor Liquido
            cReport += transform( hProdDia["vLiq"], "@RE 999,999,999.99" ) + cSep

            // Valor Liquido + Valor Cancelados
            cReport += transform( hProdDia["vLiq"]+hProdDia["vLiqC"], "@RE 999,999,999.99" ) + cSep

            cReport += CRLF

            nTotProd += hProdDia["vTot"]
            nTotDesc += hProdDia["vDes"]
            nTotOut  += hProdDia["vOut"]
            nTotCanc += hProdDia["vLiqC"]
            nTotLiq  += hProdDia["vLiq"]
            nTotCF   += 1
            nTotQtde += hProdDia["qtde"]

            nTotProdDia += hProdDia["vTot"]
            nTotDescDia += hProdDia["vDes"]
            nTotOutDia  += hProdDia["vOut"]
            nTotCancDia += hProdDia["vLiqC"]   
            nTotLiqDia  += hProdDia["vLiq"]
            nTotCFDia   += 1
            nTotQtdDia  += hProdDia["qtde"]

         next 

         cReport += "Total Dia      "+str(nTotCFDia,4)+"                                                  " + transform( nTotQtdDia, "@RE 999,999,999.999" ) + "                  " + transform( nTotProdDia, "@RE 999,999,999.99" ) + "  " + transform( nTotDescDia, "@RE 999,999,999.99" ) + "  " + transform( nTotOutDia, "@RE 999,999,999.99" ) + "  " +  transform( nTotCancDia, "@RE 999,999,999.99" ) + "  " + transform( nTotLiqDia, "@RE 999,999,999.99" ) + "  " + transform( nTotLiqDia+nTotCancDia, "@RE 999,999,999.99" ) + cSep + CRLF
         cReport += replicate("-",220) + CRLF
         cReport += "TOTAL          "+str(nTotCF,4)   +"                                                  " + transform( nTotQtde, "@RE 999,999,999.999" )   + "                  " + transform( nTotProd, "@RE 999,999,999.99" )    + "  " + transform( nTotDesc, "@RE 999,999,999.99" )    + "  " + transform( nTotOut, "@RE 999,999,999.99" )    + "  " +  transform( nTotCanc, "@RE 999,999,999.99" )    + "  " + transform( nTotLiq, "@RE 999,999,999.99" )    + "  " + transform( nTotLiq+nTotCanc, "@RE 999,999,999.99" )       + cSep + CRLF

         cReport += CRLF

      ///////////////////////////////////////////////////////////////////////////////////////////////////////
      case hOmiePdv["tipoCF"]=="SAT"

         cReport += CRLF 
         cReport += replicate("=",220) + CRLF
         cReport += "SAT - Produtos por dia" + CRLF
         cReport += replicate("=",220) + CRLF
         cReport += "Data         Codigo  Descricao                                                  Qtde     Valor Unit.     Valor Prod.     Valor Desc.    Valor Outros     Valor Canc.        Valor NF      NF + Canc." + CRLF
         cReport += replicate("-",220) + CRLF

         for each hProdDia in aProdDias

            if hProdDia["dtEmi"] <> dDtAnt 
               if !empty(dDtAnt) .and. cTpFile == "TXT" 
                  cReport += "Total Dia      "+str(nTotCFDia,4)+"                                                  " + transform( nTotQtdDia, "@RE 999,999,999.999" ) + "                  " + transform( nTotProdDia, "@RE 999,999,999.99" ) + "  " + transform( nTotDescDia, "@RE 999,999,999.99" ) + "  " + transform( nTotOutDia, "@RE 999,999,999.99" ) + "  " +  transform( nTotCancDia, "@RE 999,999,999.99" ) + "  " + transform( nTotLiqDia, "@RE 999,999,999.99" ) + "  " + transform( nTotLiqDia+nTotCancDia, "@RE 999,999,999.99" ) + cSep + CRLF
                  //cReport += CRLF
                  //cReport += "Data         Codigo  Descricao                                                  Qtde     Valor Unit.     Valor Prod.     Valor Desc.    Valor Outros     Valor Canc.        Valor NF      NF + Canc." + CRLF
                  cReport += replicate("-",220) + CRLF
               endif
               dDtAnt      := hProdDia["dtEmi"] 
               nTotProdDia := 0
               nTotDescDia := 0
               nTotOutDia  := 0
               nTotCancDia := 0               
               nTotLiqDia  := 0
               nTotCFDia   := 0
               nTotQtdDia  := 0
            endif

            // Data
            cReport += dtoc(hProdDia["dtEmi"]) + cSep

            // C digo
            cReport += hProdDia["codigo"] + cSep

            // Descrio o
            cReport += left(hProdDia["descr"]+space(50),50) + cSep

            // Qtde
            cReport += transform( hProdDia["qtde"], "@RE 999,999.999" ) + cSep

            // Valor Unit>rio
            cReport += transform( hProdDia["vTot"]/hProdDia["qtde"], "@RE 999,999,999.99" ) + cSep

            // Valor de Produtos
            cReport += transform( hProdDia["vTot"], "@RE 999,999,999.99" ) + cSep

            // Valor Desconto
            cReport += transform( hProdDia["vDes"], "@RE 999,999,999.99" ) + cSep

            // Valor Outros
            cReport += transform( hProdDia["vOut"], "@RE 999,999,999.99" ) + cSep

            // Valor Cancelados
            cReport += transform( hProdDia["vLiqC"], "@RE 999,999,999.99" ) + cSep

            // Valor Liquido
            cReport += transform( hProdDia["vLiq"], "@RE 999,999,999.99" ) + cSep

            // Valor Liquido + Valor Cancelados
            cReport += transform( hProdDia["vLiq"]+hProdDia["vLiqC"], "@RE 999,999,999.99" ) + cSep

            cReport += CRLF

            nTotProd += hProdDia["vTot"]
            nTotDesc += hProdDia["vDes"]
            nTotOut  += hProdDia["vOut"]
            nTotCanc += hProdDia["vLiqC"]
            nTotLiq  += hProdDia["vLiq"]
            nTotCF   += 1
            nTotQtde += hProdDia["qtde"]

            nTotProdDia += hProdDia["vTot"]
            nTotDescDia += hProdDia["vDes"]
            nTotOutDia  += hProdDia["vOut"]
            nTotCancDia += hProdDia["vLiqC"]   
            nTotLiqDia  += hProdDia["vLiq"]
            nTotCFDia   += 1
            nTotQtdDia  += hProdDia["qtde"]

         next 

         cReport += "Total Dia      "+str(nTotCFDia,4)+"                                                  " + transform( nTotQtdDia, "@RE 999,999,999.999" ) + "                  " + transform( nTotProdDia, "@RE 999,999,999.99" ) + "  " + transform( nTotDescDia, "@RE 999,999,999.99" ) + "  " + transform( nTotOutDia, "@RE 999,999,999.99" ) + "  " +  transform( nTotCancDia, "@RE 999,999,999.99" ) + "  " + transform( nTotLiqDia, "@RE 999,999,999.99" ) + "  " + transform( nTotLiqDia+nTotCancDia, "@RE 999,999,999.99" ) + cSep + CRLF
         cReport += replicate("-",220) + CRLF
         cReport += "TOTAL          "+str(nTotCF,4)   +"                                                  " + transform( nTotQtde, "@RE 999,999,999.999" )   + "                  " + transform( nTotProd, "@RE 999,999,999.99" )    + "  " + transform( nTotDesc, "@RE 999,999,999.99" )    + "  " + transform( nTotOut, "@RE 999,999,999.99" )    + "  " +  transform( nTotCanc, "@RE 999,999,999.99" )    + "  " + transform( nTotLiq, "@RE 999,999,999.99" )    + "  " + transform( nTotLiq+nTotCanc, "@RE 999,999,999.99" )       + cSep + CRLF

         cReport += CRLF

      ///////////////////////////////////////////////////////////////////////////////////////////////////////
      case hOmiePdv["tipoCF"]=="ECF"

         cReport += CRLF 
         cReport += replicate("=",144) + CRLF
         cReport += "ECF - Produtos por dia" + CRLF
         cReport += replicate("=",144) + CRLF
         cReport += "Data        Codigo   Descricao                                                  Qtde      Valor Unitario       Valor Liquido         Valor Total" + CRLF
         cReport += replicate("-",144) + CRLF

         for each hProdDia in aProdDias

            if hProdDia["dtEmi"] <> dDtAnt 
               if !empty(dDtAnt) .and. cTpFile == "TXT" 
                  cReport += "Total Dia                                                        " + transform( nTotQtdDia, "@RE 999,999,999,999.999" ) + "                      " + transform( nTotLiqDia, "@RE 999,999,999,999.99" ) + CRLF
                  //cReport += CRLF
                  //cReport += "Data        Codigo   Descricao                                                  Qtde      Valor Unitario       Valor Liquido         Valor Total" + CRLF
                  cReport += replicate("-",144) + CRLF
               endif
               dDtAnt     := hProdDia["dtEmi"] 
               nTotLiqDia := 0
               nTotQtdDia := 0
            endif

            // Data
            cReport += dtoc(hProdDia["dtEmi"]) + cSep

            // C digo
            cReport += hProdDia["codigo"] + cSep

            // Descrio o
            cReport += left(hProdDia["descr"]+space(50),50) + cSep

            // Qtde
            cReport += transform( hProdDia["qtde"], "@RE 999,999.999" ) + cSep

            // Valor Unit>rio
            cReport += transform( hProdDia["vLiq"]/hProdDia["qtde"], "@RE 999,999,999,999.99" ) + cSep

            // Valor Liquido
            cReport += transform( hProdDia["vLiq"], "@RE 999,999,999,999.99" ) + cSep

            // Valor Total
            cReport += transform( hProdDia["vTot"], "@RE 999,999,999,999.99" ) + cSep

            // Valor Desconto
            //cReport += transform( hProdDia["vDes"], "@RE 999,999,999,999.99" ) + cSep

            // Valor Outros
            //cReport += transform( hProdDia["vOut"], "@RE 999,999,999,999.99" ) + cSep

            cReport += CRLF

            nTotLiq    += hProdDia["vLiq"]
            nTotLiqDia += hProdDia["vLiq"]
            nTotQtdDia += hProdDia["qtde"]

         next 
         cReport += "Total Dia                                                        " + transform( nTotQtdDia, "@RE 999,999,999,999.999" ) + "                      " + transform( nTotLiqDia, "@RE 999,999,999,999.99" ) + CRLF
         cReport += replicate("-",144) + CRLF
         cReport += "TOTAL                                                                                                     " + transform( nTotLiq, "@RE 999,999,999,999.99" ) + cSep
         cReport += CRLF
      
      endcase

   endif

   //////////////////////////////////////////////////////////////////////////////////////////////////////////
   // Imprime os totais por Produto.
   //////////////////////////////////////////////////////////////////////////////////////////////////////////

   if len(aProdutos) > 0

      aProdutos := ASort( aProdutos,,, {|x,y| x["descr"] < y["descr"] } )

      nTotLiq  := 0
      nTotProd := 0
      nTotDesc := 0
      nTotOut  := 0
      nTotCF   := 0
      nTotCanc := 0
      nTotCF   := 0
      nTotQtde := 0

      do case
      ///////////////////////////////////////////////////////////////////////////////////////////////////////
      case hOmiePdv["tipoCF"]=="NFCE"

         cReport += CRLF 
         cReport += replicate("=",220) + CRLF
         cReport += "NFC-e - Resumo de Produtos" + CRLF
         cReport += replicate("=",220) + CRLF
         cReport += "Codigo   Descricao                                                              Qtde     Valor Unit.     Valor Prod.     Valor Desc.    Valor Outros     Valor Canc.        Valor NF      NF + Canc." + CRLF
         cReport += replicate("-",220) + CRLF

         for each hProduto in aProdutos

            // C digo
            cReport += hProduto["codigo"] + cSep

            // Descrio o
            cReport += left(hProduto["descr"]+space(50),50) + space(12) + cSep

            // Qtde
            cReport += transform( hProduto["qtde"], "@RE 999,999.999" ) + cSep

            // Valor Unit>rio
            cReport += transform( hProduto["vLiq"]/hProduto["qtde"], "@RE 999,999,999.99" ) + cSep

            // Valor Produtos
            cReport += transform( hProduto["vTot"], "@RE 999,999,999.99" ) + cSep

            // Valor Descontos
            cReport += transform( hProduto["vDes"], "@RE 999,999,999.99" ) + cSep

            // Valor Outros
            cReport += transform( hProduto["vOut"], "@RE 999,999,999.99" ) + cSep

            // Valor Cancelado
            cReport += transform( hProduto["vLiqC"], "@RE 999,999,999.99" ) + cSep

            // Valor Liquido
            cReport += transform( hProduto["vLiq"], "@RE 999,999,999.99" ) + cSep

            // Valor Liquido + Valor Cancelado
            cReport += transform( hProduto["vLiq"] + hProduto["vLiqC"], "@RE 999,999,999.99" ) + cSep

            cReport += CRLF

            nTotQtde += hProduto["qtde"]
            nTotProd += hProduto["vTot"]
            nTotDesc += hProduto["vDes"]
            nTotOut  += hProduto["vOut"]
            nTotCanc += hProduto["vLiqC"]
            nTotLiq  += hProduto["vLiq"]
            nTotCF   += 1

         next 

         cReport += replicate("-",220) + CRLF
         cReport += "TOTAL    "+ str(nTotCF,6)+ "                                                      " + transform( nTotQtde, "@RE 999,999,999.999" ) + "                  "  +transform( nTotProd, "@RE 999,999,999.99" ) + "  " + transform( nTotDesc, "@RE 999,999,999.99" ) + "  " + transform( nTotOut, "@RE 999,999,999.99" ) + "  " + transform( nTotCanc, "@RE 999,999,999.99" ) + "  " + transform( nTotLiq, "@RE 999,999,999.99" ) + "  " + transform( nTotLiq+nTotCanc, "@RE 999,999,999.99" ) + cSep
         cReport += CRLF

      ///////////////////////////////////////////////////////////////////////////////////////////////////////
      case hOmiePdv["tipoCF"]=="SAT"

         cReport += CRLF 
         cReport += replicate("=",220) + CRLF
         cReport += "SAT - Resumo de Produtos" + CRLF
         cReport += replicate("=",220) + CRLF
         cReport += "Codigo   Descricao                                                              Qtde     Valor Unit.     Valor Prod.     Valor Desc.    Valor Outros     Valor Canc.        Valor NF      NF + Canc." + CRLF
         cReport += replicate("-",220) + CRLF

         for each hProduto in aProdutos

            // C digo
            cReport += hProduto["codigo"] + cSep

            // Descrio o
            cReport += left(hProduto["descr"]+space(50),50) + space(12) + cSep

            // Qtde
            cReport += transform( hProduto["qtde"], "@RE 999,999.999" ) + cSep

            // Valor Unit>rio
            cReport += transform( hProduto["vLiq"]/hProduto["qtde"], "@RE 999,999,999.99" ) + cSep

            // Valor Produtos
            cReport += transform( hProduto["vTot"], "@RE 999,999,999.99" ) + cSep

            // Valor Descontos
            cReport += transform( hProduto["vDes"], "@RE 999,999,999.99" ) + cSep

            // Valor Outros
            cReport += transform( hProduto["vOut"], "@RE 999,999,999.99" ) + cSep

            // Valor Cancelado
            cReport += transform( hProduto["vLiqC"], "@RE 999,999,999.99" ) + cSep

            // Valor Liquido
            cReport += transform( hProduto["vLiq"], "@RE 999,999,999.99" ) + cSep

            // Valor Liquido + Valor Cancelado
            cReport += transform( hProduto["vLiq"] + hProduto["vLiqC"], "@RE 999,999,999.99" ) + cSep

            cReport += CRLF

            nTotQtde += hProduto["qtde"]
            nTotProd += hProduto["vTot"]
            nTotDesc += hProduto["vDes"]
            nTotOut  += hProduto["vOut"]
            nTotCanc += hProduto["vLiqC"]
            nTotLiq  += hProduto["vLiq"]
            nTotCF   += 1

         next 

         cReport += replicate("-",220) + CRLF
         cReport += "TOTAL    "+ str(nTotCF,6)+ "                                                      " + transform( nTotQtde, "@RE 999,999,999.999" ) + "                  "  +transform( nTotProd, "@RE 999,999,999.99" ) + "  " + transform( nTotDesc, "@RE 999,999,999.99" ) + "  " + transform( nTotOut, "@RE 999,999,999.99" ) + "  " + transform( nTotCanc, "@RE 999,999,999.99" ) + "  " + transform( nTotLiq, "@RE 999,999,999.99" ) + "  " + transform( nTotLiq+nTotCanc, "@RE 999,999,999.99" ) + cSep
         cReport += CRLF


      ///////////////////////////////////////////////////////////////////////////////////////////////////////
      case hOmiePdv["tipoCF"]=="ECF"

         cReport += CRLF 
         cReport += replicate("=",112) + CRLF
         cReport += "ECF - Resumo de Produtos" + CRLF
         cReport += replicate("=",112) + CRLF
         cReport += "Codigo   Descricao                                                  Qtde         Valor Total       Valor Liquido" + CRLF
         cReport += replicate("-",112) + CRLF

         for each hProduto in aProdutos

            // C digo
            cReport += hProduto["codigo"] + cSep

            // Descrio o
            cReport += left(hProduto["descr"]+space(50),50) + cSep

            // Qtde
            cReport += transform( hProduto["qtde"], "@RE 999,999.999" ) + cSep

            // Valor Total
            cReport += transform( hProduto["vTot"], "@RE 999,999,999,999.99" ) + cSep

            // Valor Liquido
            cReport += transform( hProduto["vLiq"], "@RE 999,999,999,999.99" ) + cSep

            cReport += CRLF

            nTotLiq += hProduto["vLiq"]

         next 

         cReport += replicate("-",112) + CRLF
         cReport += "TOTAL                                                                                         " + transform( nTotLiq, "@RE 999,999,999,999.99" ) + cSep
         cReport += CRLF

      endcase

   endif

   //////////////////////////////////////////////////////////////////////////////////////////////////////////
   // Imprime os totais por Data / Meio de Pagamento.
   //////////////////////////////////////////////////////////////////////////////////////////////////////////

   if len(aMeioDias) > 0 .and. hOmiePdv["ShowDetail"]

      aMeioDias := ASort( aMeioDias,,, {|x,y| dtos(x["dtEmi"])+x["descr"] < dtos(y["dtEmi"])+y["descr"] } )

      nTotLiq  := 0
      nTotProd := 0
      nTotCF   := 0

      dDtAnt  := ctod("")

      do case
      ///////////////////////////////////////////////////////////////////////////////////////////////////////
      case hOmiePdv["tipoCF"]=="NFCE"

         cReport += CRLF 
         cReport += replicate("=",77) + CRLF
         cReport += "NFC-e - Formas de Pagamento por dia" + CRLF
         cReport += replicate("=",77) + CRLF
         cReport += "Data        Meio de Pagamento      Qtde Cupom     Valor Prod.        Valor NF" + CRLF
         cReport += replicate("-",77) + CRLF

         for each hMeioDia in aMeioDias

            if hMeioDia["dtEmi"] <> dDtAnt 
               if !empty(dDtAnt) .and. cTpFile == "TXT" 
                  cReport += replicate("-",77) + CRLF
               endif
               dDtAnt := hMeioDia["dtEmi"] 
            endif

            // Data
            cReport += dtoc(hMeioDia["dtEmi"]) + cSep

            // Meio
            // cReport += left(hMeioDia["MeioPag"]+str(hMeioDia["cartao"],5)+space(25),25) + cSep
            cReport += left(hMeioDia["descr"]+space(25),25) + cSep

            // COO
            cReport += str(hMeioDia["COO"],6) + cSep

            // Valor pago
            cReport += transform( hMeioDia["vTot"], "@RE 999,999,999.99" ) + cSep

            // Valor estornado
            cReport += transform( hMeioDia["vLiq"], "@RE 999,999,999.99" ) + cSep

            // estorno
            //cReport += hMeioDia["estorno"] + cSep

            cReport += CRLF

            nTotLiq  += hMeioDia["vLiq"]
            nTotProd += hMeioDia["vTot"]
            nTotCF   += hMeioDia["COO"]

         next 

         cReport += replicate("-",77) + CRLF
         cReport += "TOTAL                                  " + str(nTotCF,6) + "  " +  transform( nTotProd, "@RE 999,999,999.99" ) + "  " +  transform( nTotLiq, "@RE 999,999,999.99" ) + cSep
         cReport += CRLF

      ///////////////////////////////////////////////////////////////////////////////////////////////////////
      case hOmiePdv["tipoCF"]=="SAT"

         cReport += CRLF 
         cReport += replicate("=",77) + CRLF
         cReport += "SAT - Formas de Pagamento por dia" + CRLF
         cReport += replicate("=",77) + CRLF
         cReport += "Data        Meio de Pagamento      Qtde Cupom     Valor Prod.        Valor NF" + CRLF
         cReport += replicate("-",77) + CRLF

         for each hMeioDia in aMeioDias

            if hMeioDia["dtEmi"] <> dDtAnt 
               if !empty(dDtAnt) .and. cTpFile == "TXT" 
                  cReport += replicate("-",77) + CRLF
               endif
               dDtAnt := hMeioDia["dtEmi"] 
            endif

            // Data
            cReport += dtoc(hMeioDia["dtEmi"]) + cSep

            // Meio
            // cReport += left(hMeioDia["MeioPag"]+str(hMeioDia["cartao"],5)+space(25),25) + cSep
            cReport += left(hMeioDia["descr"]+space(25),25) + cSep

            // COO
            cReport += str(hMeioDia["COO"],6) + cSep

            // Valor pago
            cReport += transform( hMeioDia["vTot"], "@RE 999,999,999.99" ) + cSep

            // Valor estornado
            cReport += transform( hMeioDia["vLiq"], "@RE 999,999,999.99" ) + cSep

            // estorno
            //cReport += hMeioDia["estorno"] + cSep

            cReport += CRLF

            nTotLiq  += hMeioDia["vLiq"]
            nTotProd += hMeioDia["vTot"]
            nTotCF   += hMeioDia["COO"]

         next 

         cReport += replicate("-",77) + CRLF
         cReport += "TOTAL                                  " + str(nTotCF,6) + "  " +  transform( nTotProd, "@RE 999,999,999.99" ) + "  " +  transform( nTotLiq, "@RE 999,999,999.99" ) + cSep
         cReport += CRLF

      ///////////////////////////////////////////////////////////////////////////////////////////////////////
      case hOmiePdv["tipoCF"]=="ECF"

         cReport += CRLF 
         cReport += replicate("=",85) + CRLF
         cReport += "ECF - Formas de Pagamento por dia" + CRLF
         cReport += replicate("=",85) + CRLF
         cReport += "Data        Meio de Pagamento      Qtde Cupom         Valor Total       Valor Liquido" + CRLF
         cReport += replicate("-",85) + CRLF

         for each hMeioDia in aMeioDias

            if hMeioDia["dtEmi"] <> dDtAnt 
               if !empty(dDtAnt) .and. cTpFile == "TXT" 
                  cReport += replicate("-",85) + CRLF
               endif
               dDtAnt := hMeioDia["dtEmi"] 
            endif

            // Data
            cReport += dtoc(hMeioDia["dtEmi"]) + cSep

            // Meio
            // cReport += left(hMeioDia["MeioPag"]+str(hMeioDia["cartao"],5)+space(25),25) + cSep
            cReport += left(hMeioDia["descr"]+space(25),25) + cSep

            // COO
            cReport += str(hMeioDia["COO"],6) + cSep

            // Valor pago
            cReport += transform( hMeioDia["vTot"], "@RE 999,999,999,999.99" ) + cSep

            // Valor estornado
            cReport += transform( hMeioDia["vLiq"], "@RE 999,999,999,999.99" ) + cSep

            // estorno
            //cReport += hMeioDia["estorno"] + cSep

            cReport += CRLF

            nTotLiq  += hMeioDia["vLiq"]

         next 

         cReport += replicate("-",85) + CRLF
         cReport += "TOTAL                                                              " + transform( nTotLiq, "@RE 999,999,999,999.99" ) + cSep
         cReport += CRLF

      endcase
   
   endif

   //////////////////////////////////////////////////////////////////////////////////////////////////////////
   // Imprime os totais por Meio de Pagamento.
   //////////////////////////////////////////////////////////////////////////////////////////////////////////

   if len(aMeios) > 0

      aMeios := ASort( aMeios,,, {|x,y| x["descr"] < y["descr"] } )

      nTotLiq  := 0
      nTotProd := 0
      nTotCF   := 0

      do case
      ///////////////////////////////////////////////////////////////////////////////////////////////////////
      case hOmiePdv["tipoCF"]=="NFCE"

         cReport += CRLF 
         cReport += replicate("=",77) + CRLF
         cReport += "NFC-e - Resumo de Formas de Pagamento" + CRLF
         cReport += replicate("=",77) + CRLF
         cReport += "Meio de Pagamento                  Qtde Cupom     Valor Prod.        Valor NF" + CRLF
         cReport += replicate("-",77) + CRLF

         for each hMeio in aMeios 

            // Meio
            // cReport += left(hMeio["MeioPag"]+str(hMeio["cartao"],5)+space(25),25) + cSep
            cReport += left(hMeio["descr"]+space(25),25) + space(12) + cSep

            // COO
            cReport += str(hMeio["COO"],6) + cSep

            // Valor Produtos
            cReport += transform( hMeio["vTot"], "@RE 999,999,999.99" ) + cSep

            // Valor NF
            cReport += transform( hMeio["vLiq"], "@RE 999,999,999.99" ) + cSep

            // estorno
            //cReport += hMeio["estorno"] + cSep

            cReport += CRLF

            nTotLiq  += hMeio["vLiq"]
            nTotProd += hMeio["vTot"]
            nTotCF   += hMeio["COO"]

         next 

         cReport += replicate("-",77) + CRLF
         cReport += "TOTAL                                  " + str(nTotCF,6) + "  " +  transform( nTotProd, "@RE 999,999,999.99" ) + "  " +  transform( nTotLiq, "@RE 999,999,999.99" ) + cSep
         cReport += CRLF

      ///////////////////////////////////////////////////////////////////////////////////////////////////////
      case hOmiePdv["tipoCF"]=="SAT"

         cReport += CRLF 
         cReport += replicate("=",77) + CRLF
         cReport += "SAT - Resumo de Formas de Pagamento" + CRLF
         cReport += replicate("=",77) + CRLF
         cReport += "Meio de Pagamento                  Qtde Cupom     Valor Prod.        Valor NF" + CRLF
         cReport += replicate("-",77) + CRLF

         for each hMeio in aMeios 

            // Meio
            // cReport += left(hMeio["MeioPag"]+str(hMeio["cartao"],5)+space(25),25) + cSep
            cReport += left(hMeio["descr"]+space(25),25) + space(12) + cSep

            // COO
            cReport += str(hMeio["COO"],6) + cSep

            // Valor Produtos
            cReport += transform( hMeio["vTot"], "@RE 999,999,999.99" ) + cSep

            // Valor NF
            cReport += transform( hMeio["vLiq"], "@RE 999,999,999.99" ) + cSep

            // estorno
            //cReport += hMeio["estorno"] + cSep

            cReport += CRLF

            nTotLiq  += hMeio["vLiq"]
            nTotProd += hMeio["vTot"]
            nTotCF   += hMeio["COO"]

         next 

         cReport += replicate("-",77) + CRLF
         cReport += "TOTAL                                  " + str(nTotCF,6) + "  " +  transform( nTotProd, "@RE 999,999,999.99" ) + "  " +  transform( nTotLiq, "@RE 999,999,999.99" ) + cSep
         cReport += CRLF

      ///////////////////////////////////////////////////////////////////////////////////////////////////////
      case hOmiePdv["tipoCF"]=="ECF"

         cReport += CRLF 
         cReport += replicate("=",77) + CRLF
         cReport += "ECF - Resumo de Formas de Pagamento" + CRLF
         cReport += replicate("=",77) + CRLF
         cReport += "Meio de Pagamento      Qtde Cupom         Valor Total       Valor Liquido" + CRLF
         cReport += replicate("-",77) + CRLF

         for each hMeio in aMeios

            // Meio
            // cReport += left(hMeio["MeioPag"]+str(hMeio["cartao"],5)+space(25),25) + cSep
            cReport += left(hMeio["descr"]+space(25),25) + cSep

            // COO
            cReport += str(hMeio["COO"],6) + cSep

            // Valor pago
            cReport += transform( hMeio["vTot"], "@RE 999,999,999,999.99" ) + cSep

            // Valor estornado
            cReport += transform( hMeio["vLiq"], "@RE 999,999,999,999.99" ) + cSep

            // estorno
            //cReport += hMeio["estorno"] + cSep

            cReport += CRLF

            nTotLiq += hMeio["vLiq"]

         next 

         cReport += replicate("-",77) + CRLF
         cReport += "TOTAL                                                  " + transform( nTotLiq, "@RE 999,999,999,999.99" ) + cSep
         cReport += CRLF

      endcase

   endif
 
   //////////////////////////////////////////////////////////////////////////////////////////////////////////
   // Imprime o Movimento de Caixa
   //////////////////////////////////////////////////////////////////////////////////////////////////////////

   if len(aCaixas) > 0 .and. hOmiePdv["ShowDetail"]

      nSaldo  := 0
      nTotLiq := 0
      dDtAnt  := ctod("")

      do case
      ///////////////////////////////////////////////////////////////////////////////////////////////////////
      case hOmiePdv["tipoCF"]=="NFCE"

         cReport += CRLF 
         cReport += replicate("=",77) + CRLF
         cReport += "NFC-e - Caixa por dia" + CRLF
         cReport += replicate("=",77) + CRLF
         cReport += "Data        Hora   Codigo  Descricao                                    Valor" + CRLF
         cReport += replicate("-",77) + CRLF

         for each hCaixa in aCaixas

            if hCaixa["dtEmi"] <> dDtAnt 
               if !empty(dDtAnt) .and. cTpFile == "TXT" 
                  cReport += replicate("-",77) + CRLF
               endif
               dDtAnt := hCaixa["dtEmi"] 
               nSaldo := 0
            endif

            if hCaixa["order"]="90"
               hCaixa["valor"] := nSaldo
            endif

            // Data
            cReport += dtoc(hCaixa["dtEmi"]) + cSep

            // Hora
            cReport += hCaixa["hrEmi"] + cSep

            // Order
            cReport += "    " + hCaixa["order"] + cSep

            // Descrio o
            cReport += left(hCaixa["obs"]+space(30),30) + cSep

            // Valor 
            cReport += transform( hCaixa["valor"], "@RE 999,999,999,999.99" ) + cSep

            // // Numero
            // cReport += str(hCaixa["numero"]) + cSep

            // // Codigo
            // cReport += str(hCaixa["codigo"]) + cSep

            cReport += CRLF

            nTotLiq += hCaixa["valor"]
            nSaldo  += hCaixa["valor"]

         next 

         cReport += replicate("-",77) + CRLF
         cReport += "TOTAL                                                      " + transform( nTotLiq, "@RE 999,999,999,999.99" ) + cSep
         cReport += CRLF

      ///////////////////////////////////////////////////////////////////////////////////////////////////////
      case hOmiePdv["tipoCF"]=="SAT"

         cReport += CRLF 
         cReport += replicate("=",77) + CRLF
         cReport += "SAT - Caixa por dia" + CRLF
         cReport += replicate("=",77) + CRLF
         cReport += "Data        Hora   Codigo  Descricao                                    Valor" + CRLF
         cReport += replicate("-",77) + CRLF

         for each hCaixa in aCaixas

            if hCaixa["dtEmi"] <> dDtAnt 
               if !empty(dDtAnt) .and. cTpFile == "TXT" 
                  cReport += replicate("-",77) + CRLF
               endif
               dDtAnt := hCaixa["dtEmi"] 
               nSaldo := 0
            endif

            if hCaixa["order"]="90"
               hCaixa["valor"] := nSaldo
            endif

            // Data
            cReport += dtoc(hCaixa["dtEmi"]) + cSep

            // Hora
            cReport += hCaixa["hrEmi"] + cSep

            // Order
            cReport += "    " + hCaixa["order"] + cSep

            // Descrio o
            cReport += left(hCaixa["obs"]+space(30),30) + cSep

            // Valor 
            cReport += transform( hCaixa["valor"], "@RE 999,999,999,999.99" ) + cSep

            // // Numero
            // cReport += str(hCaixa["numero"]) + cSep

            // // Codigo
            // cReport += str(hCaixa["codigo"]) + cSep

            cReport += CRLF

            nTotLiq += hCaixa["valor"]
            nSaldo  += hCaixa["valor"]

         next 

         cReport += replicate("-",77) + CRLF
         cReport += "TOTAL                                                      " + transform( nTotLiq, "@RE 999,999,999,999.99" ) + cSep
         cReport += CRLF

      ///////////////////////////////////////////////////////////////////////////////////////////////////////
      case hOmiePdv["tipoCF"]=="ECF"

         cReport += CRLF 
         cReport += replicate("=",77) + CRLF
         cReport += "ECF - Caixas por dia" + CRLF
         cReport += replicate("=",77) + CRLF
         cReport += "Data        Hora   Codigo  Descricao                                    Valor" + CRLF
         cReport += replicate("-",77) + CRLF

         for each hCaixa in aCaixas

            if hCaixa["dtEmi"] <> dDtAnt 
               if !empty(dDtAnt) .and. cTpFile == "TXT" 
                  cReport += replicate("-",77) + CRLF
               endif
               dDtAnt := hCaixa["dtEmi"] 
               nSaldo := 0
            endif

            if hCaixa["order"]="90"
               hCaixa["valor"] := nSaldo
            endif

            // Data
            cReport += dtoc(hCaixa["dtEmi"]) + cSep

            // Hora
            cReport += hCaixa["hrEmi"] + cSep

            // Order
            cReport += "    " + hCaixa["order"] + cSep

            // Descrio o
            cReport += left(hCaixa["obs"]+space(30),30) + cSep

            // Valor 
            cReport += transform( hCaixa["valor"], "@RE 999,999,999,999.99" ) + cSep

            // // Numero
            // cReport += str(hCaixa["numero"]) + cSep

            // // Codigo
            // cReport += str(hCaixa["codigo"]) + cSep

            cReport += CRLF

            nTotLiq += hCaixa["valor"]
            nSaldo  += hCaixa["valor"]

         next 

         cReport += replicate("-",77) + CRLF
         cReport += "TOTAL                                                      " + transform( nTotLiq, "@RE 999,999,999,999.99" ) + cSep
         cReport += CRLF
   
      endcase
   
   endif

   ///////////////////////////////////////////////////////////////////////////////////////////////////////////

   cReport += CRLF 
   cReport += replicate("=",220) + CRLF

   lRet    := .T.

END SEQUENCE

return { lRet, cReport }

********************************************************************************
static function pu_TotDia( dDtAnt, aDias, cSep )
********************************************************************************

local nPos    := 0
local cReport := ""

if len(aDias) > 0
   nPos := ascan( aDias, {|hItDia| hItDia["dtEmi"] == dDtAnt } )
endif

if nPos > 0

   cReport += dtoc(dDtAnt) + cSep
   
   cReport += "------->" + cSep

   // COO
   cReport += str(aDias[nPos]["COO"],6) + cSep

   cReport += "    " + cSep

   // Valor Pago
   cReport += transform( aDias[nPos]["vTot"], "@RE 999,999,999.99" ) + cSep

   // Valor Descontos
   cReport += transform( aDias[nPos]["vDes"], "@RE 999,999,999.99" ) + cSep

   // Valor Outros
   cReport += transform( aDias[nPos]["vOut"], "@RE 999,999,999.99" ) + cSep

   // Valor Cancelados
   cReport += transform( aDias[nPos]["vLiqC"], "@RE 999,999,999.99" ) + cSep

   // Valor Liquido
   cReport += transform( aDias[nPos]["vLiq"], "@RE 999,999,999.99" ) + cSep

   // Valor Liquido + Valor Cancelados
   //cReport += transform( aDias[nPos]["vLiq"]+aDias[nPos]["vLiqC"], "@RE 999,999,999.99" ) + cSep

   cReport += CRLF

endif

cReport += replicate("-",220) + CRLF

return cReport

********************************************************************************
static function pu_Tdm2Hash( cData )
********************************************************************************

local lRet      := .F.
local hTdmFile  := {=>}

local hEcf      := {=>} 
local hContr    := {=>}

local aCupons   := {}
local hCupom    := {=>}

local aDias     := {}
local hDia      := {=>}

local hTotal    := {=>}

local aMeios    := {}
local hMeio     := {=>}

local aMeioMes  := {}
local hMeioMes  := {=>}

local aCupomDet := {}
local hCupomDet := {=>} 

local aProdutos := {}
local hProdutos := {=>}

local aProdDia  := {}
local hProdDia  := {=>}

local aDetRZTNF := {}
local hDetRZTNF := {=>}

local aDetRZMP  := {}
local hDetRZMP  := {=>}

local aRZ       := {}
local hRZ       := {=>}

local aLines    := {}
local cLine     := ""
local cId       := ""
local cIdAnt    := ""
local dDtAnt    := ctod("")
local dDtProd   := ctod("")
local cCanc     := ""
local nCupom    := 0
local nPos      := 0
local nTroco    := 0

BEGIN SEQUENCE

   aLines := HB_ATokens( cData, chr(10), .F., .F. )

   if len(aLines) > 0

      // Se a primeira linha do arquivo n o for um registro "E01" indicando que + um arquivo TDM, n o lo o arquivo.

      if left(aLines[1],3) != "E01"
         BREAK 
      endif

      // Lo os dados do arquivo TDM.
      
      for each cLine in aLines
         
         // Guarda o Id da linha.

         cId := left(cLine,3)
   
         if cIdAnt <> cId

            // Se estava no registro E14, adiciona a ultima linha do dia.

            if cIdAnt = "E14"    
               if !empty(dDtAnt) .and. len(hdia) > 0
                  aadd( aDias, hDia )
               endif            
            endif

            cIdAnt := cId

         endif

         do case

         //////////////////////////////////////////////////////////////////////////////////////////////////////
         case cId = 'E01' // E01 - IDENTIFICA++O DO ECF

            hEcf := {=>} 
            hEcf["numFabr"]  := substr(cLine,   4,  20 )
            hEcf["MFAdic"]   := substr(cLine,  24,   1 )
            hEcf["tipo"]     := substr(cLine,  25,   7 )
            hEcf["marca"]    := substr(cLine,  32,  20 )
            hEcf["modelo"]   := substr(cLine,  52,  20 )
            hEcf["versaoSB"] := substr(cLine,  72,  10 )
            hEcf["dataSB"]   := substr(cLine,  82,   8 )
            hEcf["horaSB"]   := substr(cLine,  90,   6 )
            hEcf["numECF"]   := substr(cLine,  96,   3 )
            hEcf["CNPJ"]     := substr(cLine,  99,  14 )
            hEcf["comando"]  := substr(cLine, 113,   3 )
            hEcf["CRZini"]   := substr(cLine, 116,   6 )
            hEcf["CRZfim"]   := substr(cLine, 122,   6 )
            hEcf["dtIni"]    := substr(cLine, 128,   8 )
            hEcf["dtFim"]    := substr(cLine, 136,   8 )
            hEcf["verLib"]   := substr(cLine, 144,   8 )
            hEcf["VerAto"]   := substr(cLine, 152,  15 )

         //////////////////////////////////////////////////////////////////////////////////////////////////////
         case cId = 'E02' // E02 - IDENTIFICA++O DO ATUAL CONTRIBUINTE USU-RIO DO ECF

            // 01 Tipo "E02" 03 1 3 X 
            // 02 N mero de fabricao o N  de fabricao o do ECF 20 4 23 X 
            // 03 MF adicional Letra indicativa de MF adicional 01 24 24 X 
            // 04 Modelo Modelo do ECF 20 25 44 X
            // 05 CNPJ CNPJ do estabelecimento usu>rio do ECF 14 45 58 N
            // 06 Inscrio o Estadual Inscrio o Estadual do estabelecimento usu>rio 14 59 72 X
            // 07 Nome do contribuinte Nome comercial (raz o social / denominao o) do contribuinte usu>rio do ECF 40 73 112 X
            // 08 Endereoo Endereoo do estabelecimento usu>rio do ECF 120 113 232 X
            // 09 Data do cadastro Data do cadastro do usu>rio no ECF 08 233 240 D
            // 10 Hora do cadastro Hora do cadastro do usu>rio no ECF 06 241 246 H
            // 11 CRO (Contador de Reinocio de Operao o) Valor do CRO relativo ao cadastro do usu>rio no ECF 06 247 252 N
            // 12 GT (Totalizador Geral) Valor acumulado no GT, com duas casas decimais. 18 253 270 N
            // 13 N mero do usu>rio N  de ordem do usu>rio do ECF 02 271 272 N

            hContr := {=>} 
            hContr["CNPJ"]     := substr(cLine,  45,  14 )
            hContr["IE"]       := substr(cLine,  59,  14 )
            hContr["nome"]     := substr(cLine,  73,  40 )
            hContr["endereco"] := substr(cLine, 113, 120 )
            hContr["dtCad"]    := substr(cLine, 233,   8 )
            hContr["hrCad"]    := substr(cLine, 241,   6 )
            hContr["CRO"]      := substr(cLine, 247,   6 )
            hContr["GT"]       := substr(cLine, 253,  18 )
            hContr["numUser"]  := substr(cLine, 271,   2 )

         //////////////////////////////////////////////////////////////////////////////////////////////////////
         case cId = 'E12' // E12 - RELA++O DE REDU+iES Z

            hRZ := {=>}
            hRZ["numUser"]  := substr(cLine,  45,  2 )
            hRZ["CRZ"]      := substr(cLine,  47,  6 )
            hRZ["COO"]      := substr(cLine,  53,  6 )
            hRZ["CRO"]      := substr(cLine,  59,  6 )
            hRZ["dtMov"]    := stod(substr(cLine,  65,  8 ))
            hRZ["dtEmi"]    := stod(substr(cLine,  73,  8 ))
            hRZ["hrEmi"]    := substr(cLine,  81,  6 )
            hRZ["vbd"]      := val(substr(cLine,  87, 14 )) / 100
            hRZ["incISSQN"] := substr(cLine, 101,  1 )

            aadd( aRZ, hRZ )

         //////////////////////////////////////////////////////////////////////////////////////////////////////
         case cId = 'E14' // E14 - CUPOM FISCAL, NOTA FISCAL DE VENDA A CONSUMIDOR E BILHETE DE PASSAGEM

            // E14DR0914BR000000410123 MACH 2              0100015700028920141029000000000200000000000000000V0000000000000V00000000020000N0000000000000D                                        00000000000000
            // E14DR0914BR000000410123 MACH 2              0100015800029020141029000000000002500000000000000V0000000000000V00000000000250N0000000000000D                                        00000000000000
            // E14DR0914BR000000410123 MACH 2              0100015900029120141029000000000125000000000000000V0000000000000V00000000012500N0000000000000D                                        00000000000000
            
            // Lo o cupom.

            hCupom := {=>}
            hCupom["CCF"]     := val(substr(cLine, 47, 6 ))
            hCupom["COO"]     := val(substr(cLine, 53, 6 ))
            hCupom["dtstr"]   := substr(cLine, 59, 8 )
            hCupom["dtEmi"]   := stod(hCupom["dtstr"])
            hCupom["vTot"]    := val(substr(cLine, 67, 14)) / 100
            hCupom["vDesc"]   := val(substr(cLine, 81, 13)) / 100
            hCupom["tDesc"]   := substr(cLine, 94, 1 )
            hCupom["vAcre"]   := val(substr(cLine, 95, 13)) / 100
            hCupom["tAcre"]   := substr(cLine, 108, 1 )
            hCupom["vLiq"]    := val(substr(cLine, 109, 14)) / 100
            hCupom["canc"]    := substr(cLine, 123, 1 )
            hCupom["vCanc"]   := val(substr(cLine, 124, 13)) / 100
            hCupom["ordem"]   := substr(cLine, 137, 1 )
            hCupom["GNF"]     := 0
            hCupom["MeioPag"] := space(15)
            hCupom["vPago"]   := 0
            hCupom["estorno"] := ""
            hCupom["vEst"]    := 0
            hCupom["itens"]   := {}
            hCupom["read"]    := .f.

            if hCupom["canc"] = "S"
               if hCupom["vCanc"] = 0
                  hCupom["vCanc"] := hCupom["vLiq"]
               endif
               hCupom["vLiq"]  := 0
            endif

            aadd( aCupons, hCupom )

            // Se trocou o dia.

            if dDtAnt <> hCupom["dtEmi"] .or. empty(dDtAnt)

               if !empty(dDtAnt) .and. len(hdia) > 0
                  aadd( aDias, hDia )
               endif

               dDtAnt := hCupom["dtEmi"]

               hDia := {=>}
               hDia["dtEmi"] := hCupom["dtEmi"]
               hDia["COO"]   := 0
               hDia["vTot"]  := 0
               hDia["vDesc"] := 0
               hDia["vAcre"] := 0
               hDia["vLiq"]  := 0
               hDia["vCanc"] := 0

            endif

            // Totaliza o dia.

            hDia["COO"]   += 1
            hDia["vTot"]  += hCupom["vTot"]
            hDia["vDesc"] += hCupom["vDesc"]
            hDia["vAcre"] += hCupom["vAcre"]
            
            if hCupom["canc"] != "S"
               hDia["vLiq"]  += hCupom["vLiq"]
            endif

            hDia["vCanc"] += hCupom["vCanc"]

         //////////////////////////////////////////////////////////////////////////////////////////////////////
         case cId = 'E15' // E15 - DETALHE DO CUPOM FISCAL, DA NOTA FISCAL DE VENDA A CONSUMIDOR OU DO BILHETE DE PASSAGEM
            
            dDtProd   := ctod("")

            hCupomDet := {=>}

            // 01 - Tipo "E15"
            // 02 - N mero de fabricao o
            // 03 - MF adicional - Letra indicativa de MF adicional
            // 04 - Modelo do ECF
            // 05 - N mero de ordem do usu>rio do ECF

            hCupomDet["COO"]     := val(substr(cLine, 47, 6 ))        // 06 - COO (Contador de Ordem de Operao o)
            hCupomDet["CCF"]     := val(substr(cLine, 53, 6 ))        // 07 - CCF, CVC ou CBP, conforme o documento emitido
            hCupomDet["item"]    := val(substr(cLine, 59, 3 ))        // 08 - N mero do item registrado no documento
            hCupomDet["codProd"] := substr(cLine, 62, 14 )            // 09 - C digo do Produto ou Servioo
            hCupomDet["desProd"] := substr(cLine, 76, 100 )           // 10 - Descrio o do produto ou servioo constante no Cupom Fiscal
            hCupomDet["qtde"]    := val(substr(cLine, 176, 7 ))       // 11 - Quantidade comercializada, sem a separao o das casas decimais.
            hCupomDet["unid"]    := substr(cLine, 183, 3 )            // 12 - Unidade de medida
            hCupomDet["vUnit"]   := val(substr(cLine, 186, 8 ))       // 13 - Valor unit>rio do produto ou servioo, sem a separao o das casas decimais.
            hCupomDet["vDesc"]   := val(substr(cLine, 194, 8 )) / 100 // 14 - Valor do desconto incidente sobre o valor do item, com duas casas decimais.
            hCupomDet["vAcre"]   := val(substr(cLine, 202, 8 )) / 100 // 15 - Valor do acr+scimo incidente sobre o valor do item, com duas casas decimais.
            hCupomDet["vLiq"]    := val(substr(cLine, 210, 14 ))/ 100 // 16 - Valor total loquido
            hCupomDet["tParc"]   := substr(cLine, 224, 7 )            // 17 - Totalizador parcial
            hCupomDet["canc"]    := substr(cLine, 231, 1 )            // 18 - Indicador de cancelamento 
            hCupomDet["qCanc"]   := val(substr(cLine, 232, 7 ))       // 19 - Quantidade cancelada 
            hCupomDet["vCanc"]   := val(substr(cLine, 239, 13 ))      // 20 - Valor cancelado
            hCupomDet["aCanc"]   := val(substr(cLine, 252, 13 ))      // 21 - Cancelamento de acr+scimo no item
            hCupomDet["IAT"]     := substr(cLine, 265, 1 )            // 22 - Indicador de Arredondamento ou Truncamento (IAT)
            hCupomDet["qDec"]    := val(substr(cLine, 266, 1 ))       // 23 - Casas decimais da quantidade
            hCupomDet["vDec"]    := val(substr(cLine, 267, 1 ))       // 24 - Casas decimais de valor unit>rio

            // Ajusta as casas decimais.

            hCupomDet["qtde"]    := hCupomDet["qtde"]  / val("1"+replicate("0",hCupomDet["qDec"]))
            hCupomDet["vUnit"]   := hCupomDet["vUnit"] / val("1"+replicate("0",hCupomDet["vDec"]))


            // Guarda o item na lista de Cupons.
            cCanc  := "N"
            nCupom := ascan( aCupons, {|hItCupom| hItCupom["COO"] == hCupomDet["COO"] } )

            if nCupom > 0
               aadd( aCupons[nCupom]["itens"], hCupomDet )
               dDtProd := aCupons[nCupom]["dtEmi"]
               cCanc   := aCupons[nCupom]["canc"]
            endif

            if cCanc = "S" .or. hCupomDet["canc"] = "S"
               hCupomDet["vLiq"] := 0
            endif

            // Guarda o item na lista de itens.

            aadd( aCupomDet, hCupomDet )

            // Totaliza por produto

            if len(aProdutos) = 0
               nPos := 0
            else
               nPos := ascan( aProdutos, {|hItProd| hItProd["codProd"] == hCupomDet["codProd"] } )
            endif

            if nPos = 0
               hProdutos := {=>}
               hProdutos["codProd"] := hCupomDet["codProd"]
               hProdutos["desProd"] := hCupomDet["desProd"]
               hProdutos["unid"]    := hCupomDet["unid"]
               hProdutos["vDesc"]   := hCupomDet["vDesc"]
               hProdutos["vAcre"]   := hCupomDet["vAcre"]
               hProdutos["vUnit"]   := hCupomDet["vUnit"]
               hProdutos["qtde"]    := 0
               hProdutos["vLiq"]    := 0
               if cCanc != "S" .and. hCupomDet["canc"] != "S"
                  hProdutos["qtde"]  := hCupomDet["qtde"]
                  hProdutos["vLiq"]  := hCupomDet["vLiq"]
               endif
               aadd( aProdutos, hProdutos )
            else
               if cCanc != "S" .and. hCupomDet["canc"] != "S"
                  aProdutos[nPos]["qtde"]  += hCupomDet["qtde"]
                  aProdutos[nPos]["vLiq"]  += hCupomDet["vLiq"]
               endif
               aProdutos[nPos]["vDesc"] += hCupomDet["vDesc"]
               aProdutos[nPos]["vAcre"] += hCupomDet["vAcre"]
            endif
      
            // Totaliza por produto / Data

            if !empty(dDtProd) 

               if len(aProdDia) = 0
                  nPos := 0
               else
                  nPos := ascan( aProdDia, {|hItProd| hItProd["codProd"] == hCupomDet["codProd"] .and. hItProd["dtEmi"] == dDtProd } )
               endif

               if nPos = 0
                  hProdDia := {=>}
                  hProdDia["dtEmi"]   := dDtProd
                  hProdDia["codProd"] := hCupomDet["codProd"]
                  hProdDia["desProd"] := hCupomDet["desProd"]
                  hProdDia["unid"]    := hCupomDet["unid"]
                  hProdDia["vDesc"]   := hCupomDet["vDesc"]
                  hProdDia["vAcre"]   := hCupomDet["vAcre"]
                  hProdDia["vUnit"]   := hCupomDet["vUnit"]
                  hProdDia["qtde"]    := 0
                  hProdDia["vLiq"]    := 0
                  if cCanc != "S" .and. hCupomDet["canc"] != "S"
                     hProdDia["qtde"] := hCupomDet["qtde"]
                     hProdDia["vLiq"] := hCupomDet["vLiq"]
                  endif
                  aadd( aProdDia, hProdDia )
               else
                  aProdDia[nPos]["vDesc"] += hCupomDet["vDesc"]
                  aProdDia[nPos]["vAcre"] += hCupomDet["vAcre"]
                  if cCanc != "S" .and. hCupomDet["canc"] != "S"
                     aProdDia[nPos]["qtde"]  += hCupomDet["qtde"]
                     aProdDia[nPos]["vLiq"]  += hCupomDet["vLiq"]
                  endif
               endif
   
            endif

         //////////////////////////////////////////////////////////////////////////////////////////////////////
         case cId = 'E17' // E17 - DETALHE DA REDU++O Z - TOTALIZADORES N+O FISCAIS

            hDetRZTNF := {=>}
            hDetRZTNF["numUser"]   := substr(cLine, 45, 2 )
            hDetRZTNF["CRZ"]       := substr(cLine, 47, 6 )
            hDetRZTNF["descricao"] := substr(cLine, 53, 15 )
            hDetRZTNF["valor"]     := val(substr(cLine, 68, 13 )) / 100
            hDetRZTNF["dtMov"]     := ctod("")

            nPos := ascan( aRZ, {|hItRZ| hItRZ["CRZ"] == hDetRZTNF["CRZ"] } )

            if nPos > 0
               hDetRZTNF["dtMov"] := hRZ["dtMov"]
            endif

            aadd( aDetRZTNF, hDetRZTNF )

         //////////////////////////////////////////////////////////////////////////////////////////////////////
         case cId = 'E18' // E18 - DETALHE DA REDU++O Z - MEIOS DE PAGAMENTO E TROCO

            hDetRZMP := {=>}
            hDetRZMP["numUser"]   := substr(cLine, 45, 2 )
            hDetRZMP["CRZ"]       := substr(cLine, 47, 6 )
            hDetRZMP["descricao"] := substr(cLine, 53, 15 )
            hDetRZMP["valor"]     := val(substr(cLine, 68, 13 )) / 100
            hDetRZMP["dtMov"]     := ctod("")

            nPos := ascan( aRZ, {|hItRZ| hItRZ["CRZ"] == hDetRZMP["CRZ"] } )

            if nPos > 0
               hDetRZMP["dtMov"] := hRZ["dtMov"]
            endif

            if alltrim(hDetRZMP["descricao"])=="TROCO"
               nTroco += hDetRZMP["valor"]
            endif

            aadd( aDetRZMP, hDetRZMP )

         //////////////////////////////////////////////////////////////////////////////////////////////////////
         case cId = 'E21' // E21 - DETALHE DO CUPOM FISCAL E DO DOCUMENTO N+O FISCAL - MEIO DE PAGAMENTO
            
            // E21DR0914BR000000410123 MACH 2              01000284000156000000Dinheiro       0000000001490N0000000000000
            // E21DR0914BR000000410123 MACH 2              01000289000157000000Dinheiro       0000000020000N0000000000000
            // E21DR0914BR000000410123 MACH 2              01000290000158000000Dinheiro       0000000000250N0000000000000
            // E21DR0914BR000000410123 MACH 2              01000291000159000000Cartao         0000000012500N0000000000000
            // E21DR0914BR000000410123 MACH 2              01000292000160000000Cartao         0000000040000N0000000000000
            
            hCupom := {=>}
            hCupom["COO"]     := val(substr(cLine, 47, 6 ))
            hCupom["CCF"]     := val(substr(cLine, 53, 6 ))
            hCupom["GNF"]     := val(substr(cLine, 59, 6 ))
            hCupom["MeioPag"] := substr(cLine, 65, 15 )
            hCupom["vPago"]   := val(substr(cLine, 80, 13)) / 100
            hCupom["estorno"] := substr(cLine, 93, 1 )
            hCupom["vEst"]    := val(substr(cLine, 94, 13)) / 100

            // Guarda o item na lista de Cupons.
            cCanc  := "N"
            nCupom := ascan( aCupons, {|hItCupom| hItCupom["COO"] == hCupom["COO"] } )

            if nCupom > 0

               // aCupons[nCupom]["read"]    := .T.

               aCupons[nCupom]["MeioPag"] := hCupom["MeioPag"]

               // N o soma o valor pago, pois n o tem o troco, no valor pago.
               
               aCupons[nCupom]["vPago"]   += hCupom["vPago"]
               aCupons[nCupom]["estorno"] += hCupom["estorno"]
               aCupons[nCupom]["vEst"]    += hCupom["vEst"]

               cCanc := aCupons[nCupom]["canc"]

               // Totaliza por meio de pagamento

               if len(aMeios) = 0
                  nPos := 0
               else
                  nPos := ascan( aMeios, {|hItMeio| alltrim(hItMeio["MeioPag"]) == alltrim(hCupom["MeioPag"]) } )
               endif

               if nPos = 0

                  hMeio := {=>}
                  hMeio["MeioPag"] := hCupom["MeioPag"]
                  hMeio["vPago"] := hCupom["vPago"]
                  hMeio["vEst"]  := hCupom["vEst"]

                  if alltrim(hMeio["MeioPag"]) == "Dinheiro" .and. nTroco > 0
                     hMeio["vPago"] -= nTroco
                     nTroco := 0
                  endif

                  aadd( aMeios, hMeio )

               else
                  aMeios[nPos]["vPago"] += hCupom["vPago"]
                  aMeios[nPos]["vEst"]  += hCupom["vEst"]
               endif

               // Totaliza por dia / meio de pagamento

               if len(aMeioMes) = 0 
                  nPos := 0      
               else
                  nPos := ascan( aMeioMes, {|hItMeio| alltrim(hItMeio["MeioPag"]) == alltrim(hCupom["MeioPag"]) .and. hItMeio["dtEmi"] == aCupons[nCupom]["dtEmi"] } )
               endif

               if nPos = 0
               
                  hMeioMes := {=>}
                  hMeioMes["MeioPag"] := hCupom["MeioPag"]
                  hMeioMes["dtEmi"]   := aCupons[nCupom]["dtEmi"]
                  hMeioMes["vPago"]   := hCupom["vPago"]
                  hMeioMes["vEst"]    := hCupom["vEst"]

                  if alltrim(hMeioMes["MeioPag"])=="Dinheiro"
                     
                     nPos := ascan( aDetRZMP, {|hItRZ| hItRZ["dtMov"] == hMeioMes["dtEmi"] .AND. alltrim(hItRZ["descricao"]) == "TROCO" } )
   
                     if nPos > 0
                        hMeioMes["vPago"] -= aDetRZMP[nPos]["valor"]
                     endif

                  endif

                  aadd( aMeioMes, hMeioMes )
               else
                  aMeioMes[nPos]["vPago"] += hCupom["vPago"]
                  aMeioMes[nPos]["vEst"]  += hCupom["vEst"]
               endif

            endif

         endcase
         
      next
 
      // Totaliza cupons por dia / Meio de Pagamento

//      if len(aCupons) > 0 
//      
//         aMeioMes := {}
//         hMeioMes := {=>}
//
//         for each hCupom in aCupons
//
//            if !empty(hCupom["MeioPag"])
//            
//               nPos := 0      
//   
//               if len(aMeioMes) > 0 
//                  nPos := ascan( aMeioMes, {|hItMeio| hItMeio["MeioPag"] == hCupom["MeioPag"] .and. hItMeio["dtEmi"] == hCupom["dtEmi"] } )
//               endif
//   
//               if nPos = 0
//                  hMeioMes := {=>}
//                  hMeioMes["MeioPag"] := hCupom["MeioPag"]
//                  hMeioMes["dtEmi"]   := hCupom["dtEmi"]
//                  hMeioMes["vPago"]   := hCupom["vPago"]
//                  hMeioMes["vEst"]    := hCupom["vEst"]
//                  aadd( aMeioMes, hMeioMes )
//               else
//                  aMeioMes[nPos]["vPago"] += hCupom["vPago"]
//                  aMeioMes[nPos]["vEst"]  += hCupom["vEst"]
//               endif
//            
//            endif
//
//         next
//
//      endif

      hTdmFile["hEcf"]      := hEcf
      hTdmFile["hContr"]    := hContr
      hTdmFile["aCupons"]   := aclone(aCupons)
      hTdmFile["aCupomDet"] := aclone(aCupomDet)
      hTdmFile["aProdDia"]  := aclone(aProdDia)
      hTdmFile["aDias"]     := aclone(aDias)
      hTdmFile["aProdutos"] := aclone(aProdutos)
      hTdmFile["aProdDia"]  := aclone(aProdDia)
      hTdmFile["aMeios"]    := aclone(aMeios)
      hTdmFile["aMeioMes"]  := aclone(aMeioMes) 

      hTdmFile["aDetRZTNF"]  := aclone(aDetRZTNF) 
      hTdmFile["aDetRZMP"]  := aclone(aDetRZMP) 

      lRet := .T.

   endif

END SEQUENCE

return { lRet, hTdmFile }

********************************************************************************
function pu_Hash2Txt( hTdmFile, lDetalhado, cTpFile )
********************************************************************************

local lRet      := .F.
local cReport   := ""
local cSep      := ""

local nTotLiq   := 0 
local dDtAnt    := ctod("")
local cCOO      := ""

local hEcf      := {=>} 
local hContr    := {=>}
local aCupons   := {}
local hCupom    := {=>}
local aDias     := {}
local hDia      := {=>}
local hTotal    := {=>}
local aMeios    := {}
local hMeio     := {=>}
local aMeioMes  := {}
local hMeioMes  := {=>}
local hCupomDet := {=>} 
local aCupomDet := {}
local hProdutos := {=>}
local aProdutos := {}
local hProdDia  := {=>}
local aProdDia  := {}
local aDetRZTNF := {}
local hDetRZTNF := {=>}
local aDetRZMP  := {}
local hDetRZMP  := {=>}

default lDetalhado := .T.
default cTpFile    := "TXT"

BEGIN SEQUENCE

   if len(hTdmFile) = 0
      BREAK
   endif

   // Separador de campos.

   //cSep := ";"

   if cTpFile == "TXT"
      cSep := "  "
   else
      cSep := ";"
   endif

   // Lo as informao es do arquivo TDM.

   hEcf      := hTdmFile["hEcf"]      
   hContr    := hTdmFile["hContr"]    
   aCupons   := aclone(hTdmFile["aCupons"])   
   aCupomDet := aclone(hTdmFile["aCupomDet"]) 
   aDias     := aclone(hTdmFile["aDias"])     
   aProdutos := aclone(hTdmFile["aProdutos"]) 
   aProdDia  := aclone(hTdmFile["aProdDia"])  
   aMeios    := aclone(hTdmFile["aMeios"])    
   aMeioMes  := aclone(hTdmFile["aMeioMes"])  
   aDetRZTNF := aclone(hTdmFile["aDetRZTNF"]) 
   aDetRZMP  := aclone(hTdmFile["aDetRZMP"]) 
 
   // Gera o Relat rio do arquivo TDM.

   if len(aCupons) > 0 

      cReport += "TDMViewer by Omiexperience - " + dtoc(date()) + " - " + time() + " - Conf. ATO COTEPE/ICMS No 17, DE 29 DE MARCO DE 2004"+ CRLF

      if !empty(hEcf)
         cReport += replicate("=",200) + CRLF
         cReport += "E01 - IDENTIFICACAO DO ECF" + CRLF + CRLF
         cReport += "Numero de fabricacao : " + hEcf["numFabr"] + CRLF
         cReport += "Tipo/Marca/Modelo    : " + alltrim(hEcf["tipo"]) + " / " + alltrim(hEcf["marca"]) + " / " + hEcf["modelo"] + CRLF
         cReport += "Numero ECF           : " + hEcf["numECF"] + CRLF
         cReport += "CNPJ                 : " + transform(hEcf["CNPJ"], "@R 99.999.999/9999-99") + CRLF
         cReport += "Contador RZ Ini/Fim  : " + hEcf["CRZini"] + " / " + hEcf["CRZfim"] + CRLF
         cReport += "Periodo              : " + dtoc(stod(hEcf["dtIni"]))  + " a " + dtoc(stod(hEcf["dtFim"])) + CRLF
         cReport += "Versao Lib / COTEPE  : " + alltrim(hEcf["verLib"]) + " / " + alltrim(hEcf["VerAto"]) + CRLF
      endif

      if !empty(hContr)
         cReport += replicate("=",200) + CRLF
         cReport += "E02 - IDENTIFICACAO DO ATUAL CONTRIBUINTE USUARIO DO ECF" + CRLF + CRLF
         cReport += "CNPJ     : " + transform(hContr["CNPJ"], "@R 99.999.999/9999-99") + CRLF
         cReport += "IE       : " + hContr["IE"] + CRLF
         cReport += "Nome     : " + hContr["nome"] + CRLF
         cReport += "Endereco : " + hContr["endereco"] + CRLF
         cReport += "Cadastro : " + dtoc(stod(hContr["dtCad"])) + " - " + transform(hContr["hrCad"], "@R 99:99:99" ) + CRLF
         cReport += "CRO      : " + hContr["CRO"] + CRLF
         cReport += "GT       : " + alltrim(transform(val(hContr["GT"])/100, "@RE 999,999,999,999,999.99" )) + CRLF
         cReport += "Usuario  : " + hContr["numUser"] + CRLF
      endif

   endif

   ///////////////////////////////////////////////////////////////////////////////////////////////////////////

   // imprime os cupons.

   if len(aCupons) > 0

      nTotLiq := 0
      dDtAnt  := ctod("")
      
      cReport += replicate("=",200) + CRLF
      cReport += "E14 - CUPOM FISCAL, NOTA FISCAL DE VENDA A CONSUMIDOR E BILHETE DE PASSAGEM" + CRLF
      cReport += CRLF
      cReport += "Data           CCF     COO         Valor Total            Desconto              Acrescimo          Valor Liquido  Canc  Valor Cancelado     Meio Pagto               Valor Pago" + CRLF
      cReport += replicate("-",200) + CRLF

      for each hCupom in aCupons

         if hCupom["dtEmi"] <> dDtAnt 
            if !empty(dDtAnt) .and. cTpFile == "TXT" 
               cReport += replicate("-",200) + CRLF
            endif
            dDtAnt := hCupom["dtEmi"] 
         endif

         // Data de emiss o
         cReport += dtoc(hCupom["dtEmi"]) + cSep
                     
         // CCF 
         cReport += str(hCupom["CCF"],6) + cSep

         // COO
         cReport += str(hCupom["COO"],6) + cSep

         // Valor total
         cReport += transform( hCupom["vTot"], "@RE 999,999,999,999.99" ) + cSep
      
         // Desconto
         cReport += transform( hCupom["vDesc"], "@RE 999,999,999,999.99" ) + cSep

         // Valor / Percentual
         cReport += hCupom["tDesc"] + cSep

         // Acr+scimo
         cReport += transform( hCupom["vAcre"], "@RE 999,999,999,999.99" ) + cSep

         // Valor / Percentual
         cReport += hCupom["tAcre"] + cSep

         // Valor loquido
         cReport += transform( hCupom["vLiq"], "@RE 999,999,999,999.99" ) + cSep

         // Cancelado S/N
         cReport += hCupom["canc"] + cSep

         // Valor do cancelamento
         cReport += transform( hCupom["vCanc"], "@RE 999,999,999,999.99" ) + cSep

         // Ordem de aplicao o de desconto e acr+scimo
         cReport += hCupom["ordem"] + cSep

         // Meio de Pagamento
         cReport += hCupom["MeioPag"] + cSep

         // Valor Pago
         cReport += transform( hCupom["vPago"], "@RE 999,999,999,999.99" ) + cSep

         cReport += CRLF

         nTotLiq += hCupom["vLiq"]

      next 
      
      cReport += "TOTAL                                                                                         " + transform( nTotLiq, "@RE 999,999,999,999.99" ) + cSep
      cReport += CRLF

   endif

   ///////////////////////////////////////////////////////////////////////////////////////////////////////////

   // Imprime o detalhe dos cupons.

   if len(aCupomDet) > 0 .and. lDetalhado

      nTotLiq := 0
      cCOO    := 0

      cReport += CRLF 
      cReport += replicate("=",200) + CRLF
      cReport += "E15 - DETALHE DO CUPOM FISCAL, DA NOTA FISCAL DE VENDA A CONSUMIDOR OU DO BILHETE DE PASSAGEM" + CRLF
      cReport += CRLF
      cReport += "   CCF     COO Item  Codigo          Descricao                                           Quantidade  Unid     Valor Unitario            Desconto           Acrescimo       Valor Liquido  TotPArc  Canc" + CRLF
      cReport += replicate("-",200) + CRLF

      for each hCupomDet in aCupomDet

         if hCupomDet["COO"] <> cCOO 
            if !empty(cCOO) .and. cTpFile == "TXT" 
               cReport += replicate("-",200) + CRLF
            endif
            cCOO := hCupomDet["COO"] 
         endif

         // CCF 
         cReport += str(hCupomDet["CCF"],6) + cSep

         // COO
         cReport += str(hCupomDet["COO"],6) + cSep

         // Item
         cReport += str(hCupomDet["item"],3) + cSep

         // C digo do Produto
         cReport += hCupomDet["codProd"] + cSep

         // Descrio o
         cReport += left(hCupomDet["desProd"],50) + cSep

         // Quantidade
         cReport += transform( hCupomDet["qtde"], "@RE 999,999.99" ) + cSep

         // Unidade
         cReport += hCupomDet["unid"] + cSep

         // Valor Unit>rio
         cReport += transform( hCupomDet["vUnit"], "@RE 999,999,999,999.99" ) + cSep
      
         // Desconto
         cReport += transform( hCupomDet["vDesc"], "@RE 999,999,999,999.99" ) + cSep

         // Acr+scimo
         cReport += transform( hCupomDet["vAcre"], "@RE 999,999,999,999.99" ) + cSep

         // Valor Liquido
         cReport += transform( hCupomDet["vLiq"], "@RE 999,999,999,999.99" ) + cSep

         // Totalizador parcial
         cReport += hCupomDet["tParc"] + cSep

         // Indicador de cancelamento
         cReport += hCupomDet["canc"] + cSep

         cReport += CRLF

         nTotLiq += hCupomDet["vLiq"]

         // hCupomDet["qCanc"]   := val(substr(cLine, 232, 7 ))       // 19 - Quantidade cancelada 
         // hCupomDet["vCanc"]   := val(substr(cLine, 239, 13 ))      // 20 - Valor cancelado
         // hCupomDet["aCanc"]   := val(substr(cLine, 252, 13 ))      // 21 - Cancelamento de acr+scimo no item
         // hCupomDet["IAT"]     := substr(cLine, 265, 1 )            // 22 - Indicador de Arredondamento ou Truncamento (IAT)
         // hCupomDet["qDec"]    := val(substr(cLine, 266, 1 ))       // 23 - Casas decimais da quantidade
         // hCupomDet["vDec"]    := val(substr(cLine, 267, 1 ))       // 24 - Casas decimais de valor unit>rio

      next 

      cReport += "TOTAL                                                                                                                                                                 " + transform( nTotLiq, "@RE 999,999,999,999.99" ) + cSep
      cReport += CRLF

   endif

   ///////////////////////////////////////////////////////////////////////////////////////////////////////////

   // Imprime os totais por Data / produtos.

   if len(aProdDia) > 0 .and. lDetalhado

      aProdDia := ASort( aProdDia,,, {|x,y| dtoc(x["dtEmi"])+x["desProd"] < dtoc(y["dtEmi"])+y["desProd"]  } )

      nTotLiq  := 0
      dDtAnt   := ctod("")

      cReport += CRLF 
      cReport += replicate("=",200) + CRLF
      cReport += "E15 - DETALHE DO CUPOM FISCAL POR DATA / PRODUTO" + CRLF
      cReport += CRLF
      cReport += "Data        Codigo          Descricao                                           Quantidade  Unid     Valor Unitario            Desconto           Acrescimo       Valor Liquido" + CRLF
      cReport += replicate("-",200) + CRLF

      for each hProdDia in aProdDia

         if hProdDia["dtEmi"] <> dDtAnt 
            if !empty(dDtAnt) .and. cTpFile == "TXT" 
               cReport += replicate("-",200) + CRLF
            endif
            dDtAnt := hProdDia["dtEmi"] 
         endif

         // Data de emiss o
         cReport += dtoc(hProdDia["dtEmi"]) + cSep

         // C digo do Produto
         cReport += hProdDia["codProd"] + cSep

         // Descrio o
         cReport += left(hProdDia["desProd"],50) + cSep

         // Quantidade
         cReport += transform( hProdDia["qtde"], "@RE 999,999.99" ) + cSep

         // Unidade
         cReport += hProdDia["unid"] + cSep

         // Valor Unit>rio
         cReport += transform( hProdDia["vUnit"], "@RE 999,999,999,999.99" ) + cSep
      
         // Desconto
         cReport += transform( hProdDia["vDesc"], "@RE 999,999,999,999.99" ) + cSep

         // Acr+scimo
         cReport += transform( hProdDia["vAcre"], "@RE 999,999,999,999.99" ) + cSep

         // Valor Liquido
         cReport += transform( hProdDia["vLiq"], "@RE 999,999,999,999.99" ) + cSep

         cReport += CRLF

         nTotLiq += hProdDia["vLiq"]

      next 

      cReport += "TOTAL                                                                                                                                                        " + transform( nTotLiq, "@RE 999,999,999,999.99" ) + cSep
      cReport += CRLF

   endif

   ///////////////////////////////////////////////////////////////////////////////////////////////////////////

   // Imprime os totais por produtos.

   if len(aProdutos) > 0

      aProdutos := ASort( aProdutos,,, {|x,y| x["desProd"] < y["desProd"] } )

      nTotLiq := 0

      cReport += CRLF 
      cReport += replicate("=",200) + CRLF
      cReport += "E15 - DETALHE DO CUPOM FISCAL POR PRODUTO" + CRLF
      cReport += CRLF
      cReport += "Codigo          Descricao                                           Quantidade  Unid     Valor Unitario            Desconto           Acrescimo       Valor Liquido" + CRLF
      cReport += replicate("-",200) + CRLF

      for each hProdutos in aProdutos

         // C digo do Produto
         cReport += hProdutos["codProd"] + cSep

         // Descrio o
         cReport += left(hProdutos["desProd"],50) + cSep

         // Quantidade
         cReport += transform( hProdutos["qtde"], "@RE 999,999.99" ) + cSep

         // Unidade
         cReport += hProdutos["unid"] + cSep

         // Valor Unit>rio
         cReport += transform( hProdutos["vUnit"], "@RE 999,999,999,999.99" ) + cSep
      
         // Desconto
         cReport += transform( hProdutos["vDesc"], "@RE 999,999,999,999.99" ) + cSep

         // Acr+scimo
         cReport += transform( hProdutos["vAcre"], "@RE 999,999,999,999.99" ) + cSep

         // Valor Liquido
         cReport += transform( hProdutos["vLiq"], "@RE 999,999,999,999.99" ) + cSep

         cReport += CRLF

         nTotLiq += hProdutos["vLiq"]
      
      next 

      cReport += "TOTAL                                                                                                                                            " + transform( nTotLiq, "@RE 999,999,999,999.99" ) + cSep
      cReport += CRLF

   endif

   ////////////////////////////////////////////////////////////////////////////////

   // Imprime os totais por dia.

   if len(aDias) > 0 

      hTotal := {=>}
      hTotal["COO"]   := 0
      hTotal["vTot"]  := 0
      hTotal["vDesc"] := 0
      hTotal["vAcre"] := 0
      hTotal["vLiq"]  := 0
      hTotal["vCanc"] := 0

      cReport += CRLF 
      cReport += replicate("=",200) + CRLF
      cReport += "E14 - TOTAIS POR DIA" + CRLF
      cReport += CRLF
      cReport += "Data      Qtde COO         Valor Total            Desconto           Acrescimo       Valor Liquido     Valor Cancelado" + CRLF

      for each hDia in aDias

         hTotal["COO"]   += hDia["COO"]
         hTotal["vTot"]  += hDia["vTot"]
         hTotal["vDesc"] += hDia["vDesc"]
         hTotal["vAcre"] += hDia["vAcre"]
         hTotal["vLiq"]  += hDia["vLiq"]
         hTotal["vCanc"] += hDia["vCanc"]

         // Data de emiss o
         cReport += dtoc(hDia["dtEmi"]) + cSep

         // Qtde COO
         cReport += str(hDia["COO"],6) + cSep
      
         // Valor total
         cReport += transform( hDia["vTot"], "@RE 999,999,999,999.99" ) + cSep
      
         // Desconto
         cReport += transform( hDia["vDesc"], "@RE 999,999,999,999.99" ) + cSep

         // Acr+scimo
         cReport += transform( hDia["vAcre"], "@RE 999,999,999,999.99" ) + cSep

         // Valor loquido
         cReport += transform( hDia["vLiq"], "@RE 999,999,999,999.99" ) + cSep

         // Valor do cancelamento
         cReport += transform( hDia["vCanc"], "@RE 999,999,999,999.99" ) + cSep

         cReport += CRLF

      next

      // Total
      cReport += "TOTAL     " + cSep

      // Qtde COO
      cReport += str(hTotal["COO"],6) + cSep
   
      // Valor total
      cReport += transform( hTotal["vTot"], "@RE 999,999,999,999.99" ) + cSep
   
      // Desconto
      cReport += transform( hTotal["vDesc"], "@RE 999,999,999,999.99" ) + cSep

      // Acr+scimo
      cReport += transform( hTotal["vAcre"], "@RE 999,999,999,999.99" ) + cSep

      // Valor loquido
      cReport += transform( hTotal["vLiq"], "@RE 999,999,999,999.99" ) + cSep

      // Valor do cancelamento
      cReport += transform( hTotal["vCanc"], "@RE 999,999,999,999.99" ) + cSep

      cReport += CRLF

   endif

   ////////////////////////////////////////////////////////////////////////////////////

   // Imprime os totais por Meio de Pagamento / Data.

   if len(aMeioMes) > 0 .and. lDetalhado

      nTotLiq := 0
      dDtAnt  := ctod("")

      cReport += CRLF 
      cReport += replicate("=",200) + CRLF
      cReport += "E21 - RESUMO DO CUPOM FISCAL E DO DOCUMENTO NAO FISCAL - MEIO DE PAGAMENTO POR DIA" + CRLF
      cReport += CRLF
      cReport += "Data        Meio de Pagamento        Valor pago     Valor estornado" + CRLF
      cReport += replicate("-",200) + CRLF
   
      for each hMeioMes in aMeioMes 

         if hMeioMes["dtEmi"] <> dDtAnt 
            if !empty(dDtAnt) .and. cTpFile == "TXT" 
               cReport += replicate("-",200) + CRLF
            endif
            dDtAnt := hMeioMes["dtEmi"] 
         endif

         // Data de emiss o
         cReport += dtoc(hMeioMes["dtEmi"]) + cSep

         // Meio
         cReport += hMeioMes["MeioPag"] + cSep

         // Valor pago
         cReport += transform( hMeioMes["vPago"], "@RE 999,999,999,999.99" ) + cSep

         // Valor estornado
         cReport += transform( hMeioMes["vEst"], "@RE 999,999,999,999.99" ) + cSep

         cReport += CRLF     

         nTotLiq += hMeioMes["vPago"]

      next

      cReport += "TOTAL                        " + transform( nTotLiq, "@RE 999,999,999,999.99" ) + cSep
      cReport += CRLF
   
   endif

   ///////////////////////////////////////////////////////////////////////////////////////////////////////////

   // Imprime os totais por Meio de Pagamento.

   if len(aMeios) > 0

      nTotLiq := 0

      cReport += CRLF 
      cReport += replicate("=",200) + CRLF
      cReport += "E21 - RESUMO DO CUPOM FISCAL E DO DOCUMENTO NAO FISCAL - MEIO DE PAGAMENTO " + CRLF
      cReport += CRLF
      cReport += "Meio de Pagamento        Valor pago     Valor estornado" + CRLF
      cReport += replicate("-",200) + CRLF

      for each hMeio in aMeios

         // Meio
         cReport += hMeio["MeioPag"] + cSep

         // Valor pago
         cReport += transform( hMeio["vPago"], "@RE 999,999,999,999.99" ) + cSep

         // Valor estornado
         cReport += transform( hMeio["vEst"], "@RE 999,999,999,999.99" ) + cSep

         // estorno
         //cReport += hMeio["estorno"] + cSep

         cReport += CRLF

         nTotLiq += hMeio["vPago"]

      next 

      cReport += "TOTAL            " + transform( nTotLiq, "@RE 999,999,999,999.99" ) + cSep
      cReport += CRLF

   endif

   cReport += CRLF 
   cReport += replicate("=",200) + CRLF

   lRet    := .T.

END SEQUENCE

return { lRet, cReport }

****************************************************************************************************
static function pu_BackupPDV()
****************************************************************************************************
local oZip 
local cPath  := CurDrive() + ":\" + CurDir() + "\" 
local cFile  := "OmiePDV_"+strzero(day(date()),2)+".zip"
local cFileM := "OmiePDV_"+ str(year(date()),4) + "_" + strzero(month(date()),2)+".zip"

local aFiles := {}

// Arquivo para o Backup
aadd( aFiles, cPath+"dadosecf.dbf" )
aadd( aFiles, cPath+"impecf.dbf" )
aadd( aFiles, cPath+"indice.dbf" )
aadd( aFiles, cPath+"dados.dbf" )
aadd( aFiles, cPath+"cadastro.dbf" )
aadd( aFiles, cPath+"clientes.dbf" )
aadd( aFiles, cPath+"estoque.dbf" )
aadd( aFiles, cPath+"nbm.dbf" )
aadd( aFiles, cPath+"cartao.dbf" )
aadd( aFiles, cPath+"caixa.dbf" )
aadd( aFiles, cPath+"movcaixa.dbf" )
aadd( aFiles, cPath+"movecf.dbf" )

aadd( aFiles, cPath+"cupom.dbf" )
aadd( aFiles, cPath+"estat.dbf" )

aadd( aFiles, cPath+"nfccab.dbf" )
aadd( aFiles, cPath+"nfcitens.dbf" )
aadd( aFiles, cPath+"contnfce.dbf" )
aadd( aFiles, cPath+"nfcinut.dbf" )
aadd( aFiles, cPath+"nfcinut.fpt" )
aadd( aFiles, cPath+"nfcerro.dbf" )

aadd( aFiles, cPath+"satfiscal.dbf" )
aadd( aFiles, cPath+"satfiscal.fpt" )
aadd( aFiles, cPath+"satitens.dbf" )

aadd( aFiles, cPath+"omie_cupom.dbf" )
aadd( aFiles, cPath+"omie_lote.dbf" )
aadd( aFiles, cPath+"omie_lote.fpt" )
aadd( aFiles, cPath+"omie_pend.dbf" )

aadd( aFiles, cPath+"omie.ini" )
aadd( aFiles, cPath+"sysfar.ini" )

cPath += "omie\backup\"

if !IsDir(cPath)
   DirMake(cPath)
endif

if file(cPath+cFile)
   ferase(cPath+cFile)
endif
   
// Gera o ZIP do arquivo a ser enviado.

oZip := TZip():New(cPath+cFile, 1 )

oZip:AddFiles( aFiles )

oZip:end()

if !file(cPath+cFileM)

   COPY FILE (cPath+cFile) TO (cPath+cFileM)

endif

return .T.

****************************************************************************************************
static function pu_GetCupons( nLote, dDtIni, dDtFim )
****************************************************************************************************
local aFunc, aFunc2, aFunc3, aFunc4, cCateg

local cXml      := ""
local cMsg      := ""
local hResponse := {=>}
local aAlerts   := {}
local hAlert    := {=>}

local nPagina   := 1
local nTotPag   := 1
local nReg      := 0

local aCupons   := {}
local hCupom    := {=>}
local lRestart  := .F.

default nLote   := 0
default dDtIni  := ctod("")
default dDtFim  := ctod("")

sysrefresh()

begin sequence

   aFunc  := { "cupomfiscal", "ListarCupons", "cfListarRequest" }

   pu_EraseFile( aFunc[1] )

   do while .t.

      sysrefresh()

      aFunc2 := { { "nPagina",        "integer", alltrim(str(nPagina)), 0 }, ;
                  { "nRegPorPagina",  "integer", "50",               0 } }
      /*
                  , ;
                  { "dDtEmisInicial", "string",  dtoc(dDtIni),       0 }, ;
                  { "dDtEmisFinal",   "string",  dtoc(dDtFim),       0 }                  
      */
                                    
      aFunc4 := { "faultcode" }

      cCateg := "produtos"

      cria_xml_omie( cCateg, aFunc, aFunc2 )

      cXml := pu_EnviaXml( "http://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/", DIR_TEMP+"\"+aFunc[1]+".xml", DIR_TEMP+"\"+aFunc[1]+"_ret.xml", "", "",;
                            "http://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/?WSDL"+aFunc[2], "text/xml;charset=UTF-8", 0, pu_IsLog("WS") )

      fRename( DIR_TEMP+"\"+aFunc[1]+"_ret.xml", DIR_TEMP+"\"+aFunc[1]+"_ret"+strzero(nPagina,3)+".xml" )

      hResponse := pu_GetResponse( , cXml, "ListarCuponsResponse", .T., , .F. )

      if hResponse["ok"]

         nPagina := val(pu_GetValueTag( hResponse["source"], { "ListarCuponsResponse", "cfListarResponse", "nPagina" }, "C" ))
         nTotPag := val(pu_GetValueTag( hResponse["source"], { "ListarCuponsResponse", "cfListarResponse", "nTotPaginas" }, "C" ))
         nReg    := val(pu_GetValueTag( hResponse["source"], { "ListarCuponsResponse", "cfListarResponse", "nRegistros" }, "C" ))

         if nPagina > 0 .and. nTotPag > 0 .and. nPagina <= nTotpag .and. nReg > 0

            aCupons := pu_GetValueTag( hResponse["source"], { "ListarCuponsResponse", "cfListarResponse", "listaCupons" }, "A" )

            if len(aCupons) > 0

               for each hCupom in aCupons

                  if hHasKey(hCupom, "item") 
                     
                     // <<<<<< AQUI >>>>>>>>
                     // Utilize essa estrutura para obter os dados do cupom fiscal recebido: hCupom["item"]

                  endif

               next 

            endif

         endif

      else
         
         EXIT

      endif

      if nPagina >= nTotPag
         exit
      endif

      nPagina += 1

   enddo

end sequence

return .T.

****************************************************************************************************
static function // pu_GetStatusLote( nLote )
****************************************************************************************************
local aFunc, aFunc2, aFunc3, aFunc4, cCateg

local cXml       := ""
local cMsg       := ""
local hResponse  := {=>}
local aAlerts    := {}
local hAlert     := {=>}

local nPagina    := 1
local nTotPag    := 1
local nReg       := 0

local hLote  := {=>}
local aErros := {}

default nLote  := 0

sysrefresh()

begin sequence

   aFunc  := { "cupomfiscalcsv", "ObterStatus", "CsvGetStatusIn" }

   pu_EraseFile( aFunc[1] )

   aFunc2 := { { "nLote", "integer", alltrim(str(nLote)), 0 } }

   aFunc4 := { "faultcode" }

   cCateg := "produtos"

   cria_xml_omie( cCateg, aFunc, aFunc2 )

   cXml := pu_EnviaXml( "http://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/", DIR_TEMP+"\"+aFunc[1]+".xml", DIR_TEMP+"\"+aFunc[1]+"_ret.xml", "", "",;
                           "http://app.omie.com.br/api/v1/"+cCateg+"/"+aFunc[1]+"/?WSDL"+aFunc[2], "text/xml;charset=UTF-8", 0, pu_IsLog("WS") )

   fRename( DIR_TEMP+"\"+aFunc[1]+"_ret.xml", DIR_TEMP+"\"+aFunc[1]+"_ret"+strzero(nPagina,3)+".xml" )

   hResponse := pu_GetResponse( , cXml, "ObterStatusResponse", .T., , .F. )
   
   if hResponse["ok"]

      hLote := pu_GetValueTag( hResponse["source"], { "ObterStatusResponse", "CsvGetStatusOut" }, "H" )

      if len(hLote) > 0
         
         // Lista de Erros do lote.

         aErros := hLote["erros"]

      endif

   endif

end sequence

return .T.

****************************************************************************************************

// // Gera o arquivo TDM
// 
// // m->aDadosEcfLocal := { { cNome_ecf, nSerie, cPorta, nEcf_versao, nCOM, nRecnoImpecf, nTipoEcf } }
// 
// GeraCat52( m->aDadosEcfLocal[1,5], m->aDadosEcfLocal[1,7], m->aDadosEcfLocal[1,4], ;
//            m->aDadosEcfLocal[1,2], .t., ctod("16/03/2015") )
// 
//=============================================================================//

// Para Gerar Arquivo TDM

// GeraCat52( m->aDadosEcfLocal[1,5], m->aDadosEcfLocal[1,7], m->aDadosEcfLocal[1,4], ;
//         m->aDadosEcfLocal[1,2], .t., )

// LeituraZ()   - Para tirar LeituraZ() 
// _LeituraX(1) - Leitura X
// MsgAlert() - Amarelo.
// MsgStop()  - Vermelho.
// MsgInfo()  - Azul.
// MsgYesNo() - Verde.
// MsgRun()   - Branco.
// MsgMeter() - Branco.
// https://support.microsoft.com/en-us/kb/3083595
// 
// http://news.softpedia.com/news/windows-10-high-cpu-usage-fix-490908.shtml