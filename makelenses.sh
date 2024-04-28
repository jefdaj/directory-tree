rm -f MakeLenses{,.o,.hi}
ghc -XTemplateHaskell -ddump-splices MakeLenses.hs
rm -f MakeLenses{,.o,.hi}
rm -f System/Directory/Tree.{dyn*,o,hi}
