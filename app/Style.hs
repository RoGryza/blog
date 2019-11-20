module Style
  ( index
  )
where

import Clay
import qualified Clay.Media as Media
import Prelude hiding ((**))

index :: Css
index = do
  body ? do
    fontFamily ["Palantino Linotype", "Book Antiqua", "Palantino"] [serif]
    marginLeft auto
    marginRight auto
    width (em 40)
    maxWidth (pct 100)

  a ? do
    color "#000"
    visited & color "#525"
    hover & color "#444"

  ".title" ? do
    fontFamily ["Courier New", "Courier"] [monospace]
    fontSize $ em 3
    a ? color "#000"

  header ? do
    textAlign center
    nav ? do
      li ? display inlineBlock
      a ? do
        display inlineBlock
        position relative
        zIndex 1

  footer ? smallFont

  main_ ? do
    boxSizing borderBox
    width (pct 100)
    maxWidth (pct 100)
    lineHeight $ unitless 1.5

    (h1 <> h2 <> h3 <> h4 <> h5 <> h6) ? fontWeight bold
    h1 ? do
      textAlign center
      fontSize (em 3)
    h2 ? fontSize (em 2)

    ul ? listStyleType disc
    ol ? listStyleType decimal

  ".meta" ? smallFont

  (".summary" <> ".content") ? backgroundColor "#ddd"

  responsive Sm
  query Media.screen [Media.minWidth (px 720)] $ do
    responsive Md
    (main_ <> footer) ? do
      paddingLeft (em 2)
      paddingRight (em 2)
    (header ** nav ** ul) ? display inlineBlock
  where smallFont = fontSize (em 0.8)

responsive :: Breakpoint -> Css
responsive bp = do
  body ? do
    smallPadding
    defaultFontSize

  header ? marginBottom largeMarginLen
  footer ? marginTop largeMarginLen

  (".summary" <> ".content") ? do
    smallPadding
    marginBottom largeMarginLen
    (ul <> ol) ? do
      paddingLeft $ case bp of
        Sm -> px 15
        Md -> px 40
 where
  largeMarginLen = case bp of
    Sm -> px 20
    Md -> px 30
  smallPadding =
    let
      len = case bp of
        Sm -> px 5
        Md -> px 15
    in padding len len len len
  defaultFontSize =
    let
      sz = case bp of
        Sm -> px 16
        Md -> px 18
    in fontSize sz

data Breakpoint = Sm | Md
