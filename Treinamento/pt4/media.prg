/*
Leia 2 valores de ponto flutuante de dupla precis�o A e B, que correspondem a 2 notas de um aluno. 
A seguir, calcule a m�dia do aluno, sabendo que a nota A tem peso 3.5 e a nota B tem peso 7.5 (A soma dos pesos portanto � 11). 
Assuma que cada nota pode ir de 0 at� 10.0, sempre com uma casa decimal.

Entrada
O arquivo de entrada cont�m 2 valores com uma casa decimal cada um.

Sa�da
Imprima a mensagem "MEDIA" e a m�dia do aluno conforme exemplo abaixo, com 5 d�gitos ap�s o ponto decimal e com um espa�o em branco antes e depois da igualdade. 
Utilize vari�veis de dupla precis�o (double) e como todos os problemas, n�o esque�a de imprimir o fim de linha ap�s o resultado, caso contr�rio, voc� receber� "Presentation Error".
*/


Function Main()

   MediaAlunos()

Return

Function MediaAlunos()
   
   Local aAlunos := {"JOSE ALMEIDA", "LUCAS RIBEIRO", "FULANO DO BAIRRO", "Z� PASTELEIRO"}
   Local aAux    := {}
   Local n1      := 0
   Local cNota1  := 0
   Local cNota2  := 0
   Local hFile

   hFile := HB_ReadIni( "notas.ini" )  

   If hFile == NIL
      ? "Arquivo Notas.ini n�o encontrado!"
      Quit
   EndIf
   
   For n1 := 1 To Len(aAlunos)
      cNome  := aAlunos[n1]
      hData := hFile[ cNome ]

      cNota1 := Alltrim(hData["NOTA1"])
      cNota2 := Alltrim(hData["NOTA2"])

      //Media
      nTotNotas := 2
      nSomaNota := Val(cNota1) + Val(cNota2)

      nMedia := Round(nSomaNota / nTotNotas , 2)

      ? hb_OEMToANSI("A m�dia do Aluno: ") + aAlunos[n1] + hb_OEMToANSI(" � :") + Str(nMedia)

   Next n1
   
Return

