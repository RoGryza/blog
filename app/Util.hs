module Util
  ( jsonOpts
  )
where

import Control.Arrow
import Data.Char
import Data.Aeson.TH

jsonOpts :: Options
jsonOpts = defaultOptions { fieldLabelModifier = lowerFirst . stripPrefix }
 where
  stripPrefix = dropWhile isLower
  lowerFirst = uncurry (++) . first (fmap toLower) . span isUpper
