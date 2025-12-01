# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Object Storage Manager macOS application built with SwiftUI and SwiftData, providing a GUI interface for managing S3-compatible storage services including Amazon S3, MinIO, Qiniu, Aliyun OSS, and Tencent COS.

## Architecture

The application follows a clean MVVM architecture with the following key components:

### Core Layer
- **StorageManager**: The main business logic orchestrator that manages connections, file operations, and state
- **S3Client**: Low-level S3-compatible API client with AWS Signature V4 authentication
- **CredentialsStore**: Secure keychain storage for access credentials

### Models (SwiftData)
- **StorageSource**: Configuration for storage connections with provider-specific settings
- **MediaFile**: Represents stored objects with metadata and content type detection
- **FileSystemItem**: UI-friendly wrapper for files and folders in browser view
- **Tag**: Categorization system for storage sources

### Views (SwiftUI)
- **MainView**: Primary file browser with navigation and upload capabilities
- **SettingsView**: Storage source configuration and management
- **TagManagementView**: Tag system administration

### Storage Providers
Supports multiple S3-compatible providers with specific configurations:
- **Amazon S3**: Standard AWS S3 endpoints
- **MinIO**: Self-hosted object storage with path-style URLs
- **Qiniu**: Requires endpoint normalization (s3.region.qiniucs.com → s3-region.qiniucs.com)
- **Aliyun OSS**: China-based cloud storage
- **Tencent COS**: China-based cloud storage

## Development Commands

Since this is an Xcode project, use Xcode IDE for development:

### Building and Running
- Open `object-storage-manager.xcodeproj` in Xcode
- Select target "object-storage-manager"
- Build and Run (Cmd+R)

### Testing
- Unit tests: Run "object-storage-managerTests" scheme
- UI tests: Run "object-storage-managerUITests" scheme

## Key Implementation Details

### Authentication
- Uses AWS Signature V4 with RFC 3986 compliant percent encoding
- Credentials stored securely in macOS Keychain via `CredentialsStore`
- Automatic endpoint normalization for specific providers (e.g., Qiniu)

### File Management
- Hierarchical folder structure built from flat S3 object listings
- Folder marker objects (keys ending with `/`) are skipped for cleaner UI
- Drag-and-drop file upload with progress tracking
- MIME type detection based on file extensions

### Data Persistence
- SwiftData model container with automatic migration fallback
- Storage sources and tags persisted in local database
- Credentials stored separately in secure Keychain

### Error Handling
- Comprehensive error propagation from S3 client through UI
- Automatic retry and fallback mechanisms for file operations
- User-friendly error messages for common issues

## File Structure

```
object-storage-manager/
├── object_storage_managerApp.swift     # App entry point and SwiftData setup
├── ContentView.swift                    # Root UI container
├── Models/
│   ├── StorageProvider.swift           # Storage provider types and configurations
│   ├── MediaFile.swift                 # File metadata and utilities
│   └── FileSystemItem.swift            # UI file/folder representation
├── Services/
│   ├── StorageManager.swift           # Main business logic
│   ├── S3Client.swift                 # S3 API client with authentication
│   └── CredentialsStore.swift         # Keychain credential management
└── Views/
    ├── MainView.swift                 # File browser interface
    ├── SettingsView.swift             # Configuration management
    └── TagManagementView.swift        # Tag system UI
```