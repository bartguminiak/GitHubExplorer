# GitHubExplorer

A lightweight iOS application built to explore **modern Swift Concurrency**, SwiftUI, and testable application architecture.

The project demonstrates practical concurrency patterns, including actor isolation, structured concurrency, task cancellation, request deduplication, and asynchronous networking.

> **Project status:** Work in progress. This is a learning and technical demonstration project, not a production-ready GitHub client.

## Features

- Search public GitHub repositories using the GitHub REST API.
- Browse repository details, including repository name and star count.
- Debounced search input to reduce unnecessary network requests.
- Cancellation-aware asynchronous operations.
- Protection against outdated search responses.
- In-memory repository caching using Swift actors.
- Deduplication of concurrent repository detail requests.
- Concurrent batch fetching using `TaskGroup`.
- Loading, empty, and error states.

## Tech Stack

| Area | Technology |
|---|---|
| Language | Swift 6 (application and test targets) |
| UI | SwiftUI |
| Architecture | MVVM |
| State management | Observation (`@Observable`) |
| Concurrency | async/await, actors, Task, TaskGroup |
| Networking | URLSession, GitHub REST API |
| Dependency injection | Protocol-based |
| Testing | Swift Testing |
| Dependencies | No third-party dependencies |

## Architecture

The application uses a lightweight, feature-oriented MVVM architecture with clear separation between presentation, business logic, and networking.

```text
GitHubExplorer/
├── App/
│   ├── GitHubExplorerApp.swift
│   └── AppDependencies.swift
├── Features/
│   └── Repository/
│       ├── Views/          # Search and repository views
│       └── ViewModels/     # Search and repository ViewModels
├── Models/
└── Networking/
    ├── HTTPClient.swift
    ├── GitHubAPIClient.swift
    ├── GitHubRepositoryProviding.swift
    └── CachingRepositoryProvider.swift
```

The networking layer uses protocol-based abstractions, allowing API implementations to be replaced with test doubles without modifying the ViewModels.

## Swift Concurrency

Concurrency is the primary technical focus of this project.

### MainActor and UI State

ViewModels use `@MainActor` isolation to protect observable UI state and keep state updates consistent.

### Debouncing and Cancellation

Repository search uses SwiftUI's `.task(id:)` lifecycle with a debounce interval to reduce unnecessary API calls.

Request identifiers help prevent older asynchronous responses from overwriting newer results.

### Actor-Based Caching

`CachingRepositoryProvider` uses an actor to isolate its in-memory cache and track ongoing requests.

Concurrent requests for the same repository can share an in-flight operation rather than always initiating separate HTTP requests.

The current implementation is intentionally lightweight; complete shared-request cancellation management remains outside its scope.

### Structured Concurrency

Batch repository fetching demonstrates `withThrowingTaskGroup`, allowing a dynamic collection of repositories to be fetched concurrently.

The implementation illustrates the distinction between structured child tasks and unstructured tasks.

## Testing

The project uses **Swift Testing** with injected mock implementations.

Tests cover:

- JSON decoding and API response handling.
- Successful and failed network requests.
- ViewModel loading, success, and error states.
- Search input validation.
- Out-of-order asynchronous responses.
- Cancellation behavior.
- Repository caching.
- Batch fetching result and request counts.

The current tests do not verify that batch requests overlap in time or that concurrent detail requests share an in-flight operation. Cancellation coverage currently applies to the search ViewModel.

Controlled continuations are used in concurrency tests to simulate asynchronous operations and verify their behavior without relying on arbitrary delays.

## Getting Started

### Requirements

- Xcode 27.2 or later
- iOS 17.6 or later (application and test targets)
- Swift 6 language mode for both application and test targets

### Run

1. Clone the repository.
2. Open `GitHubExplorer.xcodeproj` in Xcode.
3. Select an iOS simulator.
4. Build and run the application.

The application uses GitHub's public REST API. **No API key or third-party dependencies are required** for basic usage.

Unauthenticated GitHub API requests are subject to rate limits.

### Run Tests

Use **Product → Test** in Xcode or press `Cmd + U`.

The tests use mock networking components and do not require live GitHub API access.

## Known Limitations

- Search error handling and user-facing error messages need refinement.
- GitHub API rate limits may affect unauthenticated requests.
- Search returns only the first page of up to 20 repositories; pagination is not implemented. The API's total result count and incomplete-results flag are decoded but are not exposed to the UI.
- Shared in-flight request cancellation is not fully implemented.
- Repository caching is in-memory only and does not persist across application launches.
- Cached repository details have no expiration or explicit refresh. Search bypasses this cache, so search results and cached details can show different star counts during a session.
- Batch fetching is demonstrated at the networking layer and is not exposed as a separate UI feature.

## Project Goals

This project is designed to demonstrate and reinforce:

- Swift 6 concurrency fundamentals and actor isolation.
- Safe asynchronous state management in SwiftUI.
- Dependency injection and testable architecture.
- Deterministic testing of concurrent operations.
- Practical trade-offs between implementation simplicity and production-level robustness.

The emphasis is on **code clarity, concurrency correctness, and engineering decisions**, rather than feature completeness.
