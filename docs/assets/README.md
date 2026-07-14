# Promotional assets

This directory contains the product previews and repository artwork used by the English and Simplified Chinese READMEs.

| File | Purpose |
| --- | --- |
| `hero-banner.png` | English README hero, 1600 × 800 |
| `hero-banner-zh.png` | Simplified Chinese README hero, 1600 × 800 |
| `github-social-preview.png` | 2:1 repository social preview, 1280 × 640 |
| `promo-background.png` | Text-free generated brand background used by the compositor |
| `widget-small.png` | Real SwiftUI Crystal Glass Small widget preview with synthetic values |
| `widget-medium.png` | Real SwiftUI Crystal Glass Medium widget preview with synthetic values |
| `theme-showcase.png` | English four-theme gallery assembled from real Medium SwiftUI previews, 1600 × 1000 |
| `theme-showcase-zh.png` | Simplified Chinese four-theme gallery, 1600 × 1000 |
| `aquarium-levels.png` | English Aquarium state strip at 84%, 34%, 15%, and 0%, 1600 × 680 |
| `aquarium-levels-zh.png` | Simplified Chinese Aquarium state strip, 1600 × 680 |
| `github-social-preview-themes.png` | Four-theme 2:1 repository social preview, 1280 × 640 |
| `theme-showcase-background-v1.png` | Text-free generated four-territory gallery background |
| `theme-social-background-v1.png` | Text-free generated dark 2:1 social-preview background |

The backgrounds were generated with the built-in OpenAI ImageGen workflow. The exact generation briefs are preserved in [PROMPT.md](PROMPT.md). Final artwork is assembled with the real project icon, SwiftUI views compiled from the repository, and deterministic text; generated UI or generated typography is never used.

Regenerate the real widget previews and both promotional asset families from the repository root:

```bash
zsh scripts/render-widget-previews.sh
xcrun swift scripts/render-promo.swift
zsh scripts/render-theme-assets.sh
```

`render-theme-assets.sh` treats the two checked-in `*-background-v1.png` files as immutable source artwork. It compiles the shared renderer and produces both README languages plus the four-theme social card.

The preview values are fictional and do not contain an access token, account identifier, prompt, usage history, or other user data. The widget images intentionally use a dual-window fixture to document the automatic compatibility path if Codex restores a short rolling limit; the current weekly-only response is the default app preview.
