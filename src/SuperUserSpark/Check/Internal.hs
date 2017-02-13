module SuperUserSpark.Check.Internal where

import Import hiding ((</>))

import qualified Data.ByteString.Char8 as SBC
import qualified Data.ByteString.Lazy as LB
import Data.Hashable
import Data.Maybe (catMaybes)
import System.Directory (getDirectoryContents)
import System.Exit (ExitCode(..))
import System.FilePath ((</>))
import System.Posix.Files
       (fileExist, getSymbolicLinkStatus, isBlockDevice,
        isCharacterDevice, isDirectory, isNamedPipe, isRegularFile,
        isSocket, isSymbolicLink, readSymbolicLink)
import System.Process (readProcess, system)

import SuperUserSpark.Bake.Types
import SuperUserSpark.Check.Types
import SuperUserSpark.Compiler.Types
import SuperUserSpark.Constants
import SuperUserSpark.CoreTypes

checkDeployment :: DiagnosedDeployment -> DeploymentCheckResult
checkDeployment (Diagnosed (Directions [] (D dst _ _)) _) =
    ImpossibleDeployment
        [unwords ["No source for deployment with destination", toPath dst]]
checkDeployment (Diagnosed (Directions srcs dst) kind) =
    bestResult $ map (\src -> checkSingle src dst kind) srcs

bestResult :: [CheckResult] -> DeploymentCheckResult
bestResult cs
    | all impossible cs = ImpossibleDeployment $ map (\(Impossible s) -> s) cs
    | otherwise
        -- Will not be empty as per line above
     =
        case head $ dropWhile impossible cs of
            AlreadyDone -> DeploymentDone
            Ready i -> ReadyToDeploy i
            Dirty s i c -> DirtySituation s i c
            Impossible _ -> error "Cannot be the case"

impossible :: CheckResult -> Bool
impossible (Impossible _) = True
impossible _ = False

impossibleDeployment :: DeploymentCheckResult -> Bool
impossibleDeployment (ImpossibleDeployment _) = True
impossibleDeployment _ = False

dirtyDeployment :: DeploymentCheckResult -> Bool
dirtyDeployment (DirtySituation _ _ _) = True
dirtyDeployment _ = False

deploymentReadyToDeploy :: DeploymentCheckResult -> Bool
deploymentReadyToDeploy (ReadyToDeploy _) = True
deploymentReadyToDeploy _ = False

deploymentIsDone :: DeploymentCheckResult -> Bool
deploymentIsDone DeploymentDone = True
deploymentIsDone _ = False

-- | Check a single (@source@, @destination@, @kind@) triple.
checkSingle :: DiagnosedFp -> DiagnosedFp -> DeploymentKind -> CheckResult
checkSingle (D src srcd srch) (D dst dstd dsth) kind =
    case (srcd, dstd, kind) of
        (IsFile, Nonexistent, _) -> ready
        (IsFile, IsFile, LinkDeployment) ->
            e
                [ "Both the source:"
                , toPath src
                , "and the destination:"
                , toPath dst
                , "are files for a link deployment."
                ]
        (IsFile, IsFile, CopyDeployment) ->
            if srch == dsth
                then AlreadyDone
                else e
                         [ "Both the source:"
                         , toPath src
                         , "and the destination:"
                         , toPath dst
                         , "are files for a copy deployment, but they are not equal."
                         ]
        (IsFile, IsDirectory, _) ->
            e
                [ "The source: "
                , toPath src
                , "is a file but the destination:"
                , toPath dst
                , "is a directory."
                ]
        (IsFile, IsLinkTo l, LinkDeployment) ->
            if l == src
                then AlreadyDone
                else e
                         [ "The source:"
                         , toPath src
                         , "is a file and the destination:"
                         , toPath dst
                         , "is a link for a link deployment but the destination does not point to the source. Instead it points to:"
                         , toPath l ++ "."
                         ]
        (IsFile, IsLinkTo _, CopyDeployment) ->
            e
                [ "The source:"
                , toPath src
                , "is a file and the destination:"
                , toPath dst
                , "is a link for a copy deployment."
                ]
        (IsDirectory, Nonexistent, _) -> ready
        (IsDirectory, IsFile, _) ->
            e
                [ "The source:"
                , toPath src
                , "is a directory and the destination:"
                , toPath dst
                , "is a file."
                ]
        (IsDirectory, IsDirectory, CopyDeployment) ->
            if srch == dsth
                then AlreadyDone
                else e
                         [ "The source:"
                         , toPath src
                         , "and destination:"
                         , toPath dst
                         , "are directories for a copy deployment, but they are not equal."
                         ]
        (IsDirectory, IsDirectory, LinkDeployment) ->
            e
                [ "The source:"
                , toPath src
                , "and the destination:"
                , toPath dst
                , "are directories for a link deployment."
                ]
        (IsDirectory, IsLinkTo l, LinkDeployment) ->
            if l == src
                then AlreadyDone
                else e
                         [ "The source:"
                         , toPath src
                         , "is a directory and the destination:"
                         , toPath dst
                         , "is a link for a link deployment but the destination does not point to the source. Instead it points to:"
                         , toPath l ++ "."
                         ]
        (IsDirectory, IsLinkTo _, CopyDeployment) ->
            e
                [ "The source:"
                , toPath src
                , "is a directory and the destination:"
                , toPath dst
                , "is a link for a copy deployment."
                ]
        (Nonexistent, _, _) -> i ["The source:", toPath src, "does not exist."]
        (IsLinkTo _, _, _) -> i ["The source:", toPath src, "is a link."]
        (IsWeird, IsWeird, _) ->
            i
                [ "Both the source:"
                , toPath src
                , "and the destination:"
                , toPath dst
                , "are weird."
                ]
        (IsWeird, _, _) -> i ["The source:", toPath src, "is weird."]
        (_, IsWeird, _) -> i ["The destination:", toPath dst, "is weird."]
  where
    ins = Instruction src dst kind
    ready = Ready ins
    i = Impossible . unlines
    e s = Dirty (unlines s) ins cins
    cins =
        case dstd of
            IsFile -> CleanFile dst
            IsLinkTo _ -> CleanLink dst
            IsDirectory -> CleanDirectory dst
            _ -> error "should not occur"

