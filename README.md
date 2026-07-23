# ⚠️ DO NOT DELETE — CI DEPENDS ON THIS BRANCH

This branch (`native-libs-win`) acts as a dedicated binary cache for the Windows CI pipeline.

It contains compiled `.dll` files (`tdjson.dll`, `avutil-58.dll`, etc.) that are too large or inappropriate to commit to the `main` branch. 

During the automated GitHub Actions build process, the CI runner specifically checks out this branch to download the required Windows binaries and places them into the runner's build directory (`windows/runner/libs/`) so that the application can compile successfully.

If this branch is deleted or modified incorrectly, the **Windows Release CI will crash** and fail to produce executable artifacts.

### How to update binaries
If you ever need to update the core TDLib or FFmpeg binaries:
1. Compile the new DLLs.
2. Checkout this branch locally.
3. Replace the old DLLs with the new ones.
4. Commit and push directly to this branch.
