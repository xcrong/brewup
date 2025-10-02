#!/bin/bash

# Setup Cron Job for Brewup
# This script helps you set up automated daily/weekly homebrew updates

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}⏰ BrewUp Cron Job Setup${NC}"
echo "========================"
echo ""

# Check if brewup is installed
if ! command -v brewup &> /dev/null; then
    echo -e "${RED}❌ Error: brewup is not installed or not in PATH${NC}"
    echo "Please install brewup first and make sure it's in your PATH"
    exit 1
fi

BREWUP_PATH=$(which brewup)
echo -e "${GREEN}✓ Found brewup at: $BREWUP_PATH${NC}"
echo ""

echo "Choose when you want brewup to run automatically:"
echo "1) Daily at 9:00 AM"
echo "2) Daily at 6:00 PM"
echo "3) Weekly on Monday at 9:00 AM"
echo "4) Weekly on Sunday at 10:00 AM"
echo "5) Custom schedule"
echo "6) Show current cron jobs and exit"
echo ""

read -p "Enter your choice (1-6): " choice

case $choice in
    1)
        CRON_SCHEDULE="0 9 * * *"
        DESCRIPTION="Daily at 9:00 AM"
        ;;
    2)
        CRON_SCHEDULE="0 18 * * *"
        DESCRIPTION="Daily at 6:00 PM"
        ;;
    3)
        CRON_SCHEDULE="0 9 * * 1"
        DESCRIPTION="Weekly on Monday at 9:00 AM"
        ;;
    4)
        CRON_SCHEDULE="0 10 * * 0"
        DESCRIPTION="Weekly on Sunday at 10:00 AM"
        ;;
    5)
        echo ""
        echo "Enter custom cron schedule (e.g., '0 9 * * *' for daily at 9 AM):"
        echo "Format: minute hour day month weekday"
        echo "Examples:"
        echo "  0 9 * * *     - Daily at 9:00 AM"
        echo "  30 18 * * 5   - Every Friday at 6:30 PM"
        echo "  0 12 1 * *    - First day of every month at noon"
        echo ""
        read -p "Cron schedule: " CRON_SCHEDULE
        DESCRIPTION="Custom schedule: $CRON_SCHEDULE"
        ;;
    6)
        echo ""
        echo -e "${BLUE}Current cron jobs:${NC}"
        crontab -l 2>/dev/null || echo "No cron jobs found"
        exit 0
        ;;
    *)
        echo -e "${RED}❌ Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${YELLOW}📋 Cron Job Configuration:${NC}"
echo "Schedule: $CRON_SCHEDULE ($DESCRIPTION)"
echo "Command: $BREWUP_PATH --verbose"
echo ""

# Create log directory
LOG_DIR="$HOME/.local/log"
mkdir -p "$LOG_DIR"

# Create the cron job entry
CRON_JOB="$CRON_SCHEDULE $BREWUP_PATH --verbose >> $LOG_DIR/brewup.log 2>&1"

echo -e "${BLUE}The following cron job will be added:${NC}"
echo "$CRON_JOB"
echo ""
echo "Logs will be saved to: $LOG_DIR/brewup.log"
echo ""

read -p "Do you want to add this cron job? (y/N): " confirm

if [[ $confirm =~ ^[Yy]$ ]]; then
    # Add to crontab
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

    echo ""
    echo -e "${GREEN}✅ Cron job added successfully!${NC}"
    echo ""
    echo -e "${BLUE}📝 Next steps:${NC}"
    echo "1. Your system will now automatically update Homebrew $DESCRIPTION"
    echo "2. Check logs at: $LOG_DIR/brewup.log"
    echo "3. To remove this job later, run: crontab -e"
    echo ""
    echo -e "${BLUE}📋 Current cron jobs:${NC}"
    crontab -l
else
    echo ""
    echo -e "${YELLOW}⏭️  Cron job setup cancelled${NC}"
fi

echo ""
echo -e "${BLUE}💡 Tips:${NC}"
echo "- View cron jobs: crontab -l"
echo "- Edit cron jobs: crontab -e"
echo "- Remove all cron jobs: crontab -r"
echo "- Check cron logs: tail -f $LOG_DIR/brewup.log"
echo "- Test the command manually: $BREWUP_PATH --verbose"
