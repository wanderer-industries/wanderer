%{
  title: "SDE Data Source Migration: Faster Updates, Better Reliability",
  author: "Wanderer Team",
  cover_image_uri: "/images/news/ce_logo_dark.png",
  tags: ~w(infrastructure sde update admin),
  description: "We've migrated our EVE Static Data Export (SDE) source from Fuzzworks to Wanderer-Assets, bringing version tracking, faster updates, and improved reliability to Wanderer's map data."
}

---

## What's Changing?

Wanderer relies on EVE Online's Static Data Export (SDE) for essential game data like solar systems, ship types, and stargate connections. Previously, we fetched this data from Fuzzworks, a third-party service that has served the EVE community well for years.

Starting with this release, we've migrated to **Wanderer-Assets**, our own SDE repository that pulls directly from CCP's official data releases. This change brings several improvements to how Wanderer handles EVE universe data.

---

## Key Improvements

### Version Tracking

Wanderer now tracks which SDE version is installed and when it was last updated. Administrators can see this information directly in the Admin Panel:

- **Current SDE Version** - The exact CCP release version
- **Last Updated** - When the data was last refreshed
- **Update Available** - Notification when a newer version exists

### Automatic Updates on Startup

Wanderer now automatically checks for and applies SDE updates when the application starts:

- On each startup, Wanderer checks for new SDE versions
- If an update is available, it's automatically downloaded and applied
- No manual intervention required - your data stays current

You can also manually trigger updates from the Admin Panel if needed.

### Improved Reliability

By hosting our own SDE repository on GitHub's CDN, we gain:

- **Guaranteed Availability** - No dependency on third-party service uptime
- **Faster Downloads** - GitHub's global CDN ensures quick data transfers
- **Direct CCP Data** - Parsed directly from official EVE Online releases

---

## For Administrators

### Checking SDE Status

The Admin Panel now displays comprehensive SDE information:

| Field | Description |
|-------|-------------|
| Source | Data source (Wanderer Assets or Fuzzworks) |
| Version | Current SDE version number |
| Last Updated | Timestamp of last data refresh |

### Configuration Options

Two environment variables control SDE behavior:

```bash
# Choose data source (default: wanderer_assets)
SDE_SOURCE=wanderer_assets

# Custom base URL (optional)
SDE_BASE_URL=https://your-mirror.example.com/sde-files
```

### Rollback Capability

If you encounter any issues with the new data source, you can instantly roll back:

```bash
export SDE_SOURCE=fuzzworks
# Restart your Wanderer instance
```

---

## Technical Details

For those interested in the implementation:

- **New Modules**: `WandererApp.SDE.Source`, `WandererApp.SDE.WandererAssets`, `WandererApp.SDE.Fuzzworks`
- **Version Tracking**: Database table `sde_versions_v1` stores update history
- **Backward Compatible**: Existing installations work without configuration changes

The source repository is available at [wanderer-industries/wanderer-assets](https://github.com/wanderer-industries/wanderer-assets).

---

## What's Next?

This migration lays the groundwork for future enhancements:

- **NPC Station Data** - The new source includes station data for future features
- **Faster Patch Day Updates** - Direct CCP parsing means quicker availability of new data

---

## Questions?

If you have questions about the SDE migration or encounter any issues, please reach out through our usual support channels.

---

Fly safe,
**The Wanderer Team**

---
