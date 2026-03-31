# Fix the screenshot build errors

## Features

- [x] Restore a successful app build by fixing the screenshot and outcome-status logic.
- [x] Keep screenshot capture quality and compression behavior working as it does now.
- [x] Ensure each screenshot outcome still shows the correct status color and label.

## Design

- [x] No visual redesign.
- [x] Keep the current screenshot feed, badges, and labels looking the same.
- [x] Limit the work to build-breaking issues only.

## Pages / Screens

- [x] Screenshot feed: keep status chips and labels rendering correctly.
- [x] Automation flows: keep screenshot capture running without changing the user flow.
- [x] Debug views: preserve existing screenshot data and display behavior.
