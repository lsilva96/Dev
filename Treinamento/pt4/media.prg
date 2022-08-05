/*
Leia 2 valores de ponto flutuante de dupla precisão A e B, que correspondem a 2 notas de um aluno. 
A seguir, calcule a média do aluno, sabendo que a nota A tem peso 3.5 e a nota B tem peso 7.5 (A soma dos pesos portanto é 11). 
Assuma que cada nota pode ir de 0 até 10.0, sempre com uma casa decimal.

Entrada
O arquivo de entrada contém 2 valores com uma casa decimal cada um.

Saída
Imprima a mensagem "MEDIA" e a média do aluno conforme exemplo abaixo, com 5 dígitos após o ponto decimal e com um espaço em branco antes e depois da igualdade. 
Utilize variáveis de dupla precisão (double) e como todos os problemas, não esqueça de imprimir o fim de linha após o resultado, caso contrário, você receberá "Presentation Error".
*/


Function Main()

   MediaAlunos()

Return

Function MediaAlunos()
   
   Local aAlunos := {"JOSE ALMEIDA", "LUCAS RIBEIRO", "FULANO DO BAIRRO", "ZÉ PASTELEIRO"}
   Local aAux    := {}
   Local n1      := 0
   Local cNota1  := 0
   Local cNota2  := 0
   Local hFile

   hFile := HB_ReadIni( "notas.ini" )  

   If hFile == NIL
      ? "Arquivo Notas.ini não encontrado!"
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

      ? hb_OEMToANSI("A média do Aluno: ") + aAlunos[n1] + hb_OEMToANSI(" é :") + Str(nMedia)

   Next n1
   
Return

