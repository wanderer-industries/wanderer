%{
title: "User Guide: Public API Endpoints for Map Data",
author: "Wanderer Team",
cover_image_uri: "/images/news/01-05-map-public-api/generate-key.png",
tags: ~w(map public-api guide interface),
description: "Learn how to use the Wanderer public API endpoints to retrieve system and character data from your map. This guide covers available endpoints, request examples, and sample responses."
}

---

## Introduction

As part of the Wanderer platform, a public API has been introduced to help users programmatically retrieve map data, such as system information and character tracking details. This guide explains how to use these endpoints, how to authenticate with the API, and what data to expect in the responses.

**Important:** To use these endpoints, you need a valid API key for the map in question. You can generate or copy this key from within the **Map Settings** modal in the app:

![Generate Map API Key](/images/news/01-05-map-public-api/generate-key.png "Generate Map API Key")

---

## Authentication

Each request to the Wanderer APIs that being with /api/map must include a valid API key in the `Authorization` header. The format is:
```
Authorization: Bearer <YOUR_MAP_API_KEY>
```

If the API key is missing or incorrect, you'll receive a `401 Unauthorized` response.

No api key is required for routes that being with /api/common

---

## Endpoints Overview

### 1. List Systems

    GET /api/map/systems?map_id=<UUID>
    GET /api/map/systems?slug=<map-slug>

- **Description:** Retrieves a list of systems associated with the specified map (by `map_id` or `slug`).
- **Authentication:** Required via `Authorization` header.
- **Parameters:**
  - `map_id` (optional if `slug` is provided) — the UUID of the map.
  - `slug` (optional if `map_id` is provided) — the slug identifier of the map.
  - `all=true` (optional) — if set, returns _all_ systems instead of only "visible" systems.

#### Example Request

```
    curl -H "Authorization: Bearer <REDACTED_TOKEN>" "https://wanderer.example.com/api/map/systems?slug=some-slug"
```

#### Example Response

```
    {
      "data": [
        {
          "id": "<REDACTED_ID>",
          "name": "<REDACTED_NAME>",
          "status": 0,
          "tag": null,
          "visible": false,
          "description": null,
          "labels": "<REDACTED_JSON>",
          "inserted_at": "2025-01-01T13:38:42.875843Z",
          "updated_at": "2025-01-01T13:40:16.750234Z",
          "locked": false,
          "solar_system_id": <REDACTED_NUMBER>,
          "map_id": "<REDACTED_ID>",
          "custom_name": null,
          "position_x": 1125,
          "position_y": -285
        },
        ...
      ]
    }
```

---

### 2. Show Single System

    GET /api/map/system?id=<SOLAR_SYSTEM_ID>&map_id=<UUID>
    GET /api/map/system?id=<SOLAR_SYSTEM_ID>&slug=<map-slug>

- **Description:** Retrieves information for a specific system on the specified map. You must provide:
  - `id` (the `solar_system_id`).
  - Either `map_id` or `slug`.
- **Authentication:** Required via `Authorization` header.

#### Example Request

```
    curl -H "Authorization: Bearer <REDACTED_TOKEN>" "https://wanderer.example.com/api/map/system?id=<REDACTED_NUMBER>&slug=<REDACTED_SLUG>"
```

#### Example Response

```
    {
      "data": {
        "id": "<REDACTED_ID>",
        "name": "<REDACTED_NAME>",
        "status": 0,
        "tag": null,
        "visible": false,
        "description": null,
        "labels": "<REDACTED_JSON>",
        "inserted_at": "2025-01-03T06:30:02.069090Z",
        "updated_at": "2025-01-03T07:47:07.471051Z",
        "locked": false,
        "solar_system_id": <REDACTED_NUMBER>,
        "map_id": "<REDACTED_ID>",
        "custom_name": null,
        "position_x": 1005,
        "position_y": 765
      }
    }
```

---

### 2. Show Single System Static Info

    GET /api/common/static-system-info?id=<SOLAR_SYSTEM_ID>

- **Description:** Retrieves the static information for a specific system.

- **Authentication:** No API token required

#### Example Request

```
    curl "https://wanderer.example.com/api/common/static-system-info?id=31002229
```

#### Example Response

```
{
  "data": {
    "solar_system_id": 31002229,
    "triglavian_invasion_status": "Normal",
    "solar_system_name": "J132946",
    "system_class": 5,
    "region_id": 11000028,
    "constellation_id": 21000278,
    "solar_system_name_lc": "j132946",
    "constellation_name": "E-C00278",
    "region_name": "E-R00028",
    "security": "-1.0",
    "type_description": "Class 5",
    "class_title": "C5",
    "is_shattered": false,
    "effect_name": null,
    "effect_power": 5,
    "statics": [
      "H296"
    ],
    "wandering": [
      "D792",
      "C140",
      "Z142"
    ],
    "sun_type_id": 38
  }
}

```

---

### 3. List Tracked Characters

    GET /api/map/characters?map_id=<UUID>
    GET /api/map/characters?slug=<map-slug>

- **Description:** Retrieves a list of tracked characters for the specified map (by `map_id` or `slug`), including metadata such as corporation/alliance details.
- **Authentication:** Required via `Authorization` header.

#### Example Request

```
    curl -H "Authorization: Bearer <REDACTED_TOKEN>" "https://wanderer.example.com/api/map/characters?slug=some-slug"
```

