%{
title: "Managing Upwell Structures & Timers with the Structures Widget",
author: "Wanderer Team",
cover_image_uri: "/images/news/01-20-structure-widget/cover.png",
tags: ~w(interface guide map structures),
description: "Learn how to track structure information using the Structures Widget."
}

---

### Introduction

Upwell structures like **Astrahus**, **Athanor**, and more are key strategic points in EVE Online. Staying informed about their statuses—whether they’re anchoring, powered, or reinforced—helps you plan defenses, coordinate attacks, and align with allies. Our **Structures Widget** simplifies the process by allowing you to:

- Copy structure information directly from the in-game Directional Scanner (`D-Scan`) and paste it into the widget.
- Keep track of **anchoring** or **reinforced** timers, including exact vulnerability windows.
- Share real-time data across the map with your corporation or alliance, ensuring everyone is on the same page.

In this guide, we’ll explore how to enable the Structures Widget, manage structure data, and make use of the built-in API for remote structure updates.

---

### 1. Enabling the Structure Widget

![Enabling the Structures Widget](/images/news/01-20-structure-widget/enable-widget.png "Enable Structures Widget")

1. **Open the Map:**
2. **Locate the Widget Settings:** By default, the structure widget panel is not visible.  Enable it by going to menu -> map settings -> widgets.
3. **Add the Structures Widget:** Click the checkbox for **Structures** from the list of available widgets.

> **Tip:** Rearrange your widgets by dragging them around the panel to suit your workflow.

---

### 2. Overview of the Structures Widget

![Structures Widget Overview](/images/news/01-20-structure-widget/cover.png "Structures Widget")

Once enabled, the **Structures Widget** appears in the map. It shows:

- **Structure Type** (Astrahus, Fortizar, etc.)
- **Structure Name** (auto-detected if you paste from D-Scan)
- **Owner** (Corporation ticker)
- **Status** (Powered, Anchoring, Low Power, Reinforced, etc.)
- **Timer** (Reinforced or anchoring end time)

You can **click** or **double-click** on an entry to edit details like the structure’s owner or add notes about the structure’s purpose or location.

---

### 3. Adding Structures via Copy & Paste

A fast way to add structure data is by copying from in-game D-Scan or show-info panels:

1. **In EVE Online:** Open the D-Scan window or structure context menu, select the relevant lines of text, and press **Ctrl + C**.
2. **In the Widget:** Focus on the Structures Widget, click in the widget area, and press **Ctrl + V** to paste or use the **blue** add structure info button.
3. The widget automatically parses the structure names and types. You can also add owners and notes manually.

This eliminates manual typing and reduces the chance of errors, especially useful when scanning multiple systems.

---

### 4. Tracking Reinforced Timers

When a structure is in a **Reinforced** or **Anchoring** state, we have a timer to note when it becomes vulnerable or completes anchoring:

- **Timer Field:** If the structure’s status is set to “Reinforced” or “Anchoring,” the widget enables a **Calendar** pop-up where you can set the _end time_.

Keep your fleet prepared by referencing this schedule. When the timer hits zero, the structure becomes vulnerable (or finishes anchoring).

---

### 5. Editing and Deleting Structures

1. **Single-click** a structure entry to select it.
2. Press **Delete** (or **Backspace**) to remove it entirely—useful when clearing out old data or removing outdated structures.
3. **Double-click** to open the **Edit Dialog**:
   - Change **Name**, **Owner**, or **Status**.
   - Update or remove **Reinforced** timers.
   - Add or edit **Notes**.

Any changes made here are immediately visible to other map users.

---

### 6. API Integration for Automated Timers

Beyond the in-app widget, there is a dedicated API endpoint to fetch or update structure timers programmatically. This allows advanced users and third-party applications to seamlessly incorporate structure data.

**Example API Request/Response**:

```bash
curl -H "Authorization: Bearer YOUR_API_TOKEN" \
"https://wanderer.yourdomain.space/api/map/structure-timers?slug=yourmap"

  "data": [
    {
      "name": "Overlook Hotel",
      "status": "Reinforced",
      "notes": null,
      "owner_id": null,
      "solar_system_id": 31000515,
      "solar_system_name": "J114942",
      "character_eve_id": "2122839817",
      "system_id": "4865aec4-b69d-4524-91d3-250b0556322b",
      "end_time": "2025-01-22T23:42:03.000000Z",
      "owner_name": null,
      "owner_ticker": null,
      "structure_type": "Astrahus",
      "structure_type_id": "35832"
    },
    {
      "name": "Some Structure",
      "status": "Reinforced",
      "notes": null,
      "owner_id": null,
      "solar_system_id": 3100229,
      "solar_system_name": "somecustomname",
      "character_eve_id": "some name",
      "system_id": "ae779ed6-92b3-4349-899d-f1bdf299082f",
      "end_time": "2025-01-16T03:04:00.000000Z",
      "owner_name": null,
      "owner_ticker": null,
      "structure_type": "Athanor",
      "structure_type_id": "35835"
    }
  ]
```


With this API, you could, for example, build automated pings on Slack/Discord when timers are about to expire or display status updates on a custom web dashboard.

> **Note:** Ensure your API token (`Bearer YOUR_API_TOKEN`) matches the api key generated for you map.

---

### 7. Best Practices & Tips

- **Keep Data Fresh:** Update timers as soon as possible after a structure enters reinforcement. This keeps your corporation or alliance fully informed.
- **Use Notes Effectively:** Add details such as final reinforcement phases or relevant system intel (e.g., known hostiles, safe spots) to help allies plan more effectively.

---

## Conclusion

The **Structures Widget** is your central hub for monitoring, updating, and sharing information about Upwell structures across New Eden. From real-time timer tracking to simple copy-and-paste integration with D-Scan, this widget streamlines group operations and cuts down on manual data entry.

Whether you’re a solo explorer managing a personal citadel network or a fleet commander overseeing multiple staging systems, the Structures Widget and its accompanying API ensure you’ll always have up-to-date intel on the structures that matter most.

Fly safe,
**The Wanderer Team**
