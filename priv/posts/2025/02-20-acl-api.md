%{
  title: "User Guide: Characters & ACL API Endpoints",
  author: "Wanderer Team",
  cover_image_uri: "/images/news/02-20-acl-api/generate-key.png",
  tags: ~w(acl characters guide interface),
  description: "Learn how to retrieve and manage Access Lists and Characters through the Wanderer public APIs. This guide covers available endpoints, request examples, and sample responses."
}

---

## Introduction

Wanderer’s expanded public API now lets you retrieve **all characters** in the system and manage “Access Lists” (ACLs) for controlling visibility or permissions. These endpoints allow you to:

- Fetch a list of **all** EVE characters known to the system.
- List ACLs for a given map.
- Add, remove, and change the roles of ACL members.

This guide provides step-by-step instructions, request/response examples, and details on how to authenticate each call.

---

## Authentication

Unless otherwise noted, these endpoints require a valid **Bearer** token. Pass it in the `Authorization` header:

```
Authorization: Bearer <REDACTED_TOKEN>
```

If the token is missing or invalid, you’ll receive a `401 Unauthorized` error.
_(No API key is required for some “common” endpoints, but ACL- and character-related endpoints require a valid token.)_


There are two types of tokens in use currently -- one is for map specific items, and available in the map settings

1. **Map API Token:** Available in the map settings. This token is used for map-specific endpoints (e.g. listing ACLs for a map).


![Generate Map API Key](/images/news/01-05-map-public-api/generate-key.png "Generate Map API Key")

2. **ACL API Token:** Available in the create/edit ACL screen. This token is used for ACL member management endpoints.

![Generate ACL API Key](/images/news/02-20-acl-api/generate-key.png "Generate ACL API Key")

---

## Endpoints Overview

### 1. List **All** Characters

```
GET /api/characters
```

- **Description:** Returns a list of **all** characters known to Wanderer.
- **Toggle:** The availability of this api is controlled by the env variable `WANDERER_CHARACTER_API_DISABLED`.  It is `false` by default
- **Example Request:**
  ```
  curl -H "Authorization: Bearer <REDACTED_TOKEN>" \
       "https://wanderer.example.com/api/characters"
  ```
- **Example Response (redacted)**:
  ```
  {
    "data": [
      {
        "id": "b374d9e6-47a7-4e20-85ad-d608809827b5",
        "name": "Some Character",
        "eve_id": "2122825111",
        "corporation_name": "School of Applied Knowledge",
        "alliance_name": null
      },
      {
        "id": "6963bee6-eaa1-40e2-8200-4bc2fcbd7350",
        "name": "Other Character",
        "eve_id": "2122019111",
        "corporation_name": "Some Corporation",
        "alliance_name": null
      }
      ...
    ]
  }
  ```

Use the `"eve_id"` when you want to reference a character in an ACL.

---

### 2. List ACLs for a Given Map

```
GET /api/map/acls?map_id=<UUID>
GET /api/map/acls?slug=<map-slug>
```

- **Description:** Lists all Access Lists (ACLs) associated with a map, specified by either `map_id` (UUID) or `slug`.
- **Authentication:** Required via `Authorization` header.  The token required here is the `PUBLIC_API_TOKEN` available in map settings of the map you are trying to access
- **Example Request:**
  ```
  curl -H "Authorization: Bearer <REDACTED_TOKEN>" \
       "https://wanderer.example.com/api/map/acls?slug=mapname"
  ```
- **Example Response (redacted)**:
  ```
  {
    "data": [
      {
        "id": "19712899-ec3a-47b1-b73b-2bae221c5513",
        "name": "aclName",
        "description": null,
        "owner_id": "d43a9083-2705-40c9-a314-f7f412346661",
        "inserted_at": "2025-02-13T03:32:25.144403Z",
        "updated_at": "2025-02-13T03:32:25.144403Z",
        "members": []
      }
    ]
  }
  ```

---

### 3. Show a Specific ACL (Including Members)

```
GET /api/acls/:id
```

- **Description:** Fetches a single ACL by ID, with all its members preloaded.
- **Authentication:** Required, the token uses is the token available from the create/edit acl settings.
- **Example Request:**
  ```
  curl -H "Authorization: Bearer <REDACTED_TOKEN>" \
       "https://wanderer.example.com/api/acls/19712899-ec3a-47b1-b73b-2bae221c5513"
  ```
