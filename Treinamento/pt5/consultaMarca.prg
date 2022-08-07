Function Main()
   LOCAL oHttp, cHtml, hQuery

   oHttp:= TIpClientHttp():new( "http://parallelum.com.br/fipe/api/v1/carros/marcas" )
   
   IF oHttp:open()      
      cHtml   := oHttp:readAll()      

      oHttp:close()
      ? cHtml      
   ELSE
      ? "Connection error:", oHttp:lastErrorMessage()
   ENDIF

Return