# 3Speak Storage Administration Tool

A powerful CLI tool for managing 3Speak's storage infrastructure, enabling automated cleanup of videos across MongoDB, IPFS, and S3/Wasabi storage systems.

## 🎯 Quick Reference Card

```bash
# GET OVERVIEW
npm run dev -- stats --detailed

# SAFE ANALYSIS (No changes made)
npm run dev -- list --banned-users --limit 10
npm run dev -- list --status "encoding_failed" --limit 5
npm run dev -- list --stuck-days 90 --limit 10

# CLEANUP WORKFLOW (Always follow this order!)
npm run dev -- cleanup --[criteria] --dry-run      # 1. Preview
npm run dev -- cleanup --[criteria] --batch-size 5 # 2. Small test  
npm run dev -- cleanup --[criteria] --batch-size 50 # 3. Full cleanup
```

**🚨 NEVER skip `--dry-run` for cleanup operations!**

## Features

- **MongoDB Integration**: Query user and video data from production database
- **Multi-criteria Cleanup**: Target videos by banned users, age, view counts, status, or orphaned content
- **IPFS Management**: Bulk unpin and cleanup operations
- **S3/Wasabi Support**: Delete HLS video files from cloud storage with permlink-based structure
- **Safety Features**: Dry-run mode, confirmation prompts, batch processing, and cleanup state tracking
- **Comprehensive CLI**: Interactive commands with detailed help and logging
- **Smart Storage Detection**: Automatically handles permlink-based HLS file structure (1080p.m3u8, 720p/, thumbnails/, etc.)

## Installation

```bash
git clone <repository>
cd 3speak-storage-admin
npm install
```

## Configuration

1. Copy the example environment file:
```bash
cp .env.example .env
```

2. Update the `.env` file with your production credentials:
```env
# MongoDB (Production)
MONGODB_URI=mongodb://production-host:27017/3speak
MONGODB_DB_NAME=3speak

# S3/Wasabi (Production)
AWS_ACCESS_KEY_ID=your_production_access_key
AWS_SECRET_ACCESS_KEY=your_production_secret_key
S3_BUCKET_NAME=3speak-videos
S3_ENDPOINT=https://s3.wasabisys.com

# IPFS
IPFS_API_URL=http://localhost:5001

# Safety Settings
DRY_RUN_MODE=true
REQUIRE_CONFIRMATION=true
MAX_BATCH_SIZE=100
```

## 🎯 Friendly Scripts (Recommended)

**For non-technical administrators:** Use the interactive scripts in the `/scripts` folder.

```bash
./scripts/status-check.sh          # Get overview of storage status
./scripts/free-deleted-videos.sh   # Clean admin-deleted videos (SAFEST)  
./scripts/remove-banned-content.sh # Remove banned user content
./scripts/clean-stuck-uploads.sh   # Clean old stuck uploads
```

These scripts:
- Ask simple questions in plain English
- Show exactly what will be deleted before doing it
- Use safe defaults
- Handle all the technical details automatically

**📖 See `/scripts/README.md` for detailed script documentation.**

## Usage

### 🚀 Quick Start

### For Administrators 
```bash
# 1. First time setup
npm install
cp .env.example .env
# Edit .env with your credentials

# 2. Check what needs cleaning
./scripts/status-check.sh

# 3. Start with the safest cleanup
./scripts/free-deleted-videos.sh
```

### For Developers (Direct CLI)
```bash
# 1. Test connection
npm run dev -- stats

# 2. Start exploring
npm run dev -- --help
```

### 📊 Analysis Commands (Safe - No Changes Made)

```bash
# Get storage overview
npm run dev -- stats                    # Basic stats
npm run dev -- stats --detailed         # Full breakdown

# List videos by criteria  
npm run dev -- list --banned-users --limit 10        # Videos from banned users
npm run dev -- list --status "uploaded" --limit 5    # Stuck uploads  
npm run dev -- list --age 365 --limit 10             # Old videos (365+ days)
npm run dev -- list --max-views 0 --limit 10         # Videos with 0 views
npm run dev -- list --stuck-days 30 --limit 5        # Stuck in processing 30+ days
npm run dev -- list --storage-type s3 --limit 5      # S3-stored videos
npm run dev -- list --storage-type ipfs --limit 5    # IPFS-stored videos
```

### 🧹 Cleanup Operations (Destructive - Use with Care!)

**⚠️ ALWAYS test with `--dry-run` first!**

