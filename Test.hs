{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes       #-}

module Main
    where

-- do a quick test for Darcs:

import System.Directory.Tree
import Control.Applicative
import qualified Data.Foldable as F
-- import System.Directory
import System.Process
import System.IO.Error(ioeGetErrorType,isPermissionErrorType)
import Control.Monad(void)
import Data.List(isInfixOf)

import System.Directory.OsPath
import System.OsPath
import System.File.OsPath
import System.IO (IOMode(..), Handle, utf8)
import Prelude hiding (readFile, writeFile)
import qualified Data.ByteString.Lazy as BL


testDir :: OsPath
testDir = [osp|/tmp/TESTDIR-LKJHBAE|]

main :: IO ()
main = do
    putStrLn "-- The following tests will either fail with an error "
    putStrLn "-- message or with an 'undefined' error"
    -- write our testing directory structure to disk. We include Failed
    -- constructors which should be discarded:
    _:/written <- writeDirectory testTree
    putStrLn "OK"


    if (fmap (const ()) (filterDir (not . failed) $dirTree testTree)) ==
                                  filterDir (not . failed) written
       then return ()
       else error "writeDirectory returned a tree that didn't match"
    putStrLn "OK"

    -- make file farthest to the right unreadable:
    (Dir _ [_,_,Dir [osp|C|] [_,_,File [osp|G|] p_unreadable]]) <- sortDir . dirTree <$> build testDir
    setPermissions p_unreadable emptyPermissions{readable   = False,
                                                   writable   = True,
                                                   executable = True,
                                                   searchable = True}
    putStrLn "OK"


    -- read with lazy and standard functions, compare for equality. Also test that our crazy
    -- operator works correctly inline with <$>:
    tL <- readDirectoryWithL readFile testDir
    t@(_:/Dir _ [_,_,Dir [osp|C|] [unreadable_constr,_,_]]) <- sortDir </$> id <$> readDirectory testDir
    if  t == tL  then return () else error "lazy read  /=  standard read"
    putStrLn "OK"

    -- make sure the unreadable file left the correct error type in a Failed:
    if isPermissionErrorType $ ioeGetErrorType $ err unreadable_constr
       then return ()
       else error "wrong error type for Failed file read"
    putStrLn "OK"


    -- run lazy fold, concating file contents. compare for equality:
    tL_again <- sortDir </$> readDirectoryWithL readFile testDir
    let tL_concated = F.concat $ dirTree tL_again
    if tL_concated == (BL.pack [osp|abcdef|]) then return () else error "foldable broke"
    putStrLn "OK"

     -- get a lazy DirTree at root directory with lazy Directory traversal:
    putStrLn "-- If lazy IO is not working, we should be stalled right now"
    putStrLn "-- as we try to read in the whole root directory tree."
    putStrLn "-- Go ahead and press CTRL-C if you've read this far"
    mapM_ putStr =<< (map name . contents . dirTree) <$> readDirectoryWithL readFile [osp|/|]
    putStrLn "\nOK"


    let undefinedOrdFailed = Failed undefined undefined :: DirTree Char
        undefinedOrdDir = Dir undefined undefined :: DirTree Char
        undefinedOrdFile = File undefined undefined :: DirTree Char
        -- simple equality and sorting
    if Dir [osp|d|] [File [osp|b|] [osp|b|],File [osp|a|] [osp|a|]] == Dir [osp|d|] [File [osp|a|] [osp|a|], File [osp|b|] [osp|b|]] &&
        -- recursive sort order, enforces non-recursive sorting of Dirs
       Dir [osp|d|] [Dir [osp|b|] undefined,File [osp|a|] [osp|a|]] /= Dir [osp|d|] [File [osp|a|] [osp|a|], Dir [osp|c|] undefined] &&
        -- check ordering of constructors:
       undefinedOrdFailed < undefinedOrdDir  &&
       undefinedOrdDir < undefinedOrdFile    &&
        -- check ordering by dir contents list length:
       Dir [osp|d|] [File [osp|b|] [osp|b|],File [osp|a|] [osp|a|]] > Dir [osp|d|] [File [osp|a|] [osp|a|]] &&
        -- recursive ordering on contents:
       Dir [osp|d|] [File [osp|b|] [osp|b|], Dir [osp|c|] [File [osp|a|] [osp|b|]]] > Dir [osp|d|] [File [osp|b|] [osp|b|], Dir [osp|c|] [File [osp|a|] [osp|a|]]]
        then putStrLn "OK"
        else error "Ord/Eq instance is messed up"

    if Dir [osp|d|] [File [osp|b|] [osp|b|],File [osp|a|] [osp|a|]] `equalShape` Dir [osp|d|] [File [osp|a|] undefined, File [osp|b|] undefined]
        then putStrLn "OK"
        else error "equalShape or comparinghape functions broken"

    -- clean up by removing the directory:
    void $ system $ "rm -r " ++ testDir
    putStrLn "SUCCESS"

    -- Test showTree
    -- check that showTree produces # of lines equal to length of tree, minus Failed
    let testTreeNonFailed = filterDir notFailed (dirTree testTree)
                                where notFailed (Failed _ _) = False
                                      notFailed _ = True
    let testTreeNonFailedEntryNum = length $ flattenDir testTreeNonFailed
    let testTreeStr = showTree $ dirTree testTree
    let testTreeEntryNum = length $ lines testTreeStr
    if testTreeEntryNum == testTreeNonFailedEntryNum
        then putStrLn "SUCCESS"
        else error $ "Test tree has " <> (show testTreeNonFailedEntryNum)
                      <> "non-failed entries, but tree string has "
                      <> (show testTreeEntryNum)
    -- check that showTree has the name of every file or dir in its output
    let allTreeNames = name <$> (flattenDir testTreeNonFailed)
    if all (\n -> isInfixOf n testTreeStr) allTreeNames
        then putStrLn "SUCCESS"
        else error "Could not find all names from test tree within showTree output"
    -- check that showTreeFormatted produces exactly the same result as showTree
    -- if the format function just takes the name
    let nameFormatF x = name x
    let nameFormatTreeStr = showTreeFormatted nameFormatF $ dirTree testTree
    if nameFormatTreeStr == testTreeStr
        then putStrLn "SUCCESS"
        else error $ "Test tree is " <> testTreeStr
                      <> ", but nameFormatTreeStr is "
                      <> nameFormatTreeStr
    -- Have all dirs format to just "DIR" and check that we have the right number
    -- in the string
    let dirsOnlyTestStr = showTreeFormatted dirF $ dirTree testTree
                            where dirF (Dir _ _) = [osp|DIR|]
                                  dirF x = name x
    let testTreeDirsOnly = filterDir isDir (dirTree testTree)
                            where isDir (Dir _ _) = True
                                  isDir _ = False
    let testTreeDirsOnlyEntryNum = length $ flattenDir testTreeDirsOnly
    let dirsInStringCount = length $ filter (isInfixOf [osp|DIR|]) (words dirsOnlyTestStr)
    if dirsInStringCount == testTreeDirsOnlyEntryNum
        then putStrLn "SUCCESS"
        else error $ "Test tree has " <> (show testTreeDirsOnlyEntryNum)
                      <> "directories, but tree string " <> dirsOnlyTestStr
                      <> "has " <> (show dirsInStringCount)

testTree :: AnchoredDirTree BL.ByteString
testTree = [osp|""|] :/ Dir testDir [dA , dB , dC , Failed [osp|FAAAIIILL|] undefined]
    where dA = Dir [osp|A|] [dA1 , dA2 , Failed [osp|FAIL|] undefined]
          dA1    = Dir [osp|A1|] [File [osp|A|] [osp|a|], File [osp|B|] [osp|b|]]
          dA2    = Dir [osp|A2|] [File [osp|C|] [osp|c|]]
          dB = Dir [osp|B|] [File [osp|D|] [osp|d|]]
          dC = Dir [osp|C|] [File [osp|E|] [osp|e|], File [osp|F|] [osp|f|], File [osp|G|] [osp|g|]]