diagnoseDeployment :: BakedDeployment -> IO DiagnosedDeployment
diagnoseDeployment (BakedDeployment bds kind) = do
    ddirs <- diagnoseDirs bds
    return $ Diagnosed ddirs kind

diagnoseDirs
    :: DeploymentDirections AbsP AbsP
    -> IO (DeploymentDirections DiagnosedFp DiagnosedFp)
diagnoseDirs (Directions srcs dst) =
    Directions <$> mapM diagnose srcs <*> diagnose dst

diagnose :: AbsP -> IO DiagnosedFp
diagnose fp = do
    d <- diagnoseFp fp
    hash <- hashFilePath fp
    return $ D fp d hash

diagnoseFp :: AbsP -> IO Diagnostics
diagnoseFp ap = do
    let fp = toPath ap
    e <- fileExist fp
    if e
        then do
            s <- getSymbolicLinkStatus fp
            if isBlockDevice s ||
               isCharacterDevice s || isSocket s || isNamedPipe s
                then return IsWeird
                else do
                    if isSymbolicLink s
                        then do
                            point <- readSymbolicLink fp
                            apoint <- AbsP <$> parseAbsFile point
                            return $ IsLinkTo apoint
                        else if isDirectory s
                                 then return IsDirectory
                                 else if isRegularFile s
                                          then return IsFile
                                          else error $
                                               "File " ++
                                               fp ++
                                               " was neither a block device, a character device, a socket, a named pipe, a symbolic link, a directory or a regular file"
        else do
            es <- system $ unwords ["test", "-L", fp]
            case es of
                ExitSuccess
                -- Need to do a manual call because readSymbolicLink fails for nonexistent destinations
                 -> do
                    point <- readProcess "readlink" [fp] ""
                    apoint <- AbsP <$> parseAbsFile (init point) -- remove newline
                    return $ IsLinkTo apoint
                ExitFailure _ -> return Nonexistent

-- | Hash a filepath so that two filepaths with the same contents have the same hash
hashFilePath :: AbsP -> IO HashDigest
hashFilePath fp = do
    d <- diagnoseFp fp
    case d of
        IsFile -> hashFile fp
        IsDirectory -> hashDirectory fp
        IsLinkTo _ -> return $ HashDigest $ hash ()
        IsWeird -> return $ HashDigest $ hash ()
        Nonexistent -> return $ HashDigest $ hash ()

hashFile :: AbsP -> IO HashDigest
hashFile fp = (HashDigest . hash) <$> LB.readFile (toPath fp)

hashDirectory :: AbsP -> IO HashDigest
hashDirectory fp = do
    tdir <- parseAbsDir (toPath fp)
    walkDirAccum Nothing writer tdir
  where
    writer _ subdirs files = do
        hashes <- mapM (hashFile . AbsP) files
        pure $ HashDigest $ hash hashes

formatDeploymentChecks :: [(BakedDeployment, DeploymentCheckResult)] -> String
formatDeploymentChecks dss =
    if null output
        then "Deployment is done already."
        else unlines output ++
             if all (impossibleDeployment . snd) dss
                 then "Deployment is impossible."
                 else "Deployment is possible."
  where
    output = catMaybes $ map formatDeploymentCheck dss

formatDeploymentCheck :: (BakedDeployment, DeploymentCheckResult)
                      -> Maybe String
formatDeploymentCheck (_, (ReadyToDeploy is)) =
    Just $ "READY: " ++ formatInstruction is
formatDeploymentCheck (_, DeploymentDone) = Nothing
formatDeploymentCheck (d, ImpossibleDeployment ds) =
    Just $
    concat
        [ "IMPOSSIBLE: "
        , toPath $ directionDestination $ bakedDirections d
        , " cannot be deployed:\n"
        , unlines ds
        , "\n"
        ]
formatDeploymentCheck (d, (DirtySituation str is c)) =
    Just $
    concat
        [ "DIRTY: "
        , toPath $ directionDestination $ bakedDirections d
        , "\n"
        , str
        , "planned: "
        , formatInstruction is
        , "\n"
        , "cleanup needed:\n"
        , formatCleanupInstruction c
        , "\n"
        ]

formatInstruction :: Instruction -> String
formatInstruction (Instruction src dst k) =
    unwords $ [toPath src, kindSymbol k, toPath dst]
  where
    kindSymbol LinkDeployment = linkKindSymbol
    kindSymbol CopyDeployment = copyKindSymbol

formatCleanupInstruction :: CleanupInstruction -> String
formatCleanupInstruction (CleanFile fp) = "remove file " ++ toPath fp
formatCleanupInstruction (CleanDirectory dir) =
    "remove directory " ++ toPath dir
formatCleanupInstruction (CleanLink link) = "remove link " ++ toPath link
