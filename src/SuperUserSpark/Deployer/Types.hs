{-# LANGUAGE DeriveGeneric #-}

module SuperUserSpark.Deployer.Types where

import Import

import System.FilePath.Posix (takeExtension)

import SuperUserSpark.Check.Types
import SuperUserSpark.CoreTypes
import SuperUserSpark.Language.Types

data DeployAssignment = DeployAssignment
    { deployCardReference :: DeployerCardReference
    , deploySettings :: DeploySettings
    } deriving (Show, Eq, Generic)

data DeploySettings = DeploySettings
    { deploySetsReplaceLinks :: Bool
    , deploySetsReplaceFiles :: Bool
    , deploySetsReplaceDirectories :: Bool
    , deployCheckSettings :: CheckSettings
    } deriving (Show, Eq, Generic)

defaultDeploySettings :: DeploySettings
defaultDeploySettings =
    DeploySettings
    { deploySetsReplaceLinks = False
    , deploySetsReplaceFiles = False
    , deploySetsReplaceDirectories = False
    , deployCheckSettings = defaultCheckSettings
    }

data DeployerCardReference
    = DeployerCardCompiled FilePath
    | DeployerCardUncompiled CardFileReference
    deriving (Show, Eq, Generic)

instance Read DeployerCardReference where
    readsPrec _ fp =
        case length (words fp) of
            0 -> []
            1 ->
                if takeExtension fp == ".sus"
                    then [ ( DeployerCardUncompiled
                                 (CardFileReference fp Nothing)
                           , "")
                         ]
                    else [(DeployerCardCompiled fp, "")]
            2 ->
                let [f, c] = words fp
                in [ ( DeployerCardUncompiled
                           (CardFileReference f (Just $ CardNameReference c))
                     , "")
                   ]
            _ -> []

type SparkDeployer = ExceptT DeployError (ReaderT DeploySettings IO)

data DeployError
    = DeployCheckError CheckError
    | DeployError String
    deriving (Show, Eq, Generic)

data PreDeployment
    = Ready FilePath
            FilePath
            DeploymentKind
    | AlreadyDone
    | Error String
    deriving (Show, Eq, Generic)

data ID
    = Plain String
    | Var String
    deriving (Show, Eq, Generic)