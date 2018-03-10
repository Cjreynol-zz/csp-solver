module Sudoku(
    SudokuBoard,
    updateBoard,
    initializeBoard,
    validBoard,
    solvedBoard
    ) where


import qualified Data.List as List (sortBy)
import Data.Ord (comparing)
import Data.Sequence as Seq
import qualified Data.Set as Set

data SudokuDigit =  Blank | One | Two | 
                    Three | Four | Five | 
                    Six | Seven | Eight | Nine
                    deriving (Eq, Ord)

data SudokuBoard = Board (Seq (Seq SudokuDigit))

type BoardPosition = (Int, Int)

emptyBoard :: SudokuBoard
emptyBoard = Board (Seq.replicate 9 $ Seq.replicate 9 Blank)

updateBoard :: BoardPosition -> SudokuDigit -> SudokuBoard -> SudokuBoard
updateBoard (r,c) digit (Board board) = Board (adjust' (update c digit) r board)

getDigit :: BoardPosition -> SudokuBoard -> SudokuDigit
getDigit (r,c) (Board board) = index (index board r) c

initializeBoard :: [(BoardPosition, SudokuDigit)] -> SudokuBoard
initializeBoard updates = foldr helper emptyBoard updates
    where 
        helper :: (BoardPosition, SudokuDigit) -> SudokuBoard -> SudokuBoard
        helper (pos,digit) board = updateBoard pos digit board

getRow :: Int -> SudokuBoard -> Seq SudokuDigit
getRow n (Board board) = index board n

getCol :: Int -> SudokuBoard -> Seq SudokuDigit
getCol n (Board board) = fmap (\x -> index x n) board

getCage :: Int -> SudokuBoard -> Seq SudokuDigit
getCage n board = fromList $ map (\z -> getDigit z board) [(x,y) | x <- [startr..endr], y <- [startc..endc]]
    where
        startr = (div n 3) * 3
        startc = (mod n 3) * 3
        endr = startr + 2
        endc = startc + 2

cagePosFromBoardPos :: BoardPosition -> Int
cagePosFromBoardPos (r,c) = (div r 3) * 3 + (mod c 3)

getAllRelatedDigits :: BoardPosition -> SudokuBoard -> Seq SudokuDigit
getAllRelatedDigits pos@(r,c) board = (getRow r board) >< (getCol c board) >< (getCage (cagePosFromBoardPos pos) board)

getRowPositions :: Int -> [BoardPosition]
getRowPositions n = [(r,c) | r <- [n], c <- [0..8]]

getColPositions :: Int -> [BoardPosition]
getColPositions n = [(r,c) | r <- [0..8], c <- [n]]

getCagePositions :: Int -> [BoardPosition]
getCagePositions n = [(x,y) | x <- [startr..endr], y <- [startc..endc]]
    where
        startr = (div n 3) * 3
        startc = (mod n 3) * 3
        endr = startr + 2
        endc = startc + 2

getAllRelatedPositions :: BoardPosition -> [BoardPosition]
getAllRelatedPositions pos@(r,c) = (getRowPositions r) ++ (getColPositions c) ++ (getCagePositions (cagePosFromBoardPos pos))

checkIfSeqGen :: Bool -> Seq SudokuDigit -> Bool
checkIfSeqGen solveCheck digits = helper digits Set.empty
    where
        helper :: Seq SudokuDigit -> Set.Set SudokuDigit -> Bool
        helper (Empty) set = True
        helper (x:<|xs) set 
            | x == Blank = (not solveCheck) && helper xs set
            | not (Set.member x set) = helper xs (Set.insert x set)
            | otherwise = False

checkIfValidSeq :: Seq SudokuDigit -> Bool
checkIfValidSeq digits = checkIfSeqGen False digits

checkIfSolvedSeq :: Seq SudokuDigit -> Bool
checkIfSolvedSeq digits = checkIfSeqGen True digits

checkGen :: (Seq SudokuDigit -> Bool) -> (Int -> SudokuBoard -> Seq SudokuDigit) -> SudokuBoard -> Bool
checkGen f g board = foldr (\x y -> (f x) && y) True (map (\x -> g x board) [0..8])

validRows :: SudokuBoard -> Bool
validRows board = checkGen checkIfValidSeq getRow board

validCols :: SudokuBoard -> Bool
validCols board = checkGen checkIfValidSeq getCol board

validCages :: SudokuBoard -> Bool
validCages board = checkGen checkIfValidSeq getCage board

validBoard :: SudokuBoard -> Bool
validBoard board = (validRows board) && (validCols board) && (validCages board)

solvedRows :: SudokuBoard -> Bool
solvedRows board = checkGen checkIfSolvedSeq getRow board

solvedCols :: SudokuBoard -> Bool
solvedCols board = checkGen checkIfSolvedSeq getCol board

solvedCages :: SudokuBoard -> Bool
solvedCages board = checkGen checkIfSolvedSeq getCage board

solvedBoard :: SudokuBoard -> Bool
solvedBoard board = (solvedRows board) && (solvedCols board) && (solvedCages board)

legalValues :: BoardPosition -> SudokuBoard -> Set.Set SudokuDigit
legalValues pos@(r,c) board = foldr helper sudokuDomain (getAllRelatedDigits pos board)
    where 
        helper :: SudokuDigit -> Set.Set SudokuDigit -> Set.Set SudokuDigit
        helper digit set 
            | digit == Blank = set
            | otherwise = Set.delete digit set

minRemainingValues :: SudokuBoard -> BoardPosition
minRemainingValues board@(Board ((x :<| xs) :<| xss)) 
    | x == Blank = helper (Set.size (legalValues (0,0) board)) (0,0) (0,0) (xs <| xss)
    | otherwise = helper (-1) (0,0) (0,0) (xs <| xss)
    where 
        helper :: Int -> BoardPosition ->  BoardPosition -> Seq (Seq SudokuDigit) -> BoardPosition
        helper minVals minPos newPos (Empty) = minPos
        helper minVals minPos (r,c) ((Empty) :<| xs) = helper minVals minPos ((r+1),0) xs
        helper minVals minPos pos@(r,c) ((x :<| xs) :<| xss) 
            | x == Blank = let  newVals = Set.size (legalValues pos board) 
                                nextPos = (r,(c+1)) 
                                nextSeq = (xs <| xss) in 
                                case (minVals == (-1)) || (newVals < minVals) of
                                    True -> helper newVals pos nextPos nextSeq
                                    False -> helper minVals minPos nextPos nextSeq
            | otherwise = helper minVals minPos (r,(c+1)) (xs <| xss)

leastConstrainingValue :: BoardPosition -> SudokuBoard -> [SudokuDigit]
leastConstrainingValue pos board = map fst $ List.sortBy (comparing snd) valsCounts
    where 
        vals = Set.toList $ legalValues pos board
        relatedPositions = getAllRelatedPositions pos
        valsBoards = Prelude.zip vals $ map (\x -> updateBoard pos x board) vals
        valsCounts = Prelude.zip vals $ map ((\b -> sum (map (\p -> Set.size (legalValues p b)) relatedPositions)) . snd) valsBoards

sudokuDomain :: Set.Set SudokuDigit
sudokuDomain = Set.fromList [One, Two, Three, Four, Five, Six, Seven, Eight, Nine]

{-
-- Testing helpers
-}

testBoard = initializeBoard [((0,0),One), ((0,1),Two), ((1,0), Three), ((0,8), Nine)]
testBoard2 = initializeBoard [((0,0),One), ((0,1),Two), ((1,0), Three), ((0,2), Four), ((1,1), Five), ((0,8), Nine)]


{-
-- Typeclass Instances
-}

instance Show SudokuDigit where
    show (Blank) = " "
    show (One) = "1"
    show (Two) = "2"
    show (Three) = "3"
    show (Four) = "4"
    show (Five) = "5"
    show (Six) = "6"
    show (Seven) = "7"
    show (Eight) = "8"
    show (Nine) = "9"

instance Show SudokuBoard where
    show = boardShow

boardShow :: SudokuBoard -> String
boardShow (Board Empty) = ""
boardShow (Board (x :<| Empty)) = rowShow x
boardShow (Board (x :<| xs)) = rowShow x ++ "\n" ++ boardShow (Board xs)

rowShow :: Seq SudokuDigit -> String
rowShow (Empty) = ""
rowShow (x :<| Empty) = show x
rowShow (x :<| xs) = show x ++ " | " ++ rowShow xs

