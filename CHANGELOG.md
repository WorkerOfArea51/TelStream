# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- **Season-Specific TMDB Metadata**: The app now dynamically fetches season-specific metadata from TMDB, ensuring accurate posters, synopses, and cast for each season.
- **Dynamic Recommendations**: Added "More Like This" recommendations populated from TMDB show-level data when viewing a series.
- **Persistent Metadata Caching**: Implemented local caching in `StorageService` to instantly load previously fetched season metadata without redundant API calls.

### Changed
- **UI Modernization (Material 3)**: Fully upgraded the app theme to Material 3 Expressive, introducing component-level themes for Cards, Buttons, Dialogs, Sliders, Bottom Sheets, Snackbars, and Chips.
- **Settings Screen Redesign**: Modernized the settings screen layout, introduced M3 styled section headers, replaced the old dropdown with visual color swatches for the theme picker, and cleanly separated the Logout action.
- **Episode Count Badge Alignment**: Standardized the orange episode count badge by aligning it to the top-right on all library cards (both grid and compact views).
- **Library Grid Layout Enhancements**: 
  - Increased grid padding to 16px to prevent corner cut-offs on edge cards.
  - Increased border opacity on library cards for better visibility on dark backgrounds.
  - Removed overlapping heavy shadows on untapped cards that previously caused dark spots in grid gaps.
