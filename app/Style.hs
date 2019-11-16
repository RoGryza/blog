module Style
  ( index
  )
where

import Clay
import qualified Clay.Media as Media

index :: Css
index = do
  body ? do
    fontFamily ["Palatino Linotype", "Book Antiqua", "Palatino"] [serif]
    smallPadding

  a ? do
    color "#000"
    visited & color "#525"
    hover & color "#444"

  ".title" ? do
    fontFamily ["Courier New", "Courier"] [monospace]
    fontSize $ em 3
    a ? color "#000"
    display block
    largeMarginBottom

  header ? do
    largeMarginBottom
    textAlign center

    li ? display inlineBlock
    (".main-nav-links" <> ".main-nav-icons") ? do
      qMedium $ display inlineBlock
      a ? do
        display inlineBlock
        position relative
        zIndex 1
        paddingTop (em 0.5)
        qMedium $ do
          fontSize (em 1.8)
          marginRight (em 0.6)
    ".main-nav-icons" ? do
      largeMarginVertical
      a ? do
        marginLeft (em 1)
        marginRight (em 1)
        qMedium $ do
          marginLeft (em 0.5)
          marginRight (em 0.5)
        img ? do
          width (em 3)
          height (em 3)
          qMedium $ do
            width (em 1.5)
            height (em 1.5)

  footer ? do
    largeMarginTop
    fontSize (em 0.8)

  main_ ? do
    marginLeft auto
    marginRight auto
    width (em 36)
    maxWidth (pct 100)
    fontSize (px 16)
    qMedium $ fontSize (px 18)
    lineHeight (unitless 1.5)

    h1 ? do
      fontSize (em 3)
      fontWeight bold

    h2 ? do
      fontSize (em 2.5)
      fontWeight bold

  ".meta" ? do
    fontSize (em 0.8)
    largeMarginBottom

  (".summary" <> ".content") ? do
    backgroundColor "#ddd"
    smallPadding
    largeMarginBottom
    ul ? listStyleType disc
    ol ? listStyleType decimal
    (ul <> ol) ? paddingLeft (px 15)
    qMedium $ (ul <> ol) ? paddingLeft (px 40)
  where qMedium = query Media.screen [Media.minWidth (px 720)]

data Breakpoint = Sm | Md
  deriving (Enum, Bounded)

queryFor :: Breakpoint -> Css -> Css
queryFor Sm = Prelude.id
queryFor Md = query Media.screen [Media.minWidth (px 720)]

responsive :: (Breakpoint -> a) -> (a -> Css) -> Css
responsive prop st = mapM_ bpSheet [minBound ..] where bpSheet bp = queryFor bp $ st (prop bp)

largeMarginTop :: Css
largeMarginTop = responsive largeMarginLength marginTop

largeMarginBottom :: Css
largeMarginBottom = responsive largeMarginLength marginBottom

largeMarginVertical :: Css
largeMarginVertical = responsive largeMarginLength marginVertical

marginVertical :: Size a -> Css
marginVertical sz = marginTop sz >> marginBottom sz

largeMarginLength :: Breakpoint -> Size LengthUnit
largeMarginLength Sm = px 15
largeMarginLength Md = px 30

smallPadding :: Css
smallPadding = responsive smallPaddingLength $ \sz -> padding sz sz sz sz

smallPaddingLength :: Breakpoint -> Size LengthUnit
smallPaddingLength Sm = px 5
smallPaddingLength Md = px 15
