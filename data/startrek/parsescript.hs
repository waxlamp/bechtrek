import Control.Monad
import Data.Bechdel
import Data.Bechdel.Util
import Data.Functor
import Data.List
import Data.List.Split
import Data.String.Utils
import System.Environment
import System.Exit
import System.IO
import Text.XML.HXT.Core hiding (when)
import Text.HandsomeSoup
import Text.ParserCombinators.Parsec

-- Parse a script line from a line of text.
parseRawLine :: String -> Either ParseError ScriptLine
parseRawLine s = parse parser s s
  where
    parser = try stagedirParser <|> try sceneParser <|> try lineParser

    stagedirParser = do
        char '('
        text <- manyTill anyChar (try $ lookAhead (char ')' >> eof))
        return $ StageDirection text

    sceneParser = do
        text <- between (char '[') (char ']') (many $ noneOf "[]")
        return $ Scene text

    lineParser = do
        role <- parseRawRole
        char ':'
        spaces
        line <- many anyChar
        return $ Line role line

    parseRawRole = do
        name <- many letter
        spaces
        note <- optionMaybe $ between (char '[') (char ']') (many $ noneOf "[]")
        return $ Role name Nothing note

-- Parse HTML text.
parseHTML = readString [withParseHTML yes, withWarnings no]

-- Extract all appropriate text nodes comprising script.
extractScriptText html = runX $ html >>> css "table p font" //> getText

-- Convenience function.
readHTMLScript = extractScriptText . parseHTML

report :: Either ParseError ScriptLine -> IO Bool
report (Left parseError) = do
    hPutStrLn stderr "ERROR-------"
    hPutStrLn stderr $ show parseError
    return False
report (Right result) = do
    putStrLn $ format result
    return True

-- Main function: open the file, read its contents, parse into ScriptLines, and
-- spit them back onto stdout.
main :: IO ()
main = do
    -- Open the file, read its contents, and parse out the script lines from the
    -- HTML.
    hSetEncoding stdin latin1
    script <- readHTMLScript <$> getContents

    -- Extract the appropriate tags from the text.
    scriptLines <- map parseRawLine . filter (not . null) . map (strip . unnewline) <$> script

    -- Print out the script in standard format.
    good <- mapM report scriptLines
    if all (== True) good
        then exitSuccess
        else exitFailure
