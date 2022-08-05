/*
Leia 2 valores inteiros e armazene-os nas variáveis A e B. Efetue a soma de A e B atribuindo o seu resultado na variável X. 
Imprima X conforme exemplo apresentado abaixo.
Nao apresente mensagem alguma alem daquilo que está sendo especificado e nao esqueça de imprimir o fim de linha após o resultado,
caso contrário, você receberá "Presentation Error".

dev= lucas.ribeiro
*/

/* Cenario 1
- CENA 0: Dois numeros para resultado da Soma
- CENA 1:Um numero e uma Letra para validaçao do Tipo de variavel
- CENA 2:Numero positivo e negativo
*/

Function Main()

   Local nNum1 := 0
   Local nNum2 := 0
   Local nCena := 0

   SWITCH nCena
      CASE 0
         nNum1 := 10
         nNum2 := 9

         ? "Cenario ....... 01"
         If ValidaDado(nNum1,nNum2)
            ? "A Expressao e: "+ Str(nNum1) +" + "+ Str(nNum2) +" = "+ Str(CalcSoma(nNum1, nNum2))
         Endif

         nCena += 1
      CASE 1
         nNum1 := "A"
         nNum2 := 2
         
         ? "Cenario ....... 02"
         If ValidaDado(nNum1,nNum2)
            ? "A Expressao e: "+ Str(nNum1) +" + "+ Str(nNum2) +" = " + Str(CalcSoma(nNum1, nNum2))
         Endif

         nCena += 1
      CASE 2
         nNum1 := 10
         nNum2 := 9

         ? "Cenario ....... 03"         
         If ValidaDado(nNum1,nNum2)
            ? "A Expressao e: "+ Str(nNum1) +" + "+ Str(nNum2) +" = " +  Str(CalcSoma(nNum1, nNum2))       
         Endif
  
         nCena += 1      
         EXIT
      DEFAULT
         ? "Nenhuma entrada foi detectada!"
      END

return nil

/* 
Funçao do Calculo de Soma
*/

Function CalcSoma(n1, n2)

   Local nTotal := 0

   nTotal := n1 + n2

return nTotal

/* 
Funçao que valida tipo da entrada
*/

Function ValidaDado(nNum1, nNum2)

   Local lRet := .T.

   If !(ValType(nNum1) == "N" .AND. ValType(nNum2) == "N")
      ? "Valores enviados: " + "Num1:"+ IIF(ValType(nNum1) == "C", nNum1, Str(nNum1)) + "   Num2:"+ IIF(ValType(nNum2) == "C", nNum2, Str(nNum2))
      ? "Tipos de Entrada Incorretos. Verifique e tente novamente"
      lRet := .F.
   Endif

Return lRet