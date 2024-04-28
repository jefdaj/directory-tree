{-# LANGUAGE TemplateHaskell #-}
{-# OPTIONS_GHC -ddump-to-file #-}

import Language.Haskell.TH
import Control.Lens.TH
import System.Directory.Tree

makeLensesFor [("name","_name"),("err","_err"),("contents","_contents"),("file","_file")] ''DirTree
makeLensesFor [("anchor","_anchor"),("dirTree","_dirTree")] ''AnchoredDirTree

main :: IO ()
main = putStrLn "lenses work?"
