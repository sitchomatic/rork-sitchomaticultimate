# Update the fingerprint screen link to the current iOS navigation style

**Features**

- Tapping the fingerprint button will still open the same fingerprint test screen.
- Navigation will use the app’s current modern pattern so the remaining outdated warning is removed.
- The behavior and layout of the screen will stay the same.

**Design**

- No visual redesign.
- Keep the existing toolbar button, icon, spacing, and dark appearance unchanged.
- Only the navigation wiring behind that button will be modernized.

**Pages / Screens**

- **IP Score Test**: keeps the fingerprint button in the top bar.
- **Fingerprint Test**: opens from that button using the updated navigation flow.

**Part 3 scope**

- [x] Replace the old fingerprint button navigation pattern with the newer value-based navigation style.
- [x] Add the matching destination mapping on the same screen so the route remains explicit and consistent.
- [x] Leave all other warnings and screens untouched for now.

