# Promotional assets

This directory contains the product previews and repository artwork used by the English and Simplified Chinese READMEs.

| File | Purpose |
| --- | --- |
| `hero-banner.png` | English README hero, 1600 × 800 |
| `hero-banner-zh.png` | Simplified Chinese README hero, 1600 × 800 |
| `github-social-preview.png` | 2:1 repository social preview, 1280 × 640 |
| `promo-background.png` | Text-free generated brand background used by the compositor |
| `widget-small.png` | Deterministic Small widget preview with synthetic values |
| `widget-medium.png` | Deterministic Medium widget preview with synthetic values |

The background was generated with OpenAI ImageGen using the checked-in app icon and widget previews only as palette and visual-language references. The exact generation brief is preserved in [PROMPT.md](PROMPT.md). The final artwork is assembled with the real project icon, exact preview PNGs, and deterministic text; generated UI or generated typography is never used.

Regenerate the three final promotional images from the repository root:

```bash
xcrun swift scripts/render-promo.swift
```

The preview values are fictional and do not contain an access token, account identifier, prompt, usage history, or other user data.
