## Documentação técnica do interpretador (Haskell)

### Objetivos

- Prover um intérprete didático, pequeno e legível.
- Cobrir três pilares essenciais: decisão (If), iteração (For) e estrutura de dados (Listas).
- Servir como base para expansão (While, Tuplas, Funções/Lambda, etc.).

## Arquitetura e componentes

### Tipos principais

- Identificadores e estado:
  - `type Id = String`
  - `type Estado = [(Id, Valor)]` (associação variável → valor, com atualização por substituição)
- Valores manipulados pelo intérprete:
  - `data Valor = VNum Double | VBool Bool | VList [Valor] | VUnit | VErro String`
  - Observações:
    - `VErro` carrega mensagem e é produzido em erros de tipo/execução. A execução atual não “lança” a exceção; apenas propaga o valor de erro.

### AST (árvore de sintaxe abstrata)

- Expressões relevantes:
  - Números/Booleanos/Variáveis: `LitN`, `LitB`, `Var`
  - Aritmética/Comparações: `Soma`, `Sub`, `Menor`, `Igual`
  - Listas: `ListLit`, `Cons`, `Head`, `Tail`, `IsEmpty`, `Length`
- Comandos:
  - Atribuição: `Atr Id Expressao`
  - Sequência: `Seq Comando Comando`
  - Condicional: `IfC Expressao Comando Comando`
  - Laço `for`: `ForC Comando Expressao Comando Comando`
  - Expressão como comando: `CmdExpr Expressao`

## Semântica de avaliação

### Expressões

Assinatura: `intExp :: Estado -> Expressao -> (Valor, Estado)`

- Não há efeitos além de leitura do estado (estado é retornado inalterado, salvo pelo encadeamento de avaliação de subexpressões).
- Regras principais (resumo):
  - `Var x` lê com `lookupVar` (retorna `VErro` se ausente).
  - `Soma/Sub/Menor` exigem números; caso contrário produzem `VErro`.
  - `Igual` compara estruturalmente `Valor` (útil para listas e números/booleanos).
  - `ListLit` avalia elementos da esquerda para a direita; resultado é `VList`.
  - `Cons h t` exige que `t` avalie para `VList`; caso contrário, `VErro`.
  - `Head/Tail` em lista vazia produzem `VErro`.
  - `IsEmpty` exige `VList`; retorna `VBool`.
  - `Length` exige `VList`; retorna `VNum` com o comprimento.

Observação: por simplicidade, erros não interrompem execução automaticamente. Extensões podem introduzir um “modo estrito” que aborte ao detectar `VErro`.

### Comandos

Assinatura: `intCmd :: Estado -> Comando -> Estado`

- `Atr x e`: avalia `e` e escreve `(x ← valor)` com `writeVar` (atualização por substituição).
- `Seq c1 c2`: executa `c1` no estado atual e `c2` no estado resultante.
- `IfC cond t e`:
  - Avalia `cond`; se `VBool True` executa `t`, se `VBool False` executa `e`.
  - Qualquer outro valor mantém o estado (comportamento conservador para MVP).
- `ForC init cond step body`:
  - Executa `init` uma vez; então repete: avalia `cond`; se `VBool True`, executa `body`, depois `step`; caso contrário, sai.
  - Se `cond` não for `VBool`, encerra e retorna o estado corrente (fail-safe).
- `CmdExpr e`: avalia `e` e descarta o valor; retorna estado (útil para efeitos futuros).

## Exemplos de uso

### If

```haskell
progIf =
  Seq (Atr "x" (LitN 0))
      (IfC (Igual (Var "x") (LitN 0))
           (Atr "y" (LitN 10))
           (Atr "y" (LitN 20)))
-- Estado final: {x = 0.0, y = 10.0}
```

### For (soma 0..4)

```haskell
progFor =
  Seq (Atr "soma" (LitN 0))
      (ForC (Atr "i" (LitN 0))
            (Menor (Var "i") (LitN 5))
            (Atr "i" (Soma (Var "i") (LitN 1)))
            (Atr "soma" (Soma (Var "soma") (Var "i"))))
-- Estado final: {soma = 10.0, i = 5.0}
```

### Listas

```haskell
progList =
  Seq (Atr "xs" (ListLit [LitN 1, LitN 2, LitN 3]))
  (Seq (Atr "h"  (Head (Var "xs")))
  (Seq (Atr "t"  (Tail (Var "xs")))
  (Seq (Atr "e"  (IsEmpty (Var "t")))
       (Atr "n"  (Length (Var "xs"))))))
-- Estado final: {xs = [1.0, 2.0, 3.0], h = 1.0, t = [2.0, 3.0], e = False, n = 3.0}
```

## Limitações atuais

- Sem parser: programas são construídos diretamente no AST, o que é ótimo para ensino, limitado para uso final.
- Sem tipagem estática: erros de tipo surgem em tempo de execução como `VErro`.
- Atualização de variáveis é linear no tamanho do estado.