- **Example Response (redacted)**:
  ```
  {
    "data": {
      "id": "19712899-ec3a-47b1-b73b-2bae221c5513",
      "name": "aclName",
      "description": null,
      "owner_id": "d43a9083-2705-40c9-a314-f7f412346661",
      "members": [
        {
          "id": "8d63ab1e-b44f-4e81-8227-8fb8d928dad8",
          "name": "Other Character",
          "role": "admin",
          "inserted_at": "2025-02-13T03:33:32.332598Z",
          "updated_at": "2025-02-13T03:33:36.644520Z"
        },
        ...
      ]
    }
  }
  ```

---

### 4. Add a Member to an ACL

```
POST /api/acls/:acl_id/members
```

- **Description:** Adds a new member (character, corporation, or alliance) to the specified ACL.
- **Authentication:** Required, the token used is the token available from the create/edit acl settings.
- **Body:**
  ```
  {
    "member": {
      "name": "Some Character",
      "eve_character_id": "<EVE_CHARACTER_ID>",
      "role": "viewer"
    }
  }
  ```
  - `eve_character_id` is the characters external Eve ID.

- **Example Request:**
  ```
  curl -X POST \
       -H "Authorization: Bearer <REDACTED_TOKEN>" \
       -H "Content-Type: application/json" \
       -d '{
         "member": {
           "name": "New Member",
           "eve_character_id": "111111111",
           "role": "viewer"
         }
       }' \
       "https://wanderer.example.com/api/acls/19712899-ec3a-47b1-b73b-2bae221c5513/members"
  ```
- **Example Response (redacted)**:
  ```
  {
    "data": {
      "id": "3885e87b-341d-425a-a9d9-81ddde9dfa10",
      "name": "New Member",
      "role": "viewer",
      "inserted_at": "...",
      "updated_at": "..."
    }
  }
  ```
  - `id` here is the **membership** ID, distinct from the character’s own ID.

---

### 5. Change a Member’s Role

```
PUT /api/acls/:acl_id/members/:member_id
```

- **Description:** Updates an ACL member’s `role` (e.g. `viewer` → `admin`).
- **Authentication:** Required, the token uses is the token available from the create/edit acl settings.
- **Path Params:**
  - `:acl_id` is the ACL’s ID.
  - `:member_id` is the Eve ID of the character whose role you want to update
- **Body:**
  ```
  {
    "member": {
      "role": "admin"
    }
  }
  ```
- **Example Request:**
  ```
  curl -X PUT \
       -H "Authorization: Bearer <REDACTED_TOKEN>" \
       -H "Content-Type: application/json" \
       -d '{
         "member": {
           "role": "admin"
         }
       }' \
       "https://wanderer.example.com/api/acls/19712899-ec3a-47b1-b73b-2bae221c5513/members/"111111111"
  ```
- **Example Response (redacted)**:
  ```
  {
    "data": {
      "id": "3885e87b-341d-425a-a9d9-81ddde9dfa10",
      "name": "New Member",
      "role": "admin",
      ...
    }
  }
  ```

---

### 6. Remove a Member from an ACL

```
DELETE /api/acls/:acl_id/members/:member_id
```

- **Description:** Removes the member with eve id `:member_id` from the specified ACL.
- **Authentication:** Required, the token uses is the token available from the create/edit acl settings.
- **Example Request:**
  ```
  curl -X DELETE \
       -H "Authorization: Bearer <REDACTED_TOKEN>" \
       "https://wanderer.example.com/api/acls/19712899-ec3a-47b1-b73b-2bae221c5513/members/111111111"
  ```
- **Example Response:**
  ```
  { "ok": true }
  ```

---

## Conclusion

This guide outlines how to:

1. **List** all characters (`GET /api/characters`) so you can pick a valid character to add to your ACL.
2. **Show** ACLs for a specified map (`GET /api/map/acls`...).
2. **Show**  ACL details (`GET /api/acls/:id`).
4. **Add** members (characters, corps, alliances) to an ACL.
5. **Change** their roles.
6. **Remove** them from the ACL if needed.

By following these request patterns, you can manage your ACL resources in a fully programmatic fashion. If you have any questions, feel free to reach out to the Wanderer Team.

Fly safe,
**WANDERER TEAM**
