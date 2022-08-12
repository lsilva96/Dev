
/*
Realiza consulta de CEP na API ViaCEP

dev. Lucas Ribeiro
*/

Function ConsCep()

   Local cCep := ""

   ACCEPT " Informe o CEP : " TO cCep      
   
   cCep := StrTran(cCep,"-","")   

   If !Empty(cCep) .AND. Len(cCep) == 8
      ConsultaCep(cCep)
   else
      ? "CEP Invalido!"
   Endif

Return Nil


/*
Função de pesquisa na API do ViaCEP
*/

Function ConsultaCep(cCep)

   Local hHash := {=>}  
   Local oHttp, cHtml

   oHttp:= TIpClientHttp():new( "http://viacep.com.br/ws/"+cCep+"/json/" )
   
   IF oHttp:open()      
      cHtml   := oHttp:readAll()   
      
      HB_JsonDecode( cHtml , @hHash )

      ? "----------RESULT----------"
      ? " O CEP enviado foi: " + hHash['cep']
      ? " Corresponde ao Endereco : " + HB_AnsiToOem(hHash['logradouro'])
      ? " Complemento : "     + If(Empty(hHash['complemento']), HB_AnsiToOem("Não existe complemento cadastrado"), HB_AnsiToOem(hHash['complemento']))
      ? " Bairro : "       + HB_AnsiToOem(hHash['bairro'])
      ? " Cidade : "       + HB_AnsiToOem(hHash['localidade'])
      ? " Estado : "       + hHash['uf']
      ? " DDD : "          + hHash['ddd']
      ? " Cod Ibge : "     + hHash['ibge']
                  
      oHttp:close()        
   ELSE
      ? "houve erros na comunicacao com o servidor externo:", oHttp:lastErrorMessage()
   ENDIF 

Return