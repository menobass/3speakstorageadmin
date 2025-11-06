# 3Speak Storage Admin Scripts

**🎯 Friendly Storage Management Scripts**

These scripts make storage cleanup super simple and safe. No need to remember complex commands!

## 🚀 Quick Start

1. **Check what needs cleaning:**
   ```bash
   ./scripts/status-check.sh
   ```

2. **Start with the safest cleanup:**
   ```bash
   ./scripts/free-deleted-videos.sh
   ```

## 📋 Available Scripts

### 🔍 `status-check.sh` - Storage Overview
**What it does:** Shows current storage stats and cleanup opportunities
**Safety:** 100% safe (read-only)
**When to use:** Anytime you want to see what's going on

```bash
./scripts/status-check.sh
```

### 🧹 `free-deleted-videos.sh` - Clean Admin-Deleted S3 Videos ⭐ **START HERE**
**What it does:** Removes S3 videos that admins already marked as deleted
**Safety:** Maximum safety (these videos are already marked for deletion)
**Space saved:** Usually 4-6 TB
**When to use:** First cleanup, regular maintenance

```bash
./scripts/free-deleted-videos.sh
```

### 📌 `free-deleted-ipfs.sh` - Clean Admin-Deleted IPFS Videos
**What it does:** Unpins IPFS videos that admins already marked as deleted
**Safety:** Maximum safety (admin pre-approved deletions)
**Action:** Unpins from IPFS node (different from S3 deletion)
**When to use:** After S3 cleanup, to free IPFS storage

```bash
./scripts/free-deleted-ipfs.sh
```

### ❌ `clean-failed-encodings.sh` - Remove Failed Encoding Videos
**What it does:** Removes videos with 'encoding_failed' or 'failed' status
**Safety:** High (these videos failed processing and can't be published)
**Space saved:** Can be very significant (8TB+ of failed encodings)
**When to use:** Regular maintenance to free up wasted storage

```bash
./scripts/clean-failed-encodings.sh
```

### 🚫 `remove-banned-content.sh` - Remove Banned User Content
**What it does:** Removes all content from users marked as banned
**Safety:** High (only affects banned users)  
**When to use:** After banning users, periodic cleanup

```bash
./scripts/remove-banned-content.sh
```

### 📦 `clean-stuck-uploads.sh` - Clean Old Stuck Uploads
**What it does:** Removes videos stuck in processing for X days
**Safety:** Medium (choose age threshold carefully)
**When to use:** Monthly cleanup of failed uploads

```bash
./scripts/clean-stuck-uploads.sh
```

### 📉 `clean-low-engagement.sh` - Remove Low Engagement Videos ⚠️
**What it does:** Removes old published videos with very low view counts
**Safety:** LOW - This removes published content users can watch!
**When to use:** Only when storage is critically low
**Caution:** Start with very conservative settings

```bash
./scripts/clean-low-engagement.sh
```

## 🛡️ Safety Features

✅ **Every script includes:**
- Automatic project building
- Safety checks before execution
- Dry run preview of changes
- Interactive confirmations  
- Progress monitoring
- Error handling
- Full logging

✅ **Smart defaults:**
- Conservative batch sizes
- Safe targeting (no accidentally deleting published content)
- Clear warnings for destructive operations

## 📊 Recommended Usage Order

**First Time Setup - Recommended Order:**

1. **Get familiar:** `./scripts/status-check.sh`
2. **Biggest safe wins:** `./scripts/free-deleted-videos.sh` (S3 cleanup)
3. **IPFS companion:** `./scripts/free-deleted-ipfs.sh` (IPFS cleanup)
4. **Failed encodings:** `./scripts/clean-failed-encodings.sh` (8TB+ potential)
5. **Monthly maintenance:** `./scripts/clean-stuck-uploads.sh`
6. **As needed:** `./scripts/remove-banned-content.sh`
7. **Emergency only:** `./scripts/clean-low-engagement.sh` (removes published content!)

**For Regular Maintenance:**

```bash
# Weekly: Clean admin-deleted content (both S3 and IPFS)
./scripts/free-deleted-videos.sh
./scripts/free-deleted-ipfs.sh

# Monthly: Clean failed encodings and stuck uploads
./scripts/clean-failed-encodings.sh
./scripts/clean-stuck-uploads.sh

# As needed: Remove banned content
./scripts/remove-banned-content.sh

# Emergency only: Remove low-engagement content
./scripts/clean-low-engagement.sh
```

## 🎛️ Script Options Explained

### Batch Sizes:
- **Small (10-25):** Safest, takes longer, easier to stop if needed
- **Medium (25-100):** Balanced, good for regular use
- **Large (100-250):** Faster, use when confident

### Age Thresholds (for stuck uploads):
- **30 days:** Very conservative, only clearly failed uploads
- **90 days:** Moderate, good for first cleanup
- **180+ days:** Aggressive, use when storage is critical

## 🚨 Emergency Stop

**If something goes wrong:**
- Press `Ctrl+C` to stop any running script
- All scripts can be safely re-run (they skip already processed videos)
- Check `./logs/app.log` for detailed information

## 🔧 Troubleshooting

**"ERROR: Please run this script from the 3speakstorageadmin directory"**
- Solution: `cd /path/to/3speakstorageadmin` first

**"Build failed"**
- Solution: Run `npm install` then try again

**"No videos found"**
- This is good! It means that category is already clean

## 📈 Expected Results

**After running `free-deleted-videos.sh`:**
- 4-6 TB of storage freed up
- 16,000+ admin-deleted video records cleaned
- S3 storage costs reduced

**After running `remove-banned-content.sh`:**
- All content from 438 banned users removed
- Policy compliance improved

**After running `clean-stuck-uploads.sh`:**
- Failed uploads removed
- Database cleaned up
- Storage efficiency improved

## 💡 Pro Tips

1. **Always start with status-check.sh** to understand current state
2. **Use free-deleted-videos.sh first** - it's the safest big win
3. **Start with small batch sizes** until you're comfortable
4. **Run during off-peak hours** for less system impact
5. **Check logs** if anything seems unusual: `tail -f logs/app.log`

## 🎯 For VPS Deployment

Once comfortable with the scripts, you can automate them:

```bash
# Add to crontab for automated cleanup
# Clean admin-deleted videos every 6 hours
0 */6 * * * cd /path/to/3speakstorageadmin && ./scripts/free-deleted-videos.sh

# Weekly stuck upload cleanup  
0 2 * * 1 cd /path/to/3speakstorageadmin && ./scripts/clean-stuck-uploads.sh
```