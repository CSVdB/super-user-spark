{-# OPTIONS_GHC -Wno-orphans #-}

module SuperUserSpark.Bake.Gen where

import TestImport

import SuperUserSpark.Bake.Types
import SuperUserSpark.Compiler.Gen ()

instance GenUnchecked BakeAssignment

instance GenValid BakeAssignment where
    genValid = BakeAssignment <$> genValid <*> genValid

instance GenUnchecked BakeCardReference

instance GenValid BakeCardReference

instance GenUnchecked BakeSettings

instance GenValid BakeSettings where
    genValid = BakeSettings <$> genValid <*> genValid <*> genValid

instance GenUnchecked BakeError

instance GenValid BakeError

instance GenUnchecked AbsP

instance GenValid AbsP

instance GenUnchecked ID

instance GenValid ID
