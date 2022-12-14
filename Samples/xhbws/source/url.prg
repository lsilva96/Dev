/*
 * xHarbour Project source code:
 * TIP Class oriented Internet protocol library
 *
 * Copyright 2003 Giancarlo Niccolai <gian@niccolai.ws>
 *
 * www - http://www.harbour-project.org
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this software; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place, Suite 330,
 * Boston, MA 02111-1307 USA (or visit the web site http://www.gnu.org/).
 *
 * As a special exception, the Harbour Project gives permission for
 * additional uses of the text contained in its release of Harbour.
 *
 * The exception is that, if you link the Harbour libraries with other
 * files to produce an executable, this does not by itself cause the
 * resulting executable to be covered by the GNU General Public License.
 * Your use of that executable is in no way restricted on account of
 * linking the Harbour library code into it.
 *
 * This exception does not however invalidate any other reasons why
 * the executable file might be covered by the GNU General Public License.
 *
 * This exception applies only to the code released by the Harbour
 * Project under the name Harbour.  If you copy code from other
 * Harbour Project or Free Software Foundation releases into a copy of
 * Harbour, as the General Public License permits, the exception does
 * not apply to the code that you add in this way.  To avoid misleading
 * anyone as to the status of such modified files, you must delete
 * this exception notice from them.
 *
 * If you write modifications of your own for Harbour, it is your choice
 * whether to permit this exception to apply to your modifications.
 * If you do not wish that, delete this exception notice.
 *
 */

#include "hbclass.ch"

/*
* An URL:
* http://gian:passwd@www.niccolai.ws/mypages/mysite/page.html?avar=0&avar1=1
* ^--^   ^--^ ^----^ ^-------------^ ^----------------------^ ^------------^
* cProto  UID  PWD      cServer             cPath                 cQuery
*                                    ^------------^ ^-------^
*                                      cDirectory     cFile
*                                                   ^--^ ^--^
*                                                 cFname cExt
*/

CLASS tURLSSL
   DATA cAddress
   DATA cProto
   DATA cServer
   DATA cPath
   DATA cQuery
   DATA cFile
   DATA nPort
   DATA cUserid
   DATA cPassword

   METHOD New( cUrl )
   METHOD SetAddress( cUrl )
   METHOD BuildAddress()
   METHOD BuildQuery( )
   METHOD AddGetForm( cPostData )

HIDDEN:
   CLASSDATA   cREuri   INIT HB_RegexComp("(?:(.*)://)?([^?/]*)(/[^?]*)?\??(.*)")
   CLASSDATA   cREServ  INIT HB_RegexComp("(?:([^:@]*):?([^@:]*)@|)([^:]+):?(.*)")
   CLASSDATA   cREFile  INIT HB_RegexComp("^((?:/.*/)|/)*(.*)$")

ENDCLASS


METHOD New( cUrl ) CLASS tURLSSL
   ::SetAddress( cUrl )
RETURN Self


METHOD SetAddress( cUrl ) CLASS tURLSSL
   LOCAL aMatch, cServer, cPath

   ::cAddress := ""
   ::cProto := ""
   ::cUserid := ""
   ::cPassword := ""
   ::cServer := ""
   ::cPath := ""
   ::cQuery := ""
   ::cFile := ""
   ::nPort := -1

   IF Empty( cUrl ) .or. Len( cUrl ) == 0
      RETURN .T.
   ENDIF

   // TOPLEVEL url parsing
   aMatch:= HB_Regex( ::cREuri, cUrl )

   //May fail
   IF Empty( aMatch )
      RETURN .F.
   ENDIF

   ::cProto := Lower( aMatch[2] )
   cServer := aMatch[3]
   cPath := aMatch[4]
   ::cQuery := aMatch[5]

   // server parsing (can't fail)
   aMatch := HB_Regex( ::cREServ, cServer )
   ::cUserId := aMatch[2]
   ::cPassword := aMatch[3]
   ::cServer := aMatch[4]
   ::nPort := Val(aMatch[5])
   IF ::nPort < 1
      ::nPort := -1
   ENDIF

   // Parse path and file (can't fail )
   aMatch := HB_Regex( ::cREFile, cPath )
   ::cPath := aMatch[2]
   ::cFile := aMatch[3]

RETURN .T.


METHOD BuildAddress() CLASS tURLSSL
   LOCAL cRet := ""

   IF ::cProto != NIL
      ::cProto := Lower( ::cProto )
   ENDIF

   IF .not. Empty( ::cProto ) .and. .not. Empty( ::cServer )
      cRet := ::cProto + "://"
   ENDIF

   IF ! Empty( ::cUserid )
      cRet += ::cUserid
      IF ! Empty( ::cPassword )
         cRet+= ":" + ::cPassword
      ENDIF
      cRet += "@"
   ENDIF

   IF ! Empty( ::cServer )
      cRet += ::cServer
      IF ::nPort > 0
         cRet += ":" + AllTrim( Str( ::nPort ) )
      ENDIF
   ENDIF

   IF Len( ::cPath ) == 0 .or. ::cPath[-1] != "/"
      ::cPath += "/"
   ENDIF

   cRet += ::cPath + ::cFile
   IF .not. Empty( ::cQuery )
      cRet += "?" + ::cQuery
   ENDIF

   IF Len( cRet ) == 0
      cRet := NIL
   ELSE
      ::cAddress := cRet
   ENDIF

RETURN cRet

METHOD BuildQuery( ) CLASS tURLSSL
   LOCAL cLine

   IF Len( ::cPath ) == 0 .or. ::cPath[-1] != "/"
      ::cPath += "/"
   ENDIF

   cLine := ::cPath + ::cFile
   IF .not. Empty( ::cQuery )
      cLine += "?" + ::cQuery
   ENDIF

RETURN cLine

METHOD AddGetForm( cPostData )
   LOCAL cData:='', nI, cTmp,y, cRet

   IF HB_IsHash( cPostData )
      FOR nI := 1 TO Len( cPostData )
         cTmp := HGetKeyAt( cPostData, nI )
         cTmp := CStr( cTmp )
         cTmp := AllTrim( cTmp )
         cTmp := TipEncoderUrl_Encode( cTmp )
         cData += cTmp +"="
         cTmp := HGetValueAt( cPostData, nI )
         cTmp := CStr( cTmp )
         cTmp := AllTrim( cTmp )
         cTmp := TipEncoderUrl_Encode( cTmp )
         cData += cTmp + "&"
      NEXT
      cData[-1] = ""
   elseIF HB_IsArray( cPostData )
      y:=Len(cPostData)
      FOR nI := 1 TO y
         cTmp := cPostData[ nI ,1]
         cTmp := CStr( cTmp )
         cTmp := AllTrim( cTmp )
         cTmp := TipEncoderUrl_Encode( cTmp )
         cData += cTmp +"="
         cTmp := cPostData[ nI,2]
         cTmp := CStr( cTmp )
         cTmp := AllTrim( cTmp )
         cTmp := TipEncoderUrl_Encode( cTmp )
         cData += cTmp
         IF nI!=y
            cData+="&"
         ENDIF
      NEXT

   ELSEIF HB_IsString( cPostData )
      cData := cPostData
   Endif

   IF !empty(cData)
      cRet := ::cQuery+=if(empty(::cQuery),'','&')+cData
   ENDIF

RETURN cRet
