module Brite.CLI (main) where

import Brite.Dev
import Brite.DiagnosticsMarkup (toANSIDoc)
import Brite.Exception
import System.Environment
import System.Exit
import System.IO (stdout)
import Text.PrettyPrint.ANSI.Leijen

-- The main function for the Brite CLI.
main :: IO ()
main = do
  args <- getArgs
  exitWith =<< case parseArgs args of
    Right command -> do
      result <- catchEverything (execute command)
      case result of
        Left message -> displayDoc (errorMessage (toANSIDoc message)) *> return (ExitFailure 1)
        Right exitCode -> return exitCode

    Left arg -> do
      displayDoc $
        errorMessage
          (text "Unrecognized argument “" <>
           bold (text arg) <>
           text "”. See below for the correct usage.") <>
        hardline <>
        helpMessage
      return (ExitFailure 1)

-- Displays a pretty print ANSI document.
displayDoc :: Doc -> IO ()
displayDoc x = displayIO stdout (renderPretty 0.4 80 x)

{--------------------------------------------------------------------------------------------------}
{- Commands                                                                                       -}
{--------------------------------------------------------------------------------------------------}

-- A Brite command to be executed by the CLI.
data Command
  -- An empty command means the user did not specify any command line arguments. Here we print out
  -- the help message and return a failure exit code.
  = EmptyCommand

  -- If the user ran the help command then they are looking to see the help message. Here we print
  -- out the help message and exit successfully.
  | HelpCommand

  -- If the user ran the “new” command then they want to create a new Brite project in the
  -- provided directory.
  | NewCommand

  -- If the user ran the “build” command they want to build the provided file paths.
  | BuildCommand [String]

  -- If the user ran the “reset” command then we delete their cache and any generated resources.
  | ResetCommand

-- Executes a command and returns an exit code.
execute :: Command -> IO ExitCode

-- An empty command will print out the help text and exit with a failure. We exit with a failure to
-- inform other CLI tools that this is not a correct usage of the Brite CLI.
execute EmptyCommand = do
  displayDoc helpMessage
  return (ExitFailure 1)

-- Print the help message and exit successfully.
execute HelpCommand = do
  displayDoc helpMessage
  return ExitSuccess

-- TODO: Actually implement the `new` command...
execute NewCommand = do
  displayDoc (errorMessage (text "The “new” command is currently unimplemented."))
  return (ExitFailure 1)

-- TODO: Actually implement the `build` command...
execute (BuildCommand paths) =
  if null paths then do
    displayDoc (errorMessage (text "The “build” command is currently unimplemented."))
    return (ExitFailure 1)
  else do
    displayDoc (errorMessage (text "The “build” command is currently unimplemented."))
    return (ExitFailure 1)

-- TODO: Actually implement the `reset` command...
--
-- NOTE: We use the name `reset` instead of the traditional `clean` to imply this is a hard reset of
-- the programmer’s project. We’d prefer that the programmer does not run `reset` if possible since
-- that will delete their cache slowing down future builds. We’d prefer the user run `brite build`
-- to make sure all their files are rebuilt. `clean` implies that user is deleting generated
-- resources so re-generating those resources should not take more time, but in fact the resources
-- we delete when the programmer calls `brite reset` significantly improves the performance of
-- their builds.
execute ResetCommand = do
  displayDoc (errorMessage (text "The “reset” command is currently unimplemented."))
  return (ExitFailure 1)

-- Parses a list of CLI arguments and returns either a command or an error. An error could be an
-- unrecognized argument, for instance.
parseArgs :: [String] -> Either String Command
parseArgs = loop EmptyCommand
  where
    -- If we see common help flags then the user is asking for the help command.
    loop EmptyCommand ("-h" : args) = loop HelpCommand args
    loop EmptyCommand ("--help" : args) = loop HelpCommand args

    -- Parse the “new” command.
    loop EmptyCommand ("new" : args) = loop NewCommand args

    -- Parse a build command when we see the text `build`. Add every argument to our list of paths
    -- that doesn’t start with `-`. When we reach the end of our arguments reverse the list of paths
    -- since while parsing we added them in reverse.
    loop EmptyCommand ("build" : args) = loop (BuildCommand []) args
    loop (BuildCommand paths) (arg : args) | take 1 arg /= "-" = loop (BuildCommand (arg : paths)) args
    loop (BuildCommand paths) [] = Right (BuildCommand (reverse paths))

    -- Parse the “reset” command.
    loop EmptyCommand ("reset" : args) = loop ResetCommand args

    -- If no one handled this argument then we have an unexpected argument.
    loop _ (arg : _) = Left arg

    -- We successfully parsed a command! Hooray! Return it.
    loop command [] = Right command

{--------------------------------------------------------------------------------------------------}
{- Messages                                                                                       -}
{--------------------------------------------------------------------------------------------------}

-- An operational error message logged by the CLI.
errorMessage :: Doc -> Doc
errorMessage x =
  bold (red (text "Error:")) <> text " " <> x <> hardline

-- The help text for Brite. Prints a nice little box which is reminiscent of a postcard. Also allows
-- us to do clever work with alignment since we clearly have a left-hand-side.
helpMessage :: Doc
helpMessage =
  black (text "┌" <> text (replicate 78 '─') <> text "┐") <> hardline <>
  boxContent <>
  black (text "└" <> text (replicate 78 '─') <> text "┘") <> hardline
  where
    boxContent = mconcat $
      map
        (\a ->
          case a of
            Nothing -> black (text "│") <> fill 78 mempty <> black (text "│") <> hardline
            Just b -> black (text "│") <> fill 78 (text " " <> b) <> black (text "│") <> hardline) $
        [ Just $ bold (text "Brite")
        , Just $ text "A tool for product development."
        , Nothing
        , Just $ bold (text "Usage:")
        ] ++
        (map
          (\(a, b) -> Just $
            black (text "$") <>
            text " " <>
            fill 32 (text (if isDev then "brite-dev" else "brite") <> text " " <> text a) <>
            black (text "# " <> text b))
          [ ("new {name}", "Create a new Brite project.")
          , ("build", "Build the code in your project.")
          , ("build {path...}", "Build the code at these paths.")

          -- NOTE: We intentionally don’t document `brite reset` here. We don’t want programmers
          -- using `brite reset` except in dire circumstances where they absolutely need to reset
          -- their project since `brite reset` throws away their cache which slows down everything.
          -- We would prefer the user to run `brite build`.
          ])
