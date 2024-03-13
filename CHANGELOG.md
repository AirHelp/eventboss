# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.9.0] - 2024-03-12

- Eliminate the dependency on `dotenv`. However, the application will still load `dotenv` if it is available.

## [1.4.0] - 2020-04-18

- Introduce server middlewares (#31)

## [1.1.0] - 2019-07-16

### Added
- Support for handling `SIGTERM` signal gracefully. Docker containers within Kubernetes can be terminated any time (the signal is sent to containers in a pod).
