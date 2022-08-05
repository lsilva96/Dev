#include "inkey.ch"
#include "error.ch"
#include "common.ch"
#include "set.ch"

/*
Main centralizador de chamadas
*/
Function Main()

   CodeBlock()
   Arrays()

Return Nil

/*
Exemplo de code Blocks
*/
Function CodeBlock()

   Local bBloco := NIL 

   bBloco := { |nX, nY| nX + nY }

   ? "Resultado do CodeBlock"
   ? Eval(bBloco, 1, 2)

Return nil

/*
ALIMENTA VARIAVEIS DE IDADE
*/
Function Arrays()

   Local nX      := 0
   Local nLin    := 10
   Local aIdades := {12, 25, 26, 30, 31}

   Public aUsers  := {{"John", 12},;
                     {"Marc", 25},;
                     {"Bill", 30}}

   ? "Qtde de registros no Array...... " + Str(Len(aIdades))

   For nX := 1 to Len(aUsers)
      ? aIdades[nX]      
      ? "Nome encontrato pelo AScan: " + CacaNome(aIdades[nX])
   Next nX

Return nil

/*
BUSCA NOME DO INDIVIDUO COM BASE NA IDADE
*/
Function CacaNome(nIdade)

   Local cNome    := ""
   Local nPos     := 0

   nPos := AScan( aUsers, {| x | (x[2]) == nIdade } )

   If nPos > 0
      cNome := aUsers[nPos][1]
   Endif

Return cNome
