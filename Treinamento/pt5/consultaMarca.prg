/*
Consumo de api com o TIPClientHttp

dev. Lucas Ribeiro
*/

Function Main()
   LOCAL oHttp, cHtml

   oHttp:= TIpClientHttp():new( "http://parallelum.com.br/fipe/api/v1/carros/marcas" )
   
   IF oHttp:open()      
      cHtml   := oHttp:readAll()      

      oHttp:close()
      ? cHtml      
   ELSE
      ? "erro de conexao:", oHttp:lastErrorMessage()
   ENDIF

Return