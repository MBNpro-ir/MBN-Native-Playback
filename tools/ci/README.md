# CircleCI native dependency build

Submit `.circleci/config.yml` with `run-mode: native` on main to build the pinned
Windows LGPL core, verify licenses, execute the Wine seek/frame smoke tests,
and retain binaries, complete corresponding sources, inventory and checksums.
`publish: true` additionally publishes those exact files to the existing LGPL
GitHub repository. Application source is not included.

`run-mode: android-sources` preserves the Android corresponding-sources job.
Normal pushes select `none`, so application releases do not rebuild unchanged
third-party dependencies. Change native source pins only when needed. Cache
reuse never replaces license verification or the native smoke tests.

This build runs in CircleCI Linux; no software is installed on the retired VPS.
The GitHub publication token is restricted to this CircleCI project and main.
Keep published LGPL sources available for as long as the binaries are distributed.
