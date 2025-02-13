%{
  title: "User Guide: Characters & ACL API Endpoints",
  author: "Wanderer Team",
  cover_image_uri: "/images/news/01-05-map-public-api/generate-key.png",
  tags: ~w(acl characters guide interface),
  description: "Learn how to retrieve and manage Access Lists and Characters through the Wanderer public APIs. This guide covers available endpoints, request examples, and sample responses."
}

---

## Introduction

Wanderer’s expanded public API now lets you retrieve **all characters** in the system and manage “Access Lists” (ACLs) for controlling visibility or permissions. These endpoints allow you to:

- Fetch a list of **all** EVE characters known to the system.
- List ACLs for a given map.
- Create and update individual ACLs.
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

---

## Endpoints Overview

### 1. List **All** Characters

```
GET /api/characters
```

- **Description:** Returns a list of **all** characters known to Wanderer.
- **Authentication:** Required via `Authorization` header.
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

Use the `"id"` (or `"eve_id"`) when you want to reference a character in an ACL.

---

### 2. List ACLs for a Given Map

```
GET /api/acls?map_id=<UUID>
GET /api/acls?slug=<map-slug>
```

- **Description:** Lists all Access Lists (ACLs) associated with a map, specified by either `map_id` (UUID) or `slug`.
- **Authentication:** Required via `Authorization` header.
- **Example Request:**
  ```
  curl -H "Authorization: Bearer <REDACTED_TOKEN>" \
       "https://wanderer.example.com/api/acls?slug=mapname"
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
- **Authentication:** Required.
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

### 4. Create a New ACL

```
POST /api/acls
```

- **Description:** Creates a new Access List record.
- **Authentication:** Required.
- **Body:** JSON in the shape:
  ```
  {
    "acl": {
      "name": "...",
      "description": "...",
      "owner_id": "..."
    }
  }
  ```
  - `owner_id` is typically a **character** UUID from the `/api/characters` list.

- **Example Request:**
  ```
  curl -X POST \
       -H "Authorization: Bearer <REDACTED_TOKEN>" \
       -H "Content-Type: application/json" \
       -d '{
         "acl": {
           "name": "My Second ACL",
           "description": "Created from cURL",
           "owner_id": "d43a9083-2705-40c9-a314-f7f412346661"
         }
       }' \
       "https://wanderer.example.com/api/acls"
  ```
- **Example Response (redacted)**:
  ```
  {
    "data": {
      "id": "008db28a-7106-43a3-ae18-680fec2463fa",
      "name": "My Second ACL",
      "description": "Created from cURL",
      "owner_id": "d43a9083-2705-40c9-a314-f7f412346661",
      "members": []
    }
  }
  ```

---

### 5. Update an ACL (Rename, etc.)

```
PUT /api/acls/:id
```

- **Description:** Updates an existing ACL’s top-level fields (name, description, owner_id, etc.).
- **Authentication:** Required.
- **Body:**
  ```
  {
    "acl": {
      "name": "...",
      "description": "...",
      "owner_id": "..."
    }
  }
  ```
- **Example Request:**
  ```
  curl -X PUT \
       -H "Authorization: Bearer <REDACTED_TOKEN>" \
       -H "Content-Type: application/json" \
       -d '{
         "acl": {
           "name": "Renamed ACL from cURL",
           "description": "I just updated it"
         }
       }' \
       "https://wanderer.example.com/api/acls/008db28a-7106-43a3-ae18-680fec2463fa"
  ```
- **Example Response (redacted)**:
  ```
  {
    "data": {
      "id": "008db28a-7106-43a3-ae18-680fec2463fa",
      "name": "Renamed ACL from cURL",
      "description": "I just updated it",
      "owner_id": "d43a9083-2705-40c9-a314-f7f412346661",
      "members": [...]
    }
  }
  ```

---

### 6. Add a Member to an ACL

```
POST /api/acls/:acl_id/members
```

- **Description:** Adds a new member (character, corporation, or alliance) to the specified ACL.
- **Authentication:** Required.
- **Body:**
  ```
  {
    "member": {
      "name": "Some Character",
      "eve_character_id": "<CHARACTER_UUID>",
      "role": "viewer"
    }
  }
  ```
  - `eve_character_id` is typically the **internal** `id` from `/api/characters`.

- **Example Request:**
  ```
  curl -X POST \
       -H "Authorization: Bearer <REDACTED_TOKEN>" \
       -H "Content-Type: application/json" \
       -d '{
         "member": {
           "name": "New Member",
           "eve_character_id": "b374d9e6-47a7-4e20-85ad-d608809827b5",
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

### 7. Change a Member’s Role

```
PUT /api/acls/:acl_id/members/:member_id
```

- **Description:** Updates an ACL member’s `role` (e.g. `viewer` → `admin`).
- **Authentication:** Required.
- **Path Params:**
  - `:acl_id` is the ACL’s ID.
  - `:member_id` is the **membership** row’s ID (returned by the creation above).
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
       "https://wanderer.example.com/api/acls/19712899-ec3a-47b1-b73b-2bae221c5513/members/3885e87b-341d-425a-a9d9-81ddde9dfa10"
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

### 8. Remove a Member from an ACL

```
DELETE /api/acls/:acl_id/members/:member_id
```

- **Description:** Removes the member with ID `:member_id` from the specified ACL.
- **Authentication:** Required.
- **Example Request:**
  ```
  curl -X DELETE \
       -H "Authorization: Bearer <REDACTED_TOKEN>" \
       "https://wanderer.example.com/api/acls/19712899-ec3a-47b1-b73b-2bae221c5513/members/3885e87b-341d-425a-a9d9-81ddde9dfa10"
  ```
- **Example Response:**
  ```
  { "ok": true }
  ```

---

## Conclusion

This guide outlines how to:

1. **List** all characters (`GET /api/characters`) so you can pick a valid character to add to your ACL.
2. **List** or **show** ACLs (`GET /api/acls`...).
3. **Create** a new ACL (`POST /api/acls`) or **update** it (`PUT /api/acls/:id`).
4. **Add** members (characters, corps, alliances) to an ACL.
5. **Change** their roles.
6. **Remove** them from the ACL if needed.

By following these request patterns, you can manage your ACL resources in a fully programmatic fashion. If you have any questions, feel free to reach out to the Wanderer Team.

Fly safe,
**WANDERER TEAM**
