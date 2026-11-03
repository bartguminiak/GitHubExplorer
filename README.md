# GitHub Explorer

A lightweight iOS application built with **SwiftUI**, **Swift 6**, and **MVVM**, using the public GitHub REST API.

The project explores modern iOS development practices, with a focus on Swift Concurrency, clean architecture, dependency injection, and automated testing.

## Tech Stack

- **SwiftUI** — Declarative user interface
- **Swift 6** — Modern concurrency and actor isolation
- **MVVM** — Separation of presentation and business logic
- **async/await** — Asynchronous networking with URLSession
- **Observation** — State management using `@Observable`
- **Swift Testing** — Unit testing with mocked dependencies

## Current Features

- Fetch and display a public GitHub repository
- Handle loading, success, and error states
- Decode REST API responses using `Codable`
- Test networking and ViewModel logic without external API calls

## Getting Started

1. Clone the repository.
2. Open `GitHubExplorer.xcodeproj` in Xcode 27.2 or later.
3. Select an iOS 17+ simulator and run the application.
4. Run unit tests using `Cmd + U`.

No API key or third-party dependencies are required.

## Project Status

**Work in progress.** The application is being developed incrementally to explore modern SwiftUI architecture, structured concurrency, and testable iOS code.
