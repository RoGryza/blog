{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE TemplateHaskell #-}

module Types
  ( Page(..)
  , Site(..)
  , SocialLink(..)
  , Post(..)
  , postHasMore
  , Paginated(..)
  , paginate
  , mapPages
  , paginatedAsList
  )
where

import Data.Set (Set)
import qualified Data.Set as S
import Data.Maybe
import Data.Time.Calendar
import Data.Text (Text)
import Data.Aeson.Types
import Data.Aeson.TH
import Development.Shake.Classes
import GHC.Generics (Generic)
import Util

data Page = Page
          { pageURL :: Text
          , pagePath :: Text
          , pageTitle :: Text
          , pageContent :: Text
          }
          deriving (Generic, Show, Typeable, Binary)

$(deriveJSON jsonOpts ''Page)

data Post = Post
          { postURL :: Text
          , postPath :: Text
          , postTitle :: Text
          , postDate :: Day
          , postTags :: Set Text
          , postSummary :: Text
          , postContent :: Text
          }
          deriving (Generic, Show, Typeable)

instance Binary Post where
  put post = do
    put $ postURL post
    put $ postPath post
    put $ postTitle post
    put . toGregorian $ postDate post
    put . S.toList $ postTags post
    put $ postSummary post
    put $ postContent post
  get = Post <$> get <*> get <*> get <*> fmap (\(a,b,c) -> fromGregorian a b c) get <*> (S.fromList <$> get) <*> get <*> get

instance FromJSON Post where
  parseJSON (Object v) = Post <$>
    v .: "url" <*>
    v .: "path" <*>
    v .: "title" <*>
    v .: "date" <*>
    v .:? "tags" .!= S.empty <*>
    v .: "summary" <*>
    v .: "content"
  parseJSON invalid = prependFailure "parsing Post failed, "
    (typeMismatch "Object" invalid)

postHasMore :: Post -> Bool
postHasMore p = postSummary p /= postContent p

data SocialLink = SocialLink
                { socialName :: Text
                , socialURL :: Text
                }
                deriving (Generic, Show, Typeable, Binary)

$(deriveJSON jsonOpts ''SocialLink)

data Site = Site
          { siteBaseURL :: Text
          , siteTitle :: Text
          , siteLang :: Text
          , siteAuthor :: Text
          , siteDescription :: Text
          , siteSocial :: [SocialLink]
          }
          deriving (Generic, Show, Typeable, Binary)

$(deriveJSON jsonOpts ''Site)

data Paginated a = Paginated
                   { paginatedTotalItems :: Int
                   , paginatedTotalPages :: Int
                   , paginatedIndex :: Int
                   , paginatedPrev :: Maybe (Paginated a)
                   , paginatedNext :: Maybe (Paginated a)
                   , paginatedUrl :: Text
                   , paginatedPage :: [a]
                   }
                   deriving (Show, Typeable, Foldable, Functor)

mapPages :: (Paginated a -> b) -> Paginated a -> [b]
mapPages f p = f p : maybe [] (mapPages f) (paginatedNext p)

paginatedAsList :: Paginated a -> [Paginated a]
paginatedAsList p@Paginated { paginatedNext = n } = p : maybe [] paginatedAsList n

paginate :: (Int -> Text) -> Int -> [a] -> Paginated a
paginate mkUrl size = paginateFromPages mkUrl . splitEvery size
 where
  splitEvery _ [] = []
  splitEvery n xs = let (first, rest) = splitAt n xs in first : splitEvery n rest

paginateFromPages :: (Int -> Text) -> [[a]] -> Paginated a
paginateFromPages mkUrl pages = fromMaybe
  (Paginated totalItems totalPages 0 Nothing Nothing (mkUrl 0) [])
  (go Nothing 0 pages)
 where
  go _ _ [] = Nothing
  go prev idx (page : rest)
    | idx >= totalPages
    = Nothing
    | otherwise
    = let
        this = Just $ Paginated totalItems totalPages idx prev next (mkUrl idx) page
        next = go this (idx + 1) rest
      in this
  totalPages = length pages
  totalItems = length $ concat pages
