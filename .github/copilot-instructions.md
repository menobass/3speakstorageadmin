# 3Speak Storage Administration Tool

This is a Node.js/TypeScript CLI tool for managing 3speak storage operations including:

## Core Functionality
- MongoDB connectivity for user and video data queries
- IPFS video management and cleanup operations
- S3/Wasabi storage operations for video deletion
- Automated cleanup based on various criteria:
  - Banned user videos
  - Video age thresholds
  - View count filters
  - Orphaned content detection

## Tech Stack
- **Runtime**: Node.js with TypeScript
- **Database**: MongoDB (production connection)
- **Storage**: IPFS and S3/Wasabi APIs
- **Interface**: CLI with interactive prompts
- **Configuration**: Environment-based config management

## Development Guidelines
- Use async/await for all async operations
- Implement proper error handling and logging
- Include dry-run modes for safety
- Add confirmation prompts for destructive operations
- Use typed interfaces for all data structures
- Follow defensive programming practices for production data