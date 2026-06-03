# Contributing to Lyra

![Contributions Welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat-square)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg?style=flat-square&logo=swift&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg?style=flat-square&logo=apple&logoColor=white)

Thank you for taking the time to contribute! Your help makes Lyra better for everyone.

## How to Contribute

### 1. Reporting Issues & Suggestions
* **Check first**: Search the [FAQ](FAQ.md) and existing [Issues](https://github.com/Dai-Ski/LYRA/issues) to see if it's already discussed.
* **Open a ticket**: If it's new, open an issue using the appropriate template:
  * [Report a Bug](https://github.com/Dai-Ski/LYRA/issues/new?template=bug_report.md)
  * [Request a Feature](https://github.com/Dai-Ski/LYRA/issues/new?template=feature_request.md)

### 2. Submitting Pull Requests (PRs)
* **Branch**: Fork the repo and create your branch from `main`.
* **Style**: Adhere to the existing coding conventions and layout.
* **Submit**: Open a PR using our Pull Request Template and reference any related issue numbers.

## Development Setup

Lyra is a macOS-only project built using the **Swift Package Manager (SPM)**.

### Prerequisites
* macOS 13 (Ventura) or newer
* Xcode 14 or newer (or Command Line Tools installed)

### Building & Running
* **Via Xcode (Recommended)**:
  1. Open Xcode and select **Open existing project**.
  2. Choose the root folder containing `Package.swift`.
  3. Select the `Lyra` executable scheme and press `Cmd + R` to run.
* **Via Terminal**:
  Build and compile the standalone `.app` bundle in the repository root:
  ```bash
  ./Scripts/package.sh
  ```

### Running Tests
Always verify that your changes compile and pass tests before opening a PR:
```bash
swift test
```

## Coding Standards

* **Code Style**: Adhere to the official [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/).
* **Branch Naming**: Use clean prefixes: `feature/` (new features), `bugfix/` (fixes), or `docs/` (documentation).
* **Commit Messages**: Write concise, imperative commit descriptions (e.g., `fix: handle missing metadata gracefully`).
