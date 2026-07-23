# DO NOT DELETE — CI DEPENDS ON THIS BRANCH

This branch (`native-libs-win`) contains critical pre-compiled Windows DLLs required by the application's video playback system (`MediaKit`). 

The CI/CD pipeline dynamically fetches these DLLs during the Windows build process. **Deleting or modifying this branch will cause the Windows release builds to fail.**

## Why are these here?
Because GitHub Actions Windows runners often lack the correct dependencies or take too long to compile complex media libraries from scratch. Hosting them on a separate orphan branch keeps the `main` branch lightweight while ensuring stable, fast CI/CD builds for Windows.

If you need to update the DLLs:
1. Compile the new DLLs locally.
2. Checkout this branch.
3. Replace the old DLLs and commit directly to this branch.
4. Do NOT merge this branch into `main`.
