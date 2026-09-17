module Main where

import Data.Char (digitToInt, isDigit)
import Data.List (intercalate)
import System.Environment (getArgs)
import System.IO (hSetEncoding, stdout, utf8)

type Board = [[Int]]

parseBoard :: String -> Board
parseBoard text = map (map cell) rows
  where
    rows = take 9 (filter (not . null) (lines text))
    cell c
      | isDigit c && c /= '0' = digitToInt c
      | otherwise = 0

firstEmpty :: Board -> Maybe (Int, Int)
firstEmpty b =
  case [(r, c) | r <- [0 .. 8], c <- [0 .. 8], b !! r !! c == 0] of
    [] -> Nothing
    (p : _) -> Just p

candidates :: Board -> Int -> Int -> [Int]
candidates b r c = [v | v <- [1 .. 9], v `notElem` used]
  where
    used = (b !! r) ++ map (!! c) b ++ box
    box = [b !! i !! j | i <- [br .. br + 2], j <- [bc .. bc + 2]]
    br = 3 * (r `div` 3)
    bc = 3 * (c `div` 3)

place :: Board -> Int -> Int -> Int -> Board
place b r c v =
  [ [if (i, j) == (r, c) then v else b !! i !! j | j <- [0 .. 8]]
  | i <- [0 .. 8]
  ]

-- счётчик перебранных вариантов протаскивается через рекурсию,
-- иначе после отката он сбрасывался бы вместе с веткой
solve :: Int -> Board -> (Int, Maybe Board)
solve n b =
  case firstEmpty b of
    Nothing -> (n, Just b)
    Just (r, c) -> go n (candidates b r c)
      where
        go k [] = (k, Nothing)
        go k (v : vs) =
          case solve (k + 1) (place b r c v) of
            (k', Just s) -> (k', Just s)
            (k', Nothing) -> go k' vs

render :: Board -> String
render b = unlines (concatMap block (chunks 3 b))
  where
    block rows = map line rows ++ ["------+-------+------"]
    line row = intercalate " | " (map (unwords . map shown) (chunks 3 row))
    shown 0 = "."
    shown v = show v

chunks :: Int -> [a] -> [[a]]
chunks _ [] = []
chunks n xs = take n xs : chunks n (drop n xs)

main :: IO ()
main = do
  hSetEncoding stdout utf8
  args <- getArgs
  let path = if null args then "puzzle.txt" else head args
  text <- readFile path
  let board = parseBoard text
  putStrLn "Исходное поле:"
  putStr (render board)
  case solve 0 board of
    (steps, Just answer) -> do
      putStrLn ""
      putStrLn "Решение:"
      putStr (render answer)
      putStrLn ("Рассмотрено вариантов: " ++ show steps)
    (steps, Nothing) -> do
      putStrLn ""
      putStrLn ("Решения нет, рассмотрено вариантов: " ++ show steps)
