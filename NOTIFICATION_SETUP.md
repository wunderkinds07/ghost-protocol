# Container Notification Setup 📢

Get real-time notifications from all containers about their progress. No complex integrations needed!

## 🎯 Default Configuration

All containers are pre-configured to send notifications to:
**https://ntfy.sh/callofdutyblackopsghostprotocolbravo64**

No setup required - notifications work out of the box!

## Available Notification Methods

### 1. 🌐 ntfy.sh (Easiest - No Setup!)

Free, open-source, no registration required. Works on mobile & desktop.

**Setup:**
```bash
# Just add this environment variable
-e NTFY_TOPIC=my-1stdibs-project

# View notifications at:
# https://ntfy.sh/my-1stdibs-project
```

**Mobile App:**
- iOS: https://apps.apple.com/app/id1625396347
- Android: https://play.google.com/store/apps/details?id=io.heckel.ntfy

### 2. 💬 Discord Webhook

**Setup:**
1. In Discord channel: Settings → Integrations → Webhooks → New Webhook
2. Copy webhook URL
3. Add to container:
```bash
-e DISCORD_WEBHOOK=https://discord.com/api/webhooks/YOUR_WEBHOOK_URL
```

### 3. 💼 Slack Webhook

**Setup:**
1. Go to: https://api.slack.com/apps
2. Create app → Incoming Webhooks → Add to workspace
3. Copy webhook URL
4. Add to container:
```bash
-e SLACK_WEBHOOK=https://hooks.slack.com/services/YOUR_WEBHOOK_URL
```

### 4. 📱 Telegram Bot

**Setup:**
1. Message @BotFather on Telegram
2. Create new bot, get token
3. Get your chat ID from @userinfobot
4. Add to container:
```bash
-e TELEGRAM_BOT_TOKEN=your-bot-token
-e TELEGRAM_CHAT_ID=your-chat-id
```

### 5. 📲 Pushover (Mobile Push Notifications)

**Setup:**
1. Sign up at https://pushover.net ($5 one-time)
2. Get User Key and create App Token
3. Add to container:
```bash
-e PUSHOVER_USER_KEY=your-user-key
-e PUSHOVER_APP_TOKEN=your-app-token
```

### 6. 🔗 Generic Webhook

For any service that accepts JSON webhooks (Zapier, IFTTT, n8n, etc.)

```bash
-e WEBHOOK_URL=https://your-webhook-endpoint.com/webhook
```

## Quick Start Examples

### Example 1: Using ntfy.sh (Recommended for Quick Start)

```bash
# Deploy with notifications
docker run -d \
  --name 1stdibs-phoenix \
  -e CONTAINER_ID=phoenix \
  -e NTFY_TOPIC=1stdibs-phoenix \
  -v $(pwd)/data/phoenix:/app/data \
  1stdibs-extractor:latest

# Watch notifications in browser:
# https://ntfy.sh/1stdibs-phoenix
```

### Example 2: Multiple Notification Methods

```bash
# Use Discord + ntfy.sh
docker run -d \
  --name 1stdibs-dragon \
  -e CONTAINER_ID=dragon \
  -e NTFY_TOPIC=1stdibs-extraction \
  -e DISCORD_WEBHOOK=https://discord.com/api/webhooks/xxx/yyy \
  -v $(pwd)/data/dragon:/app/data \
  1stdibs-extractor:latest
```

### Example 3: Update Docker Compose

```yaml
services:
  extractor-phoenix:
    image: 1stdibs-extractor:phoenix
    environment:
      - CONTAINER_ID=phoenix
      - NTFY_TOPIC=1stdibs-extraction
      - DISCORD_WEBHOOK=${DISCORD_WEBHOOK}
      - SLACK_WEBHOOK=${SLACK_WEBHOOK}
    volumes:
      - ./data/phoenix:/app/data
```

## Notification Events

Containers will notify you about:

1. **Started** - When container begins processing
2. **Progress** - Every 100 URLs processed
3. **Milestones** - At 500, 1000, 2500, 5000 URLs
4. **Completed** - When container finishes with statistics
5. **Errors** - If critical errors occur

