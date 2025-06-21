%{
title: "Real-Time Events API: WebSockets and Webhooks for Wanderer",
author: "Wanderer Team",
cover_image_uri: "/images/news/06-21-webhooks/webhooks-hero.png",
tags: ~w(api webhooks websocket real-time discord integration developer),
description: "Connect to Wanderer's real-time events using WebSockets or webhooks. Learn how to receive instant notifications for map changes, kills, and more - including a complete Discord integration guide."
}

---

# Real-Time Events API: WebSockets and Webhooks for Wanderer

We're excited to announce the launch of Wanderer's Real-Time Events API, giving developers and power users instant access to map events as they happen. Whether you're building a Discord bot, creating custom alerts, or integrating with external tools, our new API provides two powerful methods to receive real-time updates: WebSockets for persistent connections and webhooks for HTTP-based integrations.

In the dynamic world of EVE Online wormhole mapping, every second counts. When a new signature appears, when a hostile kill occurs in your chain, or when a scout reports a new connection - having this information delivered instantly to your tools and teams can make all the difference. Our Real-Time Events API eliminates the need for polling and provides sub-second delivery of critical map events.

## What's New?

### WebSocket Connections
- **Persistent real-time streaming** of map events
- **Event filtering** to receive only the events you care about
- **Automatic reconnection** support with event backfill
- **Lightweight protocol** using Phoenix Channels V2

### Webhook Delivery
- **HTTP POST notifications** to your endpoints
- **HMAC-SHA256 signatures** for security
- **Automatic retries** with exponential backoff
- **Secret rotation** for enhanced security

### Event Types Available
- **System Events**: `add_system`, `deleted_system`, `system_metadata_changed`
- **Connection Events**: `connection_added`, `connection_removed`, `connection_updated`
- **Signature Events**: `signature_added`, `signature_removed`, `signatures_updated`
- **Kill Events**: `map_kill`

## Getting Started

### Prerequisites
- A Wanderer map with API access enabled
- Your map API token (found in map settings)
- Basic programming knowledge for integration

### Authentication
Both WebSocket and webhook APIs use your existing map API token for authentication. This token should be kept secure and never exposed in client-side code.

## WebSocket Quick Start

Connect to Wanderer's WebSocket endpoint to receive a real-time stream of events:

### JavaScript Example
```javascript
import { Socket } from "phoenix";

// Initialize connection
const socket = new Socket("wss://wanderer.ltd/socket/events", {
  params: { token: "your-map-api-token" }
});

socket.connect();

// Join your map's event channel
const channel = socket.channel(`events:map:${mapId}`, {
  // Optional: Filter specific events
  events: ["add_system", "map_kill"]
});

// Handle events
channel.on("add_system", (event) => {
  console.log("New system added:", event);
});

channel.on("map_kill", (event) => {
  console.log("Kill detected:", event);
});

// Connect to the channel
channel.join()
  .receive("ok", () => console.log("Connected to events"))
  .receive("error", (err) => console.error("Connection failed:", err));
```

### Event Filtering
You can subscribe to specific events or use `"*"` to receive all events:

```javascript
// Subscribe to specific events only
const channel = socket.channel(`events:map:${mapId}`, {
  events: ["add_system", "connection_added", "map_kill"]
});

// Or subscribe to all events
const channel = socket.channel(`events:map:${mapId}`, {
  events: "*"
});
```

## Webhook Setup

Webhooks provide an alternative to WebSockets, delivering events via HTTP POST to your endpoint:

### 1. Create a Webhook Subscription

```bash
curl -X POST https://wanderer.ltd/api/maps/${MAP_ID}/webhooks \
  -H "Authorization: Bearer ${API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://your-server.com/webhook",
    "events": ["add_system", "map_kill"],
    "active": true
  }'
```

### 2. Handle Incoming Webhooks

Your endpoint will receive POST requests with events:

