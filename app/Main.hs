{-# LANGUAGE NamedFieldPuns #-}
module Main where

import Control.Monad
import qualified Clay
import Data.Aeson
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import qualified Data.Set as S
import qualified Data.HashMap.Strict as HM
import Data.List
import Data.Maybe
import Data.Ord
import Data.String
import Data.Text (Text)
import Data.Text.ICU (toLower, LocaleName(..))
import Data.Text.ICU.Char
import Data.Text.ICU.Normalize
import Data.Time
import Data.Typeable
import Development.Shake
import Development.Shake.Classes
import Development.Shake.FilePath
import Development.Shake.Forward
import Slick
import Slick.Pandoc
import qualified Style as St
import Text.Blaze.Html.Renderer.Pretty
import Text.Pandoc hiding (getCurrentTime)
import Text.Pandoc.Readers.Markdown
import Text.Atom.Feed
import Text.Atom.Feed.Export
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import qualified Layout as L
import Types

-- Copied from Slick.Pandoc
unPandocM :: PandocIO a -> Action a
unPandocM p = do
  result <- liftIO $ runIO p
  either (fail . show) return result

readSite :: Action Site
readSite = cacheAction ("site.yaml" :: Text) $ do
  rawContent <- readFile' "site.yaml"
  meta <- unPandocM $ yamlToMeta def $ fromString rawContent
  convert $ flattenMeta meta

copyStatic :: FilePath -> Action ()
copyStatic outputFolder = do
  files <- getDirectoryFiles "./static" ["css//*", "icons//*"]
  void $ forP files $ \filepath ->
    copyFileChanged ("static" </> filepath) (outputFolder </> filepath)

writeCss :: FilePath -> Action ()
writeCss outputFolder =
  let cssContent = Clay.renderWith Clay.pretty [] St.index
  in writeFileChanged (outputFolder </> "css/index.css") (TL.unpack cssContent)

readContent :: (Show a, Binary a, Typeable a, FromJSON a) => FilePattern -> Action [a]
readContent pat = do
  files <- getDirectoryFiles "./content" [pat]
  forP files $ \filepath -> cacheAction ("readContent" :: Text, filepath) $ do
    rawContent <- readFile' $ "content" </> filepath
    content <- markdownToHTML . T.pack $ rawContent
    let
      (baseUrl, baseFileName) = splitFileName filepath
      slug = maybe (baseFileName -<.> "") (T.unpack . sluggify) (getStr "title" content)
      url = "/" <> T.pack (baseUrl </> slug)
      summary = fst . T.breakOn "<!--more-->" . fromMaybe "" . getStr "content" $ content
    convert $ addToObject
      [("url", String url), ("path", String $ T.pack filepath), ("summary", String summary)]
      content
 where
  getStr k (Object o) = case HM.lookup k o of
    Just (String s) -> Just s
    _ -> Nothing
  getStr _ _ = Nothing
  addToObject fields (Object o) = Object $ o <> HM.fromList fields
  addToObject _ _ = error "content is not an Object"

writeContent :: FilePath -> Site -> (a -> Text) -> (a -> L.BaseContext) -> [a] -> Action ()
writeContent outputFolder site url l as = void $ forP as $ \a -> writeFileChanged
  (outputFolder </> drop 1 (T.unpack $ url a) -<.> "html")
  (renderHtml $ L.base (l a) site)

sluggify :: Text -> Text
sluggify = toLower Current . noAccents . T.map toSlugChar
 where
  toSlugChar c = if property WhiteSpace c then '-' else c
  valid c = property POSIXAlNum c || c == '-'
  noAccents = T.filter valid . normalize NFD

postsByTag :: [Post] -> Map Text [Post]
postsByTag xs = sortOn (Down . postDate)
  <$> M.fromListWith (++) [ (t, [x]) | x <- xs, t <- S.toList $ postTags x ]

writeFeed :: FilePath -> Site -> [Post] -> Action ()
writeFeed outputFolder site posts = do
  now <- liftIO getCurrentTime
  case textFeed $ toFeed now site posts of
    Just t -> writeFileChanged (outputFolder </> "atom.xml") (TL.unpack t)
    Nothing -> fail "Failed to render atom feed"

toFeed :: UTCTime -> Site -> [Post] -> Feed
toFeed updated site@Site { siteBaseURL, siteTitle, siteAuthor, siteLang } posts =
  (nullFeed siteBaseURL (TextString siteTitle) $ fmtFeedTime updated)
    { feedAuthors =
      [nullPerson { personName = siteAuthor, personURI = Just $ siteBaseURL <> "/about" }]
    , feedGenerator = Just $ Generator
      { genURI = Just "https://github.com/ChrisPenner/slick"
      , genVersion = Just "1.0.0.0"
      , genText = "Slick"
      }
    , feedLinks =
      [ (nullLink siteBaseURL)
          { linkRel = Just . Left $ "alternate"
          , linkType = Just "text/html"
          , linkHrefLang = Just siteLang
          , linkTitle = Just siteTitle
          }
      ]
    , feedEntries = fmap (postToEntry site) posts
    }

postToEntry :: Site -> Post -> Entry
postToEntry Site { siteBaseURL, siteAuthor, siteLang } Post { postURL, postDate, postTitle, postTags, postSummary, postContent }
  = (nullEntry fullURL (TextString postTitle) (fmtFeedTime postDate))
    { entryCategories = fmap newCategory . S.toList $ postTags
    , entryAuthors =
      [nullPerson { personName = siteAuthor, personURI = Just $ siteBaseURL <> "/about" }]
    , entryLinks =
      [ (nullLink fullURL)
          { linkRel = Just . Left $ "alternate"
          , linkType = Just "text/html"
          , linkHrefLang = Just siteLang
          , linkTitle = Just postTitle
          }
      ]
    , entryPublished = Just $ fmtFeedTime postDate
    , entrySummary = Just $ TextString postSummary
    , entryContent = Just $ TextContent postContent
    }
  where fullURL = siteBaseURL <> postURL

fmtFeedTime :: FormatTime t => t -> Text
fmtFeedTime = T.pack . formatTime defaultTimeLocale "%Y-%m-%d"

main :: IO ()
main = shakeArgsForward shakeOptions $ do
  site <- readSite
  copyStatic outputFolder
  writeCss outputFolder
  pages <- readContent "*.md" :: Action [Page]
  posts <- sortOn (Down . postDate) <$> readContent "posts/*.md" :: Action [Post]
  let
    paginatedPosts = paginate postPageUrl pageSize posts
    byTag = postsByTag posts
    w = writeContent outputFolder site
  w pageURL L.single pages
  w postURL L.post posts
  w (("/tags/" <>) . fst) (uncurry L.tagPosts) (M.toAscList byTag)
  w fst snd [("/posts", L.archive posts), ("/tags", L.tags byTag)]
  w paginatedUrl (L.index site) (paginatedAsList paginatedPosts)
  writeFeed outputFolder site posts
 where
  pageSize = 10
  outputFolder = "build"
  postPageUrl 0 = "/index"
  postPageUrl n = T.pack $ "/page/" ++ show (n + 1)