```bash
# SAFE: Preview what would be deleted (--dry-run)
npm run dev -- cleanup --banned-users --dry-run
npm run dev -- cleanup --status "encoding_failed" --dry-run  
npm run dev -- cleanup --stuck-days 90 --dry-run
npm run dev -- cleanup --age 730 --max-views 5 --dry-run

# REAL: Actual cleanup (removes --dry-run)
npm run dev -- cleanup --banned-users --batch-size 50
npm run dev -- cleanup --status "deleted" --batch-size 25      # Admin-deleted S3 cleanup
npm run dev -- cleanup --status "encoding_failed" --batch-size 25
npm run dev -- cleanup --stuck-days 180 --batch-size 100
```

### 🎯 Common Use Cases

```bash
# Find biggest cleanup opportunities
npm run dev -- stats --detailed

# Clean up admin-deleted videos from S3 storage
npm run dev -- list --status "deleted" --limit 10      # Preview  
npm run dev -- cleanup --status "deleted" --dry-run    # Test
npm run dev -- cleanup --status "deleted" --batch-size 25  # Execute (16k+ videos)

# Clean up banned user content
npm run dev -- list --banned-users --limit 10          # Preview
npm run dev -- cleanup --banned-users --dry-run        # Test
npm run dev -- cleanup --banned-users --batch-size 50  # Execute

# Remove failed encodings (saves lots of space!)
npm run dev -- list --status "encoding_failed" --limit 5
npm run dev -- cleanup --status "encoding_failed" --dry-run
npm run dev -- cleanup --status "encoding_failed" --batch-size 25

# Clean up old stuck uploads  
npm run dev -- list --stuck-days 90 --limit 10
npm run dev -- cleanup --stuck-days 90 --dry-run
npm run dev -- cleanup --stuck-days 90 --batch-size 100

# Remove very old, low-engagement content
npm run dev -- cleanup --age 1095 --max-views 10 --dry-run  # 3+ years, ≤10 views
```

### 🛡️ Safety Features

- **`--dry-run`** - Preview changes without executing (ALWAYS use first!)
- **`--limit X`** - Limit results to X videos for testing
- **`--batch-size X`** - Process X videos at a time (prevents overload)
- **Confirmation prompts** - Tool asks before destructive operations
- **Comprehensive logging** - All actions logged to `./logs/app.log`
- **Environment validation** - Checks credentials before starting

## 📖 Command Reference

### `stats` - Storage Analytics
Get comprehensive storage statistics and breakdowns.

```bash
npm run dev -- stats [options]
```

**Options:**
- `-d, --detailed` - Show detailed breakdown by storage type and stuck videos

**Examples:**
```bash
npm run dev -- stats              # Basic overview
npm run dev -- stats --detailed   # Full analysis with IPFS/S3 breakdown
```

### `list` - Query Videos
List videos matching specific criteria without making changes.

```bash  
npm run dev -- list [options]
```

**Filtering Options:**
- `-b, --banned-users` - Videos from banned content creators
- `-a, --age <days>` - Videos older than X days
- `--max-views <count>` - Videos with ≤ X views
- `--min-views <count>` - Videos with ≥ X views  
- `-o, --orphaned` - Videos missing filename/storage info
- `-s, --status <statuses>` - Videos with specific status (comma-separated)
- `--stuck-days <days>` - Videos stuck in processing for X+ days (default: 30)
- `--storage-type <type>` - Filter by storage: `ipfs`, `s3`, or `unknown`
- `--limit <count>` - Limit results (recommended for testing)

**Examples:**
```bash
npm run dev -- list --banned-users --limit 10
npm run dev -- list --status "uploaded,encoding_ipfs" --limit 5  
npm run dev -- list --age 365 --max-views 0 --limit 10
npm run dev -- list --stuck-days 60 --storage-type s3
```

### `cleanup` - Delete Videos  
⚠️ **DESTRUCTIVE OPERATION** - Always test with `--dry-run` first!

```bash
npm run dev -- cleanup [options]
```

**Filtering Options:** (Same as `list` command)
- All the same filtering options as `list`

**Safety Options:**
- `--dry-run` - **REQUIRED FIRST** - Preview without executing
- `--batch-size <size>` - Process X videos at a time (default: 100)
- `--no-confirm` - Skip confirmation prompts (dangerous!)

**Examples:**
```bash
# ALWAYS start with dry-run
npm run dev -- cleanup --banned-users --dry-run

# Then execute in small batches
npm run dev -- cleanup --banned-users --batch-size 25

# Complex criteria
npm run dev -- cleanup --age 1095 --max-views 5 --status "encoding_failed" --dry-run
```

## 🚨 Production Safety Workflow

**CRITICAL: Follow this order every time!**

