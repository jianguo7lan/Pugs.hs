{-# OPTIONS_GHC -fglasgow-exts #-}

{-|
    Code generation interface.

>   I sit beside the fire and think
>   of all that I have seen,
>   of meadow-flowers and butterflies
>   in summers that have been...
-}

module Pugs.CodeGen (codeGen, backends) where
import Pugs.AST
import Pugs.Pretty
import Pugs.Internals
import Pugs.CodeGen.PIL1 (genPIL1)
-- import Pugs.CodeGen.PIL2 (genPIL2, genPIL2Perl5, genPIL2JSON, genPIL2YAML)
import Pugs.CodeGen.PIR (genPIR, genPIR_YAML)
import Pugs.CodeGen.Perl5 (genPerl5)
import Pugs.CodeGen.YAML (genParseYAML, genParseHsYAML, genYAML)
import Pugs.CodeGen.Binary (genParseBinary)
import Pugs.CodeGen.JSON (genJSON)
import Pugs.Compile.Pugs (genPugs)
import Control.Exception (SomeException)
-- import Pugs.Compile.Haskell (genGHC)
-- import Pugs.CodeGen.XML (genXML)
import qualified Data.Map as Map

type Generator = FilePath -> Eval Val

generators :: Map String Generator
generators = Map.fromList $
    [ ("PIR",         genPIR)
    , ("PIR-YAML",    genPIR_YAML)
    , ("PIL1",        genPIL1)
    , ("PIL1-Perl5",  genPerl5)
    , ("PIL1-JSON",   genJSON)
    , ("PIL1-YAML",   genYAML)
--  , ("PIL2",        genPIL2)
--  , ("PIL2-Perl5",  genPIL2Perl5)
--  , ("PIL2-JSON",   genPIL2JSON)
--  , ("PIL2-YAML",   genPIL2YAML)
 -- , ("GHC",         genGHC)
    , ("Pugs",        genPugs)
    , ("Parse-YAML",  genParseYAML)
    , ("Parse-HsYAML",genParseHsYAML)
    , ("Parse-Pretty",const $ fmap (VStr . (++"\n") . pretty) (asks envBody))
    , ("Parse-Binary",genParseBinary)
--  , ("XML",         genXML)
    ]

backends :: [String]
backends = Map.keys generators

norm :: String -> String
norm = norm' . map toLower . filter isAlphaNum
    where
    norm' "ghc"    = "GHC"
    norm' "parrot" = "!PIR"
    norm' "pir"    = "PIR"
    norm' "piryaml"= "PIR-YAML"
    norm' "pil"    = "!PIL1"
    norm' "pil1"   = "PIL1"
--  norm' "pil2"   = "PIL2"
    norm' "perl5"  = "!PIL1-Perl5"
    norm' "json"   = "!PIL1-JSON"
    norm' "yaml"   = "!PIL1-YAML"
    norm' "pil1perl5"  = "PIL1-Perl5"
    norm' "pil1json"   = "PIL1-JSON"
    norm' "pil1yaml"   = "PIL1-YAML"
--  norm' "pil2perl5"  = "PIL2-Perl5"
--  norm' "pil2json"   = "PIL2-JSON"
--  norm' "pil2yaml"   = "PIL2-YAML"
    norm' "parseyaml"  = "Parse-YAML"
    norm' "parsehsyaml"= "Parse-HsYAML"
    norm' "parsepretty"= "Parse-Pretty"
    norm' "parsebinary"  = "Parse-Binary"
    norm' "pugs"   = "Pugs"
    -- norm' "xml"    = "XML"
    norm' x        = x

doLookup :: String -> IO Generator
doLookup s = do
    case norm s of
        ('!':key) -> do
            hPutStrLn stderr $ "*** The backend '" ++ s ++ "' is deprecated."
            hPutStrLn stderr $ "    Please use '" ++ key ++ "' instead."
            lookupGenerator key
        key -> lookupGenerator key
    where
    lookupGenerator :: String -> IO Generator
    lookupGenerator k = case Map.lookup k generators of
        Just g -> return g
        _      -> fail $ "Cannot find generator: " ++ k

codeGen :: String -> FilePath -> Env -> IO String
codeGen s file env = do
    gen <- catchIO (doLookup s) $ \(_ :: SomeException) -> do
        fail $ "Cannot generate code for " ++ s ++ ": " ++ file
    rv <- runEvalIO env (gen file)
    case rv of
        VStr str    -> return str
        _           -> fail (show rv)
