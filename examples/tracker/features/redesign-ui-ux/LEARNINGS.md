# LEARNINGS — shift-scheduler (lane redesign-ui-ux)

> Durable, **verified** facts only — things a future session could not cheaply re-derive: gotchas,
> landmines, environment quirks, decisions-with-why that keep paying rent. NOT a diary — session
> narrative belongs in `sessions/`; open problems belong in ISSUES.md; the current plan belongs in
> STATUS.md. Newest first.
>
> **Entry format (one bullet per learning):**
> `- (sNN, YYYY-MM-DD) **<topic>** — <the fact> · *verified by:* <command run / file:line / doc §>`
>
> A learning without its verification is a guess — mark it `(unverified)` explicitly or leave it
> out. Routing: lane-specific learnings go in that lane's LEARNINGS.md, not here.

- (s01, 2026-07-15) **Any UI control scaling `solver_det_time_limit` must scale `solver_time_limit` by the same factor** — the engine's determinism requires the deterministic limit to bind before the wall-clock safety net (designed headroom 180/24 = 7.5×); scaling only the det budget made 120-unit solves machine-dependent (a UI-reachable config consumed the full budget at wall 81s on a fast machine) · *verified by:* scheduler.py:156-162 + reviewer probe run (status=FEASIBLE, det_used=120.00, wall=81.19s)
- (s01, 2026-07-15) **Duplicate employee names are NOT checked by engine preflight** and crash the web grid (`Styler.map` raises KeyError on a non-unique DataFrame index) or yield a self-contradictory all-PASS roster; the wizard gates Continue in Setup on unique names · *verified by:* end-to-end repro in review + `targeted_checks.py` dup-names scenario (0 failures)
- (s01, 2026-07-15) **`st.data_editor` seed must be stable across reruns** — rebuilding `data=` from a session-state mirror each rerun flips the editor's element identity one run after every edit, silently reverting the second of two consecutive edits; seed once per step entry, capture the return value into the mirror · *verified by:* element-id probe (w_emp id stable across 3 mirror-changing reruns post-fix, flipped pre-fix)
- (s01, 2026-07-15) **Streamlit garbage-collects session_state entries of widgets not rendered on the current run** — wizard steps must persist inputs into plain (non-widget) keys on navigation and re-seed widget defaults from them · *verified by:* harness.py Back-navigation scenarios (S5, 0 failures)
- (s01, 2026-07-15) **AppTest artifact:** leaving a step whose `data_editor` feeds a `multiselect` corrupts AppTest's element tree (KeyError in `get_widget_states` on stale unmounted nodes) — an AppTest defect, not the app; work around by skipping GC'd nodes during widget-state serialization + a settle rerun per navigation. AppTest also has no `data_editor`/`download_button` accessors · *verified by:* minimal repro in review (runtime-verify seat) + harness workaround in `harness.py`
- (s01, 2026-07-15) **AppTest's `SafeSessionState` has no `.get()`** — use `"key" in at.session_state` · *verified by:* AttributeError in harness.py pre-fix run