```bash
# 1. ANALYZE - Understand what you're dealing with
npm run dev -- stats --detailed

# 2. QUERY - See specific videos that match criteria  
npm run dev -- list --[your-criteria] --limit 10

# 3. DRY RUN - Preview the cleanup operation
npm run dev -- cleanup --[your-criteria] --dry-run

# 4. SMALL BATCH - Execute on small batch first
npm run dev -- cleanup --[your-criteria] --batch-size 10

# 5. FULL CLEANUP - Only after verifying small batch worked
npm run dev -- cleanup --[your-criteria] --batch-size 100
```

## Development

### VS Code Tasks
The project includes preconfigured VS Code tasks:
- **Build and Run**: Build and start the application
- **Dev Mode**: Run in development mode with hot reload
- **Watch Build**: Continuously build TypeScript files

Access via `Ctrl+Shift+P` → "Tasks: Run Task"

### Project Structure
```
src/
├── commands/     # CLI command implementations
├── config/       # Environment and connection configs  
├── services/     # MongoDB, IPFS, S3 service classes
├── types/        # TypeScript interfaces
├── utils/        # Helper functions and logging
└── index.ts      # Main CLI entry point
```

## Safety Features

- **Dry Run Mode**: Preview all changes before execution
- **Confirmation Prompts**: Require explicit confirmation for destructive operations
- **Batch Processing**: Limit concurrent operations to prevent system overload
- **Comprehensive Logging**: Track all operations with Winston logger
- **Type Safety**: Full TypeScript coverage with strict type checking

## Production-Ready Status

✅ **Fully Implemented:**
- MongoDB connection to production database
- S3/Wasabi cleanup with permlink-based HLS structure detection
- Comprehensive CLI with all safety features
- Cleanup state tracking to prevent re-processing
- Battle-tested on production data

📋 **Immediate Cleanup Opportunities:**
- 16,422 admin-deleted videos ready for S3 cleanup
- 35k+ stuck uploads for IPFS cleanup
- 438 banned users with associated content

## 🚀 Production Deployment Checklist

### Pre-Deployment
- [ ] Update `.env` with production credentials
- [ ] Test MongoDB connection: `npm run dev -- stats`
- [ ] Verify Wasabi/S3 credentials work
- [ ] Run analysis: `npm run dev -- stats --detailed`

### Initial Cleanup
- [ ] Start with safest targets: `npm run dev -- list --status "encoding_failed" --limit 5`  
- [ ] Always dry-run first: `--dry-run`
- [ ] Use small batches: `--batch-size 10` initially
- [ ] Monitor logs: `tail -f ./logs/app.log`

### Scaling Up
- [ ] Increase batch sizes gradually (10 → 25 → 50 → 100)
- [ ] Clean categories in order of safety:
  1. `--status deleted` (safest - admin already deleted, just S3 cleanup)
  2. `encoding_failed` (broken videos, safe to remove)  
  3. `stuck-days 180+` (very old stuck uploads)
  4. `banned-users` (policy violations)
  5. `age 1095 --max-views 0` (3+ year old, no views)

## 🔒 Security & Backup Considerations

**Before Large Operations:**
- Backup MongoDB (at least the videos collection)
- Document what you're cleaning and why
- Test with `--limit 5` first, always
- Never skip `--dry-run` phase

**Access Control:**
- MongoDB user should have minimal required permissions
- Wasabi/S3 credentials should be scoped to specific bucket
- Store credentials in environment variables only
- Use IAM roles when possible

**Production Security:**
- Keep `.env` file secure and never commit it to git
- Use private repository for production deployment
- Rotate credentials regularly
- Monitor all cleanup operations
- Set up proper logging and alerting

**Audit Trail:**
- All operations logged to `./logs/app.log`
- Include reasoning in commit messages
- Document cleanup results and space savings

## 🆘 Troubleshooting

### Connection Issues
```bash
# Test MongoDB connection
npm run dev -- stats

# Check credentials in .env file
cat .env | grep -E "(MONGODB_URI|AWS_)"
```

### Performance Issues  
```bash
# Reduce batch size
--batch-size 10

# Add delays between batches (future feature)
# Monitor system resources during cleanup
```

### Recovery
```bash
# Check recent logs
tail -50 ./logs/app.log

# If cleanup went wrong, check MongoDB for patterns:
# - Look for videos with recent 'updated' timestamps
# - Cross-reference with logged video IDs
```

## 📞 Support

1. **Check logs first**: `./logs/app.log`
2. **Verify environment**: All required variables set in `.env`
3. **Test with minimal scope**: `--limit 1 --dry-run`
4. **Document the issue**: What command, what error, what environment

**Current Production Stats (November 2025):**
- 374k+ total videos
- 8.49 TB total storage  
- 16,422 admin-deleted videos (ready for S3 cleanup)
- 35k+ stuck videos (IPFS cleanup candidates)
- 438 banned users identified
- S3 Structure: Permlink-based HLS format with ~11 files per video