%{
title: "New Feature: Discord Kill Notifications",
author: "Wanderer Team",
cover_image_uri: "/images/news/08-02-discord-kill-notifications/cover.png",
tags: ~w(discord notifications kills map settings guide),
description: "Post kills from your map straight into a Discord channel. Set a webhook once, filter to wormhole space, exclude the systems you don't care about."
}

---

# Discord Kill Notifications

Your chain is already telling you where the fights are — the Kills widget shows
every killmail in the systems on your map. The catch is that somebody has to be
looking at it. If the map is on a second monitor nobody is watching, a hostile
gang rolling into your home hole looks exactly like an empty screen.

So we added a direct line out: **Discord kill notifications**. Point your map at
a Discord webhook and kills in your chain get posted into the channel your
corp is already sitting in.

## Setting it up

Open **Map settings → Notifications**. The tab lives inside the map's settings
page, so it is available to whoever can administer the map — in practice the map
owner and anyone granted admin rights over it.

1. **Create a webhook in Discord.** In your Discord server, open
   *Server Settings → Integrations → Webhooks*, create one, pick the channel it
   should post to, and copy the webhook URL.
2. **Paste the URL** into the *Discord webhook URL* field on the Notifications
   tab and hit **Save**.
3. **Send a test message** to confirm the wiring before you rely on it. The
   button is right there under the form.

That is the whole setup. From that point on, kills detected in systems on the
map are formatted and pushed to the channel.

## What a notification looks like

Each kill arrives as a Discord embed:

- **Title** — who lost what ("Some Pilot lost a Loki"), linking straight to the
  killmail on zKillboard.
- **System**, **Value**, **Final blow**, **Corp**, and **Alliance** fields. The
  final-blow field shows the number of other attackers, so `Some Pilot (+11)`
  tells you at a glance whether this was a solo gank or a fleet.
- A **ship render** thumbnail and the victim's corp ticker in the footer.

Fields that we have no data for are simply left out rather than posted as
"Unknown", so the embed stays readable.

When a burst of kills lands at once — a fleet fight, a gate camp working through
a convoy — the embeds are batched into as few messages as Discord allows, and a
very large batch is capped with a "…and N more kills not shown." line rather
than flooding your channel with a hundred separate posts.

## Filters

Two controls, both on the Notifications tab:

- **Only wormhole kills** (on by default). Restricts notifications to J-space,
  including Thera, shattered systems, and the drifter holes. Turn it off if you
  want kills from every system on the map, k-space included.
- **Excluded systems.** Search a system by name and add it to the list. Kills
  there are skipped. This is the one to use for your home system if you would
  rather not get a ping every time somebody shoots a structure, or for a
  highway system that generates constant noise.

There is also an **Enabled** checkbox, so you can mute the feed without
throwing away the webhook and its filter list.

**One thing worth being clear about:** these filters are *not* the same as the
Kills widget filters. The widget's filters are per-user and only change what
*you* see in the map UI. The Discord filters are per-map and server-side — they
apply to everyone in the channel. The two look similar and are deliberately
kept separate.

## About the webhook URL

A Discord webhook URL is a credential: anyone holding it can post to your
channel. So we treat it like one.

- It is **stored encrypted** in the database.
- After you save it, it is never displayed in full again — the settings tab
  shows a masked hint like `.../123456/AbCd••••`.
- To point the map at a different channel, click **Replace** and paste the new
  URL. There is no way to read the old one back out of the UI.

If a webhook is deleted on the Discord side, Discord answers with a 404 and the
map's notification config is disabled automatically — no point retrying a
channel that no longer exists. Other transient errors (rate limits, brief
outages) are retried with backoff, and only a sustained run of failures will
disable the config.

## Self-hosting notes

Wanderer CE runs this behind the same switch as the rest of the outbound events
system:

```bash
export WANDERER_WEBHOOKS_ENABLED="true"
```

With it off, the Notifications tab still renders but "Send test message" will
tell you notifications are disabled on this server.

Delivery uses its own isolated connection pool, so a slow Discord cannot back up
the rest of the application. If you run a large instance with many maps sending
notifications, you can size that pool:

```bash
export WANDERER_DISCORD_POOL_SIZE="10"   # default
```

## Known limits

Worth knowing before you wire it into an intel channel:

- Notifications are **at most once**. If a delivery fails outright, that kill is
  not re-sent later. We would rather drop the occasional kill than double-post
  into a chat channel, and a dropped kill is still visible in the Kills widget
  and on zKillboard.
- Deduplication is in memory, so a restart of the application can let a kill
  that was already posted be posted once more.
- One webhook per map. If you want kills split across several channels, that is
  not supported yet.

Fly safe. o7