#### Example Response

```
    {
      "data": [
        {
          "id": "<REDACTED_ID>",
          "character": {
            "id": "<REDACTED_ID>",
            "name": "<REDACTED_NAME>",
            "inserted_at": "2025-01-01T05:24:18.461721Z",
            "updated_at": "2025-01-03T07:45:52.294052Z",
            "alliance_id": "<REDACTED>",
            "alliance_name": "<REDACTED>",
            "alliance_ticker": "<REDACTED>",
            "corporation_id": "<REDACTED>",
            "corporation_name": "<REDACTED>",
            "corporation_ticker": "<REDACTED>",
            "eve_id": "<REDACTED>"
          },
          "tracked": true,
          "map_id": "<REDACTED_ID>"
        },
        ...
      ]
    }
```

---

### 4. Kills Activity

    GET /api/map/systems-kills?map_id=<UUID>
    GET /api/map/systems-kills?slug=<map-slug>"

- **Description:** Retrieves the kill activity for the specified map (by `map_id` or `slug`), including details on the attacker and victim

#### Example Request

```
    curl -H "Authorization: Bearer <REDACTED_TOKEN>" "https://wanderer.example.com/api/map/systems-kills?slug==some-slug"
```

#### Example Response

```
    {
      "data": [
        {
          "kills": [
            {
              "attacker_count": 1,
              "final_blow_alliance_id": 99013806,
              "final_blow_alliance_ticker": "TCE",
              "final_blow_char_id": 2116802670,
              "final_blow_char_name": "Bambi Bunny",
              "final_blow_corp_id": 98140648,
              "final_blow_corp_ticker": "GNK3D",
              "final_blow_ship_name": "Thrasher",
              "final_blow_ship_type_id": 16242,
              "kill_time": "2025-01-21T21:00:59Z",
              "killmail_id": 124181782,
              "npc": false,
              "solar_system_id": 30002768,
              "total_value": 10000,
              "victim_alliance_id": null,
              "victim_char_id": 2121725410,
              "victim_char_name": "Bill Drummond",
              "victim_corp_id": 98753095,
              "victim_corp_ticker": "KSTJK",
              "victim_ship_name": "Capsule",
              "victim_ship_type_id": 670,
              "zkb": {
                "awox": false,
                "destroyedValue": 10000,
                "droppedValue": 0,
                "fittedValue": 10000,
                "hash": "777148f8bf344bade68a6a0821bfe0a37491a7a6",
                "labels": ["cat:6","#:1","pvp","loc:highsec"],
                "locationID": 50014064,
                "npc": false,
                "points": 1,
                "solo": false,
                "totalValue": 10000
              }
            },
            {
              "attacker_count": 3,
              "final_blow_alliance_id": null,
              "final_blow_char_id": null,
              "final_blow_corp_id": null,
              "final_blow_ship_type_id": 3740,
              "kill_time": "2025-01-21T21:00:38Z",
              "killmail_id": 124181769,
              "npc": true,
              "solar_system_id": 30002768,
              "total_value": 2656048.48,
              "victim_alliance_id": 99013806,
              "victim_alliance_ticker": "TCE",
              "victim_char_id": 2116802745,
              "victim_char_name": "Brittni Bunny",
              "victim_corp_id": 98140648,
              "victim_corp_ticker": "GNK3D",
              "victim_ship_name": "Coercer",
              "victim_ship_type_id": 16236,
              "zkb": {
                "awox": false,
                "destroyedValue": 2509214.44,
                "droppedValue": 146834.04,
                "fittedValue": 2607449.82,
                "hash": "d3dd6b8833b2a9d36dd5a3eecf9838c4c8b01acd",
                "labels": ["cat:6","#:2+","npc","loc:highsec"],
                "locationID": 50014064,
                "npc": true,
                "points": 1,
                "solo": false,
                "totalValue": 2656048.48
              }
            }
          ],
          "solar_system_id": 30002768
        },
        ...
      ]
    }
```

---

### 5. Character Activity

    GET /api/map/activity?map_id=<UUID>
    GET /api/map/activity?slug=<map-slug>

- **Description:** Retrieves activity statistics for all characters on the specified map, including connections made, passages through systems, and signatures added.
- **Authentication:** Required via `Authorization` header.
- **Parameters:**
  - `map_id` (optional if `slug` is provided) — the UUID of the map.
  - `slug` (optional if `map_id` is provided) — the slug identifier of the map.

#### Example Request

```
    curl -H "Authorization: Bearer <REDACTED_TOKEN>" "https://wanderer.example.com/api/map/activity?slug=some-slug"
```

#### Example Response

```
    {
      "data": [
        {
          "character": {
            "name": "Character Name",
            "corporation_ticker": "CORP",
            "alliance_ticker": "ALLY",
            "eve_id": "12345"
          },
          "connections": 4,
          "passages": 28,
          "signatures": 1
        },
        ...
      ]
    }
```

---

## Conclusion

Using these APIs, you can programmatically retrieve system and character information from your map. Whether you're building a custom analytics dashboard, a corp management tool, or just want to explore data outside the standard UI, these endpoints provide a straightforward way to fetch up-to-date map details.

For questions or additional support, please reach out to the Wanderer Team.


---

Fly safe,  
**The Wanderer Team**