## Sample Notifications

### Discord Example:
```
🐳 Container phoenix
📍 Stage: started
💬 Container started processing 5000 URLs
```

### Slack Example:
```
Container gallardo
Stage: completed
Message: Container completed: 4950 successful, 50 failed
Success Rate: 99.0%
Time Elapsed: 2h 15m
```

### ntfy.sh Example:
```
Title: Container nebula
Tags: progress
Progress: 2500/5000 (50.0%)
Success: 2450, Failed: 50
```

## Monitoring Dashboard

### Option 1: Simple Web Dashboard

Create a simple monitoring page:

```html
<!DOCTYPE html>
<html>
<head>
    <title>1stDibs Extraction Monitor</title>
    <script>
        // Subscribe to ntfy.sh topic
        const topic = '1stdibs-extraction';
        const eventSource = new EventSource(`https://ntfy.sh/${topic}/sse`);
        
        eventSource.onmessage = (e) => {
            const data = JSON.parse(e.data);
            // Update dashboard with notification
            console.log(data);
        };
    </script>
</head>
<body>
    <h1>Container Status</h1>
    <div id="notifications"></div>
</body>
</html>
```

### Option 2: Terminal Monitoring

```bash
# Watch ntfy.sh notifications in terminal
curl -s https://ntfy.sh/1stdibs-extraction/raw

# Or with jq for formatted output
curl -s https://ntfy.sh/1stdibs-extraction/json | jq .
```

## Centralized Notifications

To get all containers reporting to one place:

```bash
# Use same topic/webhook for all containers
CENTRAL_TOPIC="1stdibs-all"

# Deploy all containers with same topic
for chunk in phoenix gallardo nebula; do
  docker run -d \
    --name 1stdibs-$chunk \
    -e CONTAINER_ID=$chunk \
    -e NTFY_TOPIC=$CENTRAL_TOPIC \
    ...
done

# Monitor all at once
# https://ntfy.sh/1stdibs-all
```

## Advanced: Custom Processing

### Using Webhook with Zapier/IFTTT

1. Create Zapier webhook trigger
2. Add webhook URL to containers
3. Create actions:
   - Send email on completion
   - Update Google Sheets
   - Post to social media
   - Trigger other workflows

### Using n8n (Self-hosted)

```yaml
# n8n webhook node
webhook:
  path: /1stdibs-notifications
  method: POST
  
# Process and route notifications
# Send alerts, update databases, etc.
```

## Testing Notifications

Test your setup before deploying:

```bash
# Test ntfy.sh
curl -d "Test notification" https://ntfy.sh/your-topic

# Test Discord webhook
curl -X POST -H "Content-Type: application/json" \
  -d '{"content":"Test from 1stDibs extractor"}' \
  YOUR_DISCORD_WEBHOOK_URL

# Test Slack webhook
curl -X POST -H "Content-Type: application/json" \
  -d '{"text":"Test from 1stDibs extractor"}' \
  YOUR_SLACK_WEBHOOK_URL
```

## No-Code Integration Ideas

1. **Google Sheets Logger**
   - Webhook → Zapier → Google Sheets
   - Track all container progress in spreadsheet

2. **Email Summaries**
   - Webhook → IFTTT → Gmail
   - Get email when container completes

3. **SMS Alerts**
   - Webhook → Twilio
   - Text message for important events

4. **Database Logging**
   - Webhook → Supabase/Airtable
   - Store all events for analysis

## Quick Reference

```bash
# Minimal setup with ntfy.sh
-e NTFY_TOPIC=my-project

# Popular combinations
-e DISCORD_WEBHOOK=xxx -e NTFY_TOPIC=yyy
-e SLACK_WEBHOOK=xxx -e PUSHOVER_USER_KEY=yyy

# Test deployment with notifications
./test_local.sh
# Then add: -e NTFY_TOPIC=test-extraction
```

That's it! Pick any method above and you'll get real-time updates from all your containers. 🎉