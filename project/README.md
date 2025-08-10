Interpretador mínimo em Haskell com as seguintes implementações:
* If
* For
* Listas

Este projeto contém um interpretador didático, escrito em Haskell, com suporte aos seguintes recursos:

- Comando condicional: If
- Laço de repetição: For (no estilo init; cond; step; body)
- Listas: literais [1,2,3], cons, head, tail, isEmpty, length

Como executar

1. Abra um terminal na raiz do repositório (onde está a pasta project/).
2. Inicie o GHCi e carregue o módulo do interpretador:
   - ghci
   - :l project/interpretador.hs
3. Rode um dos cenários de demonstração:
   - runIf (demonstra o comando If)
   - runFor (soma de 0..4 usando For)
   - runList (operações básicas de lista)
     Cada função imprime no console o estado final, no formato {variavel = valor, ...}.

Estrutura do código (alto nível)

- type Id = String e type Estado = [(Id, Valor)]
  - O estado é um mapeamento de nomes de variáveis para valores.
- data Valor = VNum Double | VBool Bool | VList [Valor] | VUnit | VErro String
  - Tipos de valores que o interpretador manipula.
- data Expressao = ... (números, booleanos, variáveis, aritmética, comparações e listas)
  - Exemplos: LitN 1, Soma (LitN 1) (LitN 2), ListLit [LitN 1, LitN 2], Head (Var "xs")
- data Comando = Atr Id Expressao | Seq Comando Comando | IfC ... | ForC ... | CmdExpr ...
  - Atribuição, sequência, if, for e avaliação de expressão como comando.
- Avaliador de expressões: intExp :: Estado -> Expressao -> (Valor, Estado)
  - Avalia expressões e retorna o valor e (possivelmente) um estado atualizado.
- Avaliador de comandos: intCmd :: Estado -> Comando -> Estado
  - Executa comandos e retorna o novo estado.

O que está implementado

- If (IfC cond thenCmd elseCmd)
- For (ForC init cond step body)
- Listas (ListLit, Cons, Head, Tail, IsEmpty, Length)
- Aritmética básica (Soma, Sub) e comparação (Menor, Igual)

Exemplos inclusos
No arquivo project/interpretador.hs você encontra três programas de exemplo:

- progIf e runIf: mostra decisão com If.
- progFor e runFor: soma de 0 a 4 usando For.
- progList e runList: criação e manipulação de listas.