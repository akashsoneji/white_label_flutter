---
name: project-no-map-string-dynamic-cast
description: "Avoid using `as Map<String, dynamic>` when mapping over lists from API responses to prevent silent white screen build crashes."
type: project
createdAt: 1787210149709
updatedAt: 1787210149709
---

In UI lists constructed from API responses (like `linksList` or `plansList`), do NOT use `as Map<String, dynamic>`. JSON decoders often produce `Map<dynamic, dynamic>`, which causes a `TypeError` and crashes the build, leading to a blank white screen.

**Why:** User reported the IB Wallet Screen showing a blank white screen. The root cause was `...plans.map((p) => _buildPlanCard(p as Map<String, dynamic>))`.
**How to apply:** Use type-checking and fallback instead of casting: `...plans.map((p) => _buildPlanCard(p is Map ? p : {}))` and change the widget parameter to `Map` (without generics).
