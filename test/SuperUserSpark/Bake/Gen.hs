{-# OPTIONS_GHC -Wno-orphans #-}

module SuperUserSpark.Bake.Gen where

import TestImport

import SuperUserSpark.Bake.Types
import SuperUserSpark.Compiler.Gen ()

instance GenUnchecked BakeAssignment

instance GenValid BakeAssignment

instance GenUnchecked BakeCardReference

instance GenValid BakeCardReference

instance GenUnchecked BakeSettings

instance GenValid BakeSettings

instance GenUnchecked BakeError

instance GenValid BakeError

instance GenUnchecked BakedDeployment

instance GenValid BakedDeployment where
    genValid = BakedDeployment <$> genValid <*> genValid

instance GenUnchecked AbsP

instance GenValid AbsP

instance Arbitrary AbsP where
    arbitrary = genValid

instance (GenUnchecked a, GenUnchecked b) =>
         GenUnchecked (DeploymentDirections a b)

instance (GenValid a, GenValid b) =>
         GenValid (DeploymentDirections a b) where
    genValid = Directions <$> genValid <*> genValid

instance GenUnchecked ID

instance GenValid ID
