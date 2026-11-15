# Deviations from the legacy mod

Every place where the port behaves differently from Preparations 6.2, with the reason, who decided and when, and a question for the original author (wghost81) where their intent is unclear. Add an entry whenever the port deviates, in the same commit.

"Owner" is this project's owner; "porter's call" means not yet confirmed by the owner.

| # | Feature | Legacy | Port | Why | Decided | Question for the author |
|---|---|---|---|---|---|---|
| 1 | PREP-MENU | The defaults come from `user.settings` lines the player pastes by hand; without them most options are off | Every option has its default in script (legacy's "Defaults" preset, the same values); options never set get it when a save loads, and the reads fall back to it | No manual install step; same values as legacy's install | Porter's call (as planned in [port-plan.md](port-plan.md)), not confirmed by the owner | None |
