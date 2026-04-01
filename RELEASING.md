# Release Process

We (maintainers) plan to release a new version of wasi-sdk every three months,
coinciding with our monthly meeting to discuss latest issues and pull requests.
This provides regularity to the release cadence, though we also reserve the
right to publish at any intervening time if there is a pressing need (i.e., open
an issue to discuss).

To publish a new version of `wasi-sdk` as a GitHub release:

1. Tag a commit with an annotated tag. Note that this must be an annotated tag,
   not a lightweight tag, so that `version.py` can use it for calculating the
   package version (use `git show wasi-sdk-...` to show other tag messages).
   Note that you may need to clear the repository cache to avoid problems with
   cached artifacts [^cache].

   ```shell script
   TAG=wasi-sdk-1
   git tag -a $TAG
   git push origin $TAG
   ```

2. Wait for the CI build of the tag to finish. This will automatically publish
   a draft pre-release to [GitHub Releases](https://github.com/WebAssembly/wasi-sdk/releases).
   Release notes are auto-generated and should be reviewed for accuracy. Once
   everything looks good manually publish the release through the GitHub UI.

3. Remember to tag the wasi-libc repository with the new `$TAG` version.

   ```shell script
   git submodule status -- src/wasi-libc  # grab $WASI_LIBC_COMMIT from the output
   cd $WASI_LIBC_REPO_DIR
   git tag $TAG $WASI_LIBC_COMMIT
   git push origin $TAG
   ```

[^cache]: Here is an example of how to clear a cache with the GitHub CLI:

    ```shell script
    URL=/repos/WebAssembly/wasi-sdk/actions/caches
    gh api $URL -q '.actions_caches[].id' \
       | xargs -I {} gh api --method DELETE $URL/{}
    ```