```javascript
// Express.js webhook handler
app.post('/webhook', (req, res) => {
  // Verify signature
  const signature = req.headers['x-wanderer-signature'];
  const timestamp = req.headers['x-wanderer-timestamp'];
  
  if (!verifyWebhookSignature(req.body, signature, timestamp, webhookSecret)) {
    return res.status(401).send('Invalid signature');
  }
  
  // Process the event
  const event = req.body;
  console.log(`Received ${event.type} event for map ${event.map_id}`);
  
  // Always respond quickly
  res.status(200).send('OK');
  
  // Process event asynchronously
  processEvent(event);
});
```

### 3. Signature Verification

Verify webhook authenticity using HMAC-SHA256:

```javascript
function verifyWebhookSignature(payload, signature, timestamp, secret) {
  const data = `${timestamp}.${JSON.stringify(payload)}`;
  const hmac = crypto.createHmac('sha256', secret);
  const expectedSignature = `sha256=${hmac.update(data).digest('hex')}`;
  
  return crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(expectedSignature)
  );
}
```

## Discord Integration Guide

One of the most popular uses for real-time events is sending notifications to Discord. Here's how to integrate Wanderer events with Discord webhooks.

### Ready-Made Solution: Wanderer Notifier

If you want a fully-featured Discord integration without writing any code, check out [Wanderer Notifier](https://wanderer.ltd/news/03-18-bots) - our official Discord bot that provides:
- Rich formatted notifications with images and embeds
- Kill tracking with zKillboard integration
- Character and system tracking
- Easy Docker deployment
- Premium features for map subscribers

The examples below are for developers who want to build custom integrations or understand how the webhook system works.

### Understanding Discord Webhooks

Discord webhooks require messages in a specific format - you can't send raw Wanderer events directly. Discord expects either:
- A `content` field with plain text
- An `embeds` array with structured message objects

Since Wanderer sends events as `{id, type, map_id, ts, payload}`, you'll need a small transformer service to wrap the data in Discord's format. You have two options:
1. **Simple text notifications** (minimal transformation)
2. **Rich embeds** (formatted messages with colors and fields)

### Step 1: Create a Discord Webhook

1. In your Discord server, go to Server Settings → Integrations → Webhooks
2. Click "New Webhook" and configure:
   - Name: "Wanderer Events"
   - Channel: Select your notification channel
3. Copy the webhook URL

### Option A: Minimal Transformation (Simple Text)

If you want the simplest possible integration, here's a minimal transformer that sends raw event data as text:

```javascript
const express = require('express');
const axios = require('axios');

const app = express();
app.use(express.json());

const DISCORD_WEBHOOK_URL = process.env.DISCORD_WEBHOOK_URL;

app.post('/webhook', async (req, res) => {
  // Respond immediately
  res.status(200).send('OK');
  
  // Send raw event as Discord message
  const event = req.body;
  try {
    await axios.post(DISCORD_WEBHOOK_URL, {
      content: `**${event.type}** event in map: \`\`\`json\n${JSON.stringify(event.payload, null, 2)}\n\`\`\``
    });
  } catch (error) {
    console.error('Discord error:', error);
  }
});

app.listen(3000);
```

This sends events to Discord as formatted code blocks, preserving all the raw data.

### Option B: Rich Embed Transformer (Formatted Messages)

For a better user experience with formatted messages, colors, and clickable links:

```javascript
const express = require('express');
const crypto = require('crypto');
const axios = require('axios');

const app = express();
app.use(express.json());

// Configuration
const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET;
const DISCORD_WEBHOOK_URL = process.env.DISCORD_WEBHOOK_URL;

// Event formatters for Discord
const formatters = {
  add_system: (event) => ({
    embeds: [{
      title: "New System Added",
      description: `System **${event.payload.name}** has been added to the map`,
      color: 0x00ff00,
      fields: [
        { name: "System ID", value: event.payload.solar_system_id, inline: true },
        { name: "Type", value: event.payload.type || "Unknown", inline: true }
      ],
      timestamp: event.ts
    }]
  }),
  
  map_kill: (event) => ({
    embeds: [{
      title: "Kill Detected",
      description: `${event.payload.victim.ship} destroyed in ${event.payload.system_name}`,
      color: 0xff0000,
      fields: [
        { name: "Victim", value: event.payload.victim.name, inline: true },
        { name: "Ship", value: event.payload.victim.ship, inline: true },
        { name: "Value", value: `${(event.payload.value / 1000000).toFixed(1)}M ISK`, inline: true }
      ],
      url: `https://zkillboard.com/kill/${event.payload.killmail_id}`,
      timestamp: event.ts
    }]
  }),
  
  connection_added: (event) => ({
    embeds: [{
      title: "New Connection",
      description: `Connection established: **${event.payload.from_name}** → **${event.payload.to_name}**`,
      color: 0x0099ff,
      fields: [
        { name: "Type", value: event.payload.type || "Unknown", inline: true },
        { name: "Mass Status", value: event.payload.mass_status || "Fresh", inline: true }
      ],
      timestamp: event.ts
    }]
  })
};

