#include "inkey.ch"
#include "error.ch"
#include "common.ch"
#include "set.ch"
#include "sqlrdd.ch"

#define CRLF    chr(10)+chr(12)

REQUEST SIGNXML
REQUEST SIGNXMLEX

********************************************************************************
function main( cServer, cXmlEnviar )
********************************************************************************
local cXmlrec := ""
local cFile   := ""

default cServer to ""
default cXmlEnviar to ""

SetMode( 35, 100 )

if empty(cServer)
   ? "use omiews <SERVER> <XML_FILE>"
   return .f.
endif

if empty(cXmlEnviar)
   ? "use omiews <SERVER> <XML_FILE>"
   return .f.
endif

if !file(cXmlEnviar)
   ? "File not found... " + cXmlEnviar
   return .F.
endif

cXmlEnviar := memoread(cXmlEnviar)
cXmlEnviar := strtran(cXmlEnviar,chr(10))
cXmlEnviar := strtran(cXmlEnviar,chr(12))

if empty(cXmlEnviar)
   ? "XML file invalid."
   return .f.
endif

cls

@ 04, 10 say "Sending request..."
@ 14, 10 say "Status......: Sending..."
                  
cFile   := "log\response_"+dtos(date())+"_"+strtran(time(),":")+".xml"

cXmlrec := PreparaXml( upper(cServer), cXmlEnviar )

if GravaXML( cFile, cXmlrec )                   
   @ 14, 10 say "Status......: Done, see file " + cFile
else
   @ 14, 10 say "Status......: Error."
endif

@ 16, 10 say "Goodbye!" 
@ 18, 10 say "" 

return NIL

********************************************************************************
function PreparaXml( cServer, cXmlEnviar )
********************************************************************************
local cXmlRet := ""
local aRet := {}

local cURL          := ""
local cCert         := ""
local cSenha        := ""
local cSoapAction   := ""
local cContentType  := "text/xml;charset=UTF-8"
local nTimeOut      := 0
local cExibeLog     := "N"

hIniFile := HB_ReadIni( "omiews.ini", .F.,,.F. )     

If hIniFile == NIL
   ? "Could not read from omiews.ini"
   Quit
EndIf

If ! cServer IN hIniFile
   ? "Server [" + cServer + "] not found in omiews.ini"
   Quit
EndIf

hData := hIniFile[ cServer ]

If !"URL" IN hData
   ? "URL not found in " + cServer
   Quit
EndIf

If !"CERTFILE" IN hData
   ? "CertFile not found in " + cServer
   Quit
EndIf

If !"CERTPASSWORD" IN hData
   ? "CertPassword not found in " + cServer
   Quit
EndIf

If !"SOAPACTION" IN hData
   ? "SoapAction not found in " + cServer
   Quit
EndIf

If !"CONTENTTYPE" IN hData
   ? "ContentType not found in " + cServer
   Quit
EndIf

If !"TIMEOUT" IN hData
   ? "TimeOut not found in " + cServer
   Quit
EndIf

If !"WITHLOG" IN hData
   ? "WithLog not found in " + cServer
   Quit
EndIf

cURL          := alltrim(hData[ "URL" ])
cCert         := alltrim(hData[ "CERTFILE" ])
cSenha        := alltrim(hData[ "CERTPASSWORD" ])
cSoapAction   := alltrim(hData[ "SOAPACTION" ])
cContentType  := alltrim(hData[ "CONTENTTYPE" ])
nTimeOut      := val(hData[ "TIMEOUT" ])
cExibeLog     := alltrim(hData[ "WITHLOG" ])

@ 6, 10 say "URL.........: " + cURL
@ 7, 10 say "Certificado.: " + cCert
@ 8, 10 say "Senha.......: " + replicate("*",len(cSenha))
@ 9, 10 say "Soap Action.: " + cSoapAction
@10, 10 say "Content Type: " + cContentType
@11, 10 say "Timeout.....: " + alltrim(str(nTimeOut))
@12, 10 say "Exibe Log...: " + cExibeLog

cXmlRet := EnviaXml( cURL, cXmlEnviar, cCert, cSenha, cSoapAction, cContentType, nTimeOut, cExibeLog )

return cXmlRet

********************************************************************************
function EnviaXml( cURL, cXml, cCert, cSenha, cSoapAction, cContentType, nTimeOut, cExibeLog )
********************************************************************************

LOCAL cRet := ""
local oUrl
local oWebService
local cPath := ""
local cFile  := ""
local cFile2 := "wssend.log"
local aDir_ := {}
local cString := ""
 
default cSoapAction  to ""
default cContentType to ""
default nTimeOut     to 0
default cExibeLog    to "N"

oUrl := tURLSSL():New( cUrl )

oWebService := TipClientSSLHTTP():New( oUrl,cExibeLog="S",,,,cCert,,cSenha)

if nTimeOut=0
   oWebService:nConnTimeout := 30000
else
   if nTimeOut > 100000
      nTimeOut := 100000
   endif
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

oWebService:cConnetion:='Keep-Alive'

oWebService:cUserAgent := 'XHB-SOAP/1.2.1'

IF oWebService:Open()
   IF oWebService:Post(cXml)
      cRet := oWebService:ReadAll()
   ENDIF
ENDIF

if oWebService:ltrace .and. oWebService:nhandle > -1
   fClose( oWebService:nHandle )
   oWebService:nhandle := -1 
endif

oWebService:close() 

return cRet

********************************************************************************
function GravaXML( cFile, cStream )
********************************************************************************

LOCAL nHandle := FCreate( cFile )

if FError() <> 0
   return .F.
endif

FWrite( nHandle, cStream )

FClose( nHandle )
   
return( FError() == 0 )
         
********************************************************************************
FUNCTION cValToChar( uData )
********************************************************************************

LOCAL cType := VALTYPE( uData )

   DO CASE
   CASE cType == "C"
      RETURN uData
   CASE cType == "N"
      RETURN ALLTRIM( STR( uData ) )
   CASE cType == "D"
      RETURN DTOC( uData )
   CASE cType == "L"
      RETURN IF( uData, ".T.", ".F." )
   CASE cType == "A"

      RETURN "{Array}..."
   CASE cType == "O"
      RETURN "{Object}..."
   OTHERWISE
      RETURN ""
   ENDCASE

RETURN ""

********************************************************************************