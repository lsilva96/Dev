/*
Consumo de api com o TIPClientHttp

dev. Lucas Ribeiro
*/

Function Main()

   Public cMarca
   Public cVeiculo
   Public cAno
   
   //Funcoes do processo
   Marcas()
   Modelos() 
   Anos()
   Veiculos()

Return

/*
Consumo de api
- Exibe Marcas dos carros

dev. Lucas Ribeiro
*/

Function Marcas()
   LOCAL oHttp, cHtml
   Local hHash := {=>}

   oHttp:= TIpClientHttp():new( "http://parallelum.com.br/fipe/api/v1/carros/marcas" )
   
   IF oHttp:open()      
      cHtml   := oHttp:readAll()      

      hb_jsonDecode(cHtml, @hHash )
      
      ? " "
      ? "----|CODIGO|-----|NOME|-----"
      ? " "
      For n1 := 1 To Len(hHash)
         ? hHash[n1]['codigo'] + " - " + hHash[n1]['nome']                             
      Next n1
      
      ACCEPT " Informe o Codigo da Marca que deseja consultar : " TO cMarca

      oHttp:close()    
   ELSE
      ? "erro de conexao:", oHttp:lastErrorMessage()
   ENDIF

Return

/*
Consumo de api
- Exibe Modelos das Marcas dos carros

dev. Lucas Ribeiro
*/

Function Modelos()
   Local oHttp, cHtml
   Local hHash := {=>}  
   Local n1    := 0 

   oHttp:= TIpClientHttp():new( "http://parallelum.com.br/fipe/api/v1/carros/marcas/"+cMarca+"/modelos" )
   
   IF oHttp:open()      
      cHtml   := oHttp:readAll()   
      
      If !Empty(cHtml)

         hb_jsonDecode(cHtml, @hHash )

         ? " "
         ? "----|CODIGO|-----|NOME|-----"
         ? " "
         For n1 := 1 To Len(hHash)
            ? Str(hHash['modelos'][n1]['codigo'])  + " - " + hHash['modelos'][n1]['nome']                         
         Next n1    

         ACCEPT " Informe o Codigo do Veiculo que deseja consultar : " TO cVeiculo

         oHttp:close()    
      else
         ? " Parametros enviados incorretos "    
      Endif
   ELSE
      ? "erro de conexao:", oHttp:lastErrorMessage()
   ENDIF

Return

/*
Consumo de api
- Exibe Ano dos Modelos das Marcas dos carros

dev. Lucas Ribeiro
*/


Function Anos()
   Local oHttp, cHtml
   Local hHash := {=>}   
   Local n1    := 0 

   oHttp:= TIpClientHttp():new( "http://parallelum.com.br/fipe/api/v1/carros/marcas/"+cMarca+"/modelos/"+cVeiculo+"/anos" )
   
   IF oHttp:open()      
      cHtml   := oHttp:readAll()      

      If !Empty(cHtml)
         hb_jsonDecode(cHtml, @hHash )

         ? " "
         ? "----|CODIGO|-----|NOME|-----"
         ? " "
         For n1 := 1 To Len(hHash)
            ? Alltrim(hHash[n1]['codigo'])  + " - " + Alltrim(hHash[n1]['nome'])
         Next n1
         
         ACCEPT " Informe o Codigo do Ano do Veiculo que deseja consultar : " TO cAno

         oHttp:close()    

      Else
         ? " Parametros enviados incorretos "    
      Endif
   ELSE
      ? "erro de conexao:", oHttp:lastErrorMessage()
   ENDIF

Return

/*
Consumo de api
- Exibe Dados do Ano do Modelo da Marca do carro escolhido kkk

dev. Lucas Ribeiro
*/


Function Veiculos()
   Local oHttp, cHtml
   Local hHash := {=>}   

   oHttp:= TIpClientHttp():new( "http://parallelum.com.br/fipe/api/v1/carros/marcas/"+cMarca+"/modelos/"+cVeiculo+"/anos/"+cAno+"" )
   
   IF oHttp:open()      
      cHtml   := oHttp:readAll()    
      
      If !Empty(cHtml)

         hb_jsonDecode(cHtml, @hHash )

         ? " "
         ? "----DADOS DO VEICULO-----"
         ? " "
         ? "Valor: " + hHash['Valor']
         ? "Marca: " + hHash['Marca']
         ? "Modelo: " + hHash['Modelo']
         ? "AnoModelo: " + Alltrim(Str(hHash['AnoModelo']))
         ? "Combustivel: " + hHash['Combustivel']
         ? "Cod Fipe: " + hHash['CodigoFipe']
         ? "Mes Ref.: " + hHash['MesReferencia']
         ? "Tipo Veiculo: " + Alltrim(Str(hHash['TipoVeiculo']))
         ? "Sigla Combustivel: " + hHash['SiglaCombustivel']

         oHttp:close()  
      Else
         ? " Parametros enviados incorretos "       
      Endif
   ELSE
      ? "erro de conexao:", oHttp:lastErrorMessage()
   ENDIF

Return