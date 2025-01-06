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

Each request to the Wanderer API must include a valid API key in the `Authorization` header. The format is:

    Authorization: Bearer <YOUR_MAP_API_KEY>

If the API key is missing or incorrect, you’ll receive a `401 Unauthorized` response.

---

## Endpoints Overview

### 1. List Systems

    GET /api/systems?map_id=<UUID>
    GET /api/systems?slug=<map-slug>

- **Description:** Retrieves a list of systems associated with the specified map (by `map_id` or `slug`).
- **Authentication:** Required via `Authorization` header.
- **Parameters:**
  - `map_id` (optional if `slug` is provided) — the UUID of the map.
  - `slug` (optional if `map_id` is provided) — the slug identifier of the map.
  - `all=true` (optional) — if set, returns *all* systems instead of only "visible" systems.

#### Example Request
```
    curl -H "Authorization: Bearer <REDACTED_TOKEN>" "https://wanderer.example.com/api/systems?slug=some-slug"
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

    GET /api/system?id=<SOLAR_SYSTEM_ID>&map_id=<UUID>
    GET /api/system?id=<SOLAR_SYSTEM_ID>&slug=<map-slug>

- **Description:** Retrieves information for a specific system on the specified map. You must provide:
  - `id` (the `solar_system_id`).
  - Either `map_id` or `slug`.
- **Authentication:** Required via `Authorization` header.

#### Example Request
```
    curl -H "Authorization: Bearer <REDACTED_TOKEN>" "https://wanderer.example.com/api/system?id=<REDACTED_NUMBER>&slug=<REDACTED_SLUG>"
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

### 3. List Tracked Characters

    GET /api/characters?map_id=<UUID>
    GET /api/characters?slug=<map-slug>

- **Description:** Retrieves a list of tracked characters for the specified map (by `map_id` or `slug`), including metadata such as corporation/alliance details.
- **Authentication:** Required via `Authorization` header.

#### Example Request
```
    curl -H "Authorization: Bearer <REDACTED_TOKEN>" "https://wanderer.example.com/api/characters?slug=some-slug"
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

## Conclusion

Using these APIs, you can programmatically retrieve system and character information from your map. Whether you’re building a custom analytics dashboard, a corp management tool, or just want to explore data outside the standard UI, these endpoints provide a straightforward way to fetch up-to-date map details.

For questions or additional support, please reach out to the Wanderer Team.

Fly safe,
WANDERER TEAM