// Webhook endpoint
app.post('/webhook', async (req, res) => {
  // Verify signature
  const signature = req.headers['x-wanderer-signature'];
  const timestamp = req.headers['x-wanderer-timestamp'];
  
  if (!verifySignature(req.body, signature, timestamp)) {
    return res.status(401).send('Invalid signature');
  }
  
  // Respond immediately
  res.status(200).send('OK');
  
  // Process event
  const event = req.body;
  const formatter = formatters[event.type];
  
  if (formatter) {
    try {
      const discordPayload = formatter(event);
      await axios.post(DISCORD_WEBHOOK_URL, discordPayload);
    } catch (error) {
      console.error('Failed to send to Discord:', error);
    }
  }
});

function verifySignature(payload, signature, timestamp) {
  const data = `${timestamp}.${JSON.stringify(payload)}`;
  const hmac = crypto.createHmac('sha256', WEBHOOK_SECRET);
  const expected = `sha256=${hmac.update(data).digest('hex')}`;
  return crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected));
}

app.listen(3000, () => {
  console.log('Discord webhook transformer running on port 3000');
});
```

### Step 2: Deploy Your Transformer

Deploy this service to any platform that can run Node.js applications:

#### Using Docker:
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["node", "index.js"]
```

#### Using Docker Compose:
```yaml
version: '3'
services:
  discord-transformer:
    build: .
    environment:
      - WEBHOOK_SECRET=${WEBHOOK_SECRET}
      - DISCORD_WEBHOOK_URL=${DISCORD_WEBHOOK_URL}
    ports:
      - "3000:3000"
    restart: unless-stopped
```

### Step 3: Register Your Webhook

Register your transformer service with Wanderer:

```bash
curl -X POST https://wanderer.ltd/api/maps/${MAP_ID}/webhooks \
  -H "Authorization: Bearer ${API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://your-transformer.com/webhook",
    "events": ["add_system", "map_kill", "connection_added"],
    "active": true
  }'
```

Your Discord channel will now receive formatted notifications for all map events!

## Event Payload Examples

### System Added Event
```json
{
  "id": "01J0XXXXXXXXXXXXXXXXXXX",
  "type": "add_system",
  "map_id": "550e8400-e29b-41d4-a716-446655440000",
  "ts": "2025-06-21T12:34:56.789Z",
  "payload": {
    "solar_system_id": 31000001,
    "name": "J123456",
    "type": "wormhole",
    "class": "C3",
    "statics": ["C3", "HS"]
  }
}
```

### Kill Event
```json
{
  "id": "01J0YYYYYYYYYYYYYYYYYYY",
  "type": "map_kill",
  "map_id": "550e8400-e29b-41d4-a716-446655440000",
  "ts": "2025-06-21T12:35:00.123Z",
  "payload": {
    "killmail_id": 12345678,
    "system_name": "J123456",
    "victim": {
      "name": "Pilot Name",
      "ship": "Stratios",
      "corporation": "Corp Name"
    },
    "value": 250000000
  }
}
```

## Best Practices

### For WebSocket Connections
- **Implement reconnection logic** with exponential backoff
- **Handle connection drops** gracefully
- **Use event filtering** to reduce bandwidth
- **Process events asynchronously** to avoid blocking

### For Webhooks
- **Respond quickly** (within 3 seconds) to webhook deliveries
- **Verify signatures** on every request
- **Handle retries** idempotently
- **Monitor your endpoint** availability
- **Use HTTPS** exclusively

