// Function ConsCep()

//    Local cUrl  := "viacep.com.br/ws/"
//    Local cType := "/xml/"
//    Local aUrl  := {}

//    Local cCep := "08572-730"

// Return Nil


// Function PesquisaCEP()

//    local oHttp, cUrl, aResult
//    local cCEP:= Space(13)
   
//    MsgGet("Pesquisa CEP", "Informe o CEP", @cCep)
   
//    if Empty(cCep)
//        return nil
//    endif
       
//    cUrl:= "http://viacep.com.br/ws/"+ cCep +"/json"
   
//    oHttp:= CreateObject( 'MSXML2.ServerXMLHTTP.6.0' )
                            
//    oHttp:Open( "GET", cUrl, .f. )
//    oHttp:setRequestHeader('Content-Type'  , 'application/json')                

//    oHttp:Send()

//    IF oHttp:status != 200
//        MsgStop( Alltrim(Str(oHttp:status)) +" - "+ oHttp:statusText , "Erro na requisição")
//        RETURN NIL
//    ENDIF    

//    x :=  hb_jsondecode( oHttp:ResponseBody, @aResult )

//    xbrowse(aResult, "Resultado")
   
// return nil


Function Main()
   ? "teste"
Return nil

