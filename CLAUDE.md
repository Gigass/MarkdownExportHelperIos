# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an iOS SwiftUI application called "MarkdownExportHelper" - a comprehensive Markdown editor and export tool. The app provides real-time preview, multiple export formats (PNG, PDF, HTML, Markdown), theme switching, history management, and smart content loading features.

## Build and Development Commands

Build the project:
```bash
xcodebuild -project MarkdownExportHelper.xcodeproj -scheme MarkdownExportHelper
```

Run tests:
```bash
xcodebuild test -project MarkdownExportHelper.xcodeproj -scheme MarkdownExportHelper
```

Run tests for a specific target:
```bash
xcodebuild test -project MarkdownExportHelper.xcodeproj -scheme MarkdownExportHelper -only-testing:MarkdownExportHelperTests
```

## Architecture

The app follows a simple SwiftUI architecture:

- **MarkdownExportHelperApp.swift**: Main app entry point using SwiftUI App lifecycle
- **ContentView.swift**: Primary view (currently showing placeholder content)
- **ImageSaver.swift**: Utility class for saving images to photo album using UIKit integration
- **View+Extensions.swift**: Platform-specific SwiftUI extensions for rendering views as images

### Key Components

- **ContentView.swift**: Main UI with adaptive layout (side-by-side in landscape, tabbed in portrait)
- **MarkdownViewModel.swift**: Core business logic handling content management, export functions, and history
- **HistoryView.swift**: History management interface with restore/delete functionality
- **ToastView.swift**: Modern notification system with different toast types
- **View+Extensions.swift**: Rendering utilities for image and PDF generation
- **ImageSaver.swift**: Photo album integration for image exports

### Core Features

- **Real-time Markdown Preview**: Uses MarkdownUI library for GitHub-flavored markdown rendering
- **Multiple Export Formats**: PNG images, PDF documents, HTML files, and raw Markdown
- **Theme Switching**: Light/dark mode with system preference support
- **Auto History**: Saves last 20 editing sessions automatically
- **Smart Loading**: Restores last content or loads from clipboard
- **Toast Notifications**: User-friendly feedback system

### Dependencies

- **MarkdownUI**: GitHub-flavored markdown rendering
- **ToastUI**: Modern notification components
- **swift-algorithms**: Algorithm utilities
- **Ink**: Markdown parsing (supporting library)