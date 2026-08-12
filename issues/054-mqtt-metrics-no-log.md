---
title: Add no_log to the mqtt_metrics secret-rendering task
status: open
priority: low
created: 2026-08-12
closed: null
labels: [epic:services]
---

## Description

The mqtt_metrics role templates the collector's MQTT password into its config
file without `no_log`, unlike every other secret-rendering task in this codebase
(restic, edge_stack, compose_stack). The rendered file itself is correctly locked
down (root-only, mode 0600), but a verbose or diff-mode playbook run would print
the plaintext password to the console/log — exactly what the `no_log` convention
elsewhere exists to prevent.

## Acceptance criteria

- [ ] The task rendering the MQTT credential into the collector's config has
      `no_log: true`, consistent with the rest of the codebase's secret-handling
      convention.
- [ ] Running the role with `-vvv`/`--diff` no longer surfaces the plaintext MQTT
      password.
