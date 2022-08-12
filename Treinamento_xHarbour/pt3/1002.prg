/*
A fórmula para calcular a área de uma circunferência é: area = ? . raio2. Considerando para este problema que ? = 3.14159:
- Efetue o cálculo da área, elevando o valor de raio ao quadrado e multiplicando por ?.
Entrada
A entrada contém um valor de ponto flutuante (dupla precisão), no caso, a variável raio.
Saída
Apresentar a mensagem "A=" seguido pelo valor da variável area, conforme exemplo abaixo, com 4 casas após o ponto decimal. 
Utilize variáveis de dupla precisão (double). Como todos os problemas, não esqueça de imprimir o fim de linha após o resultado, caso contrário, 
você receberá "Presentation Error".
*/

function Main()

   Public aInputs := {2.00, 100.64, 150.00}

   AreaDoCirculo()

Return 

/*
Função que calcula Area conforme parametros enviados
*/

Function AreaDoCirculo()

   Local nPII  := 3.14159
   Local n1    := 0

   For n1 := 1 to Len(aInputs)
      ? "A=" + Str(Round(nPII*(aInputs[n1]*2),4))
   Next n1

Return

