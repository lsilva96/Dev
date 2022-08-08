


Function ConsCep()

   Local cCep := ""

   ACCEPT " Informe o CEP : " TO cCep      
   
   If !Empty(cCep)
      ConsultaCep(cCep)
   else
      ? "CEP não preenchido!"
   Endif

Return Nil


Function ConsultaCep(cCep)

   Local cUrl  := "viacep.com.br/ws/"    
   Local hHash := {=>}  
   Local oHttp, cHtml

   oHttp:= TIpClientHttp():new( "http://viacep.com.br/ws/"+cCep+"/json/" )
   
   IF oHttp:open()      
      cHtml   := oHttp:readAll()   
      
      HB_JsonDecode( cHtml , @hHash )

      ? hHash['cep']
                  
      oHttp:close()
      ? cHtml      
   ELSE
      ? "erro de conexao:", oHttp:lastErrorMessage()
   ENDIF 

Return