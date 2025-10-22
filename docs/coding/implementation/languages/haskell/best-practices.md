# Haskell Best Practices

---

## Type Signatures

```haskell
add :: Int -> Int -> Int
add x y = x + y
```

---

## Algebraic Data Types

```haskell
data Result a = Success a | Failure String

processResult :: Result Int -> String
processResult (Success n) = "Got: " ++ show n
processResult (Failure msg) = "Error: " ++ msg
```

---

## Monads

```haskell
main :: IO ()
main = do
    putStrLn "Enter your name:"
    name <- getLine
    putStrLn $ "Hello, " ++ name
```

---

## Higher-Order Functions

```haskell
map :: (a -> b) -> [a] -> [b]
filter :: (a -> Bool) -> [a] -> [a]
fold :: (b -> a -> b) -> b -> [a] -> b
```