### Security Considerations
- **Never expose** your API token in client-side code
- **Rotate webhook secrets** regularly
- **Validate all inputs** from events
- **Use environment variables** for sensitive configuration
- **Monitor for unusual activity**

## API Reference

### WebSocket Endpoints
- **Connection URL**: `wss://wanderer.ltd/socket/events`
- **Channel Topic**: `events:map:{map_id}`
- **Authentication**: Bearer token in connection params

### REST API Endpoints
- **List Webhooks**: `GET /api/maps/{map_id}/webhooks`
- **Create Webhook**: `POST /api/maps/{map_id}/webhooks`
- **Update Webhook**: `PUT /api/maps/{map_id}/webhooks/{id}`
- **Delete Webhook**: `DELETE /api/maps/{map_id}/webhooks/{id}`
- **Rotate Secret**: `POST /api/maps/{map_id}/webhooks/{id}/rotate-secret`
- **Get Events** (backfill): `GET /api/maps/{map_id}/events?since={timestamp}`

### Rate Limits
- **WebSocket Connections**: 10 per map
- **Webhook Subscriptions**: 5 per map
- **Event Delivery**: No limit (all events delivered)
- **API Requests**: 100 per minute

## Advanced Use Cases

### Multi-Map Monitoring
Connect to multiple maps simultaneously:

```javascript
const maps = ['map-id-1', 'map-id-2', 'map-id-3'];
const channels = {};

maps.forEach(mapId => {
  const channel = socket.channel(`events:map:${mapId}`, {
    events: "*"
  });
  
  channel.on("*", (eventType, event) => {
    console.log(`[${mapId}] ${eventType}:`, event);
  });
  
  channel.join();
  channels[mapId] = channel;
});
```

### Event Aggregation
Build activity summaries:

```javascript
const activityTracker = {
  kills: 0,
  systemsAdded: 0,
  connectionsAdded: 0,
  
  handleEvent(event) {
    switch(event.type) {
      case 'map_kill': this.kills++; break;
      case 'add_system': this.systemsAdded++; break;
      case 'connection_added': this.connectionsAdded++; break;
    }
  },
  
  getHourlyStats() {
    return {
      kills: this.kills,
      systemsAdded: this.systemsAdded,
      connectionsAdded: this.connectionsAdded,
      timestamp: new Date()
    };
  }
};
```

### Custom Alerting
Create sophisticated alert conditions:

```javascript
// Alert on high-value kills
channel.on("map_kill", (event) => {
  if (event.payload.value > 1000000000) { // 1B+ ISK
    sendUrgentAlert({
      title: "High Value Kill Detected!",
      message: `${event.payload.victim.ship} worth ${event.payload.value / 1e9}B ISK destroyed`,
      priority: "high"
    });
  }
});

// Alert on new connections to specific systems
channel.on("connection_added", (event) => {
  const watchedSystems = ["J123456", "J234567"];
  if (watchedSystems.includes(event.payload.to_name)) {
    sendAlert({
      title: "Connection to Watched System",
      message: `New connection to ${event.payload.to_name} from ${event.payload.from_name}`
    });
  }
});
```

## Coming Soon

We're continuously improving our real-time events API. Upcoming features include:

- **Batch event delivery** for high-volume maps
- **Historical event replay** for analysis
- **Event transformations** and filtering rules
- **Additional event types** (structure timers, ACL changes)

## Get Support

Need help with the Real-Time Events API?

- **Documentation**: [Full API Reference](https://docs.wanderer.ltd/api/events)
- **Discord Community**: [Join our Discord](https://discord.gg/wanderer)


## Conclusion

The Real-Time Events API opens up endless possibilities for integrating Wanderer with your tools and workflows. Whether you're sending notifications to Discord, building custom dashboards, or creating advanced alerting systems, you now have instant access to everything happening in your maps.

Start building with real-time events today and take your wormhole operations to the next level!

---

*The Real-Time Events API is available now for all Wanderer maps. No additional subscription required - if you have API access to a map, you can use webhooks and WebSockets.*