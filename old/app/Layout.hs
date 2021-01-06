{-# LANGUAGE NamedFieldPuns #-}
module Layout
  ( base
  , single
  , index
  , archive
  , post
  , tags
  , tagPosts
  , BaseContext(..)
  )
where

import Control.Monad
import Data.Foldable
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Maybe
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time.Format
import Text.Blaze
import qualified Text.Blaze.Html5 as H
import qualified Text.Blaze.Html5.Attributes as A
import Types

data BaseContext = BaseContext
                 { baseCtxTitle :: Text
                 , baseCtxContent :: H.Html
                 }

base :: BaseContext -> Site -> H.Html
base BaseContext { baseCtxTitle, baseCtxContent } site@Site { siteLang, siteAuthor, siteDescription }
  = (H.docTypeHtml ! A.lang (toValue siteLang)) $ do
    H.head $ do
      H.title $ toMarkup baseCtxTitle
      H.meta ! A.httpEquiv "X-UA-Compatible" ! A.content "IE=edge"
      H.meta ! A.name "viewport" ! A.content "width=device-width,initial-scale=1"
      H.meta ! A.name "description" ! A.content (toValue siteDescription)
      H.meta ! A.name "author" ! A.content (toValue siteAuthor)
      H.link ! A.rel "alternate" ! A.type_ "application/atom+xml" ! A.href "/atom.xml"
      H.link ! A.rel "stylesheet" ! A.type_ "text/css" ! A.href "/css/reset.css"
      H.link ! A.rel "stylesheet" ! A.type_ "text/css" ! A.href "/css/index.css"
    H.body $ do
      header site
      baseCtxContent
      footer site

header :: Site -> H.Html
header Site { siteTitle, siteSocial } = H.header $ do
  H.span ! A.class_ "title" $ H.a ! A.href "/" $ H.toHtml siteTitle
  H.nav $ do
    H.ul ! A.class_ "main-nav-links" $ sequenceA_
      [ H.li $ H.a ! A.href url $ name
      | (name, url) <-
        [ ("/now", "/now")
        , ("Home", "/")
        , ("Archive", "/posts")
        , ("Tags", "/tags")
        , ("About Me", "/about")
        ]
      ]
    H.ul ! A.class_ "main-nav-social" $ do
      sequenceA_
        [ H.li $ H.a ! A.href (toValue url) $ toMarkup name | SocialLink name url <- siteSocial ]
      H.li $ H.a ! A.rel "alternate" ! A.type_ "application/atom+xml" ! A.href "/atom.xml" $ "rss"

footer :: Site -> H.Html
footer Site { siteAuthor } = H.footer $ do
  H.div $ do
    "Created with "
    H.a ! A.href "https://github.com/ChrisPenner/slick" $ "slick"
  H.a
    ! A.rel "license"
    ! A.href "http://creativecommons.org/licenses/by-sa/4.0/"
    $ H.img
    ! A.alt "Creative Commons License"
    ! A.style "border-width:0"
    ! A.src "https://i.creativecommons.org/l/by-sa/4.0/80x15.png"
  H.br
  "This work by "
  H.a
    ! A.href "/about"
    ! customAttribute "xmlns:cc" "http://creativecommons.org/ns#"
    ! customAttribute "property" "cc:atributionName"
    ! A.rel "cc:atributionURL"
    $ H.toHtml siteAuthor
  " is licensed under a "
  H.a
    ! A.rel "license"
    ! A.href "http://creativecommons.org/licenses/by-sa/4.0/"
    $ "Creative Commons Attribution-ShareAlike 4.0 International License"

single :: Page -> BaseContext
single Page { pageTitle, pageContent } = BaseContext pageTitle $ H.main $ H.article $ do
  H.h1 $ toMarkup pageTitle
  H.div ! A.class_ "content" $ preEscapedToMarkup pageContent

index :: Site -> Paginated Post -> BaseContext
index Site { siteTitle } Paginated { paginatedIndex, paginatedTotalPages, paginatedPage, paginatedPrev, paginatedNext }
  = BaseContext siteTitle $ H.main $ do
    H.h1 $ if isNothing paginatedPrev then "Latest Posts" else "Posts"
    forM_ paginatedPage $ \p@Post { postURL, postTitle, postSummary } -> do
      H.h2 $ H.a ! A.href (toValue postURL) $ toMarkup postTitle
      postMeta p
      H.div ! A.class_ "summary" $ do
        preEscapedToMarkup postSummary
        when (postHasMore p) $ H.div $ H.a ! A.href (toValue postURL) $ "Read more..."
    H.div $ do
      case paginatedPrev of
        Just Paginated { paginatedUrl = prevUrl } ->
          H.a ! A.href (toValue prevUrl) $ "Earlier posts"
        Nothing -> return ()
      when (paginatedTotalPages > 1)
        $ toMarkup
        $ "Page "
        ++ show (paginatedIndex + 1)
        ++ " of "
        ++ show paginatedTotalPages
      case paginatedNext of
        Just Paginated { paginatedUrl = nextUrl } -> H.a ! A.href (toValue nextUrl) $ "Older posts"
        Nothing -> return ()

archive :: [Post] -> BaseContext
archive = baseArchive "All Posts"

tags :: Map Text [Post] -> BaseContext
tags postsByTag = BaseContext "Tags" $ H.main $ do
  H.h1 "Tags"
  forM_ (M.toAscList postsByTag) $ \(tag, posts) ->
    H.h2 $ H.a ! A.href (tagUrl tag) $ toMarkup $ T.unpack tag <> " (" <> show (length posts) <> ")"

tagPosts :: Text -> [Post] -> BaseContext
tagPosts tag = baseArchive ("Posts in Tag " <> tag)

baseArchive :: Text -> [Post] -> BaseContext
baseArchive title posts = BaseContext title $ H.main $ do
  H.h1 $ toMarkup title
  forM_ posts $ \p@Post { postURL, postTitle } -> do
    H.h2 $ H.a ! A.href (toValue postURL) $ toMarkup postTitle
    postMeta p

post :: Post -> BaseContext
post p@Post { postTitle, postContent } = BaseContext postTitle $ H.main $ H.article $ do
  H.h1 $ toMarkup postTitle
  postMeta p
  H.div ! A.class_ "content" $ preEscapedToMarkup postContent

postMeta :: Post -> H.Html
postMeta Post { postDate, postTags } = H.div ! A.class_ "meta" $ do
  H.time . toMarkup $ formatTime defaultTimeLocale "%d %b %Y" postDate
  forM_ postTags renderTag

renderTag :: Text -> H.Html
renderTag tag = H.a ! A.class_ "tag" ! A.href (tagUrl tag) $ toMarkup tag

tagUrl :: Text -> AttributeValue
tagUrl tag = "/tags/" <> toValue tag
