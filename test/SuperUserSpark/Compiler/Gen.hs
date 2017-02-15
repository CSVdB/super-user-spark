{-# OPTIONS_GHC -Wno-orphans #-}

module SuperUserSpark.Compiler.Gen where

import TestImport

import SuperUserSpark.Compiler.Types
import SuperUserSpark.Language.Gen ()
import SuperUserSpark.PreCompiler.Gen ()

instance GenUnchecked CompileAssignment

instance GenValid CompileAssignment

instance Arbitrary CompileAssignment where
    arbitrary = genValid

instance GenUnchecked StrongCardFileReference

instance GenValid StrongCardFileReference

instance Arbitrary StrongCardFileReference where
    arbitrary = genValid

instance GenUnchecked CompileSettings

instance GenValid CompileSettings

instance Arbitrary CompileSettings where
    arbitrary = genValid

instance GenUnchecked Deployment where
    genUnchecked = Put <$> genUnchecked <*> genUnchecked

instance GenValid Deployment

instance Arbitrary Deployment where
    arbitrary = genValid

instance GenUnchecked a =>
         GenUnchecked (DeploymentDirections a)

instance GenValid a =>
         GenValid (DeploymentDirections a) where
    genValid = Directions <$> genValid <*> genValid


instance GenUnchecked PrefixPart

instance GenValid PrefixPart

instance Arbitrary PrefixPart where
    arbitrary = genValid

instance GenUnchecked CompilerState

instance GenValid CompilerState

instance Arbitrary CompilerState where
    arbitrary = genValid

instance GenUnchecked CompileError where
    genUnchecked =
        oneof
            [ PreCompileErrors <$> genUnchecked
            , DuringCompilationError <$> genUnchecked
            ]

instance GenValid CompileError

instance Arbitrary CompileError where
    arbitrary = genValid
