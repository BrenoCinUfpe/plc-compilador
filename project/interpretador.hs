module Interpretador where

type Id = String

data Valor
  = VNum Double
  | VBool Bool
  | VList [Valor]
  | VUnit
  | VErro String
  deriving (Eq)

instance Show Valor where
  show (VNum n)      = show n
  show (VBool b)     = show b
  show (VList vs)    = "[" ++ joinWith ", " (map show vs) ++ "]"
  show VUnit         = "()"
  show (VErro msg)   = "Erro(" ++ msg ++ ")"

type Estado = [(Id, Valor)]

showEstado :: Estado -> String
showEstado es = "{" ++ joinWith ", " (map (\(k,v) -> k ++ " = " ++ show v) es) ++ "}"

joinWith :: String -> [String] -> String
joinWith _ []     = ""
joinWith _ [x]    = x
joinWith s (x:xs) = x ++ s ++ joinWith s xs

data Expressao
  = LitN Double
  | LitB Bool
  | Var Id
  | Soma Expressao Expressao
  | Sub  Expressao Expressao
  | Menor Expressao Expressao
  | Igual Expressao Expressao
  -- Listas
  | ListLit [Expressao]
  | Cons  Expressao Expressao       -- cons x xs
  | Head  Expressao                 -- head xs
  | Tail  Expressao                 -- tail xs
  | IsEmpty Expressao               -- isEmpty xs
  | Length  Expressao               -- length xs
  deriving (Show, Eq)

data Comando
  = Atr Id Expressao
  | Seq Comando Comando
  | IfC Expressao Comando Comando        -- if cond then c1 else c2
  | ForC Comando Expressao Comando Comando -- for (init; cond; step) { body }
  | CmdExpr Expressao                     -- avalia e descarta o valor
  deriving (Show, Eq)

intExp :: Estado -> Expressao -> (Valor, Estado)
intExp st expr = case expr of
  LitN n -> (VNum n, st)
  LitB b -> (VBool b, st)
  Var x  -> (lookupVar x st, st)

  Soma a b ->
    let (va, st1) = intExp st a
        (vb, st2) = intExp st1 b
    in case (va, vb) of
         (VNum x, VNum y) -> (VNum (x + y), st2)
         _                -> (VErro "+ espera números", st2)

  Sub a b ->
    let (va, st1) = intExp st a
        (vb, st2) = intExp st1 b
    in case (va, vb) of
         (VNum x, VNum y) -> (VNum (x - y), st2)
         _                -> (VErro "- espera números", st2)

  Menor a b ->
    let (va, st1) = intExp st a
        (vb, st2) = intExp st1 b
    in case (va, vb) of
         (VNum x, VNum y) -> (VBool (x < y), st2)
         _                -> (VErro "< espera números", st2)

  Igual a b ->
    let (va, st1) = intExp st a
        (vb, st2) = intExp st1 b
    in (VBool (va == vb), st2)

  ListLit es ->
    let (vals, st') = evalList st es
    in (VList vals, st')

  Cons eHead eTail ->
    let (vh, st1) = intExp st eHead
        (vt, st2) = intExp st1 eTail
    in case vt of
         VList xs -> (VList (vh:xs), st2)
         _        -> (VErro "cons espera lista no segundo argumento", st2)

  Head e ->
    let (v, st1) = intExp st e
    in case v of
         VList (x:_) -> (x, st1)
         VList []    -> (VErro "head em lista vazia", st1)
         _           -> (VErro "head espera lista", st1)

  Tail e ->
    let (v, st1) = intExp st e
    in case v of
         VList (_:xs) -> (VList xs, st1)
         VList []     -> (VErro "tail em lista vazia", st1)
         _            -> (VErro "tail espera lista", st1)

  IsEmpty e ->
    let (v, st1) = intExp st e
    in case v of
         VList xs -> (VBool (null xs), st1)
         _        -> (VErro "isEmpty espera lista", st1)

  Length e ->
    let (v, st1) = intExp st e
    in case v of
         VList xs -> (VNum (fromIntegral (length xs)), st1)
         _        -> (VErro "length espera lista", st1)


evalList :: Estado -> [Expressao] -> ([Valor], Estado)
evalList st []     = ([], st)
evalList st (e:es) =
  let (v, st1)   = intExp st e
      (vs, st2)  = evalList st1 es
  in (v:vs, st2)

intCmd :: Estado -> Comando -> Estado
intCmd st cmd = case cmd of
  Atr x e ->
    let (v, st1) = intExp st e
    in writeVar x v st1

  Seq c1 c2 ->
    let st1 = intCmd st c1
    in intCmd st1 c2

  IfC cond cThen cElse ->
    let (vc, st1) = intExp st cond
    in case vc of
         VBool True  -> intCmd st1 cThen
         VBool False -> intCmd st1 cElse
         _           -> st1  -- mantém estado se cond inválida

  ForC cInit cond cStep cBody ->
    let st1 = intCmd st cInit
    in forLoop st1
    where
      forLoop s =
        let (vc, s1) = intExp s cond
        in case vc of
             VBool True  ->
               let sBody = intCmd s1 cBody
                   sStep = intCmd sBody cStep
               in forLoop sStep
             VBool False -> s1
             _           -> s1

  CmdExpr e ->
    let (_, st1) = intExp st e
    in st1

lookupVar :: Id -> Estado -> Valor
lookupVar x [] = VErro ("variavel nao encontrada: " ++ x)
lookupVar x ((y,v):r)
  | x == y    = v
  | otherwise = lookupVar x r

writeVar :: (Id) -> Valor -> Estado -> Estado
writeVar x v [] = [(x,v)]
writeVar x v ((y,u):r)
  | x == y    = (x,v):r
  | otherwise = (y,u):writeVar x v r


--------------------------------------------------------------------------------
-- Run examples

-- 1) If: x := 0; if (x == 0) then y := 10 else y := 20
progIf :: Comando
progIf =
  Seq (Atr "x" (LitN 0))
      (IfC (Igual (Var "x") (LitN 0))
           (Atr "y" (LitN 10))
           (Atr "y" (LitN 20)))

runIf :: IO ()
runIf = do
  let stFinal = intCmd [] progIf
  putStrLn ("Estado final (If): " ++ showEstado stFinal)


-- 2) For: soma 0..4
-- soma := 0; for (i := 0; i < 5; i := i + 1) { soma := soma + i }
progFor :: Comando
progFor =
  Seq (Atr "soma" (LitN 0))
      (ForC (Atr "i" (LitN 0))
            (Menor (Var "i") (LitN 5))
            (Atr "i" (Soma (Var "i") (LitN 1)))
            (Atr "soma" (Soma (Var "soma") (Var "i"))))

runFor :: IO ()
runFor = do
  let stFinal = intCmd [] progFor
  putStrLn ("Estado final (For): " ++ showEstado stFinal)


-- 3) Listas: xs := [1,2,3]; h := head xs; t := tail xs; e := isEmpty t; n := length xs; xs := cons 0 xs
progList :: Comando
progList =
  Seq (Atr "xs" (ListLit [LitN 1, LitN 2, LitN 3]))
  (Seq (Atr "h"  (Head (Var "xs")))
  (Seq (Atr "t"  (Tail (Var "xs")))
  (Seq (Atr "e"  (IsEmpty (Var "t")))
  (Seq (Atr "n"  (Length (Var "xs")))
       (Atr "xs" (Cons (LitN 0) (Var "xs")))))))

runList :: IO ()
runList = do
  let stFinal = intCmd [] progList
  putStrLn ("Estado final (Listas): " ++ showEstado stFinal)


